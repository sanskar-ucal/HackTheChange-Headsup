// Chess demo timeline (Scholar's Mate): every frame is a pure function of time, so the loop is easy to pause.
import { bump, clamp, easeInOut, easeOut, lerp } from "@/lib/hooks";

export type Pt = { x: number; y: number };
export type PieceType = "K" | "Q" | "R" | "B" | "N" | "P";
export type Color = "w" | "b";
export type Piece = { id: string; type: PieceType; color: Color; sq: string };

// Screen is a 640 × 400 SVG viewBox.
export const SQ = 40;
export const BX = 36;
export const BY = 46;

export const center = (sq: string): Pt => {
  const col = sq.charCodeAt(0) - 97;
  const rank = Number(sq[1]);
  return { x: BX + col * SQ + SQ / 2, y: BY + (8 - rank) * SQ + SQ / 2 };
};

const BACK: PieceType[] = ["R", "N", "B", "Q", "K", "B", "N", "R"];
const FILES = "abcdefgh";

export const INITIAL: Piece[] = [
  ...BACK.map((type, i) => ({ id: `w${type}${FILES[i]}`, type, color: "w" as const, sq: `${FILES[i]}1` })),
  ...[...FILES].map((f) => ({ id: `wP${f}`, type: "P" as const, color: "w" as const, sq: `${f}2` })),
  ...BACK.map((type, i) => ({ id: `b${type}${FILES[i]}`, type, color: "b" as const, sq: `${FILES[i]}8` })),
  ...[...FILES].map((f) => ({ id: `bP${f}`, type: "P" as const, color: "b" as const, sq: `${f}7` })),
];

type Move = { from: string; to: string; color: Color; san: string };
export const MOVES: Move[] = [
  { from: "e2", to: "e4", color: "w", san: "e4" },
  { from: "e7", to: "e5", color: "b", san: "e5" },
  { from: "f1", to: "c4", color: "w", san: "Bc4" },
  { from: "b8", to: "c6", color: "b", san: "Nc6" },
  { from: "d1", to: "h5", color: "w", san: "Qh5" },
  { from: "g8", to: "f6", color: "b", san: "Nf6" },
  { from: "h5", to: "f7", color: "w", san: "Qxf7#" },
];

type Seg =
  | { k: "still"; s: number; e: number; at: Pt }
  | { k: "glide"; s: number; e: number; from: Pt; to: Pt; bend: number; phase: number }
  | { k: "nod"; s: number; e: number; at: Pt };

type MoveTiming = { lift?: number; slideStart: number; slideEnd: number };

const D = {
  lead: 0.45,
  nod: 0.5,
  register: 0.12,
  slide: 0.3,
  blackPause: 0.32,
  blackSlide: 0.38,
  blackTail: 0.1,
  mateHold: 1.9,
  fade: 0.45,
};

const glideDur = (a: Pt, b: Pt) => clamp(0.42 + Math.hypot(b.x - a.x, b.y - a.y) * 0.0016, 0.5, 0.9);

// HeadsUp doesn't snap to targets, so the cursor aims slightly off each square's center.
const AIM_OFFSETS: [number, number][] = [[4, -5], [-5, 3], [3, 6], [-4, -3], [6, 2], [-2, 5], [5, -2], [-6, -4]];
const aim = (sq: string, k: number): Pt => {
  const c = center(sq);
  const [dx, dy] = AIM_OFFSETS[k % AIM_OFFSETS.length];
  return { x: c.x + dx, y: c.y + dy };
};

export const REST: Pt = { x: 382, y: 214 };

function build() {
  const segs: Seg[] = [];
  const timings: MoveTiming[] = [];
  let t = 0;
  let pos = REST;
  segs.push({ k: "still", s: 0, e: D.lead, at: pos });
  t = D.lead;
  let seed = 0;

  for (const m of MOVES) {
    if (m.color === "w") {
      const from = aim(m.from, seed);
      const to = aim(m.to, seed + 1);
      let d = glideDur(pos, from);
      segs.push({ k: "glide", s: t, e: t + d, from: pos, to: from, bend: seed++ % 2 ? 1 : -1, phase: seed * 1.7 });
      t += d;
      segs.push({ k: "nod", s: t, e: t + D.nod, at: from });
      const lift = t + D.register;
      t += D.nod;
      d = glideDur(from, to);
      segs.push({ k: "glide", s: t, e: t + d, from, to, bend: seed++ % 2 ? 1 : -1, phase: seed * 1.7 });
      t += d;
      segs.push({ k: "nod", s: t, e: t + D.nod, at: to });
      const slideStart = t + D.register;
      timings.push({ lift, slideStart, slideEnd: slideStart + D.slide });
      t += D.nod;
      pos = to;
    } else {
      const total = D.blackPause + D.blackSlide + D.blackTail;
      segs.push({ k: "still", s: t, e: t + total, at: pos });
      const slideStart = t + D.blackPause;
      timings.push({ slideStart, slideEnd: slideStart + D.blackSlide });
      t += total;
    }
  }
  const mateAt = timings[timings.length - 1].slideEnd;
  segs.push({ k: "still", s: t, e: t + D.mateHold, at: pos });
  t += D.mateHold;
  const fadeStart = t;
  t += D.fade;
  return { segs, timings, mateAt, fadeStart, duration: t };
}

const SCRIPT = build();
export const DURATION = SCRIPT.duration;

export type Frame = {
  opacity: number;
  cursor: Pt;
  pressed: number;
  ripple: { at: Pt; p: number } | null;
  head: { yaw: number; pitch: number; label: "look" | "nod" };
  pieces: { piece: Piece; at: Pt; lift: number; opacity: number }[];
  selected: string | null;
  hint: string | null;
  lastMove: [string, string] | null;
  movesDone: number;
  mate: number;
  toast: number;
  turn: Color;
};

function cursorAt(t: number) {
  const seg = SCRIPT.segs.find((s) => t >= s.s && t < s.e) ?? SCRIPT.segs[SCRIPT.segs.length - 1];
  if (seg.k === "still") return { pos: seg.at, head: { yaw: 0, pitch: 0, label: "look" as const }, nod: null };
  if (seg.k === "nod") {
    const p = (t - seg.s) / (seg.e - seg.s);
    // Head dips down and back up; cursor stays perfectly still.
    const dip = bump(clamp(p / 0.62));
    return { pos: seg.at, head: { yaw: 0, pitch: dip * 1.1, label: "nod" as const }, nod: { s: seg.s, at: seg.at, p } };
  }
  const p = (t - seg.s) / (seg.e - seg.s);
  const e = easeInOut(p);
  const dx = seg.to.x - seg.from.x;
  const dy = seg.to.y - seg.from.y;
  const len = Math.hypot(dx, dy) || 1;
  const nx = -dy / len;
  const ny = dx / len;
  // Gentle arc plus a tiny natural wobble, both zero at the endpoints.
  const env = bump(p);
  const off = seg.bend * env * Math.min(len * 0.07, 14) + env * 1.3 * Math.sin(2 * Math.PI * 2.2 * p + seg.phase);
  const pos = { x: lerp(seg.from.x, seg.to.x, e) + nx * off, y: lerp(seg.from.y, seg.to.y, e) + ny * off };
  const look = Math.pow(env, 0.6);
  return { pos, head: { yaw: (dx / len) * look, pitch: (dy / len) * look * 0.8, label: "look" as const }, nod: null };
}

export function frameAt(t: number): Frame {
  const { timings, mateAt, fadeStart } = SCRIPT;
  const c = cursorAt(t);

  const map = new Map<string, Piece>(INITIAL.map((p) => [p.id, { ...p }]));
  const bySq = () => {
    const m = new Map<string, Piece>();
    map.forEach((p) => m.set(p.sq, p));
    return m;
  };
  const extra = new Map<string, { at?: Pt; lift?: number; opacity?: number }>();
  let selected: string | null = null;
  let hint: string | null = null;
  let lastMove: [string, string] | null = null;
  let movesDone = 0;
  let turn: Color = "w";

  MOVES.forEach((m, i) => {
    const tm = timings[i];
    const squares = bySq();
    const mover = squares.get(m.from);
    if (!mover) return;
    const victim = squares.get(m.to);
    if (t >= tm.slideEnd) {
      if (victim) map.delete(victim.id);
      mover.sq = m.to;
      lastMove = [m.from, m.to];
      movesDone = i + 1;
      turn = m.color === "w" ? "b" : "w";
      return;
    }
    if (tm.lift !== undefined && t >= tm.lift && t < tm.slideStart) {
      const p = easeOut(clamp((t - tm.lift) / 0.18));
      extra.set(mover.id, { lift: p });
      selected = m.from;
      hint = m.to;
    }
    if (t >= tm.slideStart) {
      const p = easeInOut(clamp((t - tm.slideStart) / (tm.slideEnd - tm.slideStart)));
      const a = center(m.from);
      const b = center(m.to);
      extra.set(mover.id, { at: { x: lerp(a.x, b.x, p), y: lerp(a.y, b.y, p) }, lift: tm.lift !== undefined ? 1 - p : 0 });
      if (victim) extra.set(victim.id, { opacity: 1 - p });
      selected = m.from;
    }
  });

  const pieces = [...map.values()].map((piece) => {
    const x = extra.get(piece.id);
    return { piece, at: x?.at ?? center(piece.sq), lift: x?.lift ?? 0, opacity: x?.opacity ?? 1 };
  });
  pieces.sort((a, b) => a.lift - b.lift + (extra.get(a.piece.id)?.at ? 1 : 0) - (extra.get(b.piece.id)?.at ? 1 : 0));

  let ripple: Frame["ripple"] = null;
  if (c.nod) {
    const rp = (t - (c.nod.s + D.register * 0.6)) / 0.55;
    if (rp >= 0 && rp <= 1) ripple = { at: c.nod.at, p: rp };
  }

  const opacity = t < 0.35 ? t / 0.35 : t >= fadeStart ? 1 - clamp((t - fadeStart) / D.fade) : 1;

  return {
    opacity,
    cursor: c.pos,
    pressed: c.nod ? bump(clamp(c.nod.p / 0.7)) : 0,
    ripple,
    head: c.head,
    pieces,
    selected,
    hint,
    lastMove,
    movesDone,
    mate: clamp((t - mateAt) / 0.4),
    toast: easeOut(clamp((t - mateAt - 0.25) / 0.35)),
    turn,
  };
}

/** Reduced-motion still: checkmate with the cursor on the queen. */
export const MATE_FRAME: Frame = (() => {
  const f = frameAt(SCRIPT.fadeStart - 0.01);
  return { ...f, opacity: 1, ripple: null, pressed: 0, head: { yaw: 0, pitch: 0, label: "nod" } };
})();

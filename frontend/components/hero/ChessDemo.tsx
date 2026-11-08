"use client";

import { useInView } from "framer-motion";
import { memo, useRef } from "react";
import { useLoopClock, usePrefersReducedMotion } from "@/lib/hooks";
import { BX, BY, DURATION, MATE_FRAME, MOVES, SQ, center, frameAt, type Color, type Frame, type PieceType } from "./chessScript";

const NAVY = "#0B1A30";
const PALE = "#E6EFFB";
const SKY = "#A8C6F0";
const LINE = "#C9D8EE";
const MUTED = "#46546A";
const POINTER = "#33D959";

/** Simple geometric chess pieces drawn in a 40 × 40 box. */
function PieceShape({ type, color }: { type: PieceType; color: Color }) {
  const fill = color === "w" ? "#FFFFFF" : NAVY;
  const detail = color === "w" ? NAVY : PALE;
  const s = { fill, stroke: NAVY, strokeWidth: 1.4, strokeLinejoin: "round" as const };
  const base = <rect x={10.5} y={30.5} width={19} height={4} rx={1.6} {...s} />;
  switch (type) {
    case "P":
      return (
        <g>
          <path d="M14.5 31 C15.5 25 17.5 22.5 17.5 21 H22.5 C22.5 22.5 24.5 25 25.5 31 Z" {...s} />
          <circle cx={20} cy={16} r={5} {...s} />
          {base}
        </g>
      );
    case "R":
      return (
        <g>
          <path d="M14.5 31 L15.5 18 H24.5 L25.5 31 Z" {...s} />
          <path d="M12.5 10 H16 V13 H18.3 V10 H21.7 V13 H24 V10 H27.5 V18 H12.5 Z" {...s} />
          {base}
        </g>
      );
    case "B":
      return (
        <g>
          <path d="M15 31 C16 27 17 24.5 17 22.5 H23 C23 24.5 24 27 25 31 Z" {...s} />
          <path d="M20 8.5 C24.8 12.5 26 17.5 23.6 22.5 H16.4 C14 17.5 15.2 12.5 20 8.5 Z" {...s} />
          <circle cx={20} cy={6.6} r={2} {...s} />
          <path d="M21.6 13.4 L18.4 17.4" stroke={detail} strokeWidth={1.3} strokeLinecap="round" />
          {base}
        </g>
      );
    case "N":
      return (
        <g>
          <path d="M13.5 31 C13.5 25.5 16.5 22.5 18.6 19.6 C15.8 20.6 12.6 20.4 11.4 17.8 C12.4 14.4 16 10.8 19.6 9 L20.6 5.6 L22.8 8.6 C27.2 9.6 29.2 14.6 28.4 20.4 C27.8 24.8 27.4 28 27.6 31 Z" {...s} />
          <circle cx={19.6} cy={12.8} r={1.1} fill={detail} />
          {base}
        </g>
      );
    case "Q":
      return (
        <g>
          <path d="M14 24.5 H26 L27 31 H13 Z" {...s} />
          <path d="M11 13.5 L14 24.5 H26 L29 13.5 L24.2 19.6 L20 10.6 L15.8 19.6 Z" {...s} />
          <circle cx={11} cy={12.4} r={2} {...s} />
          <circle cx={20} cy={9.2} r={2} {...s} />
          <circle cx={29} cy={12.4} r={2} {...s} />
          {base}
        </g>
      );
    case "K":
      return (
        <g>
          <path d="M13.5 31 C13.5 25 14.5 19.5 15.6 17 H24.4 C25.5 19.5 26.5 25 26.5 31 Z" {...s} />
          <rect x={14} y={14} width={12} height={3.4} rx={1} {...s} />
          <path d="M20 4.5 V12.5 M16.8 7.6 H23.2" stroke={NAVY} strokeWidth={4} strokeLinecap="round" />
          <path d="M20 4.5 V12.5 M16.8 7.6 H23.2" stroke={fill} strokeWidth={1.6} strokeLinecap="round" />
          {base}
        </g>
      );
  }
}

/** Static 8×8 board, memoized so only pieces and cursor re-render. */
const Board = memo(function Board() {
  const squares = [];
  for (let r = 0; r < 8; r++) {
    for (let c = 0; c < 8; c++) {
      squares.push(<rect key={`${r}${c}`} x={BX + c * SQ} y={BY + r * SQ} width={SQ} height={SQ} fill={(r + c) % 2 ? SKY : PALE} />);
    }
  }
  return (
    <g>
      <rect x={BX - 6} y={BY - 6} width={SQ * 8 + 12} height={SQ * 8 + 12} rx={8} fill="#FFFFFF" stroke={LINE} />
      {squares}
    </g>
  );
});

/** Navy tint over one square (selection, last move). */
function SquareTint({ sq, opacity }: { sq: string; opacity: number }) {
  const c = center(sq);
  return <rect x={c.x - SQ / 2} y={c.y - SQ / 2} width={SQ} height={SQ} fill={NAVY} opacity={opacity} />;
}

/** Side panel with the moves so far and whose turn it is. */
function MoveList({ done, turn, mate }: { done: number; turn: Color; mate: boolean }) {
  const rows = [];
  for (let i = 0; i < MOVES.length; i += 2) {
    rows.push({ n: i / 2 + 1, w: i < done ? MOVES[i].san : "", b: i + 1 < done ? (MOVES[i + 1]?.san ?? "") : "" });
  }
  const x = 410;
  return (
    <g fontSize={11} fill={NAVY}>
      <rect x={x - 8} y={BY - 6} width={210} height={196} rx={10} fill="#FFFFFF" stroke={LINE} />
      <text x={x + 6} y={BY + 16} fontSize={9.5} fontWeight={600} letterSpacing={1.2} fill={MUTED}>
        MOVES
      </text>
      {rows.map((r, i) => (
        <g key={r.n} transform={`translate(${x + 6} ${BY + 42 + i * 24})`}>
          <text fill={MUTED}>{r.n}.</text>
          <text x={26} fontWeight={600}>{r.w}</text>
          <text x={92}>{r.b}</text>
        </g>
      ))}
      <line x1={x + 6} x2={x + 188} y1={BY + 146} y2={BY + 146} stroke={PALE} />
      <circle cx={x + 11} cy={BY + 167} r={4} fill={mate || turn === "b" ? NAVY : "#FFFFFF"} stroke={NAVY} strokeWidth={1.2} />
      <text x={x + 22} y={BY + 171} fill={MUTED}>
        {mate ? "White wins" : turn === "w" ? "White to move" : "Black to move"}
      </text>
    </g>
  );
}

/** Abstract input readout: AirPods outline, the current gesture and its direction. */
function AirPodsPill({ head }: { head: Frame["head"] }) {
  const nod = head.label === "nod";
  const angle = Math.atan2(head.pitch, head.yaw) * (180 / Math.PI);
  const moving = Math.hypot(head.yaw, head.pitch) > 0.15;
  return (
    <g transform="translate(402 290)">
      <rect width={210} height={56} rx={28} fill={NAVY} />
      <g transform="translate(16 12)" stroke={SKY} strokeWidth={1.6} fill="none" strokeLinejoin="round">
        <rect x={0} y={0} width={10} height={11} rx={5} />
        <rect x={3.5} y={9} width={4} height={14} rx={2} />
        <rect x={14} y={0} width={10} height={11} rx={5} />
        <rect x={16.5} y={9} width={4} height={14} rx={2} />
      </g>
      <text x={54} y={25} fontSize={10} fill={SKY} fontWeight={600} letterSpacing={0.8}>
        AIRPODS
      </text>
      <text x={54} y={42} fontSize={13} fill="#FFFFFF" fontWeight={600}>
        {nod ? "Nod → click" : moving ? "Looking" : "Holding still"}
      </text>
      <g transform="translate(182 28)">
        <circle r={14} fill={nod ? POINTER : "#1B3152"} />
        {nod ? (
          <path d="M-5 0 L-1 4 L6 -4" stroke={NAVY} strokeWidth={2.2} fill="none" strokeLinecap="round" strokeLinejoin="round" />
        ) : (
          <g transform={`rotate(${angle})`} opacity={moving ? 1 : 0.35}>
            <path d="M-6 0 H5 M1 -4 L5 0 L1 4" stroke={SKY} strokeWidth={2} fill="none" strokeLinecap="round" strokeLinejoin="round" />
          </g>
        )}
      </g>
    </g>
  );
}

/** Board, pieces, cursor, ripple and toast for one frame. */
function Scene({ f }: { f: Frame }) {
  const mate = f.mate > 0;
  const e8 = center("e8");
  return (
    <>
      <g opacity={f.opacity}>
        <Board />
        {f.lastMove && (
          <>
            <SquareTint sq={f.lastMove[0]} opacity={0.08} />
            <SquareTint sq={f.lastMove[1]} opacity={0.14} />
          </>
        )}
        {f.selected && <SquareTint sq={f.selected} opacity={0.2} />}
        {mate && (
          <rect x={e8.x - SQ / 2 + 1.5} y={e8.y - SQ / 2 + 1.5} width={SQ - 3} height={SQ - 3} rx={3} fill="none" stroke={NAVY} strokeWidth={2.5} opacity={f.mate} />
        )}
        {f.hint && <circle cx={center(f.hint).x} cy={center(f.hint).y} r={5} fill={NAVY} opacity={0.3} />}

        {f.pieces.map(({ piece, at, lift, opacity }) => (
          <g key={piece.id} opacity={opacity} transform={`translate(${at.x - 20} ${at.y - 20 - lift * 4})`}>
            {lift > 0 && <ellipse cx={20} cy={36 + lift * 3} rx={9 + lift * 2} ry={2.4} fill={NAVY} opacity={0.18 * lift} />}
            <g transform={`translate(20 20) scale(${1 + lift * 0.08}) translate(-20 -20)`}>
              <PieceShape type={piece.type} color={piece.color} />
            </g>
          </g>
        ))}

        <MoveList done={f.movesDone} turn={f.turn} mate={mate} />

        {f.ripple && (
          <circle cx={f.ripple.at.x} cy={f.ripple.at.y} r={10 + 22 * f.ripple.p} fill="none" stroke={POINTER} strokeWidth={2.5 * (1 - f.ripple.p) + 0.5} opacity={0.9 * (1 - f.ripple.p)} />
        )}
        <g transform={`translate(${f.cursor.x} ${f.cursor.y})`}>
          <circle r={12.5} fill="none" stroke={NAVY} strokeWidth={1.5} opacity={0.55} />
          <circle r={11} fill={POINTER} opacity={0.3 + f.pressed * 0.25} />
          <circle r={11} fill="none" stroke={POINTER} strokeWidth={2.4} />
          <circle r={2.6} fill={POINTER} />
        </g>

        {f.toast > 0 && (
          <g opacity={f.toast} transform={`translate(${BX + SQ * 4} ${BY + SQ * 8 - 26 - f.toast * 8})`}>
            <rect x={-94} y={-17} width={188} height={34} rx={17} fill={NAVY} />
            <text y={4.2} textAnchor="middle" fontSize={12.5} fill="#FFFFFF" fontWeight={600}>
              Checkmate. No hands.
            </text>
          </g>
        )}
      </g>
      <AirPodsPill head={f.head} />
    </>
  );
}

/** Hero demo; the loop pauses off-screen and shows a still frame for reduced motion. */
export function ChessDemo() {
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { amount: 0.15 });
  const reduced = usePrefersReducedMotion();
  const t = useLoopClock(inView && !reduced, DURATION);
  const f = reduced ? MATE_FRAME : frameAt(t);

  return (
    <div ref={ref} className="h-full w-full">
      <svg
        viewBox="0 0 640 400"
        className="block h-full w-full"
        role="img"
        aria-label="Animated demo: HeadsUp moving chess pieces with head nods"
        style={{ fontFamily: "var(--font-inter), system-ui, sans-serif" }}
      >
        <rect width={640} height={400} fill="#F4F8FD" />
        <rect width={640} height={28} fill="#D6E3F6" />
        {[16, 32, 48].map((x) => (
          <circle key={x} cx={x} cy={14} r={4.5} fill="#B5C8E4" />
        ))}
        <text x={320} y={18} textAnchor="middle" fontSize={11} fontWeight={600} fill={NAVY}>
          Chess
        </text>
        <Scene f={f} />
      </svg>
    </div>
  );
}

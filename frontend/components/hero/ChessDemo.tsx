"use client";

import { useInView } from "framer-motion";
import { memo, useRef } from "react";
import { HeadGlyph } from "@/components/HeadGlyph";
import { useLoopClock, usePrefersReducedMotion } from "@/lib/hooks";
import { BX, BY, DURATION, MATE_FRAME, MOVES, SQ, center, frameAt, type Color, type Frame, type PieceType } from "./chessScript";

const INK = "#1D1C1A";
const PAPER = "#F3EFE6";
const SAGE = "#A9B79A";
const GREEN = "#2E7D5B";

/** Simple geometric pieces drawn in a 40 × 40 box. */
function PieceShape({ type, color }: { type: PieceType; color: Color }) {
  const fill = color === "w" ? "#FFFFFF" : INK;
  const detail = color === "w" ? INK : PAPER;
  const s = { fill, stroke: INK, strokeWidth: 1.4, strokeLinejoin: "round" as const };
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
          <path d="M20 4.5 V12.5 M16.8 7.6 H23.2" stroke={INK} strokeWidth={4} strokeLinecap="round" />
          <path d="M20 4.5 V12.5 M16.8 7.6 H23.2" stroke={fill} strokeWidth={1.6} strokeLinecap="round" />
          {base}
        </g>
      );
  }
}

const Board = memo(function Board() {
  const squares = [];
  for (let r = 0; r < 8; r++) {
    for (let c = 0; c < 8; c++) {
      squares.push(
        <rect key={`${r}${c}`} x={BX + c * SQ} y={BY + r * SQ} width={SQ} height={SQ} fill={(r + c) % 2 ? SAGE : PAPER} />,
      );
    }
  }
  return (
    <g>
      <rect x={BX - 6} y={BY - 6} width={SQ * 8 + 12} height={SQ * 8 + 12} rx={6} fill="#FFFFFF" stroke="#DDD6C8" />
      {squares}
      {"abcdefgh".split("").map((f, i) => (
        <text key={f} x={BX + i * SQ + SQ - 3.5} y={BY + 8 * SQ - 3.5} fontSize={7.5} textAnchor="end" fill={i % 2 ? "#5C6B52" : "#7A8670"}>
          {f}
        </text>
      ))}
      {[8, 7, 6, 5, 4, 3, 2, 1].map((n, i) => (
        <text key={n} x={BX + 3} y={BY + i * SQ + 10} fontSize={7.5} fill={i % 2 ? "#7A8670" : "#5C6B52"}>
          {n}
        </text>
      ))}
    </g>
  );
});

function SquareTint({ sq, fill, opacity = 1 }: { sq: string; fill: string; opacity?: number }) {
  const c = center(sq);
  return <rect x={c.x - SQ / 2} y={c.y - SQ / 2} width={SQ} height={SQ} fill={fill} opacity={opacity} />;
}

function MoveList({ done, turn, mate }: { done: number; turn: Color; mate: boolean }) {
  const rows = [];
  for (let i = 0; i < MOVES.length; i += 2) {
    rows.push({ n: i / 2 + 1, w: i < done ? MOVES[i].san : "", b: i + 1 < done ? (MOVES[i + 1]?.san ?? "") : "" });
  }
  const x = 410;
  return (
    <g fontSize={11} fill={INK}>
      <rect x={x - 8} y={BY - 6} width={210} height={196} rx={8} fill="#FFFFFF" stroke="#DDD6C8" />
      <text x={x + 6} y={BY + 16} fontSize={9.5} letterSpacing={1.2} fill="#5C5850">
        MOVES
      </text>
      {rows.map((r, i) => (
        <g key={r.n} transform={`translate(${x + 6} ${BY + 42 + i * 24})`}>
          <text fill="#8A857B">{r.n}.</text>
          <text x={26} fontWeight={600}>
            {r.w}
          </text>
          <text x={92}>{r.b}</text>
        </g>
      ))}
      <line x1={x + 6} x2={x + 188} y1={BY + 146} y2={BY + 146} stroke="#EAE4D8" />
      <circle cx={x + 11} cy={BY + 167} r={4} fill={mate ? GREEN : turn === "w" ? "#FFFFFF" : INK} stroke={INK} strokeWidth={1.2} />
      <text x={x + 22} y={BY + 171} fill="#5C5850">
        {mate ? "White wins" : turn === "w" ? "White to move · HeadsUp" : "Black to move"}
      </text>
    </g>
  );
}

function Scene({ f }: { f: Frame }) {
  const mate = f.mate > 0;
  return (
    <>
      <g opacity={f.opacity}>
        <Board />
        {f.lastMove && (
          <>
            <SquareTint sq={f.lastMove[0]} fill={GREEN} opacity={0.16} />
            <SquareTint sq={f.lastMove[1]} fill={GREEN} opacity={0.24} />
          </>
        )}
        {f.selected && <SquareTint sq={f.selected} fill={GREEN} opacity={0.32} />}
        {mate && (
          <g opacity={f.mate}>
            <SquareTint sq="e8" fill={GREEN} opacity={0.38} />
            <rect x={center("e8").x - SQ / 2 + 1.5} y={center("e8").y - SQ / 2 + 1.5} width={SQ - 3} height={SQ - 3} fill="none" stroke={GREEN} strokeWidth={2} rx={3} />
          </g>
        )}
        {f.hint && <circle cx={center(f.hint).x} cy={center(f.hint).y} r={5} fill={GREEN} opacity={0.45} />}

        {f.pieces.map(({ piece, at, lift, opacity }) => (
          <g key={piece.id} opacity={opacity} transform={`translate(${at.x - 20} ${at.y - 20 - lift * 4}) `}>
            {lift > 0 && <ellipse cx={20} cy={36 + lift * 3} rx={9 + lift * 2} ry={2.4} fill={INK} opacity={0.14 * lift} />}
            <g transform={`translate(20 20) scale(${1 + lift * 0.08}) translate(-20 -20)`}>
              <PieceShape type={piece.type} color={piece.color} />
            </g>
          </g>
        ))}

        <MoveList done={f.movesDone} turn={f.turn} mate={mate} />

        {/* HeadsUp cursor */}
        {f.ripple && (
          <circle cx={f.ripple.at.x} cy={f.ripple.at.y} r={9 + 22 * f.ripple.p} fill="none" stroke={GREEN} strokeWidth={2.5 * (1 - f.ripple.p) + 0.5} opacity={0.7 * (1 - f.ripple.p)} />
        )}
        <g transform={`translate(${f.cursor.x} ${f.cursor.y})`}>
          <circle r={11} fill={GREEN} opacity={0.22 + f.pressed * 0.2} />
          <circle r={11} fill="none" stroke={GREEN} strokeWidth={2} />
          <circle r={2.6} fill={GREEN} />
        </g>

        {f.toast > 0 && (
          <g opacity={f.toast} transform={`translate(${BX + SQ * 4} ${BY + SQ * 8 - 24 - f.toast * 8})`}>
            <rect x={-92} y={-17} width={184} height={34} rx={17} fill="#FFFFFF" stroke="#DDD6C8" filter="url(#chess-shadow)" />
            <circle cx={-74} cy={0} r={4} fill={GREEN} />
            <text x={8} y={4.2} textAnchor="middle" fontSize={12.5} fill={INK} fontWeight={500}>
              Checkmate. No hands.
            </text>
          </g>
        )}
      </g>

      {/* Head indicator badge */}
      <g transform="translate(507 318)">
        <circle r={44} fill="#FFFFFF" stroke="#DDD6C8" filter="url(#chess-shadow)" />
        <g clipPath="url(#badge-clip)">
          <HeadGlyph y={-12} scale={1.05} yaw={f.head.yaw} pitch={f.head.pitch} />
        </g>
        <rect x={-17} y={22} width={34} height={14} rx={7} fill={f.head.label === "nod" ? GREEN : "#EFEAE0"} />
        <text y={32} textAnchor="middle" fontSize={9} fontWeight={600} letterSpacing={0.6} fill={f.head.label === "nod" ? "#FFFFFF" : "#4A4740"}>
          {f.head.label}
        </text>
      </g>
    </>
  );
}

export function ChessDemo() {
  const ref = useRef<HTMLDivElement>(null);
  // IntersectionObserver-backed: the loop only runs while the demo is on screen.
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
        <defs>
          <filter id="chess-shadow" x="-30%" y="-30%" width="160%" height="170%">
            <feDropShadow dx={0} dy={3} stdDeviation={4} floodColor={INK} floodOpacity={0.12} />
          </filter>
          <clipPath id="badge-clip">
            <circle r={40} />
          </clipPath>
        </defs>
        <rect width={640} height={400} fill={PAPER} />
        {/* Minimal window bar */}
        <rect width={640} height={28} fill="#E9E4DA" />
        <line x1={0} x2={640} y1={28} y2={28} stroke="#DDD6C8" />
        {[16, 32, 48].map((x) => (
          <circle key={x} cx={x} cy={14} r={4.5} fill="#CFC8BA" />
        ))}
        <text x={320} y={18} textAnchor="middle" fontSize={11} fontWeight={500} fill="#4A4740">
          Chess
        </text>
        <Scene f={f} />
      </svg>
    </div>
  );
}

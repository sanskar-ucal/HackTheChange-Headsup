"use client";

import { useState } from "react";
import { gestures, type GestureId } from "@/content/site";
import { clamp, easeInOut, useLoopClock, useNoHover, usePrefersReducedMotion } from "@/lib/hooks";
import { Reveal } from "./Reveal";
import { Emph, Eyebrow, POINTER_FILL, POINTER_RING } from "./ui";

const NAVY = "#0B1A30";
const SKY = "#A8C6F0";

// Loop length of each gesture demo, in seconds.
const PERIOD: Record<GestureId, number> = { look: 4, nod: 2, shake: 2.2, tiltLeft: 3.2, tiltRight: 3.2, edge: 3.4 };

type Pose = {
  dot: { x: number; y: number };
  arrow: number | null;
  roll: number;
  ripple: number;
  progress: number;
  flag: number;
  scroll: number;
};

/** Mini screen spans x 70–190, y 10–100; C is its center. */
const C = { x: 130, y: 55 };

/** Each pose function returns a resting pose at t = 0; `still` is the reduced-motion frame. */
function pose(id: GestureId, t: number, still: boolean): Pose {
  const p: Pose = { dot: { ...C }, arrow: null, roll: 0, ripple: -1, progress: 0, flag: 0, scroll: 0 };
  // Ramps 0 → 1 at `start`, holds for `len`, then ramps back to 0.
  const hold = (start: number, ramp: number, len: number) =>
    clamp((t - start) / ramp) * (1 - clamp((t - start - ramp - len) / ramp));

  switch (id) {
    case "look": {
      if (still) return { ...p, dot: { x: C.x + 26, y: C.y - 16 }, arrow: -30 };
      const a = (t / PERIOD.look) * Math.PI * 2;
      p.dot = { x: C.x + Math.sin(a) * 34, y: C.y + Math.sin(a * 2) * 22 };
      p.arrow = (Math.atan2(Math.cos(a * 2) * 44, Math.cos(a) * 34) * 180) / Math.PI;
      return p;
    }
    case "nod": {
      if (still) return { ...p, arrow: 90, ripple: 0.3 };
      const n = clamp((t - 0.35) / 0.5);
      p.arrow = n > 0 && n < 1 ? (n < 0.5 ? 90 : -90) : null;
      p.ripple = t >= 0.55 && t < 1.2 ? (t - 0.55) / 0.65 : -1;
      return p;
    }
    case "shake": {
      if (still) return { ...p, arrow: 180, flag: 1 };
      const s = clamp((t - 0.25) / 0.8);
      p.arrow = s > 0 && s < 1 ? (Math.cos(s * Math.PI * 4) > 0 ? 0 : 180) : null;
      p.flag = hold(1.05, 0.12, 0.6);
      return p;
    }
    case "tiltLeft":
    case "tiltRight": {
      const dir = id === "tiltLeft" ? -1 : 1;
      const drift = { x: C.x + 30, y: C.y + 18 };
      if (still) return { ...p, roll: 20 * dir, progress: 1, flag: 1, dot: id === "tiltRight" ? { ...C } : drift };
      p.roll = 20 * dir * easeInOut(hold(0.2, 0.35, 1.5));
      p.progress = t > 0.55 && t < 2.05 ? clamp((t - 0.55) / 1.5) : 0;
      p.flag = hold(2.05, 0.15, 0.7);
      const back = id === "tiltRight" ? easeInOut(clamp((t - 2.05) / 0.45)) : 0;
      p.dot = { x: drift.x + (C.x - drift.x) * back, y: drift.y + (C.y - drift.y) * back };
      return p;
    }
    case "edge": {
      if (still) return { ...p, dot: { x: C.x, y: 16 }, arrow: -90, flag: 1, scroll: 8 };
      const h = hold(0.3, 0.4, 1.8);
      p.dot = { x: C.x, y: C.y - (C.y - 16) * easeInOut(h) };
      p.arrow = h > 0.5 ? -90 : null;
      p.flag = h;
      p.scroll = t < 2.7 ? Math.max(0, t - 0.6) * 14 : 14 * 2.1;
      return p;
    }
  }
}

/** Mini screen with the green pointer, plus an AirPods chip showing the head movement. */
function Scene({ id, t, still }: { id: GestureId; t: number; still: boolean }) {
  const s = pose(id, t, still);
  const paused = id === "tiltLeft" && s.flag > 0.5;
  return (
    <svg viewBox="0 0 200 110" aria-hidden className="h-full w-full">
      <rect x={70} y={10} width={120} height={90} rx={10} fill="#E6EFFB" />
      <clipPath id={`clip-${id}`}>
        <rect x={70} y={10} width={120} height={90} rx={10} />
      </clipPath>
      <g clipPath={`url(#clip-${id})`}>
        {id === "edge" &&
          Array.from({ length: 9 }, (_, i) => {
            const y = ((i * 14 + s.scroll) % 126) - 6;
            return <rect key={i} x={84} y={y} width={i % 3 === 0 ? 56 : 82} height={5} rx={2.5} fill="#C9D8EE" />;
          })}
        {id === "shake" && (
          <g opacity={0.35 + s.flag * 0.65}>
            <rect x={110} y={40} width={40} height={28} rx={7} fill={s.flag > 0.5 ? NAVY : "#C9D8EE"} />
            <text x={130} y={58.5} textAnchor="middle" fontSize={12} fontWeight={700} fill={s.flag > 0.5 ? "#FFFFFF" : NAVY}>
              esc
            </text>
          </g>
        )}
        {id === "tiltRight" && (
          <g stroke="#9DB3D3" strokeWidth={1}>
            <line x1={C.x - 10} x2={C.x + 10} y1={C.y} y2={C.y} />
            <line x1={C.x} x2={C.x} y1={C.y - 10} y2={C.y + 10} />
          </g>
        )}
        {s.ripple >= 0 && (
          <circle cx={s.dot.x} cy={s.dot.y} r={9 + 16 * s.ripple} fill="none" stroke={POINTER_RING} strokeWidth={2.5} opacity={1 - s.ripple} />
        )}
        {s.progress > 0 && (
          <circle cx={s.dot.x} cy={s.dot.y} r={15} fill="none" stroke={NAVY} strokeWidth={3} strokeLinecap="round"
            strokeDasharray={`${s.progress * 94} 94`} transform={`rotate(-90 ${s.dot.x} ${s.dot.y})`} />
        )}
        <g transform={`translate(${s.dot.x} ${s.dot.y})`} opacity={paused ? 0.45 : 1}>
          <circle r={9} fill={POINTER_FILL} opacity={0.75} />
          <circle r={9} fill="none" stroke={POINTER_RING} strokeWidth={2.2} />
          <circle r={2.2} fill={POINTER_RING} />
          {paused && (
            <g transform="translate(9 -10)">
              <circle r={7} fill={NAVY} />
              <rect x={-3} y={-3.5} width={2.2} height={7} fill="#FFFFFF" />
              <rect x={0.8} y={-3.5} width={2.2} height={7} fill="#FFFFFF" />
            </g>
          )}
        </g>
      </g>

      <g transform="translate(32 55)">
        <circle r={26} fill="#1B3152" />
        <g transform={`rotate(${s.roll}) translate(-12 -13)`} stroke={SKY} strokeWidth={1.7} fill="none" strokeLinejoin="round">
          <rect x={0} y={0} width={10} height={11} rx={5} />
          <rect x={3.5} y={9} width={4} height={15} rx={2} />
          <rect x={14} y={0} width={10} height={11} rx={5} />
          <rect x={16.5} y={9} width={4} height={15} rx={2} />
        </g>
        {s.arrow !== null && (
          <g transform={`rotate(${s.arrow}) translate(34 0)`}>
            <path d="M-4 -5 L3 0 L-4 5" stroke={SKY} strokeWidth={2.2} fill="none" strokeLinecap="round" strokeLinejoin="round" />
          </g>
        )}
      </g>
    </svg>
  );
}

/** One gesture row; its demo plays on hover or focus, and always on touch screens. */
function GestureRow({ item, index }: { item: (typeof gestures.items)[number]; index: number }) {
  const [hovered, setHovered] = useState(false);
  const noHover = useNoHover();
  const reduced = usePrefersReducedMotion();
  const t = useLoopClock(!reduced && (hovered || noHover), PERIOD[item.id], true);
  const titleId = `gesture-${item.id}`;

  return (
    <Reveal as="li" delay={index * 0.04}>
      <article
        tabIndex={0}
        aria-labelledby={titleId}
        onPointerEnter={() => setHovered(true)}
        onPointerLeave={() => setHovered(false)}
        onFocus={() => setHovered(true)}
        onBlur={() => setHovered(false)}
        className="grid items-center gap-6 rounded-[28px] bg-navy-2 p-5 transition-colors duration-300 hover:bg-navy-3 sm:grid-cols-[minmax(0,15rem)_1fr] sm:p-6"
      >
        <div className="aspect-[20/11] rounded-[20px] bg-navy p-2">
          <Scene id={item.id} t={t} still={reduced} />
        </div>
        <div>
          <div className="flex flex-wrap items-center gap-3">
            <h3 id={titleId} className="display text-[2rem]">
              {item.name}
            </h3>
            <p className="rounded-full bg-sky px-3 py-1 text-sm font-semibold text-navy">{item.action}</p>
          </div>
          <p className="mt-3 leading-relaxed text-white/75">{item.body}</p>
        </div>
      </article>
    </Reveal>
  );
}

/** Navy section: sticky intro and the six gesture rows. */
export function Gestures() {
  return (
    <section id="gestures" aria-labelledby="gestures-title" className="on-dark bg-navy text-white">
      <div className="mx-auto grid max-w-7xl gap-14 px-5 py-24 sm:px-8 sm:py-32 lg:grid-cols-[1fr_1.45fr] lg:gap-20">
        <Reveal className="lg:sticky lg:top-32 lg:self-start">
          <Eyebrow tone="dark">{gestures.eyebrow}</Eyebrow>
          <h2 id="gestures-title" className="display text-[clamp(2.75rem,5.5vw,4.5rem)]">
            <Emph text={gestures.title} />
          </h2>
          <p className="mt-6 max-w-md text-lg leading-relaxed text-white/75">{gestures.body}</p>
        </Reveal>
        <ul className="space-y-4">
          {gestures.items.map((g, i) => (
            <GestureRow key={g.id} item={g} index={i} />
          ))}
        </ul>
      </div>
    </section>
  );
}

"use client";

import { useState } from "react";
import { gestures, type GestureId } from "@/content/site";
import { bump, clamp, easeInOut, useLoopClock, useNoHover, usePrefersReducedMotion } from "@/lib/hooks";
import { HeadGlyph } from "./HeadGlyph";
import { Reveal } from "./Reveal";
import { SectionHeading } from "./ui";

const GREEN = "#2E7D5B";
const INK = "#1D1C1A";

const PERIOD: Record<GestureId, number> = { look: 4, nod: 2, shake: 2.2, tiltLeft: 3.2, tiltRight: 3.2, edge: 3.4 };

type Pose = { yaw: number; pitch: number; roll: number; dot: { x: number; y: number }; ripple: number; progress: number; flag: number; scroll: number };

/** Mini screen sits at x 104–188, y 18–92. Its center is (146, 55). */
const C = { x: 146, y: 55 };

/** Each pose function returns the resting pose at t = 0, and `still` is shown for reduced motion. */
function pose(id: GestureId, t: number, still: boolean): Pose {
  const p: Pose = { yaw: 0, pitch: 0, roll: 0, dot: { ...C }, ripple: -1, progress: 0, flag: 0, scroll: 0 };
  const hold = (start: number, ramp: number, len: number) =>
    clamp((t - start) / ramp) * (1 - clamp((t - start - ramp - len) / ramp));

  switch (id) {
    case "look": {
      if (still) return { ...p, yaw: 0.6, pitch: -0.3, dot: { x: C.x + 22, y: C.y - 14 } };
      const a = (t / PERIOD.look) * Math.PI * 2;
      p.yaw = Math.sin(a) * 0.75;
      p.pitch = Math.sin(a * 2) * 0.45;
      p.dot = { x: C.x + p.yaw * 30, y: C.y + p.pitch * 28 };
      return p;
    }
    case "nod": {
      if (still) return { ...p, pitch: 0.9, ripple: 0.3 };
      p.pitch = bump(clamp((t - 0.35) / 0.5)) * 1.05;
      p.ripple = t >= 0.55 && t < 1.2 ? (t - 0.55) / 0.65 : -1;
      return p;
    }
    case "shake": {
      if (still) return { ...p, yaw: -0.5, flag: 1 };
      const s = clamp((t - 0.25) / 0.8);
      p.yaw = Math.sin(s * Math.PI * 4) * 0.75 * bump(s);
      p.flag = hold(1.05, 0.12, 0.6);
      return p;
    }
    case "tiltLeft":
    case "tiltRight": {
      const dir = id === "tiltLeft" ? -1 : 1;
      if (still) return { ...p, roll: 20 * dir, progress: 1, flag: 1, dot: id === "tiltRight" ? { ...C } : p.dot };
      const r = hold(0.2, 0.35, 1.5);
      p.roll = 20 * dir * easeInOut(r);
      p.progress = t > 0.55 ? clamp((t - 0.55) / 1.5) * (t < 2.05 ? 1 : 0) : 0;
      p.flag = hold(2.05, 0.15, 0.7);
      if (id === "tiltRight") {
        // Drifted dot glides back to center once the hold completes.
        const back = easeInOut(clamp((t - 2.05) / 0.45));
        p.dot = { x: C.x + 24 * (1 - back), y: C.y + 14 * (1 - back) };
      }
      return p;
    }
    case "edge": {
      if (still) return { ...p, pitch: -0.9, dot: { x: C.x, y: 22 }, flag: 1, scroll: 8 };
      const h = hold(0.3, 0.4, 1.8);
      p.pitch = -0.9 * easeInOut(h);
      p.dot = { x: C.x, y: C.y - (C.y - 22) * easeInOut(h) };
      p.flag = h;
      p.scroll = Math.max(0, t - 0.6) * 14 * (t < 2.7 ? 1 : 0) + (t >= 2.7 ? 14 * 2.1 : 0);
      return p;
    }
  }
}

function Scene({ id, t, still }: { id: GestureId; t: number; still: boolean }) {
  const s = pose(id, t, still);
  return (
    <svg viewBox="0 0 200 110" aria-hidden className="h-full w-full">
      <HeadGlyph x={52} y={50} scale={1.35} yaw={s.yaw} pitch={s.pitch} roll={s.roll} />
      {s.progress > 0 && (
        <circle cx={52} cy={50} r={28} fill="none" stroke={GREEN} strokeWidth={3} strokeLinecap="round" strokeDasharray={`${s.progress * 176} 176`} transform="rotate(-90 52 50)" />
      )}

      {/* Mini screen */}
      <rect x={104} y={18} width={84} height={74} rx={7} fill="#FFFFFF" stroke="#DDD6C8" />
      <clipPath id={`clip-${id}`}>
        <rect x={104} y={18} width={84} height={74} rx={7} />
      </clipPath>
      <g clipPath={`url(#clip-${id})`}>
        {id === "edge" &&
          Array.from({ length: 9 }, (_, i) => {
            const y = ((i * 14 + s.scroll) % 126) + 4;
            return <rect key={i} x={116} y={y} width={i % 3 === 0 ? 46 : 60} height={5} rx={2.5} fill="#EAE4D8" />;
          })}
        {id === "shake" && (
          <g opacity={0.25 + s.flag * 0.75}>
            <rect x={128} y={42} width={36} height={26} rx={6} fill={s.flag > 0.5 ? GREEN : "#EFEAE0"} />
            <text x={146} y={59} textAnchor="middle" fontSize={11} fontWeight={600} fill={s.flag > 0.5 ? "#FFFFFF" : INK}>
              esc
            </text>
          </g>
        )}
        {id === "tiltLeft" && (
          <g opacity={s.flag} transform={`translate(${C.x} ${C.y})`}>
            <circle r={15} fill="#E3ECE3" />
            <rect x={-6} y={-7} width={4} height={14} rx={1.5} fill={GREEN} />
            <rect x={2} y={-7} width={4} height={14} rx={1.5} fill={GREEN} />
          </g>
        )}
        {id === "tiltRight" && (
          <g stroke="#C9C2B4" strokeWidth={1}>
            <line x1={C.x - 10} x2={C.x + 10} y1={C.y} y2={C.y} />
            <line x1={C.x} x2={C.x} y1={C.y - 10} y2={C.y + 10} />
          </g>
        )}
        {id === "edge" && (
          <path d={`M${C.x - 7} 30 L${C.x} 24 L${C.x + 7} 30`} transform="translate(0 -1)" stroke={GREEN} strokeWidth={2} fill="none" strokeLinecap="round" opacity={s.flag} />
        )}
        {s.ripple >= 0 && (
          <circle cx={s.dot.x} cy={s.dot.y} r={7 + 16 * s.ripple} fill="none" stroke={GREEN} strokeWidth={2} opacity={0.8 * (1 - s.ripple)} />
        )}
        {!(id === "tiltLeft" && s.flag > 0.5) && (
          <g transform={`translate(${s.dot.x} ${s.dot.y})`} opacity={id === "tiltLeft" ? 1 - s.flag : 1}>
            <circle r={7} fill={GREEN} opacity={0.25} />
            <circle r={7} fill="none" stroke={GREEN} strokeWidth={1.6} />
            <circle r={1.8} fill={GREEN} />
          </g>
        )}
      </g>
    </svg>
  );
}

function GestureCard({ item, index }: { item: (typeof gestures.items)[number]; index: number }) {
  const [hovered, setHovered] = useState(false);
  const noHover = useNoHover();
  const reduced = usePrefersReducedMotion();
  const active = !reduced && (hovered || noHover);
  const t = useLoopClock(active, PERIOD[item.id], true);
  const titleId = `gesture-${item.id}`;

  return (
    <Reveal as="li" delay={(index % 3) * 0.06}>
      <article
        tabIndex={0}
        aria-labelledby={titleId}
        onPointerEnter={() => setHovered(true)}
        onPointerLeave={() => setHovered(false)}
        onFocus={() => setHovered(true)}
        onBlur={() => setHovered(false)}
        className="group h-full rounded-[1.4rem] bg-white p-6 shadow-[var(--shadow-card)] ring-1 ring-line/60 transition-[box-shadow,transform] duration-300 hover:-translate-y-0.5 hover:shadow-[var(--shadow-lift)] focus-visible:-translate-y-0.5"
      >
        <div className="aspect-[20/11] rounded-2xl bg-paper p-2">
          <Scene id={item.id} t={t} still={reduced} />
        </div>
        <div className="mt-5 flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1">
          <h3 id={titleId} className="text-xl font-semibold tracking-tight">
            {item.name}
          </h3>
          <p className="rounded-full bg-accent-wash px-3 py-1 text-sm font-medium text-accent-ink">{item.action}</p>
        </div>
        <p className="mt-3 leading-relaxed text-ink-soft">{item.body}</p>
      </article>
    </Reveal>
  );
}

export function Gestures() {
  return (
    <section id="gestures" aria-labelledby="gestures-title" className="bg-paper-deep/60 py-24 sm:py-32">
      <div className="mx-auto max-w-6xl px-5 sm:px-8">
        <Reveal>
          <SectionHeading id="gestures-title" eyebrow={gestures.eyebrow} titleStart={gestures.titleStart} titleEmphasis={gestures.titleEmphasis} body={gestures.body} />
        </Reveal>
        <ul className="mt-14 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {gestures.items.map((g, i) => (
            <GestureCard key={g.id} item={g} index={i} />
          ))}
        </ul>
      </div>
    </section>
  );
}

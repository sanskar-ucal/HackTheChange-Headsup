"use client";

import { motion } from "framer-motion";
import type { ComponentType } from "react";
import { usePrefersReducedMotion } from "@/lib/hooks";
import { features, type FeatureId } from "@/content/site";
import { Reveal } from "./Reveal";
import { SectionHeading } from "./ui";

const GREEN = "#2E7D5B";

function Cursor({ size = 22, color = GREEN }: { size?: number; color?: string }) {
  return (
    <span
      className="relative block rounded-full border-2"
      style={{ width: size, height: size, borderColor: color, background: `${color}40` }}
    >
      <span className="absolute left-1/2 top-1/2 h-1.5 w-1.5 -translate-x-1/2 -translate-y-1/2 rounded-full" style={{ background: color }} />
    </span>
  );
}

function VoiceMock() {
  const reduced = usePrefersReducedMotion();
  return (
    <div className="flex h-full flex-col justify-center gap-5 p-6 sm:p-10">
      <div className="relative flex h-14 items-center gap-3 rounded-full bg-white px-5 shadow-[var(--shadow-card)] ring-2 ring-accent/60">
        <svg aria-hidden viewBox="0 0 20 20" className="h-5 w-5 text-ink-soft" fill="none" stroke="currentColor" strokeWidth={1.8}>
          <circle cx={9} cy={9} r={5.5} />
          <path d="m13 13 4 4" strokeLinecap="round" />
        </svg>
        <span className="text-ink">
          weather tomorrow
          <motion.span
            aria-hidden
            className="ml-0.5 inline-block h-5 w-[2px] translate-y-1 bg-ink"
            animate={reduced ? undefined : { opacity: [1, 0, 1] }}
            transition={{ duration: 1, repeat: Infinity }}
          />
        </span>
        <span className="absolute -bottom-4 right-10 flex items-center">
          <Cursor />
          <span className="-ml-2 -mt-5 flex h-6 w-6 items-center justify-center rounded-full bg-accent text-white">
            <svg aria-hidden viewBox="0 0 20 20" className="h-3.5 w-3.5" fill="currentColor">
              <rect x={7} y={2.5} width={6} height={10} rx={3} />
              <path d="M4.5 9.5a5.5 5.5 0 0 0 11 0M10 15v2.5" stroke="currentColor" strokeWidth={1.6} fill="none" strokeLinecap="round" />
            </svg>
          </span>
        </span>
      </div>
      <div className="ml-auto mr-4 max-w-[15rem] rounded-2xl rounded-tr-sm bg-ink px-4 py-3 text-[0.95rem] text-paper">
        &ldquo;weather tomorrow&rdquo;
        <span className="mt-1 block text-xs text-paper/70">Nod to search · shake to undo</span>
      </div>
    </div>
  );
}

function PointerMock() {
  return (
    <div className="flex h-full flex-col justify-center gap-6 p-6 sm:p-10">
      <svg viewBox="0 0 300 110" aria-hidden className="w-full">
        <motion.path
          d="M12 92 C60 92 70 30 120 34 C170 38 170 82 220 76 C250 72 262 40 286 24"
          fill="none"
          stroke={GREEN}
          strokeWidth={2.5}
          strokeLinecap="round"
          initial={{ pathLength: 0 }}
          whileInView={{ pathLength: 1 }}
          viewport={{ once: true }}
          transition={{ duration: 1.8, ease: "easeInOut" }}
        />
        <circle cx={286} cy={24} r={10} fill={GREEN} opacity={0.25} />
        <circle cx={286} cy={24} r={10} fill="none" stroke={GREEN} strokeWidth={2} />
        <circle cx={286} cy={24} r={2.5} fill={GREEN} />
      </svg>
      <div className="rounded-2xl bg-white p-5 shadow-[var(--shadow-card)]">
        <div className="flex items-center justify-between text-sm font-medium">
          <span>Sensitivity</span>
          <span className="text-ink-soft">Balanced</span>
        </div>
        <div className="mt-4 flex items-center gap-3">
          <span className="flex h-9 w-9 items-center justify-center rounded-full bg-paper text-lg" aria-hidden>
            −
          </span>
          <div className="relative h-2 flex-1 rounded-full bg-paper-deep">
            <div className="absolute inset-y-0 left-0 w-[55%] rounded-full bg-accent" />
            <div className="absolute left-[55%] top-1/2 h-6 w-6 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-accent bg-white shadow" />
          </div>
          <span className="flex h-9 w-9 items-center justify-center rounded-full bg-paper text-lg" aria-hidden>
            +
          </span>
        </div>
        <div className="mt-2 flex justify-between text-xs text-ink-soft">
          <span>Calmer</span>
          <span>Faster</span>
        </div>
      </div>
    </div>
  );
}

function ScrollMock() {
  return (
    <div className="relative h-full overflow-hidden p-6 sm:p-10">
      <div className="absolute left-1/2 top-4 z-10 flex -translate-x-1/2 flex-col items-center gap-1">
        <svg aria-hidden viewBox="0 0 20 12" className="h-3 w-5 text-accent" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round">
          <path d="M3 10 10 3l7 7" />
        </svg>
        <Cursor />
      </div>
      <motion.div
        className="mt-10 space-y-4 rounded-2xl bg-white p-5 shadow-[var(--shadow-card)]"
        animate={{ y: [0, 24, 0] }}
        transition={{ duration: 5, repeat: Infinity, ease: "easeInOut" }}
      >
        <div className="h-3 w-2/3 rounded-full bg-ink/80" />
        {Array.from({ length: 7 }, (_, i) => (
          <div key={i} className="h-2.5 rounded-full bg-paper-deep" style={{ width: `${[92, 84, 96, 70, 88, 94, 60][i]}%` }} />
        ))}
      </motion.div>
    </div>
  );
}

function StylesMock() {
  const swatches = ["#2E7D5B", "#1D1C1A", "#B4532A", "#2F5E9E"];
  const glyphs = [
    { label: "Green circle", el: <Cursor size={28} /> },
    {
      label: "Hand",
      el: (
        <svg viewBox="0 0 24 24" className="h-8 w-8" aria-hidden>
          <path
            d="M9 11V4.5a1.5 1.5 0 0 1 3 0V10m0-.5V3.5a1.5 1.5 0 0 1 3 0V10m0-.5V5a1.5 1.5 0 0 1 3 0v8c0 4-2.5 7-6.5 7-2.6 0-4-1.2-5.5-3.2L3.6 13a1.6 1.6 0 0 1 2.5-2L9 14"
            fill="#FFFFFF"
            stroke="#1D1C1A"
            strokeWidth={1.4}
            strokeLinejoin="round"
            strokeLinecap="round"
          />
        </svg>
      ),
    },
    { label: "Ring", el: <span className="block h-7 w-7 rounded-full border-[3px] border-accent" /> },
    { label: "Dot", el: <span className="block h-3.5 w-3.5 rounded-full bg-accent" /> },
    {
      label: "Crosshair",
      el: (
        <svg viewBox="0 0 24 24" className="h-8 w-8" aria-hidden stroke={GREEN} strokeWidth={2} strokeLinecap="round">
          <path d="M12 2v7M12 15v7M2 12h7M15 12h7" />
        </svg>
      ),
    },
  ];
  return (
    <div className="flex h-full flex-col justify-center gap-5 p-6 sm:p-10">
      <ul className="grid grid-cols-3 gap-3 sm:grid-cols-5">
        {glyphs.map((g, i) => (
          <li key={g.label} className={`flex flex-col items-center gap-2 rounded-2xl bg-white px-2 py-4 shadow-[var(--shadow-card)] ${i === 0 ? "ring-2 ring-accent" : ""}`}>
            <span className="flex h-9 items-center">{g.el}</span>
            <span className="text-xs text-ink-soft">{g.label}</span>
          </li>
        ))}
      </ul>
      <div className="flex items-center gap-3 rounded-2xl bg-white px-5 py-4 shadow-[var(--shadow-card)]">
        <span className="text-sm font-medium">Color</span>
        <span className="ml-auto flex gap-2">
          {swatches.map((c, i) => (
            <span key={c} className={`h-7 w-7 rounded-full ${i === 0 ? "ring-2 ring-ink ring-offset-2" : ""}`} style={{ background: c }} />
          ))}
        </span>
      </div>
    </div>
  );
}

function AudioMock() {
  const reduced = usePrefersReducedMotion();
  const cues = ["Click", "Paused", "Recentered"];
  return (
    <div className="flex h-full items-center justify-center gap-8 p-6 sm:p-10">
      <svg viewBox="0 0 90 120" className="h-36 w-auto shrink-0" aria-hidden>
        <rect x={22} y={14} width={34} height={40} rx={17} fill="#FFFFFF" stroke="#1D1C1A" strokeWidth={2} />
        <rect x={30} y={46} width={14} height={60} rx={7} fill="#FFFFFF" stroke="#1D1C1A" strokeWidth={2} />
        {[0, 1, 2].map((i) => (
          <motion.path
            key={i}
            d={`M${66 + i * 8} ${22 - i * 4} C${74 + i * 10} ${30} ${74 + i * 10} ${40} ${66 + i * 8} ${48 + i * 4}`}
            fill="none"
            stroke={GREEN}
            strokeWidth={2.4}
            strokeLinecap="round"
            animate={reduced ? undefined : { opacity: [0.15, 1, 0.15] }}
            transition={{ duration: 1.8, repeat: Infinity, delay: i * 0.25 }}
          />
        ))}
      </svg>
      <ul className="space-y-3">
        {cues.map((c) => (
          <li key={c} className="flex items-center gap-3 rounded-full bg-white px-4 py-2 text-sm shadow-[var(--shadow-card)]">
            <span aria-hidden className="h-2 w-2 rounded-full bg-accent" />
            {c}
          </li>
        ))}
      </ul>
    </div>
  );
}

const MOCKS: Record<FeatureId, ComponentType> = {
  voice: VoiceMock,
  pointer: PointerMock,
  scroll: ScrollMock,
  styles: StylesMock,
  audio: AudioMock,
};

export function Features() {
  return (
    <section id="features" aria-labelledby="features-title" className="mx-auto max-w-6xl px-5 py-24 sm:px-8 sm:py-32">
      <Reveal>
        <SectionHeading id="features-title" eyebrow={features.eyebrow} titleStart={features.titleStart} titleEmphasis={features.titleEmphasis} />
      </Reveal>
      <div className="mt-16 space-y-20 sm:space-y-28">
        {features.items.map((f, i) => {
          const Mock = MOCKS[f.id];
          const flip = i % 2 === 1;
          return (
            <article key={f.id} aria-labelledby={`feature-${f.id}`} className="grid items-center gap-10 md:grid-cols-2 md:gap-16">
              <Reveal className={flip ? "md:order-2" : ""}>
                <h3 id={`feature-${f.id}`} className="serif text-4xl leading-tight sm:text-5xl">
                  {f.title}
                </h3>
                <p className="mt-4 text-lg leading-relaxed text-ink-soft">{f.body}</p>
                <ul className="mt-6 space-y-3">
                  {f.points.map((p) => (
                    <li key={p} className="flex items-start gap-3">
                      <svg aria-hidden viewBox="0 0 20 20" className="mt-1 h-4 w-4 shrink-0 text-accent" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round">
                        <path d="m4 10.5 4 4 8-9" />
                      </svg>
                      {p}
                    </li>
                  ))}
                </ul>
              </Reveal>
              <Reveal delay={0.1} className={flip ? "md:order-1" : ""}>
                <div aria-hidden className="aspect-[4/3] overflow-hidden rounded-[1.6rem] bg-paper-deep ring-1 ring-line/70">
                  <Mock />
                </div>
              </Reveal>
            </article>
          );
        })}
      </div>
    </section>
  );
}

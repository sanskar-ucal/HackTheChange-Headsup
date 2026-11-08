"use client";

import { motion } from "framer-motion";
import type { ReactNode } from "react";
import { features } from "@/content/site";
import { usePrefersReducedMotion } from "@/lib/hooks";
import { Reveal } from "./Reveal";
import { AirPodsIcon, Eyebrow, POINTER_GREEN, PointerDot } from "./ui";

/** A bento tile: product snippet on top, title and one line of copy below. */
function Tile({ title, body, children, className = "", dark = false }: { title: string; body: string; children: ReactNode; className?: string; dark?: boolean }) {
  return (
    <Reveal className={`flex flex-col overflow-hidden rounded-[32px] ${dark ? "bg-navy text-white" : "bg-white text-navy"} ${className}`}>
      <div aria-hidden className="flex flex-1 items-center justify-center p-6 sm:p-8">{children}</div>
      <div className="px-7 pb-7 sm:px-8 sm:pb-8">
        <h3 className="font-[family-name:var(--font-display)] text-[1.6rem] font-bold leading-tight tracking-tight">{title}</h3>
        <p className={`mt-2 leading-relaxed ${dark ? "text-white/75" : "text-ink-soft"}`}>{body}</p>
      </div>
    </Reveal>
  );
}

/** Static copy of a Settings slider row with −/+ buttons. */
function MiniSlider({ label, value, pct, min, max }: { label: string; value: string; pct: number; min?: string; max?: string }) {
  return (
    <div>
      <div className="flex justify-between text-[0.95rem]">
        <span className="font-medium">{label}</span>
        <span className="tabular-nums text-white/60">{value}</span>
      </div>
      <div className="mt-2.5 flex items-center gap-2.5">
        <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-white/10 text-white/80">−</span>
        <div className="relative h-1.5 flex-1 rounded-full bg-white/15">
          <div className="absolute inset-y-0 left-0 rounded-full bg-sky" style={{ width: `${pct}%` }} />
          <div className="absolute top-1/2 h-5 w-5 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-sky bg-navy" style={{ left: `${pct}%` }} />
        </div>
        <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-white/10 text-white/80">+</span>
      </div>
      {min && (
        <div className="mt-1 flex justify-between px-10 text-xs text-white/50">
          <span>{min}</span>
          <span>{max}</span>
        </div>
      )}
    </div>
  );
}

/** Mirrors the real Settings window, with its actual labels and default values. */
function SettingsSnippet() {
  return (
    <div className="w-full max-w-xl overflow-hidden rounded-[20px] bg-navy-2 ring-1 ring-white/10">
      <div className="flex items-center gap-1.5 border-b border-white/10 px-4 py-3">
        {[0, 1, 2].map((i) => (
          <span key={i} className="h-2.5 w-2.5 rounded-full bg-white/20" />
        ))}
        <span className="mx-auto pr-8 text-sm font-semibold text-white/80">HeadsUp Settings</span>
      </div>
      <div className="space-y-6 p-5 sm:p-7">
        <p className="text-xs font-semibold uppercase tracking-[0.14em] text-sky">Movement</p>
        <MiniSlider label="Sensitivity" value="0.60" pct={28} min="Calmer" max="Faster" />
        <MiniSlider label="Smoothing" value="30%" pct={30} min="Snappy" max="Smooth" />
        <p className="pt-2 text-xs font-semibold uppercase tracking-[0.14em] text-sky">Gestures</p>
        <MiniSlider label="Hold after click" value="0.40 s" pct={27} />
        <div className="flex items-center gap-3">
          <span className="flex h-6 w-6 items-center justify-center rounded-md bg-sky text-navy">
            <svg viewBox="0 0 20 20" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth={2.6} strokeLinecap="round" strokeLinejoin="round">
              <path d="m4.5 10.5 3.5 3.5 7.5-8" />
            </svg>
          </span>
          <span className="text-[0.95rem] font-medium">Spoken prompts</span>
        </div>
      </div>
    </div>
  );
}

/** The five real pointer styles in their default colors, plus sizes. */
function StylePicker() {
  const styles = [
    { label: "Green circle", el: <PointerDot size={26} /> },
    {
      label: "Hand",
      el: (
        <svg viewBox="0 0 24 24" className="h-7 w-7">
          <path d="M9 11V4.5a1.5 1.5 0 0 1 3 0V10m0-.5V3.5a1.5 1.5 0 0 1 3 0V10m0-.5V5a1.5 1.5 0 0 1 3 0v8c0 4-2.5 7-6.5 7-2.6 0-4-1.2-5.5-3.2L3.6 13a1.6 1.6 0 0 1 2.5-2L9 14"
            fill="#FFFFFF" stroke="#0B1A30" strokeWidth={1.4} strokeLinejoin="round" strokeLinecap="round" />
        </svg>
      ),
    },
    { label: "Ring", el: <span className="block h-6 w-6 rounded-full border-[3px] border-[#FFD71A]" /> },
    { label: "Dot", el: <span className="block h-3.5 w-3.5 rounded-full bg-[#FFD71A] ring-1 ring-navy/40" /> },
    {
      label: "Crosshair",
      el: (
        <svg viewBox="0 0 24 24" className="h-7 w-7" stroke="#FFD71A" strokeWidth={2.4} strokeLinecap="round">
          <path d="M12 2v7M12 15v7M2 12h7M15 12h7" />
        </svg>
      ),
    },
  ];
  return (
    <div className="w-full">
      <ul className="grid grid-cols-5 gap-2">
        {styles.map((s, i) => (
          <li key={s.label} className={`flex flex-col items-center gap-2 rounded-2xl bg-pale px-1 py-3 ${i === 0 ? "ring-2 ring-navy" : ""}`}>
            <span className="flex h-8 items-center">{s.el}</span>
            <span className="text-center text-[0.68rem] font-medium leading-tight text-ink-soft">{s.label}</span>
          </li>
        ))}
      </ul>
      <div className="mt-3 flex gap-2">
        {["S", "M", "L", "XL"].map((size) => (
          <span key={size} className={`flex h-9 flex-1 items-center justify-center rounded-xl text-sm font-semibold ${size === "L" ? "bg-navy text-white" : "bg-pale text-navy"}`}>
            {size}
          </span>
        ))}
      </div>
    </div>
  );
}

/** Search field with the live transcript bubble the app shows. */
function VoiceSnippet() {
  const reduced = usePrefersReducedMotion();
  return (
    <div className="w-full">
      <div className="relative flex h-12 items-center gap-3 rounded-full bg-pale px-4 ring-2 ring-navy/70">
        <svg viewBox="0 0 20 20" className="h-4 w-4 text-ink-soft" fill="none" stroke="currentColor" strokeWidth={2}>
          <circle cx={9} cy={9} r={5.5} />
          <path d="m13 13 4 4" strokeLinecap="round" />
        </svg>
        <span className="text-[0.95rem] text-navy">
          weather tomorrow
          <motion.span className="ml-0.5 inline-block h-4 w-[2px] translate-y-0.5 bg-navy"
            animate={reduced ? undefined : { opacity: [1, 0, 1] }} transition={{ duration: 1, repeat: Infinity }} />
        </span>
      </div>
      <div className="mt-3 flex items-start gap-2 pl-6">
        <PointerDot size={22} />
        <div className="rounded-xl bg-navy px-3 py-2 text-sm text-white">
          weather tomorrow
          <span className="mt-0.5 block text-xs text-white/70">Nod: search · Shake: undo</span>
        </div>
      </div>
    </div>
  );
}

/** Blink controls live view: status, eye meters with the close threshold, sequence dots. */
function EARSnippet() {
  const meter = (label: string, value: number) => (
    <div className="flex items-center gap-3 text-sm">
      <span className="w-16 text-white/70">{label}</span>
      <div className="relative h-2 flex-1 rounded-full bg-white/15">
        <div className="absolute inset-y-0 left-0 rounded-full bg-sky" style={{ width: `${value}%` }} />
        <div className="absolute -top-1 h-4 w-0.5 bg-white" style={{ left: "40%" }} />
      </div>
      <span className="w-9 text-right tabular-nums text-white/70">{(value * 0.0045).toFixed(2)}</span>
    </div>
  );
  return (
    <div className="w-full space-y-3">
      <div className="flex items-center justify-between">
        <span className="rounded-full bg-sky px-3 py-1 text-sm font-semibold text-navy">OK</span>
        <span className="flex gap-1.5" aria-hidden>
          <span className="h-2.5 w-2.5 rounded-full bg-sky" />
          <span className="h-2.5 w-2.5 rounded-full bg-sky" />
          <span className="h-2.5 w-2.5 rounded-full bg-white/25" />
        </span>
      </div>
      {meter("Left eye", 66)}
      {meter("Right eye", 63)}
      <p className="text-sm text-white/70">Last: Double blink → Click</p>
    </div>
  );
}

/** Pointer at the top edge while the page scrolls. */
function ScrollSnippet() {
  const reduced = usePrefersReducedMotion();
  return (
    <div className="relative h-36 w-full overflow-hidden rounded-2xl bg-pale">
      <div className="absolute left-1/2 top-2 z-10 -translate-x-1/2">
        <PointerDot size={22} />
      </div>
      <motion.div className="space-y-2.5 px-5 pt-12" animate={reduced ? undefined : { y: [0, 22, 0] }} transition={{ duration: 5, repeat: Infinity, ease: "easeInOut" }}>
        {[70, 92, 84, 96, 60, 88].map((w, i) => (
          <div key={i} className="h-2.5 rounded-full bg-[#C9D8EE]" style={{ width: `${w}%` }} />
        ))}
      </motion.div>
    </div>
  );
}

/** AirPods outline with the cues it plays. */
function AudioSnippet() {
  return (
    <div className="flex w-full items-center gap-5">
      <AirPodsIcon className="h-20 w-20 shrink-0 text-sky" strokeWidth={1.4} />
      <ul className="flex-1 space-y-2">
        {["Click", "Paused", "Recentered"].map((c) => (
          <li key={c} className="flex items-center gap-2.5 rounded-full bg-white/10 px-4 py-2 text-sm">
            <span className="h-2 w-2 rounded-full" style={{ background: POINTER_GREEN }} />
            {c}
          </li>
        ))}
      </ul>
    </div>
  );
}

/** Pale bento grid of product UI snippets. */
export function Features() {
  return (
    <section id="features" aria-labelledby="features-title" className="on-pale bg-pale text-navy">
      <div className="mx-auto max-w-7xl px-5 py-24 sm:px-8 sm:py-32">
        <Reveal className="grid gap-6 lg:grid-cols-[1.4fr_1fr] lg:items-end">
          <div>
            <Eyebrow tone="light">{features.eyebrow}</Eyebrow>
            <h2 id="features-title" className="display text-[clamp(2.6rem,5.5vw,4.5rem)]">
              {features.title}
            </h2>
          </div>
          <p className="max-w-md text-lg leading-relaxed text-ink-soft lg:pb-2">{features.body}</p>
        </Reveal>

        <div className="mt-14 grid gap-5 md:grid-cols-2 lg:grid-cols-6">
          <Tile dark title={features.settings.title} body={features.settings.note} className="md:col-span-2 lg:col-span-4 lg:row-span-2">
            <SettingsSnippet />
          </Tile>
          <Tile title={features.styles.title} body={features.styles.body} className="lg:col-span-2">
            <StylePicker />
          </Tile>
          <Tile title={features.voice.title} body={features.voice.body} className="lg:col-span-2">
            <VoiceSnippet />
          </Tile>
          <Tile dark title={features.blink.title} body={features.blink.body} className="lg:col-span-2">
            <EARSnippet />
          </Tile>
          <Tile title={features.scroll.title} body={features.scroll.body} className="lg:col-span-2">
            <ScrollSnippet />
          </Tile>
          <Tile dark title={features.audio.title} body={features.audio.body} className="md:col-span-2 lg:col-span-2">
            <AudioSnippet />
          </Tile>
        </div>
      </div>
    </section>
  );
}

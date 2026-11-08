"use client";

import { motion, useMotionValue, useSpring, useTransform } from "framer-motion";
import type { PointerEvent } from "react";
import { hero } from "@/content/site";
import { usePrefersReducedMotion } from "@/lib/hooks";
import { ChessDemo } from "./hero/ChessDemo";
import { Laptop } from "./Laptop";
import { Eyebrow, GitHubButton } from "./ui";

/** Navy opener: headline left, pitch right, and a large laptop playing chess below. */
export function Hero() {
  const reduced = usePrefersReducedMotion();
  const mx = useMotionValue(0);
  const my = useMotionValue(0);
  const rotateY = useSpring(useTransform(mx, [-0.5, 0.5], [-4, 4]), { stiffness: 80, damping: 18 });
  const rotateX = useSpring(useTransform(my, [-0.5, 0.5], [3, -3]), { stiffness: 80, damping: 18 });

  // Subtle tilt toward the mouse; skipped for touch and reduced motion.
  const onMove = (e: PointerEvent<HTMLElement>) => {
    if (reduced || e.pointerType !== "mouse") return;
    const r = e.currentTarget.getBoundingClientRect();
    mx.set((e.clientX - r.left) / r.width - 0.5);
    my.set((e.clientY - r.top) / r.height - 0.5);
  };

  return (
    <section
      id="top"
      aria-labelledby="hero-title"
      className="relative overflow-hidden bg-navy"
      onPointerMove={onMove}
      onPointerLeave={() => {
        mx.set(0);
        my.set(0);
      }}
    >
      <div className="mx-auto max-w-7xl px-5 pt-14 sm:px-8 sm:pt-20 lg:pt-24">
        <div className="grid items-end gap-10 lg:grid-cols-[1.35fr_1fr] lg:gap-16">
          <div className="rise">
            <Eyebrow>{hero.eyebrow}</Eyebrow>
            <h1 id="hero-title" className="display text-[clamp(3.4rem,10vw,8.25rem)]">
              {hero.headline}
            </h1>
          </div>
          <div className="rise [animation-delay:120ms] lg:pb-3">
            <p className="max-w-md text-lg leading-relaxed text-white/80 sm:text-xl">{hero.subline}</p>
            <GitHubButton label={hero.cta} className="mt-8" />
          </div>
        </div>

        <div className="rise mt-14 [animation-delay:220ms] sm:mt-20" style={{ perspective: 1600 }}>
          <motion.div style={reduced ? undefined : { rotateX, rotateY }}>
            <Laptop className="max-w-6xl">
              <ChessDemo />
            </Laptop>
          </motion.div>
        </div>

        <ul className="mx-auto flex max-w-6xl flex-wrap justify-center gap-x-10 gap-y-3 py-12 text-[0.95rem] text-white/75 sm:justify-between">
          {hero.facts.map((f) => (
            <li key={f} className="flex items-center gap-3">
              <span aria-hidden className="h-1.5 w-1.5 rounded-full bg-sky" />
              {f}
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

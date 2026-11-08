"use client";

import { motion, useMotionValue, useSpring, useTransform } from "framer-motion";
import type { PointerEvent } from "react";
import { hero } from "@/content/site";
import { usePrefersReducedMotion } from "@/lib/hooks";
import { ChessDemo } from "./hero/ChessDemo";
import { Laptop } from "./Laptop";
import { Emph, GitHubButton } from "./ui";

/** Centered opener: headline, the chess laptop sized to fit the first screen, then the pitch and the GitHub button. */
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
      className="relative overflow-hidden"
      onPointerMove={onMove}
      onPointerLeave={() => {
        mx.set(0);
        my.set(0);
      }}
    >
      <div className="mx-auto flex max-w-6xl flex-col items-center px-5 pb-16 pt-6 text-center sm:px-8 sm:pt-8">
        <h1 id="hero-title" className="display rise text-[clamp(2.75rem,5vw,4.25rem)]">
          <Emph text={hero.headline} />
        </h1>

        <div className="hero-laptop rise mt-5 [animation-delay:120ms]" style={{ perspective: 1600 }}>
          <motion.div style={reduced ? undefined : { rotateX, rotateY }}>
            <Laptop>
              <ChessDemo />
            </Laptop>
          </motion.div>
        </div>

        <p className="rise mt-6 max-w-2xl text-lg leading-relaxed text-ink-soft [animation-delay:200ms]">{hero.subline}</p>
        <GitHubButton label={hero.cta} className="rise mt-5 [animation-delay:260ms]" />

        <ul className="mt-10 flex flex-wrap justify-center gap-x-8 gap-y-2 text-[0.95rem] text-ink-soft">
          {hero.facts.map((f) => (
            <li key={f} className="flex items-center gap-2.5">
              <span aria-hidden className="h-1.5 w-1.5 rounded-full bg-blue" />
              {f}
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

"use client";

import { motion, useMotionValue, useSpring, useTransform } from "framer-motion";
import type { PointerEvent } from "react";
import { hero } from "@/content/site";
import { usePrefersReducedMotion } from "@/lib/hooks";
import { DOWNLOAD_URL, GITHUB_URL } from "@/site.config";
import { ChessDemo } from "./hero/ChessDemo";
import { Laptop } from "./Laptop";
import { ButtonLink, CodeIcon, DownloadIcon } from "./ui";

export function Hero() {
  const reduced = usePrefersReducedMotion();
  const mx = useMotionValue(0);
  const my = useMotionValue(0);
  const rotateY = useSpring(useTransform(mx, [-0.5, 0.5], [-7, 7]), { stiffness: 80, damping: 18 });
  const rotateX = useSpring(useTransform(my, [-0.5, 0.5], [5, -5]), { stiffness: 80, damping: 18 });

  const onMove = (e: PointerEvent<HTMLElement>) => {
    if (reduced || e.pointerType !== "mouse") return;
    const r = e.currentTarget.getBoundingClientRect();
    mx.set((e.clientX - r.left) / r.width - 0.5);
    my.set((e.clientY - r.top) / r.height - 0.5);
  };
  const onLeave = () => {
    mx.set(0);
    my.set(0);
  };

  return (
    <section
      id="top"
      aria-labelledby="hero-title"
      className="relative overflow-hidden"
      onPointerMove={onMove}
      onPointerLeave={onLeave}
    >
      <div className="mx-auto grid max-w-6xl items-center gap-14 px-5 pb-20 pt-14 sm:px-8 sm:pt-20 lg:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)] lg:gap-10 lg:pb-28 lg:pt-24">
        <div className="hero-in">
          <h1 id="hero-title" className="serif text-[3.6rem] leading-[0.95] sm:text-[5.2rem] lg:text-[5.6rem]">
            {hero.headlineStart} <span className="em">{hero.headlineEmphasis}</span>
          </h1>
          <p className="mt-7 max-w-[34rem] text-lg leading-relaxed text-ink-soft sm:text-xl">{hero.subline}</p>
          <div className="mt-9 flex flex-col gap-3 sm:flex-row">
            <ButtonLink href={DOWNLOAD_URL}>
              <DownloadIcon />
              {hero.primaryCta}
            </ButtonLink>
            <ButtonLink href={GITHUB_URL} variant="secondary" external>
              <CodeIcon />
              {hero.secondaryCta}
            </ButtonLink>
          </div>
          <p className="mt-6 text-sm text-ink-soft">
            {hero.smallPrint.map((s, i) => (
              <span key={s}>
                {i > 0 && <span aria-hidden className="mx-2 text-muted">·</span>}
                {s}
              </span>
            ))}
          </p>
        </div>

        <div className="hero-in [animation-delay:150ms]" style={{ perspective: 1400 }}>
          <motion.div style={reduced ? undefined : { rotateX, rotateY, transformStyle: "preserve-3d" }}>
            <Laptop>
              <ChessDemo />
            </Laptop>
          </motion.div>
        </div>
      </div>
    </section>
  );
}

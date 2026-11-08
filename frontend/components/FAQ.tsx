"use client";

import { AnimatePresence, motion } from "framer-motion";
import { useState } from "react";
import { faq } from "@/content/site";
import { Reveal } from "./Reveal";
import { SectionHeading } from "./ui";

export function FAQ() {
  const [open, setOpen] = useState<number | null>(0);

  return (
    <section id="faq" aria-labelledby="faq-title" className="bg-paper-deep/60 py-24 sm:py-32">
      <div className="mx-auto grid max-w-6xl gap-12 px-5 sm:px-8 lg:grid-cols-[0.8fr_1.2fr]">
        <Reveal>
          <SectionHeading id="faq-title" eyebrow={faq.eyebrow} titleStart={faq.titleStart} titleEmphasis={faq.titleEmphasis} />
        </Reveal>
        <Reveal delay={0.05}>
          <div className="divide-y divide-line rounded-[1.4rem] bg-white shadow-[var(--shadow-card)] ring-1 ring-line/60">
            {faq.items.map((item, i) => {
              const isOpen = open === i;
              const btnId = `faq-q-${i}`;
              const panelId = `faq-a-${i}`;
              return (
                <div key={item.q}>
                  <h3>
                    <button
                      id={btnId}
                      type="button"
                      aria-expanded={isOpen}
                      aria-controls={isOpen ? panelId : undefined}
                      onClick={() => setOpen(isOpen ? null : i)}
                      className="flex min-h-16 w-full items-center justify-between gap-6 rounded-[1.4rem] px-6 py-4 text-left text-lg font-medium transition-colors hover:text-accent-ink"
                    >
                      {item.q}
                      <span aria-hidden className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-paper transition-transform duration-300 ${isOpen ? "rotate-45" : ""}`}>
                        <svg viewBox="0 0 20 20" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round">
                          <path d="M10 4v12M4 10h12" />
                        </svg>
                      </span>
                    </button>
                  </h3>
                  <AnimatePresence initial={false}>
                    {isOpen && (
                      <motion.div
                        id={panelId}
                        role="region"
                        aria-labelledby={btnId}
                        initial={{ height: 0, opacity: 0 }}
                        animate={{ height: "auto", opacity: 1 }}
                        exit={{ height: 0, opacity: 0 }}
                        transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
                        className="overflow-hidden"
                      >
                        <p className="max-w-prose px-6 pb-6 leading-relaxed text-ink-soft">{item.a}</p>
                      </motion.div>
                    )}
                  </AnimatePresence>
                </div>
              );
            })}
          </div>
        </Reveal>
      </div>
    </section>
  );
}

"use client";

import { useEffect, useId, useState } from "react";
import { nav } from "@/content/site";
import { GitHubButton, Wordmark } from "./ui";

/** Sticky top bar with anchor links and the GitHub call to action. */
export function Nav() {
  const [open, setOpen] = useState(false);
  const menuId = useId();

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open]);

  return (
    <header className="sticky top-0 z-50 border-b border-white/10 bg-navy">
      <nav aria-label="Main" className="mx-auto flex h-[4.5rem] max-w-7xl items-center justify-between gap-4 px-5 sm:px-8">
        <a href="#top" className="-ml-2 inline-flex min-h-11 items-center rounded-lg px-2" aria-label="HeadsUp, back to top">
          <Wordmark />
        </a>

        <ul className="hidden items-center gap-1 md:flex">
          {nav.links.map((l) => (
            <li key={l.href}>
              <a href={l.href} className="inline-flex min-h-11 items-center rounded-full px-4 text-[0.95rem] font-medium text-white/80 transition-colors hover:bg-white/10 hover:text-white">
                {l.label}
              </a>
            </li>
          ))}
        </ul>

        <div className="flex items-center gap-2">
          <GitHubButton label={nav.cta} size="md" className="hidden sm:inline-flex" />
          <button
            type="button"
            className="inline-flex h-11 w-11 items-center justify-center rounded-full bg-white/10 md:hidden"
            aria-expanded={open}
            aria-controls={menuId}
            aria-label={open ? "Close menu" : "Open menu"}
            onClick={() => setOpen((o) => !o)}
          >
            <svg aria-hidden viewBox="0 0 20 20" className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth={1.9} strokeLinecap="round">
              {open ? <path d="M5 5l10 10M15 5 5 15" /> : <path d="M3.5 6.5h13M3.5 13.5h13" />}
            </svg>
          </button>
        </div>
      </nav>

      <div id={menuId} hidden={!open} className="border-t border-white/10 md:hidden">
        <ul className="mx-auto flex max-w-7xl flex-col px-5 py-3">
          {nav.links.map((l) => (
            <li key={l.href}>
              <a href={l.href} onClick={() => setOpen(false)} className="flex min-h-12 items-center rounded-lg px-2 text-lg">
                {l.label}
              </a>
            </li>
          ))}
          <li className="pt-2">
            <GitHubButton label={nav.cta} size="md" className="w-full" />
          </li>
        </ul>
      </div>
    </header>
  );
}

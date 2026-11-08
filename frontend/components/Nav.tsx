"use client";

import { useEffect, useId, useState } from "react";
import { nav } from "@/content/site";
import { DOWNLOAD_URL } from "@/site.config";
import { DownloadIcon, Wordmark } from "./ui";

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
    <header className="sticky top-0 z-50 border-b border-line/70 bg-paper/85 backdrop-blur-md supports-[backdrop-filter]:bg-paper/75">
      <nav aria-label="Main" className="mx-auto flex h-[4.25rem] max-w-6xl items-center justify-between gap-4 px-5 sm:px-8">
        <a href="#top" className="-ml-2 inline-flex min-h-11 items-center rounded-lg px-2" aria-label="HeadsUp, back to top">
          <Wordmark />
        </a>

        <ul className="hidden items-center gap-1 md:flex">
          {nav.links.map((l) => (
            <li key={l.href}>
              <a href={l.href} className="inline-flex min-h-11 items-center rounded-full px-4 text-[0.95rem] text-ink-soft transition-colors hover:bg-white hover:text-ink">
                {l.label}
              </a>
            </li>
          ))}
        </ul>

        <div className="flex items-center gap-2">
          <a
            href={DOWNLOAD_URL}
            className="hidden min-h-11 items-center gap-2 rounded-full bg-accent px-5 text-[0.95rem] font-medium text-white transition-colors hover:bg-accent-ink sm:inline-flex"
          >
            <DownloadIcon className="h-4 w-4" />
            {nav.download}
          </a>
          <button
            type="button"
            className="inline-flex h-11 w-11 items-center justify-center rounded-full bg-white ring-1 ring-line md:hidden"
            aria-expanded={open}
            aria-controls={menuId}
            aria-label={open ? "Close menu" : "Open menu"}
            onClick={() => setOpen((o) => !o)}
          >
            <svg aria-hidden viewBox="0 0 20 20" className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round">
              {open ? <path d="M5 5l10 10M15 5 5 15" /> : <path d="M3.5 6.5h13M3.5 13.5h13" />}
            </svg>
          </button>
        </div>
      </nav>

      <div id={menuId} hidden={!open} className="border-t border-line/70 bg-paper md:hidden">
        <ul className="mx-auto flex max-w-6xl flex-col px-5 py-3">
          {nav.links.map((l) => (
            <li key={l.href}>
              <a href={l.href} onClick={() => setOpen(false)} className="flex min-h-12 items-center rounded-lg px-2 text-lg">
                {l.label}
              </a>
            </li>
          ))}
          <li className="pt-2">
            <a href={DOWNLOAD_URL} className="flex min-h-12 items-center justify-center gap-2 rounded-full bg-accent px-5 font-medium text-white">
              <DownloadIcon className="h-4 w-4" />
              {nav.download}
            </a>
          </li>
        </ul>
      </div>
    </header>
  );
}

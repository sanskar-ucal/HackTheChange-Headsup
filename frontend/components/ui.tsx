import type { ReactNode } from "react";
import { GITHUB_URL } from "@/site.config";

export const POINTER_GREEN = "#33D959";

/** `< >` glyph used on GitHub links. */
export function CodeIcon({ className = "h-5 w-5" }: { className?: string }) {
  return (
    <svg aria-hidden viewBox="0 0 20 20" className={className} fill="none" stroke="currentColor" strokeWidth={1.9} strokeLinecap="round" strokeLinejoin="round">
      <path d="M7 6 3 10l4 4M13 6l4 4-4 4" />
    </svg>
  );
}

/** Right arrow; rotate it for other directions. */
export function ArrowIcon({ className = "h-4 w-4" }: { className?: string }) {
  return (
    <svg aria-hidden viewBox="0 0 20 20" className={className} fill="none" stroke="currentColor" strokeWidth={1.9} strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 10h12M11 5l5 5-5 5" />
    </svg>
  );
}

/** The site's single call to action. */
export function GitHubButton({ label, size = "lg", className = "" }: { label: string; size?: "md" | "lg"; className?: string }) {
  const sizing = size === "lg" ? "min-h-14 px-7 text-[1.05rem]" : "min-h-11 px-5 text-[0.95rem]";
  return (
    <a
      href={GITHUB_URL}
      target="_blank"
      rel="noopener noreferrer"
      className={`inline-flex items-center justify-center gap-2.5 rounded-full bg-sky font-semibold text-navy transition-[background-color,transform] duration-200 hover:bg-white active:translate-y-px ${sizing} ${className}`}
    >
      <CodeIcon className="h-[1.15em] w-[1.15em]" />
      {label}
      <span className="sr-only"> (opens in a new tab)</span>
    </a>
  );
}

/** Small uppercase label above a section title. */
export function Eyebrow({ children, tone = "dark" }: { children: ReactNode; tone?: "dark" | "light" }) {
  return (
    <p className={`mb-5 text-sm font-semibold uppercase tracking-[0.16em] ${tone === "dark" ? "text-sky" : "text-navy"}`}>
      {children}
    </p>
  );
}

/** HeadsUp's real default pointer: the green circle. */
export function PointerDot({ size = 28, className = "" }: { size?: number; className?: string }) {
  return (
    <span
      aria-hidden
      className={`relative block shrink-0 rounded-full border-[2.5px] ${className}`}
      style={{ width: size, height: size, borderColor: POINTER_GREEN, background: `${POINTER_GREEN}40` }}
    >
      <span className="absolute left-1/2 top-1/2 h-[22%] w-[22%] -translate-x-1/2 -translate-y-1/2 rounded-full" style={{ background: POINTER_GREEN }} />
    </span>
  );
}

/** Simple AirPods outline icon. */
export function AirPodsIcon({ className = "h-6 w-6", strokeWidth = 1.6 }: { className?: string; strokeWidth?: number }) {
  return (
    <svg aria-hidden viewBox="0 0 32 32" className={className} fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinejoin="round">
      <rect x={5} y={4} width={9} height={10} rx={4.5} />
      <rect x={8} y={12} width={4} height={14} rx={2} />
      <rect x={18} y={4} width={9} height={10} rx={4.5} />
      <rect x={20} y={12} width={4} height={14} rx={2} />
    </svg>
  );
}

/** Logo: a pointer ring plus the name. */
export function Wordmark({ className = "" }: { className?: string }) {
  return (
    <span className={`inline-flex items-center gap-2.5 font-[family-name:var(--font-display)] text-[1.4rem] font-bold tracking-[-0.03em] ${className}`}>
      <span aria-hidden className="relative block h-5 w-5 rounded-full border-2 border-sky bg-sky/25">
        <span className="absolute left-1/2 top-1/2 h-1.5 w-1.5 -translate-x-1/2 -translate-y-1/2 rounded-full bg-sky" />
      </span>
      HeadsUp
    </span>
  );
}

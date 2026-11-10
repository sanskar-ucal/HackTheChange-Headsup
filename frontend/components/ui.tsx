import type { ReactNode } from "react";
import { GITHUB_URL } from "@/site.config";

export const POINTER_FILL = "#A8C6F0";
export const POINTER_RING = "#3E6FB0";

/** `< >` glyph used on the GitHub button. */
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

/** The site's single GitHub link, shown under the hero description. */
export function GitHubButton({ label, className = "" }: { label: string; className?: string }) {
  return (
    <a
      href={GITHUB_URL}
      target="_blank"
      rel="noopener noreferrer"
      className={`inline-flex min-h-12 items-center justify-center gap-2.5 rounded-full bg-blue px-7 text-[1rem] font-medium text-white shadow-[0_6px_16px_-6px_rgb(62_111_176/0.6)] transition-colors duration-200 hover:bg-blue-ink active:translate-y-px ${className}`}
    >
      <CodeIcon className="h-[1.15em] w-[1.15em]" />
      {label}
      <span className="sr-only"> (opens in a new tab)</span>
    </a>
  );
}

/** Renders `*word*` spans as italic blue emphasis inside serif headings. */
export function Emph({ text }: { text: string }) {
  const parts = text.split(/\*(.+?)\*/);
  return <>{parts.map((part, i) => (i % 2 ? <span key={i} className="em">{part}</span> : part))}</>;
}

/** Small uppercase label above a section title. */
export function Eyebrow({ children, tone = "light" }: { children: ReactNode; tone?: "dark" | "light" }) {
  return (
    <p className={`mb-5 text-sm font-semibold uppercase tracking-[0.16em] ${tone === "dark" ? "text-sky" : "text-blue-ink"}`}>
      {children}
    </p>
  );
}

/** HeadsUp's circle pointer, in the site's soft blue. */
export function PointerDot({ size = 28, className = "" }: { size?: number; className?: string }) {
  return (
    <span
      aria-hidden
      className={`relative block shrink-0 rounded-full border-[2.5px] ${className}`}
      style={{ width: size, height: size, borderColor: POINTER_RING, background: `${POINTER_FILL}99` }}
    >
      <span className="absolute left-1/2 top-1/2 h-[22%] w-[22%] -translate-x-1/2 -translate-y-1/2 rounded-full" style={{ background: POINTER_RING }} />
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

/** Logo: a blue pointer dot plus the serif name. */
export function Wordmark({ className = "" }: { className?: string }) {
  return (
    <span className={`inline-flex items-center gap-2 font-serif text-[1.6rem] leading-none ${className}`}>
      <span aria-hidden className="mt-1 inline-block h-2.5 w-2.5 rounded-full bg-blue" />
      HeadsUp
    </span>
  );
}

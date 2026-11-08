import type { ReactNode } from "react";

export function DownloadIcon({ className = "h-5 w-5" }: { className?: string }) {
  return (
    <svg aria-hidden viewBox="0 0 20 20" className={className} fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round">
      <path d="M10 3v10M5.5 9 10 13.5 14.5 9M4 16.5h12" />
    </svg>
  );
}

export function ArrowIcon({ className = "h-4 w-4" }: { className?: string }) {
  return (
    <svg aria-hidden viewBox="0 0 20 20" className={className} fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 10h12M11 5l5 5-5 5" />
    </svg>
  );
}

export function CodeIcon({ className = "h-5 w-5" }: { className?: string }) {
  return (
    <svg aria-hidden viewBox="0 0 20 20" className={className} fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round">
      <path d="M7 6 3 10l4 4M13 6l4 4-4 4" />
    </svg>
  );
}

const base =
  "inline-flex min-h-12 items-center justify-center gap-2 rounded-full px-6 text-[0.975rem] font-medium transition-[background-color,box-shadow,transform] duration-200 active:translate-y-px";

export function ButtonLink({
  href,
  children,
  variant = "primary",
  className = "",
  external = false,
}: {
  href: string;
  children: ReactNode;
  variant?: "primary" | "secondary";
  className?: string;
  external?: boolean;
}) {
  const styles =
    variant === "primary"
      ? "bg-accent text-white shadow-[0_1px_0_rgb(255_255_255/0.2)_inset,0_6px_16px_-6px_rgb(46_125_91/0.6)] hover:bg-accent-ink"
      : "bg-white text-ink ring-1 ring-line shadow-[var(--shadow-card)] hover:ring-ink/30";
  return (
    <a
      href={href}
      className={`${base} ${styles} ${className}`}
      {...(external ? { target: "_blank", rel: "noopener noreferrer" } : {})}
    >
      {children}
      {external && <span className="sr-only"> (opens in a new tab)</span>}
    </a>
  );
}

export function SectionHeading({
  id,
  eyebrow,
  titleStart,
  titleEmphasis,
  body,
  align = "left",
}: {
  id: string;
  eyebrow: string;
  titleStart: string;
  titleEmphasis: string;
  body?: string;
  align?: "left" | "center";
}) {
  return (
    <div className={align === "center" ? "mx-auto max-w-2xl text-center" : "max-w-2xl"}>
      <p className="mb-4 text-sm font-medium uppercase tracking-[0.14em] text-accent-ink">{eyebrow}</p>
      <h2 id={id} className="serif text-[2.6rem] leading-[1.02] sm:text-6xl">
        {titleStart} <span className="em">{titleEmphasis}</span>
      </h2>
      {body && <p className="mt-5 text-lg leading-relaxed text-ink-soft">{body}</p>}
    </div>
  );
}

export function Wordmark({ className = "" }: { className?: string }) {
  return (
    <span className={`serif inline-flex items-center gap-2 text-[1.6rem] leading-none ${className}`}>
      <span aria-hidden className="mt-1 inline-block h-2.5 w-2.5 rounded-full bg-accent" />
      HeadsUp
    </span>
  );
}

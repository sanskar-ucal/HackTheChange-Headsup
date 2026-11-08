import type { ReactNode } from "react";

/**
 * A generic, CSS-drawn laptop. No product photos. The screen keeps a 16:10 aspect ratio.
 */
export function Laptop({ children, className = "" }: { children: ReactNode; className?: string }) {
  return (
    <div className={`relative mx-auto w-full ${className}`}>
      {/* Lid */}
      <div className="relative mx-auto w-[88%] rounded-t-[1.1rem] bg-ink p-[1.6%] pb-[2.4%] shadow-[var(--shadow-lift)] ring-1 ring-black/10">
        <div aria-hidden className="absolute left-1/2 top-[0.55%] h-[0.9%] min-h-[3px] w-[0.9%] min-w-[3px] -translate-x-1/2 rounded-full bg-[#3a3835]" />
        <div className="relative aspect-[16/10] overflow-hidden rounded-[0.35rem] bg-paper">{children}</div>
      </div>
      {/* Base */}
      <div aria-hidden className="relative mx-auto h-[0.85rem] w-full rounded-b-[1.2rem] rounded-t-[0.2rem] bg-gradient-to-b from-[#e2ddd3] via-[#cfc9bd] to-[#b4aea3] shadow-[0_18px_30px_-14px_rgb(29_28_26/0.45)]">
        <div className="absolute left-1/2 top-0 h-[40%] w-[14%] -translate-x-1/2 rounded-b-[0.5rem] bg-[#b9b3a7]" />
      </div>
    </div>
  );
}

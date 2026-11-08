import type { ReactNode } from "react";

/** A generic, CSS-drawn laptop with a 16:10 screen. */
export function Laptop({ children, className = "" }: { children: ReactNode; className?: string }) {
  return (
    <div className={`relative mx-auto w-full ${className}`}>
      <div className="relative mx-auto w-[88%] rounded-t-[1.4rem] bg-[#050d1a] p-[1.5%] pb-[2.2%] ring-1 ring-white/10">
        <div aria-hidden className="absolute left-1/2 top-[0.5%] h-[0.8%] min-h-[3px] w-[0.8%] min-w-[3px] -translate-x-1/2 rounded-full bg-[#1d2a40]" />
        <div className="relative aspect-[16/10] overflow-hidden rounded-[0.5rem] bg-pale">{children}</div>
      </div>
      <div aria-hidden className="relative mx-auto h-[0.9rem] w-full rounded-b-[1.4rem] rounded-t-[0.25rem] bg-gradient-to-b from-[#dfe8f5] to-[#9fb0c8]">
        <div className="absolute left-1/2 top-0 h-[40%] w-[14%] -translate-x-1/2 rounded-b-[0.5rem] bg-[#8d9db5]" />
      </div>
    </div>
  );
}

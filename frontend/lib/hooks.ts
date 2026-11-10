"use client";

import { useAnimationFrame } from "framer-motion";
import { useCallback, useRef, useState, useSyncExternalStore } from "react";

/** SSR-safe media query. The server (and hydration) snapshot is `false`. */
export function useMediaQuery(query: string): boolean {
  const subscribe = useCallback(
    (onChange: () => void) => {
      const mql = window.matchMedia(query);
      mql.addEventListener("change", onChange);
      return () => mql.removeEventListener("change", onChange);
    },
    [query],
  );
  return useSyncExternalStore(
    subscribe,
    () => window.matchMedia(query).matches,
    () => false,
  );
}

export const usePrefersReducedMotion = () => useMediaQuery("(prefers-reduced-motion: reduce)");

/** True on touch-first devices, where hover demos play continuously. */
export const useNoHover = () => useMediaQuery("(hover: none)");

/** Looping clock in seconds that only advances while `running`; optionally snaps to 0 when stopped. */
export function useLoopClock(running: boolean, period: number, resetOnStop = false): number {
  const [t, setT] = useState(0);
  const elapsed = useRef(0);
  const wasRunning = useRef(running);

  useAnimationFrame((_, delta) => {
    if (!running) {
      if (wasRunning.current && resetOnStop) {
        elapsed.current = 0;
        setT(0);
      }
      wasRunning.current = false;
      return;
    }
    wasRunning.current = true;
    // Clamp so returning to a background tab does not jump the story ahead.
    elapsed.current = (elapsed.current + Math.min(delta, 50) / 1000) % period;
    setT(elapsed.current);
  });

  return t;
}

export const clamp = (v: number, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, v));
export const lerp = (a: number, b: number, p: number) => a + (b - a) * p;
export const easeInOut = (p: number) => (p < 0.5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2);
export const easeOut = (p: number) => 1 - Math.pow(1 - p, 3);
/** 0 → 1 → 0 bump over [0, 1]. */
export const bump = (p: number) => (p <= 0 || p >= 1 ? 0 : Math.sin(Math.PI * p));

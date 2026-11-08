"use client";

import { MotionConfig } from "framer-motion";
import type { ReactNode } from "react";

/** Makes every Framer Motion animation respect the reduced-motion setting. */
export function Providers({ children }: { children: ReactNode }) {
  return <MotionConfig reducedMotion="user">{children}</MotionConfig>;
}

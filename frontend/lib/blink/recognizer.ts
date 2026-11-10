/**
 * A TypeScript port of the app's `BlinkSequenceRecognizer` (HeadsUpKit/Sources/Gestures).
 * Same rules and defaults, so the site's blink trainer behaves exactly like HeadsUp:
 *
 * - A blink is an eye closure lasting `minClosure`…`maxClosure` seconds.
 * - Blinks belong to one sequence while each closure starts within `sequenceWindow`
 *   of the previous blink's reopening.
 * - The third blink cancels at once. Two blinks select only after the eyes stayed open
 *   for the whole window, so a triple blink never selects first.
 * - Anything ambiguous (too short, too long, lost tracking, a frame gap) abandons the
 *   sequence without an action. After an action, a cooldown ignores further blinks.
 *
 * Unlike the Swift version, `process` also says *why* nothing happened, for teaching.
 */

export type BlinkCommand = "select" | "cancel";

export type BlinkEvent =
  /** A valid blink was counted; `count` is its position in the sequence (1 or 2). */
  | { type: "blink"; count: number; duration: number }
  | { type: "select" }
  | { type: "cancel" }
  /** A closure that is not a blink; the sequence is abandoned. */
  | { type: "rejected"; reason: "tooShort" | "tooLong"; duration: number }
  /** The eyes stayed open after a single blink: nothing happens. */
  | { type: "expired"; count: number }
  /** A partial sequence was dropped because tracking stopped. */
  | { type: "reset"; reason: "trackingLost" | "frameGap" }
  /** A closure started during the cooldown after an action. */
  | { type: "cooldown" };

export interface BlinkConfig {
  /** Seconds. Shorter closures are noise or reflex blinks. */
  minClosure: number;
  /** Seconds. Longer closures are resting eyes. */
  maxClosure: number;
  /** Longest eyes-open time between blinks of one sequence, in seconds. */
  sequenceWindow: number;
  /** Seconds after an action during which blinks are ignored. */
  actionCooldown: number;
  /** A partial sequence resets if samples stop for longer than this (seconds). */
  maxFrameGap: number;
}

/** Mirrors `HeadsUpSettings` defaults in the app. */
export const DEFAULT_BLINK_CONFIG: Readonly<BlinkConfig> = Object.freeze({
  minClosure: 0.1,
  maxClosure: 0.45,
  sequenceWindow: 0.5,
  actionCooldown: 0.85,
  maxFrameGap: 0.35,
});

export const commandOf = (event: BlinkEvent | null): BlinkCommand | null =>
  event?.type === "select" || event?.type === "cancel" ? event.type : null;

export class BlinkSequenceRecognizer {
  config: BlinkConfig;
  /** Valid blinks in the current, unresolved sequence. */
  blinkCount = 0;
  /** Every valid blink counted since creation. */
  totalBlinks = 0;
  isClosed = false;

  private closedAt: number | null = null;
  private lastBlinkAt: number | null = null;
  private lastSampleAt: number | null = null;
  private cooldownUntil = -Infinity;

  constructor(config: Partial<BlinkConfig> = {}) {
    this.config = { ...DEFAULT_BLINK_CONFIG, ...config };
    if (this.config.maxClosure < this.config.minClosure) this.config.maxClosure = this.config.minClosure;
  }

  /** True while an action's cooldown is running at time `t`. */
  inCooldown(t: number): boolean {
    return t < this.cooldownUntil;
  }

  /**
   * @param eyesClosed true when both eyes are closed, false when open, null when the face
   *   can't be tracked.
   * @param t monotonic seconds.
   */
  process(eyesClosed: boolean | null, t: number): BlinkEvent | null {
    if (!Number.isFinite(t) || eyesClosed === null) {
      const hadSequence = this.blinkCount > 0;
      this.reset();
      return hadSequence ? { type: "reset", reason: "trackingLost" } : null;
    }

    let event: BlinkEvent | null = null;
    if (this.lastSampleAt !== null) {
      if (t < this.lastSampleAt) {
        this.reset();
        this.cooldownUntil = -Infinity;
      } else if (t - this.lastSampleAt > this.config.maxFrameGap) {
        if (this.blinkCount > 0) event = { type: "reset", reason: "frameGap" };
        this.reset();
      }
    }
    this.lastSampleAt = t;
    const wasClosed = this.isClosed;
    this.isClosed = eyesClosed;

    if (t < this.cooldownUntil) {
      // A closure that began during the cooldown never counts, even if it ends after it.
      if (eyesClosed && !wasClosed) event = { type: "cooldown" };
      this.closedAt = null;
      return event;
    }

    if (eyesClosed) {
      if (!wasClosed) {
        if (this.lastBlinkAt !== null && t - this.lastBlinkAt > this.config.sequenceWindow) this.clearSequence();
        this.closedAt = t;
      } else if (this.closedAt !== null && t - this.closedAt > this.config.maxClosure) {
        const duration = t - this.closedAt;
        this.clearSequence();
        return { type: "rejected", reason: "tooLong", duration };
      }
      return event;
    }

    if (wasClosed) {
      if (this.closedAt === null) return event;
      const duration = t - this.closedAt;
      this.closedAt = null;
      if (duration < this.config.minClosure || duration > this.config.maxClosure) {
        this.clearSequence();
        return { type: "rejected", reason: duration < this.config.minClosure ? "tooShort" : "tooLong", duration };
      }
      this.blinkCount += 1;
      this.totalBlinks += 1;
      this.lastBlinkAt = t;
      if (this.blinkCount >= 3) {
        this.clearSequence();
        this.cooldownUntil = t + this.config.actionCooldown;
        return { type: "cancel" };
      }
      return { type: "blink", count: this.blinkCount, duration };
    }

    // Eyes stayed open: resolve the sequence once no further blink began in time.
    if (this.blinkCount > 0 && this.lastBlinkAt !== null && t - this.lastBlinkAt >= this.config.sequenceWindow) {
      const count = this.blinkCount;
      this.clearSequence();
      if (count === 2) {
        this.cooldownUntil = t + this.config.actionCooldown;
        return { type: "select" };
      }
      return { type: "expired", count };
    }
    return event;
  }

  /** Drops any partial sequence. The cooldown is kept, so a reset never allows a quicker repeat. */
  reset(): void {
    this.clearSequence();
    this.isClosed = false;
    this.lastSampleAt = null;
  }

  private clearSequence(): void {
    this.blinkCount = 0;
    this.closedAt = null;
    this.lastBlinkAt = null;
  }
}

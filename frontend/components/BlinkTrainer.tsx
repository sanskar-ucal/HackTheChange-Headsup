"use client";

import { useEffect, useId, useRef, useState, type KeyboardEvent, type PointerEvent } from "react";
import { trainer } from "@/content/blink";
import { BlinkSequenceRecognizer, DEFAULT_BLINK_CONFIG, type BlinkCommand, type BlinkEvent } from "@/lib/blink/recognizer";

type MessageKey = keyof typeof trainer.messages;
type Verdict = "pending" | "blink" | "short" | "long" | "cooldown";
type Closure = { id: number; start: number; end: number | null; verdict: Verdict };
type Outcome = { id: number; key: MessageKey };

/** Seconds of history shown on the timeline. */
const SPAN = 6;
const TIMELINE_WIDTH = 600;
const MAX_HISTORY = 5;

const VERDICT_STYLE: Record<Verdict, { fill: string; label: string }> = {
  pending: { fill: "#5C5850", label: "closing" },
  blink: { fill: "#2E7D5B", label: "blink" },
  short: { fill: "#C98A2B", label: "too quick" },
  long: { fill: "#B5523B", label: "too long" },
  cooldown: { fill: "#A9B79A", label: "cooldown" },
};

const now = () => performance.now() / 1000;

/** Which message a recognizer event shows, and how it marks the latest closure. */
function describe(event: BlinkEvent): { key: MessageKey; verdict?: Verdict } {
  switch (event.type) {
    case "blink":
      return { key: event.count === 1 ? "blink1" : "blink2", verdict: "blink" };
    case "select":
      return { key: "select" };
    case "cancel":
      return { key: "cancel", verdict: "blink" };
    case "expired":
      return { key: "expired" };
    case "rejected":
      return { key: event.reason, verdict: event.reason === "tooShort" ? "short" : "long" };
    case "cooldown":
      return { key: "cooldown", verdict: "cooldown" };
    case "reset":
      return { key: "reset" };
  }
}

function Eye({ closed }: { closed: boolean }) {
  return (
    <svg viewBox="0 0 120 64" aria-hidden className="h-20 w-36">
      <path d="M6 32 Q60 -8 114 32 Q60 72 6 32 Z" fill="#FFFFFF" stroke="#1D1C1A" strokeWidth={3} opacity={closed ? 0 : 1} className="motion-safe:transition-opacity motion-safe:duration-100" />
      <circle cx={60} cy={32} r={13} fill="#2E7D5B" opacity={closed ? 0 : 1} className="motion-safe:transition-opacity motion-safe:duration-100" />
      <circle cx={60} cy={32} r={5} fill="#1D1C1A" opacity={closed ? 0 : 1} />
      <path d="M8 34 Q60 58 112 34" fill="none" stroke="#1D1C1A" strokeWidth={3.5} strokeLinecap="round" opacity={closed ? 1 : 0} />
      {closed && (
        <g stroke="#1D1C1A" strokeWidth={2.5} strokeLinecap="round">
          <path d="M30 46 l-5 8M60 50 v9M90 46 l5 8" />
        </g>
      )}
    </svg>
  );
}

function RangeControl({
  label,
  help,
  value,
  min,
  max,
  step,
  onChange,
}: {
  label: string;
  help: string;
  value: number;
  min: number;
  max: number;
  step: number;
  onChange: (value: number) => void;
}) {
  const id = useId();
  const helpId = `${id}-help`;
  return (
    <div>
      <div className="flex items-baseline justify-between gap-3">
        <label htmlFor={id} className="font-medium">
          {label}
        </label>
        <output htmlFor={id} className="tabular-nums text-ink-soft">
          {value.toFixed(2)} s
        </output>
      </div>
      <input
        id={id}
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        aria-describedby={helpId}
        onChange={(e) => onChange(Number(e.target.value))}
        className="mt-2 h-11 w-full cursor-pointer accent-[#2E7D5B]"
      />
      <p id={helpId} className="text-sm text-ink-soft">
        {help}
      </p>
    </div>
  );
}

export function BlinkTrainer() {
  const recognizer = useRef<BlinkSequenceRecognizer | null>(null);
  const closedRef = useRef(false);
  const nextId = useRef(0);
  const [closed, setClosed] = useState(false);
  const [clock, setClock] = useState(0);
  const [pending, setPending] = useState(0);
  const [lastBlinkAt, setLastBlinkAt] = useState<number | null>(null);
  const [closures, setClosures] = useState<Closure[]>([]);
  const [history, setHistory] = useState<Outcome[]>([]);
  const [status, setStatus] = useState<MessageKey | null>(null);
  const [flash, setFlash] = useState<{ command: BlinkCommand; until: number } | null>(null);
  const [sequenceWindow, setSequenceWindow] = useState(DEFAULT_BLINK_CONFIG.sequenceWindow);
  const [minClosure, setMinClosure] = useState(DEFAULT_BLINK_CONFIG.minClosure);
  const statusId = useId();

  useEffect(() => {
    recognizer.current ??= new BlinkSequenceRecognizer();
    recognizer.current.config = { ...recognizer.current.config, sequenceWindow, minClosure };
  }, [sequenceWindow, minClosure]);

  useEffect(() => {
    let frame = 0;
    const handle = (event: BlinkEvent, t: number) => {
      const { key, verdict } = describe(event);
      setStatus(key);
      if (verdict) {
        setClosures((list) => list.map((c, i) => (i === list.length - 1 ? { ...c, verdict } : c)));
      }
      if (event.type === "blink") setLastBlinkAt(t);
      if (event.type !== "blink") setLastBlinkAt(null);
      if (event.type === "select" || event.type === "cancel") setFlash({ command: event.type, until: t + 1.4 });
      if (event.type !== "blink") {
        setHistory((list) => [{ id: nextId.current++, key }, ...list].slice(0, MAX_HISTORY));
      }
    };
    const tick = (ms: number) => {
      const t = ms / 1000;
      const r = (recognizer.current ??= new BlinkSequenceRecognizer());
      const event = r.process(closedRef.current, t);
      if (event) handle(event, t);
      setPending(r.blinkCount);
      setClock(t);
      setClosures((list) => (list.length && (list[0]!.end ?? t) < t - SPAN ? list.filter((c) => (c.end ?? t) >= t - SPAN) : list));
      frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, []);

  const press = () => {
    if (closedRef.current) return;
    closedRef.current = true;
    setClosed(true);
    const start = now();
    setClosures((list) => [...list, { id: nextId.current++, start, end: null, verdict: "pending" }]);
  };

  const release = () => {
    if (!closedRef.current) return;
    closedRef.current = false;
    setClosed(false);
    const end = now();
    setClosures((list) => list.map((c, i) => (i === list.length - 1 && c.end === null ? { ...c, end } : c)));
  };

  const reset = () => {
    closedRef.current = false;
    recognizer.current = new BlinkSequenceRecognizer({ sequenceWindow, minClosure });
    setClosed(false);
    setPending(0);
    setLastBlinkAt(null);
    setClosures([]);
    setHistory([]);
    setStatus(null);
    setFlash(null);
  };

  const onPointerDown = (e: PointerEvent<HTMLButtonElement>) => {
    if (e.button !== 0) return;
    e.currentTarget.setPointerCapture(e.pointerId);
    press();
  };

  const onKeyDown = (e: KeyboardEvent<HTMLButtonElement>) => {
    if (e.key !== " " && e.key !== "Enter") return;
    e.preventDefault();
    if (!e.repeat) press();
  };

  const onKeyUp = (e: KeyboardEvent<HTMLButtonElement>) => {
    if (e.key !== " " && e.key !== "Enter") return;
    e.preventDefault();
    release();
  };

  const x = (t: number) => ((t - (clock - SPAN)) / SPAN) * TIMELINE_WIDTH;
  const showFlash = flash && clock < flash.until ? flash.command : null;

  return (
    <div className="rounded-[1.6rem] bg-white p-6 shadow-[var(--shadow-card)] ring-1 ring-line/60 sm:p-8">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div className="max-w-xl">
          <h3 className="text-2xl font-semibold tracking-tight">{trainer.title}</h3>
          <p className="mt-2 leading-relaxed text-ink-soft">{trainer.body}</p>
        </div>
        <button
          type="button"
          onClick={reset}
          className="inline-flex min-h-11 items-center rounded-full px-5 text-ink-soft ring-1 ring-line transition-colors hover:text-ink hover:ring-ink/30"
        >
          {trainer.reset}
        </button>
      </div>

      <div className="mt-8 grid items-center gap-8 lg:grid-cols-[auto_1fr]">
        <div className="flex flex-col items-center gap-4">
          <div className="relative flex h-28 w-48 items-center justify-center rounded-2xl bg-paper">
            <Eye closed={closed} />
            {showFlash && (
              <span className="absolute -top-3 right-0 rounded-full bg-accent px-3 py-1 text-sm font-semibold text-white shadow-[var(--shadow-card)]">
                {showFlash === "select" ? "Click" : "Escape"}
              </span>
            )}
          </div>
          <div className="flex items-center gap-2" aria-hidden>
            {[0, 1, 2].map((i) => (
              <span
                key={i}
                className={`h-3.5 w-3.5 rounded-full ring-2 ring-accent motion-safe:transition-colors ${i < pending ? "bg-accent" : "bg-transparent"}`}
              />
            ))}
          </div>
          <button
            type="button"
            aria-pressed={closed}
            aria-describedby={statusId}
            onPointerDown={onPointerDown}
            onPointerUp={release}
            onPointerCancel={release}
            onLostPointerCapture={release}
            onKeyDown={onKeyDown}
            onKeyUp={onKeyUp}
            onBlur={release}
            onContextMenu={(e) => e.preventDefault()}
            className={`min-h-16 w-56 touch-none select-none rounded-full px-6 text-lg font-semibold motion-safe:transition-[background-color,transform] ${
              closed ? "scale-[0.98] bg-ink text-paper" : "bg-accent text-white hover:bg-accent-ink"
            }`}
          >
            {closed ? trainer.holding : trainer.hold}
          </button>
        </div>

        <div className="min-w-0 space-y-6">
          <p id={statusId} role="status" className="min-h-7 text-lg font-medium">
            {status ? trainer.messages[status] : trainer.idle}
          </p>

          <figure>
            <figcaption className="mb-2 text-sm font-medium text-ink-soft">{trainer.timelineLabel}</figcaption>
            <svg viewBox={`0 0 ${TIMELINE_WIDTH} 44`} className="h-11 w-full rounded-xl bg-paper" aria-hidden preserveAspectRatio="none">
              {lastBlinkAt !== null && pending > 0 && (
                <rect x={x(lastBlinkAt)} y={4} width={(sequenceWindow / SPAN) * TIMELINE_WIDTH} height={36} rx={6} fill="#E3ECE3" />
              )}
              {closures.map((c) => (
                <rect
                  key={c.id}
                  x={x(c.start)}
                  y={10}
                  width={Math.max(2, x(c.end ?? clock) - x(c.start))}
                  height={24}
                  rx={5}
                  fill={VERDICT_STYLE[c.verdict].fill}
                />
              ))}
            </svg>
            <ul className="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-sm text-ink-soft">
              {(["blink", "short", "long", "cooldown"] as const).map((v) => (
                <li key={v} className="inline-flex items-center gap-2">
                  <span aria-hidden className="h-2.5 w-2.5 rounded-full" style={{ background: VERDICT_STYLE[v].fill }} />
                  {VERDICT_STYLE[v].label}
                </li>
              ))}
              <li className="inline-flex items-center gap-2">
                <span aria-hidden className="h-2.5 w-4 rounded bg-accent-wash" />
                waiting for the next blink
              </li>
            </ul>
          </figure>

          <div>
            <h4 className="text-sm font-medium text-ink-soft">{trainer.historyLabel}</h4>
            {history.length === 0 ? (
              <p className="mt-2 text-ink-soft">—</p>
            ) : (
              <ol className="mt-2 space-y-1">
                {history.map((h, i) => (
                  <li key={h.id} className={i === 0 ? "font-medium" : "text-ink-soft"}>
                    {trainer.messages[h.key]}
                  </li>
                ))}
              </ol>
            )}
          </div>

          <div className="grid gap-6 sm:grid-cols-2">
            <RangeControl
              label={trainer.windowLabel}
              help={trainer.windowHelp}
              value={sequenceWindow}
              min={0.3}
              max={1}
              step={0.05}
              onChange={setSequenceWindow}
            />
            <RangeControl label={trainer.minLabel} help={trainer.minHelp} value={minClosure} min={0.05} max={0.3} step={0.01} onChange={setMinClosure} />
          </div>
        </div>
      </div>
    </div>
  );
}

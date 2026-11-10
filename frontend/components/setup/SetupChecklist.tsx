"use client";

import { useCallback, useSyncExternalStore } from "react";
import { checklist, checklistGroups } from "@/content/setup";

const STORAGE_KEY = "headsup.setup.checklist.v1";
const CHANGE_EVENT = "headsup-checklist-change";
const EMPTY: readonly string[] = [];

let cachedRaw: string | null = null;
let cachedDone: readonly string[] = EMPTY;

/** Done step ids from localStorage, cached so React sees a stable snapshot. */
function readDone(): readonly string[] {
  let raw: string | null = null;
  try {
    raw = window.localStorage.getItem(STORAGE_KEY);
  } catch {
    return EMPTY; // storage blocked (private mode, policy): the checklist still works, unsaved
  }
  if (raw === cachedRaw) return cachedDone;
  cachedRaw = raw;
  try {
    const parsed: unknown = raw ? JSON.parse(raw) : [];
    const known = new Set(checklist.map((c) => c.id));
    cachedDone = Array.isArray(parsed) ? parsed.filter((id): id is string => typeof id === "string" && known.has(id)) : EMPTY;
  } catch {
    cachedDone = EMPTY;
  }
  return cachedDone;
}

let memoryDone: readonly string[] | null = null;

function writeDone(done: readonly string[]) {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(done));
    memoryDone = null;
  } catch {
    memoryDone = done;
  }
  window.dispatchEvent(new Event(CHANGE_EVENT));
}

function subscribe(onChange: () => void) {
  const onStorage = (e: StorageEvent) => e.key === STORAGE_KEY && onChange();
  window.addEventListener("storage", onStorage); // other tabs
  window.addEventListener(CHANGE_EVENT, onChange);
  return () => {
    window.removeEventListener("storage", onStorage);
    window.removeEventListener(CHANGE_EVENT, onChange);
  };
}

function useDoneSteps() {
  const done = useSyncExternalStore(subscribe, () => memoryDone ?? readDone(), () => EMPTY);
  const toggle = useCallback(
    (id: string) => writeDone(done.includes(id) ? done.filter((d) => d !== id) : [...done, id]),
    [done],
  );
  const reset = useCallback(() => writeDone([]), []);
  return { done, toggle, reset };
}

function CheckIcon({ checked }: { checked: boolean }) {
  return (
    <span
      aria-hidden
      className={`mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-lg ring-2 motion-safe:transition-colors ${
        checked ? "bg-accent ring-accent" : "bg-white ring-line"
      }`}
    >
      {checked && (
        <svg viewBox="0 0 20 20" className="h-4 w-4 text-white" fill="none" stroke="currentColor" strokeWidth={2.6} strokeLinecap="round" strokeLinejoin="round">
          <path d="m5 10.5 3.2 3L15 6.5" />
        </svg>
      )}
    </span>
  );
}

export function SetupChecklist() {
  const { done, toggle, reset } = useDoneSteps();
  const total = checklist.length;
  const count = done.length;
  const complete = count === total;

  return (
    <div className="rounded-[1.6rem] bg-white p-6 shadow-[var(--shadow-card)] ring-1 ring-line/60 sm:p-8 print:shadow-none print:ring-0">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div className="min-w-56 flex-1">
          <p className="font-medium" aria-live="polite">
            {complete ? "All done. HeadsUp is ready to use." : `${count} of ${total} steps done`}
          </p>
          <div
            role="progressbar"
            aria-label="Setup progress"
            aria-valuemin={0}
            aria-valuemax={total}
            aria-valuenow={count}
            className="mt-3 h-2.5 overflow-hidden rounded-full bg-paper-deep"
          >
            <div className="h-full rounded-full bg-accent motion-safe:transition-[width] motion-safe:duration-300" style={{ width: `${(count / total) * 100}%` }} />
          </div>
        </div>
        <div className="flex gap-2 print:hidden">
          <button
            type="button"
            onClick={() => window.print()}
            className="inline-flex min-h-11 items-center rounded-full px-5 ring-1 ring-line transition-colors hover:ring-ink/30"
          >
            Print checklist
          </button>
          <button
            type="button"
            onClick={reset}
            disabled={count === 0}
            className="inline-flex min-h-11 items-center rounded-full px-5 text-ink-soft ring-1 ring-line transition-colors hover:text-ink hover:ring-ink/30 disabled:cursor-not-allowed disabled:opacity-50"
          >
            Start over
          </button>
        </div>
      </div>

      <div className="mt-8 space-y-8">
        {checklistGroups.map((group, groupIndex) => {
          const steps = checklist.filter((c) => c.group === group.id);
          const groupDone = steps.filter((s) => done.includes(s.id)).length;
          return (
            <fieldset key={group.id} className="break-inside-avoid">
              <legend className="flex w-full items-baseline justify-between gap-3 text-lg font-semibold">
                <span>
                  <span className="mr-2 text-accent-ink">{groupIndex + 1}.</span>
                  {group.title}
                </span>
                <span className="text-sm font-normal tabular-nums text-ink-soft">
                  {groupDone}/{steps.length}
                </span>
              </legend>
              <ul className="mt-3 space-y-2">
                {steps.map((step) => {
                  const checked = done.includes(step.id);
                  const inputId = `step-${step.id}`;
                  return (
                    <li key={step.id}>
                      <label
                        htmlFor={inputId}
                        className={`flex min-h-12 cursor-pointer gap-4 rounded-2xl p-3 transition-colors hover:bg-paper has-[:focus-visible]:outline has-[:focus-visible]:outline-[3px] has-[:focus-visible]:outline-ink ${
                          checked ? "bg-accent-wash/60" : ""
                        }`}
                      >
                        <input id={inputId} type="checkbox" checked={checked} onChange={() => toggle(step.id)} className="sr-only" />
                        <CheckIcon checked={checked} />
                        <span>
                          <span className={`block font-medium ${checked ? "text-ink-soft line-through decoration-accent/60" : ""}`}>{step.title}</span>
                          <span className="mt-0.5 block text-ink-soft">{step.detail}</span>
                        </span>
                      </label>
                    </li>
                  );
                })}
              </ul>
            </fieldset>
          );
        })}
      </div>
    </div>
  );
}

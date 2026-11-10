"use client";

import { useDeferredValue, useId, useMemo, useState } from "react";
import { troubleshooting, troubleshootingSection as copy } from "@/content/setup";
import { search } from "@/lib/search";

type Entry = (typeof troubleshooting)[number];

const fields = (t: Entry) => [
  { text: t.problem, weight: 3 },
  { text: t.keywords.join(" "), weight: 2 },
  { text: t.steps.join(" "), weight: 1 },
];

function Disclosure({ entry, open, onToggle }: { entry: Entry; open: boolean; onToggle: () => void }) {
  const buttonId = `trouble-${entry.id}`;
  const panelId = `${buttonId}-panel`;
  return (
    <li className="border-b border-line last:border-b-0">
      <h3>
        <button
          id={buttonId}
          type="button"
          aria-expanded={open}
          aria-controls={panelId}
          onClick={onToggle}
          className="flex min-h-16 w-full items-center justify-between gap-6 px-6 py-4 text-left text-lg font-medium transition-colors hover:text-accent-ink"
        >
          {entry.problem}
          <span aria-hidden className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-paper motion-safe:transition-transform ${open ? "rotate-45" : ""}`}>
            <svg viewBox="0 0 20 20" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round">
              <path d="M10 4v12M4 10h12" />
            </svg>
          </span>
        </button>
      </h3>
      <div id={panelId} role="region" aria-labelledby={buttonId} hidden={!open}>
        <ol className="max-w-prose list-decimal space-y-2 pb-6 pl-12 pr-6 leading-relaxed text-ink-soft marker:font-medium marker:text-accent-ink">
          {entry.steps.map((step) => (
            <li key={step}>{step}</li>
          ))}
        </ol>
      </div>
    </li>
  );
}

export function Troubleshooter() {
  const [query, setQueryState] = useState("");
  /** Entries the user opened or closed, overriding the default (top search result open). */
  const [toggled, setToggled] = useState<ReadonlySet<string>>(() => new Set());
  const deferredQuery = useDeferredValue(query);
  const results = useMemo(() => search(troubleshooting, deferredQuery, fields), [deferredQuery]);
  const inputId = useId();
  const statusId = useId();
  const searching = deferredQuery.trim().length > 0;

  const setQuery = (value: string) => {
    setQueryState(value);
    setToggled(new Set());
  };

  const toggle = (id: string) =>
    setToggled((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  // While searching, open the best match so the answer is visible right away.
  const isOpen = (id: string, index: number) => toggled.has(id) !== (searching && index === 0);

  return (
    <div>
      <div className="rounded-[1.4rem] bg-white p-5 shadow-[var(--shadow-card)] ring-1 ring-line/60">
        <label htmlFor={inputId} className="font-medium">
          {copy.searchLabel}
        </label>
        <div className="mt-2 flex gap-2">
          <input
            id={inputId}
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={copy.searchPlaceholder}
            aria-describedby={statusId}
            autoComplete="off"
            className="min-h-12 w-full rounded-full bg-paper px-5 text-lg ring-1 ring-line placeholder:text-ink-soft/80 focus:outline-none focus-visible:ring-2 focus-visible:ring-ink"
          />
          {query && (
            <button
              type="button"
              onClick={() => setQuery("")}
              className="inline-flex min-h-12 shrink-0 items-center rounded-full px-5 text-ink-soft ring-1 ring-line hover:text-ink"
            >
              {copy.clear}
            </button>
          )}
        </div>
        <div className="mt-4 flex flex-wrap items-center gap-2">
          <span className="text-sm text-ink-soft">{copy.suggestionsLabel}:</span>
          {copy.suggestions.map((s) => (
            <button
              key={s}
              type="button"
              aria-pressed={query.trim().toLowerCase() === s}
              onClick={() => setQuery(s)}
              className="inline-flex min-h-11 items-center rounded-full bg-paper px-4 text-sm font-medium ring-1 ring-line transition-colors hover:ring-ink/30 aria-pressed:bg-accent-wash aria-pressed:text-accent-ink"
            >
              {s}
            </button>
          ))}
        </div>
        <p id={statusId} role="status" className="mt-4 text-sm text-ink-soft">
          {searching ? (results.length === 0 ? copy.noResults : `${results.length} matching ${results.length === 1 ? "problem" : "problems"}`) : `${troubleshooting.length} common problems`}
        </p>
      </div>

      {results.length > 0 && (
        <ul className="mt-6 rounded-[1.4rem] bg-white shadow-[var(--shadow-card)] ring-1 ring-line/60">
          {results.map((entry, index) => (
            <Disclosure key={entry.id} entry={entry} open={isOpen(entry.id, index)} onToggle={() => toggle(entry.id)} />
          ))}
        </ul>
      )}
    </div>
  );
}

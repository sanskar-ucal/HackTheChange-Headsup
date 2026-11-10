import { blink, type BlinkGestureId } from "@/content/blink";
import { BlinkTrainer } from "./BlinkTrainer";
import { Reveal } from "./Reveal";
import { SectionHeading } from "./ui";

const BLINKS: Record<BlinkGestureId, number> = { double: 2, triple: 3 };

/** A row of closed eyes, one per blink in the gesture. */
function BlinkRhythm({ count }: { count: number }) {
  return (
    <svg viewBox={`0 0 ${count * 46 + 8} 40`} aria-hidden className="h-10">
      {Array.from({ length: count }, (_, i) => (
        <g key={i} transform={`translate(${8 + i * 46} 8)`}>
          <path d="M2 10 Q18 26 34 10" fill="none" stroke="#2E7D5B" strokeWidth={3} strokeLinecap="round" />
          <path d="M8 18 l-3 6M18 21 v6M28 18 l3 6" stroke="#2E7D5B" strokeWidth={2.2} strokeLinecap="round" />
        </g>
      ))}
    </svg>
  );
}

function ShieldIcon() {
  return (
    <svg aria-hidden viewBox="0 0 24 24" className="mt-0.5 h-5 w-5 shrink-0 text-accent" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 3 5 6v6c0 4 3 7 7 9 4-2 7-5 7-9V6z" />
      <path d="m9 12 2 2 4-4" />
    </svg>
  );
}

export function BlinkGestures() {
  return (
    <section id="blink" aria-labelledby="blink-title" className="py-24 sm:py-32">
      <div className="mx-auto max-w-6xl px-5 sm:px-8">
        <Reveal>
          <SectionHeading id="blink-title" eyebrow={blink.eyebrow} titleStart={blink.titleStart} titleEmphasis={blink.titleEmphasis} body={blink.body} />
        </Reveal>

        <div className="mt-14 grid gap-6 lg:grid-cols-[1fr_1fr_1.1fr]">
          {blink.items.map((item, i) => (
            <Reveal key={item.id} delay={i * 0.06}>
              <article aria-labelledby={`blink-${item.id}`} className="h-full rounded-[1.4rem] bg-white p-6 shadow-[var(--shadow-card)] ring-1 ring-line/60">
                <div className="flex h-24 items-center justify-center rounded-2xl bg-paper">
                  <BlinkRhythm count={BLINKS[item.id]} />
                </div>
                <div className="mt-5 flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1">
                  <h3 id={`blink-${item.id}`} className="text-xl font-semibold tracking-tight">
                    {item.name}
                  </h3>
                  <p className="rounded-full bg-accent-wash px-3 py-1 text-sm font-medium text-accent-ink">{item.action}</p>
                </div>
                <p className="mt-3 leading-relaxed text-ink-soft">{item.body}</p>
              </article>
            </Reveal>
          ))}

          <Reveal delay={0.12}>
            <div className="h-full rounded-[1.4rem] bg-paper-deep/70 p-6 ring-1 ring-line/60">
              <h3 className="text-xl font-semibold tracking-tight">{blink.safeguardsTitle}</h3>
              <ul className="mt-4 space-y-3">
                {blink.safeguards.map((s) => (
                  <li key={s} className="flex gap-3 leading-relaxed text-ink-soft">
                    <ShieldIcon />
                    {s}
                  </li>
                ))}
              </ul>
              <p className="mt-5 border-t border-line pt-4 text-sm leading-relaxed text-ink-soft">
                {blink.privacy} Turn it on under <strong className="font-medium text-ink">{blink.enable}</strong>.
              </p>
            </div>
          </Reveal>
        </div>

        <Reveal className="mt-10">
          <BlinkTrainer />
        </Reveal>
      </div>
    </section>
  );
}

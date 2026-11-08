import { requirements } from "@/content/site";
import { Reveal } from "./Reveal";
import { SectionHeading } from "./ui";

export function Requirements() {
  return (
    <section id="requirements" aria-labelledby="req-title" className="mx-auto max-w-6xl px-5 pb-24 sm:px-8 sm:pb-32">
      <Reveal>
        <SectionHeading id="req-title" eyebrow={requirements.eyebrow} titleStart={requirements.titleStart} titleEmphasis={requirements.titleEmphasis} />
      </Reveal>
      <div className="mt-12 grid gap-6 md:grid-cols-3">
        {requirements.groups.map((g, i) => (
          <Reveal key={g.title} delay={i * 0.08} className="rounded-[1.4rem] bg-white p-7 shadow-[var(--shadow-card)] ring-1 ring-line/60">
            <h3 className="text-xl font-semibold tracking-tight">{g.title}</h3>
            <ul className="mt-4 space-y-3">
              {g.items.map((it) => (
                <li key={it} className="flex gap-3 leading-relaxed text-ink-soft">
                  <span aria-hidden className="mt-[0.6rem] h-1.5 w-1.5 shrink-0 rounded-full bg-accent" />
                  {it}
                </li>
              ))}
            </ul>
          </Reveal>
        ))}
      </div>
    </section>
  );
}

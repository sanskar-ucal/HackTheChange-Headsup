import { howItWorks } from "@/content/site";
import { Reveal } from "./Reveal";
import { Eyebrow } from "./ui";

/** Pale section: sticky intro on the left, numbered steps on the right. */
export function HowItWorks() {
  return (
    <section id="how-it-works" aria-labelledby="how-title" className="on-pale bg-pale text-navy">
      <div className="mx-auto grid max-w-7xl gap-14 px-5 py-24 sm:px-8 sm:py-32 lg:grid-cols-[1fr_1.2fr] lg:gap-24">
        <Reveal className="lg:sticky lg:top-32 lg:self-start">
          <Eyebrow tone="light">{howItWorks.eyebrow}</Eyebrow>
          <h2 id="how-title" className="display text-[clamp(2.6rem,5.5vw,4.5rem)]">
            {howItWorks.title}
          </h2>
          <p className="mt-6 max-w-md text-lg leading-relaxed text-ink-soft">{howItWorks.body}</p>
        </Reveal>
        <ol className="space-y-5">
          {howItWorks.steps.map((s, i) => (
            <Reveal as="li" key={s.title} delay={i * 0.06} className="grid grid-cols-[auto_1fr] gap-6 rounded-[28px] bg-white p-7 sm:gap-8 sm:p-9">
              <span aria-hidden className="display text-[3.5rem] leading-none text-navy/25 sm:text-[4.5rem]">
                {i + 1}
              </span>
              <div>
                <h3 className="font-[family-name:var(--font-display)] text-2xl font-bold tracking-tight">
                  <span className="sr-only">Step {i + 1}: </span>
                  {s.title}
                </h3>
                <p className="mt-3 text-[1.05rem] leading-relaxed text-ink-soft">{s.body}</p>
              </div>
            </Reveal>
          ))}
        </ol>
      </div>
    </section>
  );
}

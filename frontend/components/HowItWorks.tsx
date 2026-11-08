import { howItWorks } from "@/content/site";
import { Reveal } from "./Reveal";
import { Emph, Eyebrow } from "./ui";

/** Pale-blue section: sticky intro on the left, numbered steps on the right. */
export function HowItWorks() {
  return (
    <section id="how-it-works" aria-labelledby="how-title" className="bg-pale">
      <div className="mx-auto grid max-w-6xl gap-14 px-5 py-24 sm:px-8 sm:py-32 lg:grid-cols-[1fr_1.2fr] lg:gap-20">
        <Reveal className="lg:sticky lg:top-28 lg:self-start">
          <Eyebrow>{howItWorks.eyebrow}</Eyebrow>
          <h2 id="how-title" className="display text-[clamp(2.75rem,5.5vw,4.5rem)]">
            <Emph text={howItWorks.title} />
          </h2>
          <p className="mt-6 max-w-md text-lg leading-relaxed text-ink-soft">{howItWorks.body}</p>
        </Reveal>
        <ol className="space-y-5">
          {howItWorks.steps.map((s, i) => (
            <Reveal as="li" key={s.title} delay={i * 0.06} className="grid grid-cols-[auto_1fr] gap-6 rounded-[28px] bg-white p-7 shadow-[var(--shadow-card)] sm:gap-8 sm:p-9">
              <span aria-hidden className="display text-[3.5rem] italic leading-none text-blue sm:text-[4.25rem]">
                {i + 1}
              </span>
              <div>
                <h3 className="text-xl font-semibold tracking-tight">
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

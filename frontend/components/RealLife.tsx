import { realLife } from "@/content/site";
import { Reveal } from "./Reveal";
import { ArrowIcon, Emph, Eyebrow } from "./ui";

/** Pale-blue section: three everyday moments, plus a link back up to the chess demo. */
export function RealLife() {
  return (
    <section aria-labelledby="life-title" className="bg-pale">
      <div className="mx-auto max-w-6xl px-5 py-24 sm:px-8 sm:py-32">
        <Reveal>
          <Eyebrow>{realLife.eyebrow}</Eyebrow>
          <h2 id="life-title" className="display max-w-4xl text-[clamp(2.75rem,5.5vw,4.5rem)]">
            <Emph text={realLife.title} />
          </h2>
        </Reveal>
        <ul className="mt-14 grid gap-5 lg:grid-cols-3">
          {realLife.items.map((item, i) => (
            <Reveal as="li" key={item.title} delay={i * 0.06} className="flex min-h-[17rem] flex-col justify-end rounded-[28px] bg-white p-8 shadow-[var(--shadow-card)] sm:p-9">
              <h3 className="display text-[2.4rem] italic">{item.title}</h3>
              <p className="mt-3 max-w-sm text-lg leading-relaxed text-ink-soft">{item.body}</p>
            </Reveal>
          ))}
        </ul>
        <Reveal className="mt-5">
          <div className="flex flex-col gap-5 rounded-[28px] bg-white p-8 shadow-[var(--shadow-card)] sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h3 className="display text-[2rem] italic">{realLife.fun.title}</h3>
              <p className="mt-2 text-ink-soft">{realLife.fun.body}</p>
            </div>
            <a href="#top" className="inline-flex min-h-12 items-center gap-2 self-start rounded-full px-6 font-medium text-blue-ink ring-2 ring-blue/40 transition-colors hover:bg-pale sm:self-auto">
              {realLife.fun.link}
              <ArrowIcon className="h-4 w-4 -rotate-90" />
            </a>
          </div>
        </Reveal>
      </div>
    </section>
  );
}

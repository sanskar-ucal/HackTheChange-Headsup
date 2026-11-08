import { realLife } from "@/content/site";
import { Reveal } from "./Reveal";
import { ArrowIcon, Eyebrow } from "./ui";

/** Navy section: three everyday moments, plus a link back up to the chess demo. */
export function RealLife() {
  return (
    <section aria-labelledby="life-title" className="bg-navy">
      <div className="mx-auto max-w-7xl px-5 py-24 sm:px-8 sm:py-32">
        <Reveal>
          <Eyebrow>{realLife.eyebrow}</Eyebrow>
          <h2 id="life-title" className="display max-w-4xl text-[clamp(2.6rem,5.5vw,4.5rem)]">
            {realLife.title}
          </h2>
        </Reveal>
        <ul className="mt-14 grid gap-5 lg:grid-cols-[1.3fr_1fr_1fr]">
          {realLife.items.map((item, i) => (
            <Reveal as="li" key={item.title} delay={i * 0.06}
              className={`flex flex-col justify-end rounded-[32px] p-8 sm:p-10 ${i === 0 ? "min-h-[22rem] bg-sky text-navy" : "min-h-[18rem] bg-navy-2"}`}>
              <h3 className="display text-[2.4rem] sm:text-[2.8rem]">{item.title}</h3>
              <p className={`mt-4 max-w-sm text-lg leading-relaxed ${i === 0 ? "text-navy/80" : "text-white/75"}`}>{item.body}</p>
            </Reveal>
          ))}
        </ul>
        <Reveal className="mt-5">
          <div className="flex flex-col gap-5 rounded-[32px] bg-navy-2 p-8 sm:flex-row sm:items-center sm:justify-between sm:p-10">
            <div>
              <h3 className="display text-[2rem]">{realLife.fun.title}</h3>
              <p className="mt-2 text-white/75">{realLife.fun.body}</p>
            </div>
            <a href="#top" className="inline-flex min-h-12 items-center gap-2 self-start rounded-full px-6 font-semibold text-sky ring-2 ring-sky/50 transition-colors hover:bg-sky hover:text-navy sm:self-auto">
              {realLife.fun.link}
              <ArrowIcon className="h-4 w-4 -rotate-90" />
            </a>
          </div>
        </Reveal>
      </div>
    </section>
  );
}

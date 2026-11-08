import { privacy } from "@/content/site";
import { Reveal } from "./Reveal";
import { Eyebrow } from "./ui";

/** Pale section listing exactly what is processed where. */
export function Privacy() {
  return (
    <section id="privacy" aria-labelledby="privacy-title" className="on-pale bg-pale text-navy">
      <div className="mx-auto grid max-w-7xl gap-14 px-5 py-24 sm:px-8 sm:py-32 lg:grid-cols-[1fr_1.3fr] lg:gap-20">
        <Reveal>
          <Eyebrow tone="light">{privacy.eyebrow}</Eyebrow>
          <h2 id="privacy-title" className="display text-[clamp(2.6rem,5.5vw,4.5rem)]">
            {privacy.title}
          </h2>
        </Reveal>
        <dl className="grid gap-5 sm:grid-cols-2">
          {privacy.points.map((p, i) => (
            <Reveal key={p.title} delay={i * 0.05} className="rounded-[28px] bg-white p-7">
              <dt className="font-[family-name:var(--font-display)] text-xl font-bold tracking-tight">{p.title}</dt>
              <dd className="mt-2 leading-relaxed text-ink-soft">{p.body}</dd>
            </Reveal>
          ))}
        </dl>
      </div>
    </section>
  );
}

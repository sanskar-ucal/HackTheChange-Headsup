import { privacy } from "@/content/site";
import { Reveal } from "./Reveal";

export function Privacy() {
  return (
    <section id="privacy" aria-labelledby="privacy-title" className="mx-auto max-w-6xl px-5 py-24 sm:px-8 sm:py-32">
      <div className="grid gap-12 rounded-[2rem] bg-ink p-8 text-paper sm:p-14 lg:grid-cols-[1.1fr_1fr] lg:gap-16">
        <Reveal>
          <p className="mb-4 text-sm font-medium uppercase tracking-[0.14em] text-[#9fd1b7]">{privacy.eyebrow}</p>
          <h2 id="privacy-title" className="serif text-[2.6rem] leading-[1.02] sm:text-6xl">
            {privacy.titleStart} <span className="italic text-[#9fd1b7]">{privacy.titleEmphasis}</span>
          </h2>
          <p className="mt-5 max-w-md text-lg leading-relaxed text-paper/80">{privacy.body}</p>
        </Reveal>
        <ul className="space-y-4">
          {privacy.points.map((p, i) => (
            <Reveal as="li" key={p.title} delay={i * 0.08} className="flex gap-4 rounded-2xl bg-white/[0.06] p-5 ring-1 ring-white/10">
              <svg aria-hidden viewBox="0 0 24 24" className="mt-0.5 h-6 w-6 shrink-0 text-[#9fd1b7]" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round">
                <circle cx={12} cy={12} r={9} />
                <path d="M5.6 5.6l12.8 12.8" />
              </svg>
              <div>
                <h3 className="text-lg font-semibold">{p.title}</h3>
                <p className="mt-1 text-paper/80">{p.body}</p>
              </div>
            </Reveal>
          ))}
        </ul>
      </div>
    </section>
  );
}

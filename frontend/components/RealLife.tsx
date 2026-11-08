import { realLife, type LifeId } from "@/content/site";
import { Reveal } from "./Reveal";
import { ArrowIcon, SectionHeading } from "./ui";

function Icon({ id }: { id: LifeId }) {
  const common = { fill: "none", stroke: "currentColor", strokeWidth: 1.6, strokeLinecap: "round" as const, strokeLinejoin: "round" as const };
  return (
    <svg aria-hidden viewBox="0 0 48 48" className="h-12 w-12 text-accent">
      {id === "close" && (
        <g {...common}>
          <rect x={6} y={12} width={26} height={24} rx={5} />
          <path d="m32 21 10-6v18l-10-6" />
          <circle cx={19} cy={21} r={4} />
          <path d="M12 32c1.5-3.5 4-5 7-5s5.5 1.5 7 5" />
        </g>
      )}
      {id === "care" && (
        <g {...common}>
          <rect x={7} y={10} width={34} height={30} rx={5} />
          <path d="M7 19h34M16 6v8M32 6v8" />
          <path d="m18 29 4 4 8-8" />
        </g>
      )}
      {id === "slow" && (
        <g {...common}>
          <path d="M24 13c-4-3-10-4-16-3v26c6-1 12 0 16 3 4-3 10-4 16-3V10c-6-1-12 0-16 3Z" />
          <path d="M24 13v26" />
        </g>
      )}
      {id === "fun" && (
        <g {...common}>
          <path d="M16 39c0-6 2-10 5-13-3 .6-6 .2-7.5-2.4 1-3.6 5-7.6 9-9.4l1-3.7 2.4 3.2c5 1.1 7.3 6.8 6.4 13.3-.6 4.8-1 8.4-.8 12" />
          <path d="M13 40h22" />
          <circle cx={22.5} cy={18} r={0.8} fill="currentColor" />
        </g>
      )}
    </svg>
  );
}

export function RealLife() {
  const [a, b, c, fun] = realLife.items;
  return (
    <section aria-labelledby="life-title" className="bg-paper-deep/60 py-24 sm:py-32">
      <div className="mx-auto max-w-6xl px-5 sm:px-8">
        <Reveal>
          <SectionHeading id="life-title" eyebrow={realLife.eyebrow} titleStart={realLife.titleStart} titleEmphasis={realLife.titleEmphasis} />
        </Reveal>
        <ul className="mt-14 grid gap-6 md:grid-cols-3">
          {[a, b, c].map((item, i) => (
            <Reveal as="li" key={item.id} delay={i * 0.08} className="rounded-[1.4rem] bg-white p-8 shadow-[var(--shadow-card)] ring-1 ring-line/60">
              <Icon id={item.id} />
              <h3 className="serif mt-8 text-[2.1rem] italic leading-none text-ink">{item.title}</h3>
              <p className="mt-4 text-lg leading-relaxed text-ink-soft">{item.body}</p>
            </Reveal>
          ))}
        </ul>
        {fun.link && (
          <Reveal className="mt-6">
            <div className="flex flex-col gap-5 rounded-[1.4rem] bg-white p-6 shadow-[var(--shadow-card)] ring-1 ring-line/60 sm:flex-row sm:items-center sm:p-7">
              <Icon id="fun" />
              <div className="flex-1">
                <h3 className="serif text-[1.8rem] italic leading-none">{fun.title}</h3>
                <p className="mt-2 text-ink-soft">{fun.body}</p>
              </div>
              <a href={fun.link.href} className="inline-flex min-h-12 items-center gap-2 self-start rounded-full px-5 font-medium text-accent-ink ring-1 ring-accent/40 transition-colors hover:bg-accent-wash sm:self-auto">
                {fun.link.label}
                <ArrowIcon className="h-4 w-4 -rotate-90" />
              </a>
            </div>
          </Reveal>
        )}
      </div>
    </section>
  );
}

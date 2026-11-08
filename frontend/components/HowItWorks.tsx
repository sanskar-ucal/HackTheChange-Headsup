import { howItWorks } from "@/content/site";
import { HeadGlyph } from "./HeadGlyph";
import { Reveal } from "./Reveal";
import { SectionHeading } from "./ui";

const GREEN = "#2E7D5B";

function AirPodsArt() {
  return (
    <svg viewBox="0 0 160 100" aria-hidden className="h-full w-full">
      <rect x={40} y={56} width={80} height={34} rx={14} fill="#FFFFFF" stroke="#DDD6C8" />
      <line x1={40} x2={120} y1={66} y2={66} stroke="#E8E2D6" />
      <circle cx={80} cy={78} r={2.2} fill={GREEN} />
      {[58, 102].map((x, i) => (
        <g key={x} transform={`translate(${x} ${i ? 26 : 30}) rotate(${i ? 12 : -12})`}>
          <rect x={-7} y={-9} width={14} height={16} rx={7} fill="#FFFFFF" stroke="#1D1C1A" strokeWidth={1.4} />
          <rect x={-3} y={4} width={6} height={18} rx={3} fill="#FFFFFF" stroke="#1D1C1A" strokeWidth={1.4} />
        </g>
      ))}
    </svg>
  );
}

function CalibrateArt() {
  const dots = [
    [80, 50],
    [26, 18],
    [134, 18],
    [26, 82],
    [134, 82],
  ];
  return (
    <svg viewBox="0 0 160 100" aria-hidden className="h-full w-full">
      <rect x={8} y={6} width={144} height={88} rx={8} fill="#FFFFFF" stroke="#DDD6C8" />
      {dots.map(([x, y], i) => (
        <g key={i}>
          <circle cx={x} cy={y} r={7} fill={i === 0 ? GREEN : "#E3ECE3"} />
          {i === 0 && <circle cx={x} cy={y} r={12} fill="none" stroke={GREEN} strokeWidth={2} strokeDasharray="56 76" transform={`rotate(-90 ${x} ${y})`} strokeLinecap="round" />}
        </g>
      ))}
    </svg>
  );
}

function PointArt() {
  return (
    <svg viewBox="0 0 160 100" aria-hidden className="h-full w-full">
      <HeadGlyph x={42} y={44} scale={1.25} yaw={0.6} pitch={-0.1} />
      <path d="M72 40 C88 30 100 30 112 36" fill="none" stroke="#8A857B" strokeWidth={1.4} strokeDasharray="3 4" strokeLinecap="round" />
      <circle cx={124} cy={40} r={11} fill={GREEN} opacity={0.22} />
      <circle cx={124} cy={40} r={11} fill="none" stroke={GREEN} strokeWidth={2} />
      <circle cx={124} cy={40} r={2.6} fill={GREEN} />
      <circle cx={124} cy={40} r={19} fill="none" stroke={GREEN} strokeWidth={1.2} opacity={0.4} />
    </svg>
  );
}

const ART = [AirPodsArt, CalibrateArt, PointArt];

export function HowItWorks() {
  return (
    <section id="how-it-works" aria-labelledby="how-title" className="mx-auto max-w-6xl px-5 py-24 sm:px-8 sm:py-32">
      <Reveal>
        <SectionHeading id="how-title" eyebrow={howItWorks.eyebrow} titleStart={howItWorks.titleStart} titleEmphasis={howItWorks.titleEmphasis} />
      </Reveal>
      <ol className="mt-14 grid gap-6 md:grid-cols-3">
        {howItWorks.steps.map((s, i) => {
          const Art = ART[i];
          return (
            <Reveal as="li" key={s.title} delay={i * 0.08} className="flex flex-col rounded-[1.4rem] bg-white p-7 shadow-[var(--shadow-card)] ring-1 ring-line/60">
              <div className="mb-6 aspect-[16/10] rounded-2xl bg-paper p-4">
                <Art />
              </div>
              <p className="serif text-2xl text-accent-ink" aria-hidden>
                0{i + 1}
              </p>
              <h3 className="mt-1 text-xl font-semibold tracking-tight">
                <span className="sr-only">Step {i + 1}: </span>
                {s.title}
              </h3>
              <p className="mt-3 leading-relaxed text-ink-soft">{s.body}</p>
            </Reveal>
          );
        })}
      </ol>
    </section>
  );
}

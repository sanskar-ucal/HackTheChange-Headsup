import { quickFacts } from "@/content/site";

export function QuickFacts() {
  return (
    <section aria-label="Quick facts" className="border-y border-line bg-white/55">
      <ul className="mx-auto grid max-w-6xl grid-cols-2 gap-y-6 px-5 py-8 sm:px-8 md:grid-cols-4">
        {quickFacts.map((f, i) => (
          <li
            key={f.strong}
            className={`flex items-center justify-center gap-3 text-center text-base text-ink-soft sm:text-lg ${i > 0 ? "md:border-l md:border-line" : ""}`}
          >
            <span aria-hidden className="h-1.5 w-1.5 shrink-0 rounded-full bg-accent" />
            <span>
              <strong className="serif text-[1.45rem] font-normal text-ink">{f.strong}</strong>
              {f.rest}
            </span>
          </li>
        ))}
      </ul>
    </section>
  );
}

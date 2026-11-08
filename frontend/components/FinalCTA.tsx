import { finalCta } from "@/content/site";
import { Reveal } from "./Reveal";
import { Emph } from "./ui";

/** Closing serif line on pale blue. */
export function FinalCTA() {
  return (
    <section aria-labelledby="cta-title" className="bg-pale">
      <div className="mx-auto max-w-6xl px-5 py-28 text-center sm:px-8 sm:py-40">
        <Reveal>
          <span aria-hidden className="mx-auto mb-10 block h-3 w-3 rounded-full bg-blue" />
          <h2 id="cta-title" className="display mx-auto max-w-4xl text-[clamp(3rem,8vw,5.75rem)]">
            <Emph text={finalCta.title} />
          </h2>
          <p className="mx-auto mt-8 max-w-md text-lg leading-relaxed text-ink-soft">{finalCta.body}</p>
        </Reveal>
      </div>
    </section>
  );
}

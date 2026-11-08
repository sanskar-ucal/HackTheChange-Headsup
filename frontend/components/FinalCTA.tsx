import { finalCta } from "@/content/site";
import { Reveal } from "./Reveal";
import { GitHubButton } from "./ui";

/** Closing line with the GitHub call to action. */
export function FinalCTA() {
  return (
    <section aria-labelledby="cta-title" className="bg-navy">
      <div className="mx-auto max-w-7xl px-5 py-28 sm:px-8 sm:py-40">
        <Reveal className="grid gap-10 lg:grid-cols-[1.5fr_1fr] lg:items-end">
          <h2 id="cta-title" className="display text-[clamp(3rem,8vw,7rem)]">
            {finalCta.title}
          </h2>
          <div className="lg:pb-4">
            <p className="max-w-sm text-lg leading-relaxed text-white/75">{finalCta.body}</p>
            <GitHubButton label={finalCta.cta} className="mt-8" />
          </div>
        </Reveal>
      </div>
    </section>
  );
}

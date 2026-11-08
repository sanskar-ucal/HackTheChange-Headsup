import { finalCta } from "@/content/site";
import { DOWNLOAD_URL, INSTALL_GUIDE_URL } from "@/site.config";
import { Reveal } from "./Reveal";
import { ArrowIcon, ButtonLink, DownloadIcon } from "./ui";

export function FinalCTA() {
  return (
    <section aria-labelledby="cta-title" className="mx-auto max-w-6xl px-5 py-28 text-center sm:px-8 sm:py-40">
      <Reveal>
        <span aria-hidden className="mx-auto mb-10 block h-3 w-3 rounded-full bg-accent" />
        <h2 id="cta-title" className="serif mx-auto max-w-4xl text-[3.2rem] leading-[0.98] sm:text-[5.5rem]">
          {finalCta.lineStart} <span className="em">{finalCta.lineEmphasis}</span>
        </h2>
        <div className="mt-12 flex flex-col justify-center gap-3 sm:flex-row">
          <ButtonLink href={DOWNLOAD_URL}>
            <DownloadIcon />
            {finalCta.primary}
          </ButtonLink>
          <ButtonLink href={INSTALL_GUIDE_URL} variant="secondary" external>
            {finalCta.secondary}
            <ArrowIcon />
          </ButtonLink>
        </div>
      </Reveal>
    </section>
  );
}

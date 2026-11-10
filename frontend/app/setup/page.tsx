import type { Metadata } from "next";
import { Footer } from "@/components/Footer";
import { Nav } from "@/components/Nav";
import { Reveal } from "@/components/Reveal";
import { SetupChecklist } from "@/components/setup/SetupChecklist";
import { Troubleshooter } from "@/components/setup/Troubleshooter";
import { ArrowIcon, ButtonLink, SectionHeading } from "@/components/ui";
import { permissions, permissionsSection, setupPage, troubleshootingSection } from "@/content/setup";
import { GITHUB_URL, INSTALL_GUIDE_URL } from "@/site.config";

export const metadata: Metadata = {
  title: setupPage.metaTitle,
  description: setupPage.metaDescription,
  alternates: { canonical: "/setup" },
  openGraph: { url: "/setup", title: setupPage.metaTitle, description: setupPage.metaDescription },
};

function RequiredBadge({ required }: { required: boolean }) {
  return (
    <span
      className={`inline-flex rounded-full px-3 py-1 text-sm font-medium ${required ? "bg-accent-wash text-accent-ink" : "bg-paper text-ink-soft ring-1 ring-line"}`}
    >
      {required ? "Required" : "Optional"}
    </span>
  );
}

export default function SetupPage() {
  return (
    <>
      <div className="print:hidden">
        <Nav />
      </div>
      <main id="main" tabIndex={-1} className="outline-none">
        <section aria-labelledby="setup-title" className="mx-auto max-w-6xl px-5 pb-12 pt-16 sm:px-8 sm:pt-24">
          <p className="mb-4 text-sm font-medium uppercase tracking-[0.14em] text-accent-ink">{setupPage.eyebrow}</p>
          <h1 id="setup-title" className="serif text-[3rem] leading-[1] sm:text-7xl">
            {setupPage.titleStart} <span className="em">{setupPage.titleEmphasis}</span>
          </h1>
          <p className="mt-6 max-w-2xl text-lg leading-relaxed text-ink-soft">{setupPage.body}</p>
          <nav aria-label="On this page" className="mt-8 print:hidden">
            <ul className="flex flex-wrap gap-2">
              {setupPage.sections.map((s) => (
                <li key={s.href}>
                  <a href={s.href} className="inline-flex min-h-11 items-center gap-2 rounded-full bg-white px-5 ring-1 ring-line transition-colors hover:ring-ink/30">
                    {s.label}
                    <ArrowIcon className="h-4 w-4 rotate-90" />
                  </a>
                </li>
              ))}
            </ul>
          </nav>
        </section>

        <section id="checklist" aria-label="Setup checklist" className="mx-auto max-w-6xl px-5 pb-24 sm:px-8">
          <SetupChecklist />
        </section>

        <section id="permissions" aria-labelledby="permissions-title" className="bg-paper-deep/60 py-24 print:hidden sm:py-32">
          <div className="mx-auto max-w-6xl px-5 sm:px-8">
            <Reveal>
              <SectionHeading
                id="permissions-title"
                eyebrow={permissionsSection.eyebrow}
                titleStart={permissionsSection.titleStart}
                titleEmphasis={permissionsSection.titleEmphasis}
                body={permissionsSection.body}
              />
            </Reveal>
            <div className="mt-12 overflow-x-auto rounded-[1.4rem] bg-white shadow-[var(--shadow-card)] ring-1 ring-line/60">
              <table className="w-full min-w-[40rem] text-left">
                <caption className="sr-only">Permissions HeadsUp uses</caption>
                <thead className="border-b border-line text-sm text-ink-soft">
                  <tr>
                    <th scope="col" className="px-6 py-4 font-medium">
                      Permission
                    </th>
                    <th scope="col" className="px-6 py-4 font-medium">
                      Needed?
                    </th>
                    <th scope="col" className="px-6 py-4 font-medium">
                      Why
                    </th>
                    <th scope="col" className="px-6 py-4 font-medium">
                      Where to turn it on
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {permissions.map((p) => (
                    <tr key={p.name}>
                      <th scope="row" className="px-6 py-4 font-semibold">
                        {p.name}
                      </th>
                      <td className="px-6 py-4">
                        <RequiredBadge required={p.required} />
                      </td>
                      <td className="px-6 py-4 leading-relaxed text-ink-soft">{p.why}</td>
                      <td className="px-6 py-4 leading-relaxed text-ink-soft">System Settings → {p.where}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <Reveal className="mt-8">
              <div className="rounded-[1.4rem] bg-white p-6 ring-1 ring-line/60">
                <h3 className="text-lg font-semibold">{permissionsSection.fixTitle}</h3>
                <ol className="mt-3 list-decimal space-y-1 pl-6 leading-relaxed text-ink-soft marker:font-medium marker:text-accent-ink">
                  {permissionsSection.fixSteps.map((s) => (
                    <li key={s}>{s}</li>
                  ))}
                </ol>
                <p className="mt-3 text-ink-soft">The same steps fix Motion & Fitness, Microphone, Speech Recognition and Camera.</p>
              </div>
            </Reveal>
          </div>
        </section>

        <section id="troubleshooting" aria-labelledby="troubleshooting-title" className="py-24 print:hidden sm:py-32">
          <div className="mx-auto grid max-w-6xl gap-12 px-5 sm:px-8 lg:grid-cols-[0.8fr_1.2fr]">
            <div>
              <SectionHeading
                id="troubleshooting-title"
                eyebrow={troubleshootingSection.eyebrow}
                titleStart={troubleshootingSection.titleStart}
                titleEmphasis={troubleshootingSection.titleEmphasis}
                body={troubleshootingSection.body}
              />
              <div className="mt-10 rounded-[1.4rem] bg-ink p-6 text-paper">
                <h3 className="text-lg font-semibold">{setupPage.stillStuckTitle}</h3>
                <p className="mt-2 leading-relaxed text-paper/80">{setupPage.stillStuckBody}</p>
                <div className="mt-5 flex flex-wrap gap-3">
                  <ButtonLink href={`${GITHUB_URL}/issues`} external>
                    {setupPage.stillStuckCta}
                  </ButtonLink>
                  <ButtonLink href={INSTALL_GUIDE_URL} variant="secondary" external>
                    Full install guide
                  </ButtonLink>
                </div>
              </div>
            </div>
            <Troubleshooter />
          </div>
        </section>
      </main>
      <div className="print:hidden">
        <Footer />
      </div>
    </>
  );
}

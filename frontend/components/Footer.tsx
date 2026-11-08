import { footer } from "@/content/site";
import { GITHUB_URL } from "@/site.config";
import { CodeIcon, Wordmark } from "./ui";

/** Wordmark, audience line, GitHub link and copyright. */
export function Footer() {
  const year = new Date().getFullYear();
  return (
    <footer className="border-t border-white/10 bg-navy">
      <div className="mx-auto flex max-w-7xl flex-col gap-6 px-5 py-10 sm:flex-row sm:items-center sm:justify-between sm:px-8">
        <div>
          <Wordmark />
          <p className="mt-2 text-white/70">{footer.tagline}</p>
        </div>
        <div className="flex flex-col gap-1 text-white/70 sm:items-end">
          <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer" className="-mx-2 inline-flex min-h-11 items-center gap-2 rounded-lg px-2 font-semibold text-white hover:text-sky">
            <CodeIcon />
            GitHub
            <span className="sr-only"> (opens in a new tab)</span>
          </a>
          <p className="text-sm">© {year} HeadsUp</p>
        </div>
      </div>
    </footer>
  );
}

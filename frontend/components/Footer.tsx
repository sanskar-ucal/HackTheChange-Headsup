import Link from "next/link";
import { setupNavLink } from "@/content/setup";
import { footer } from "@/content/site";
import { GITHUB_URL } from "@/site.config";
import { CodeIcon, Wordmark } from "./ui";

export function Footer() {
  const year = new Date().getFullYear();
  return (
    <footer className="border-t border-line">
      <div className="mx-auto flex max-w-6xl flex-col gap-6 px-5 py-10 sm:flex-row sm:items-center sm:justify-between sm:px-8">
        <div>
          <Wordmark />
          <p className="mt-2 text-ink-soft">{footer.tagline}</p>
        </div>
        <div className="flex flex-col gap-2 text-ink-soft sm:items-end">
          <Link href={setupNavLink.href} className="-mx-2 inline-flex min-h-11 items-center rounded-lg px-2 font-medium text-ink hover:text-accent-ink">
            {setupNavLink.label}
          </Link>
          <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer" className="-mx-2 inline-flex min-h-11 items-center gap-2 rounded-lg px-2 font-medium text-ink hover:text-accent-ink">
            <CodeIcon />
            {footer.github}
            <span className="sr-only"> (opens in a new tab)</span>
          </a>
          <p className="text-sm">© {year} HeadsUp</p>
        </div>
      </div>
    </footer>
  );
}

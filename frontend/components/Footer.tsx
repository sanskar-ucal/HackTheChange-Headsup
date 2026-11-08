import { footer } from "@/content/site";
import { Wordmark } from "./ui";

/** Navy footer: wordmark, audience line and copyright. */
export function Footer() {
  const year = new Date().getFullYear();
  return (
    <footer className="on-dark bg-navy text-white">
      <div className="mx-auto flex max-w-6xl flex-col gap-4 px-5 py-10 sm:flex-row sm:items-center sm:justify-between sm:px-8">
        <div>
          <Wordmark className="[&>span]:bg-sky" />
          <p className="mt-2 text-white/75">{footer.tagline}</p>
        </div>
        <p className="text-sm text-white/70">© {year} HeadsUp</p>
      </div>
    </footer>
  );
}

import { existsSync } from "node:fs";
import path from "node:path";
import { FAQ } from "@/components/FAQ";
import { Features } from "@/components/Features";
import { FinalCTA } from "@/components/FinalCTA";
import { Footer } from "@/components/Footer";
import { Gestures } from "@/components/Gestures";
import { Hero } from "@/components/Hero";
import { HowItWorks } from "@/components/HowItWorks";
import { Nav } from "@/components/Nav";
import { Privacy } from "@/components/Privacy";
import { QuickFacts } from "@/components/QuickFacts";
import { RealLife } from "@/components/RealLife";
import { Requirements } from "@/components/Requirements";
import { SeeItInAction } from "@/components/SeeItInAction";

// Resolved at build time (static export): drop demo.mp4 (and optionally demo-poster.jpg) into /public.
const publicFile = (name: string) => existsSync(path.join(process.cwd(), "public", name));
const hasVideo = publicFile("demo.mp4");
const poster = publicFile("demo-poster.jpg") ? "/demo-poster.jpg" : undefined;

export default function Home() {
  return (
    <>
      <Nav />
      <main id="main" tabIndex={-1} className="outline-none">
        <Hero />
        <QuickFacts />
        <SeeItInAction hasVideo={hasVideo} poster={poster} />
        <HowItWorks />
        <Gestures />
        <Features />
        <RealLife />
        <Privacy />
        <Requirements />
        <FAQ />
        <FinalCTA />
      </main>
      <Footer />
    </>
  );
}

import { Features } from "@/components/Features";
import { FinalCTA } from "@/components/FinalCTA";
import { Footer } from "@/components/Footer";
import { Gestures } from "@/components/Gestures";
import { Hero } from "@/components/Hero";
import { HowItWorks } from "@/components/HowItWorks";
import { Nav } from "@/components/Nav";
import { Privacy } from "@/components/Privacy";
import { RealLife } from "@/components/RealLife";

/** One page; sections alternate navy and pale blue. */
export default function Home() {
  return (
    <>
      <Nav />
      <main id="main" tabIndex={-1} className="outline-none">
        <Hero />
        <HowItWorks />
        <Gestures />
        <Features />
        <RealLife />
        <Privacy />
        <FinalCTA />
      </main>
      <Footer />
    </>
  );
}

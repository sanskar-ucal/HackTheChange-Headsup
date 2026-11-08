"use client";

import { useEffect, useRef, useState, type CSSProperties } from "react";
import { demo } from "@/content/site";
import { usePrefersReducedMotion } from "@/lib/hooks";
import { Laptop } from "./Laptop";
import { Reveal } from "./Reveal";
import { SectionHeading } from "./ui";

function VideoPlayer({ poster }: { poster?: string }) {
  const ref = useRef<HTMLVideoElement>(null);
  const reduced = usePrefersReducedMotion();
  const [playing, setPlaying] = useState(false);

  // Respect reduced motion: never autoplay, the viewer starts it.
  useEffect(() => {
    const v = ref.current;
    if (!v) return;
    if (reduced) v.pause();
    else v.play().catch(() => setPlaying(false));
  }, [reduced]);

  const toggle = () => {
    const v = ref.current;
    if (!v) return;
    if (v.paused) void v.play();
    else v.pause();
  };

  return (
    <div className="relative h-full w-full bg-ink">
      <video
        ref={ref}
        className="h-full w-full object-cover"
        src={poster ? "/demo.mp4" : "/demo.mp4#t=0.1"}
        poster={poster}
        muted
        loop
        playsInline
        autoPlay={false}
        preload="metadata"
        onPlay={() => setPlaying(true)}
        onPause={() => setPlaying(false)}
        aria-label="HeadsUp demo video: controlling a Mac with head movements"
      />
      <button
        type="button"
        onClick={toggle}
        aria-pressed={playing}
        className="absolute bottom-3 left-3 inline-flex min-h-11 items-center gap-2 rounded-full bg-white/95 px-4 text-sm font-medium text-ink shadow-[var(--shadow-card)] hover:bg-white"
      >
        <svg aria-hidden viewBox="0 0 20 20" className="h-4 w-4" fill="currentColor">
          {playing ? <path d="M6 4h3v12H6zM11 4h3v12h-3z" /> : <path d="M6 4l10 6-10 6z" />}
        </svg>
        {playing ? "Pause video" : "Play video"}
      </button>
    </div>
  );
}

/** Shown when /demo.mp4 is not in /public: the cursor glides between buttons and clicks. */
function CssFallback() {
  const buttons = [
    { label: "Call family", x: "22%", y: "38%" },
    { label: "Appointments", x: "50%", y: "38%" },
    { label: "Read news", x: "78%", y: "38%" },
  ];
  // Cursor stops (percent of its own box == percent of the stage, since the box fills the stage).
  const vars = {
    "--b1x": buttons[0].x,
    "--b1y": "47%",
    "--b2x": buttons[1].x,
    "--b2y": "47%",
    "--b3x": buttons[2].x,
    "--b3y": "47%",
  } as CSSProperties;

  return (
    <div className="relative h-full w-full select-none bg-paper" role="img" aria-label={demo.fallbackCaption}>
      <div className="flex h-[9%] items-center gap-1.5 border-b border-line bg-paper-deep px-[2%]">
        {[0, 1, 2].map((i) => (
          <span key={i} className="h-[0.55rem] w-[0.55rem] rounded-full bg-[#cfc8ba]" />
        ))}
        <span className="mx-auto pr-10 text-[clamp(0.55rem,1.2vw,0.8rem)] font-medium text-ink-soft">Home</span>
      </div>
      <p className="serif mt-[6%] text-center text-[clamp(1rem,3.4vw,2.2rem)] text-ink">
        Good morning. <span className="em">What would you like to do?</span>
      </p>
      {buttons.map((b, i) => (
        <div
          key={b.label}
          className="absolute flex h-[22%] w-[24%] -translate-x-1/2 items-center justify-center rounded-[0.9rem] bg-white text-[clamp(0.6rem,1.5vw,1rem)] font-medium text-ink shadow-[var(--shadow-card)] ring-1 ring-line"
          style={{ left: b.x, top: "36%", animation: `demo-press 8s ${1.85 + i * 2.08}s infinite` }}
        >
          {b.label}
        </div>
      ))}
      <div className="demo-cursor absolute inset-0" style={{ ...vars, animation: "demo-cursor 8s cubic-bezier(0.45,0.05,0.25,1) infinite" }}>
        <span className="absolute left-0 top-0 block h-[clamp(1.1rem,3vw,1.9rem)] w-[clamp(1.1rem,3vw,1.9rem)] -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-accent bg-accent/25">
          {[0, 1, 2].map((i) => (
            <span
              key={i}
              className="absolute inset-0 rounded-full border-2 border-accent"
              style={{ animation: `demo-ripple 8s ${1.85 + i * 2.08}s infinite`, opacity: 0 }}
            />
          ))}
        </span>
      </div>
      <div className="absolute bottom-[7%] left-1/2 flex -translate-x-1/2 items-center gap-2 rounded-full bg-white px-3 py-1.5 text-[clamp(0.55rem,1.2vw,0.8rem)] text-ink-soft shadow-[var(--shadow-card)]">
        <span className="h-2 w-2 rounded-full bg-accent" /> Look to point · nod to click
      </div>
    </div>
  );
}

export function SeeItInAction({ hasVideo, poster }: { hasVideo: boolean; poster?: string }) {
  return (
    <section aria-labelledby="demo-title" className="mx-auto max-w-6xl px-5 py-24 sm:px-8 sm:py-32">
      <Reveal>
        <SectionHeading id="demo-title" eyebrow={demo.eyebrow} titleStart={demo.titleStart} titleEmphasis={demo.titleEmphasis} body={demo.body} align="center" />
      </Reveal>
      <Reveal delay={0.1} className="mx-auto mt-14 max-w-4xl">
        <Laptop>{hasVideo ? <VideoPlayer poster={poster} /> : <CssFallback />}</Laptop>
      </Reveal>
    </section>
  );
}

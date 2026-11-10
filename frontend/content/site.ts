/**
 * All copy for the landing page lives here so it can be edited without touching layout code.
 */

export const nav = {
  links: [
    { href: "#how-it-works", label: "How it works" },
    { href: "#gestures", label: "Gestures" },
    { href: "#features", label: "Features" },
    { href: "#faq", label: "FAQ" },
  ],
  download: "Download for macOS",
};

export const hero = {
  headlineStart: "Your head is",
  headlineEmphasis: "the mouse.",
  subline:
    "HeadsUp turns the AirPods already in your ears into a hands-free mouse for your Mac, made for people who can't use their hands.",
  primaryCta: "Download for macOS",
  secondaryCta: "View on GitHub",
  smallPrint: ["Free & open source", "macOS 14+", "AirPods with head tracking"],
};

/** Honest facts only: no stats, reviews or download counts. */
export const quickFacts = [
  { strong: "3", rest: " head gestures" },
  { strong: "Camera", rest: " optional" },
  { strong: "Runs", rest: " on-device" },
  { strong: "Free", rest: " & open source" },
];

export const demo = {
  eyebrow: "See it in action",
  titleStart: "Point, nod,",
  titleEmphasis: "done.",
  body: "A short tour of everyday HeadsUp use: looking around the screen, nodding to click, and speaking into a search field.",
  fallbackCaption: "Preview animation. The full demo video plays here when it is available.",
};

export const howItWorks = {
  eyebrow: "How it works",
  titleStart: "Three steps,",
  titleEmphasis: "no hands.",
  steps: [
    {
      title: "Put in your AirPods",
      body: "Any AirPods with head tracking work. HeadsUp reads their motion sensors. No extra hardware, and no camera unless you turn on blink gestures.",
    },
    {
      title: "Calibrate by looking at 5 dots",
      body: "Look at each dot until its ring fills: center, the four corners, then center again. It takes about a minute.",
    },
    {
      title: "Look to point, nod to click",
      body: "Turn your head and the pointer follows. Nod and it clicks exactly where it was, then holds still.",
    },
  ],
};

export type GestureId = "look" | "nod" | "shake" | "tiltLeft" | "tiltRight" | "edge";

export const gestures: {
  eyebrow: string;
  titleStart: string;
  titleEmphasis: string;
  body: string;
  items: { id: GestureId; name: string; action: string; body: string }[];
} = {
  eyebrow: "Gestures",
  titleStart: "A small vocabulary,",
  titleEmphasis: "easy to learn.",
  body: "Hover over or focus a card to see the movement. Every action is confirmed with a soft sound in your AirPods.",
  items: [
    {
      id: "look",
      name: "Look",
      action: "Point",
      body: "Turn your head to move the pointer. The same head pose always lands on the same spot.",
    },
    {
      id: "nod",
      name: "Nod",
      action: "Click",
      body: "A small down-up nod clicks. The pointer freezes the moment the nod starts, so the click lands where you meant.",
    },
    {
      id: "shake",
      name: "Shake",
      action: "Back / Escape",
      body: "A quick left-right shake presses Escape. After voice input, it undoes the inserted text.",
    },
    {
      id: "tiltLeft",
      name: "Tilt & hold left",
      action: "Pause",
      body: "Tilt toward your left shoulder and hold for 1.5 seconds to pause or resume HeadsUp.",
    },
    {
      id: "tiltRight",
      name: "Tilt & hold right",
      action: "Recenter",
      body: "Tilt toward your right shoulder and hold to make your current pose the new center.",
    },
    {
      id: "edge",
      name: "Look past the edge",
      action: "Scroll",
      body: "Keep looking a little past the top or bottom of the screen to scroll. Look back to stop.",
    },
  ],
};

export type FeatureId = "voice" | "pointer" | "scroll" | "styles" | "audio";

export const features: {
  eyebrow: string;
  titleStart: string;
  titleEmphasis: string;
  items: { id: FeatureId; title: string; body: string; points: string[] }[];
} = {
  eyebrow: "Features",
  titleStart: "Everything a mouse does,",
  titleEmphasis: "gently.",
  items: [
    {
      id: "voice",
      title: "Voice search",
      body: "Nod-click into a search field and just speak. Your words appear in a bubble beside the pointer, then go into the field.",
      points: ["Nod to press Return", "Shake to undo", "Password fields never listen"],
    },
    {
      id: "pointer",
      title: "A smooth, precise pointer",
      body: "Head motion is filtered and eased so the pointer glides without jitter. A sensitivity control sets how far you need to turn.",
      points: ["Calmer or faster with one slider", "Optional 20-second practice suggests a setting", "No drift during clicks"],
    },
    {
      id: "scroll",
      title: "Scrolling that just works",
      body: "Look a little past the top or bottom edge and the page scrolls. The further you look, the faster it goes.",
      points: ["Adjustable scroll speed", "Optional left and right scrolling", "Stops as soon as you look back"],
    },
    {
      id: "styles",
      title: "Pointer styles",
      body: "Choose the pointer that is easiest for you to see: the green circle, a hand that changes shape, a ring, a dot or a crosshair.",
      points: ["Any color, four sizes", "High-contrast outline", "The hand shows what you're doing"],
    },
    {
      id: "audio",
      title: "Audio cues in your AirPods",
      body: "Short, quiet sounds confirm every click, pause and recenter, so you always know what happened without looking for it.",
      points: ["Spoken prompts during setup", "Distinct sound for each action", "Works with your music playing"],
    },
  ],
};

export type LifeId = "close" | "care" | "slow" | "fun";

export const realLife: {
  eyebrow: string;
  titleStart: string;
  titleEmphasis: string;
  items: { id: LifeId; title: string; body: string; link?: { href: string; label: string } }[];
} = {
  eyebrow: "Made for real life",
  titleStart: "The things that",
  titleEmphasis: "matter most.",
  items: [
    {
      id: "close",
      title: "Staying close",
      body: "Start a video call with family on your own, whenever you like.",
    },
    {
      id: "care",
      title: "Taking care",
      body: "Book your own appointments and fill in forms without waiting for help.",
    },
    {
      id: "slow",
      title: "Slowing down",
      body: "Read the news or a long article at your own pace, one gentle scroll at a time.",
    },
    {
      id: "fun",
      title: "Having fun",
      body: "Games work too. Watch HeadsUp play a quick game of chess.",
      link: { href: "#top", label: "Watch the chess demo" },
    },
  ],
};

export const privacy = {
  eyebrow: "Privacy",
  titleStart: "Stays on",
  titleEmphasis: "your Mac.",
  body: "Head motion, voice and, if you turn on blink gestures, camera frames are processed on your Mac. Nothing about how you move, what you say or what the camera sees is sent to us.",
  points: [
    { title: "No account", body: "Download it and use it. There's nothing to sign up for." },
    { title: "No tracking", body: "No analytics, no ads, no telemetry." },
    {
      title: "Camera only if you ask",
      body: "Blink gestures are off by default. When on, the camera only measures how open your eyes are: no video is saved and no face is identified.",
    },
  ],
};

export const requirements = {
  eyebrow: "Requirements",
  titleStart: "What you'll",
  titleEmphasis: "need.",
  groups: [
    {
      title: "A Mac",
      items: ["macOS 14 Sonoma or later"],
    },
    {
      title: "AirPods with head tracking",
      items: ["AirPods Pro (any generation)", "AirPods (3rd generation or later)", "AirPods Max", "Beats with head tracking"],
    },
    {
      title: "Permissions",
      items: [
        "Accessibility (required, to move and click)",
        "Motion & Fitness (required)",
        "Microphone & Speech Recognition (optional, for voice search)",
      ],
    },
  ],
};

export const faq = {
  eyebrow: "FAQ",
  titleStart: "Questions,",
  titleEmphasis: "answered.",
  items: [
    {
      q: "Who is it for?",
      a: "People who can't use their hands, or find a mouse and keyboard painful or tiring: for example after a spinal cord injury, with ALS, MS, arthritis or a stroke. It's also useful for anyone who wants hands-free control for a while.",
    },
    {
      q: "Which AirPods work?",
      a: "Any AirPods with head tracking: AirPods Pro (any generation), AirPods (3rd generation or later), AirPods Max, and Beats with head tracking. They need to be connected to your Mac and selected as its sound output.",
    },
    {
      q: "Does it need a camera?",
      a: "No. HeadsUp uses the motion sensors inside your AirPods, so it works in the dark, in bed, and without anything pointed at your face. If you like, you can turn on blink gestures (double blink to click, triple blink to cancel), which use the Mac's camera. They're off by default and everything stays on your Mac.",
    },
    {
      q: "Is my data private?",
      a: "Yes. Head motion and speech are processed on your Mac. There's no account, no analytics and no tracking.",
    },
    {
      q: "How do I click?",
      a: "Nod. A small down-up nod clicks wherever the pointer is. The pointer freezes the moment the nod starts, so the click lands exactly where you aimed, then holds still briefly before following your head again.",
    },
    {
      q: "Can I play games like chess?",
      a: "Yes. Anything you can do with clicks works: board games, card games, puzzles. Nod on a piece to pick it up, look at the square, and nod again to place it.",
    },
    {
      q: "Why does macOS say the app is from an unidentified developer?",
      a: "HeadsUp isn't signed with a paid Apple developer certificate yet, so macOS shows a warning the first time. Right-click the app and choose Open, or go to System Settings → Privacy & Security and click Open Anyway. The install guide walks through it step by step.",
    },
    {
      q: "Can caregivers help set it up?",
      a: "Yes, and we recommend it. Setup takes about three minutes: install, allow two permissions, connect the AirPods. After that, calibration and daily use are completely hands-free. There's also a keyboard shortcut (Control-Option-Command-H) a caregiver can press to pause.",
    },
    {
      q: "Is it free?",
      a: "Yes. HeadsUp is free and open source. You can read, build and change the code on GitHub.",
    },
  ],
};

export const finalCta = {
  lineStart: "Independence,",
  lineEmphasis: "one nod at a time.",
  primary: "Download for macOS",
  secondary: "Read the install guide",
};

export const footer = {
  tagline: "Made with care for hands-free computing",
  github: "GitHub",
};

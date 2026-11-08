export const nav = {
  links: [
    { href: "#how-it-works", label: "How it works" },
    { href: "#gestures", label: "Gestures" },
    { href: "#features", label: "Features" },
    { href: "#privacy", label: "Privacy" },
  ],
  cta: "View on GitHub",
};

export const hero = {
  eyebrow: "Hands-free Mac mouse",
  headline: "Your head is the mouse.",
  subline:
    "HeadsUp is built for people with tetraplegia. Turn your head to move the pointer and nod to click, using the AirPods already in your ears.",
  cta: "View on GitHub",
  facts: ["macOS 14 or later", "AirPods with head tracking", "Free, code on GitHub"],
};

export const howItWorks = {
  eyebrow: "How it works",
  title: "Set up once. Then it's all head movement.",
  body: "A caregiver can do the one-time setup with a mouse and keyboard in a few minutes. Everything after that is hands-free.",
  steps: [
    {
      title: "Put in your AirPods",
      body: "HeadsUp reads the motion sensors in AirPods with head tracking. You don't need a camera or extra hardware to point.",
    },
    {
      title: "Look at each calibration dot",
      body: "One dot at a time: the center, the four corners, then the center again. Hold still until each ring fills. Spoken prompts guide you.",
    },
    {
      title: "Look to point, nod to click",
      body: "The pointer follows your head. A nod clicks exactly where the pointer was, and the pointer holds still for a moment, like a mouse.",
    },
  ],
};

export type GestureId = "look" | "nod" | "shake" | "tiltLeft" | "tiltRight" | "edge";

export const gestures: {
  eyebrow: string;
  title: string;
  body: string;
  items: { id: GestureId; name: string; action: string; body: string }[];
} = {
  eyebrow: "Gestures",
  title: "Six movements cover the whole Mac.",
  body: "Every action plays a short sound in your AirPods, so you always know it worked. Hover over or focus a row to see it.",
  items: [
    { id: "look", name: "Look", action: "Point", body: "Turn your head and the pointer follows. The same head position always lands on the same spot." },
    { id: "nod", name: "Nod", action: "Click", body: "A small down-up nod clicks. The pointer freezes the moment the nod starts and holds still after the click." },
    { id: "shake", name: "Shake", action: "Escape", body: "A quick left-right shake presses Escape. After voice input, it undoes the text." },
    { id: "tiltLeft", name: "Tilt left and hold", action: "Pause", body: "Hold the tilt for 1.5 seconds to pause or resume HeadsUp. It works while voice input is listening too." },
    { id: "tiltRight", name: "Tilt right and hold", action: "Recenter", body: "Your current head position becomes the new center, and the pointer glides back to the middle." },
    { id: "edge", name: "Look past the edge", action: "Scroll", body: "Keep looking a little past the top or bottom of the screen. The further you look, the faster it scrolls." },
  ],
};

export const features = {
  eyebrow: "Features",
  title: "The settings you'd want, sized for head pointing.",
  body: "Every control has a large target and −/+ buttons, so you can change your own settings without help.",
  settings: {
    title: "Settings",
    note: "Changes apply instantly. No recalibration.",
  },
  styles: {
    title: "Pointer styles",
    body: "Green circle by default. Hand, ring, dot or crosshair, in any color and four sizes.",
  },
  voice: {
    title: "Voice search",
    body: "Nod-click into a search field and speak. Nod to search, shake to undo. Password fields never listen.",
  },
  blink: {
    title: "Blink controls (beta)",
    body: "Optional: the Mac's camera notices a double blink (click) or triple blink (Escape). Off by default.",
  },
  scroll: {
    title: "Edge scrolling",
    body: "Look past the top or bottom edge to scroll. Speed is adjustable.",
  },
  audio: {
    title: "Sounds in your AirPods",
    body: "Short cues confirm clicks, pauses and recenters. Spoken prompts guide calibration.",
  },
};

export const realLife = {
  eyebrow: "Made for real life",
  title: "The things that matter, on your own terms.",
  items: [
    { title: "Staying close", body: "Start a video call with family whenever you like." },
    { title: "Taking care", body: "Book appointments and fill in forms yourself." },
    { title: "Slowing down", body: "Read a long article at your own pace, one look at a time." },
  ],
  fun: { title: "Having fun", body: "Games work too. Scroll up to watch HeadsUp play chess.", link: "Watch the chess demo" },
};

export const privacy = {
  eyebrow: "Privacy",
  title: "Your movements stay on your Mac.",
  points: [
    { title: "Head motion", body: "AirPods motion is processed on your Mac and never leaves it." },
    { title: "Voice", body: "Speech recognition runs on your Mac whenever macOS supports it for your language." },
    { title: "Blink controls (beta)", body: "Camera frames are analyzed in memory and dropped right away. No face recognition, nothing stored." },
    { title: "No account", body: "Nothing to sign up for. No ads, no analytics." },
  ],
};

export const finalCta = {
  title: "Independence, one nod at a time.",
  body: "HeadsUp is free. The code, the install guide and the releases are on GitHub.",
  cta: "View on GitHub",
};

export const footer = {
  tagline: "A hands-free Mac mouse for people with tetraplegia.",
};

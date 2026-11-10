/** Copy for the /setup guide: a caregiver checklist, permissions and troubleshooting. */

export const setupNavLink = { href: "/setup", label: "Setup guide" };

export const setupPage = {
  metaTitle: "Set up HeadsUp: a step-by-step guide",
  metaDescription:
    "A checklist for setting up HeadsUp on a Mac: install, permissions, AirPods and calibration, plus fixes for the most common problems.",
  eyebrow: "Setup guide",
  titleStart: "Ready in",
  titleEmphasis: "ten minutes.",
  body: "Written for the caregiver or family member doing the one-time setup. Tick off each step as you go. Your progress is saved in this browser only.",
  sections: [
    { href: "#checklist", label: "Checklist" },
    { href: "#permissions", label: "Permissions" },
    { href: "#troubleshooting", label: "Troubleshooting" },
  ],
  stillStuckTitle: "Still stuck?",
  stillStuckBody: "Open an issue on GitHub with what you tried and what you see. Screenshots of the HeadsUp menu-bar panel help a lot.",
  stillStuckCta: "Ask on GitHub",
};

export type ChecklistGroupId = "prepare" | "install" | "permissions" | "calibrate";

export const checklistGroups: { id: ChecklistGroupId; title: string }[] = [
  { id: "prepare", title: "Before you start" },
  { id: "install", title: "Install" },
  { id: "permissions", title: "Permissions" },
  { id: "calibrate", title: "AirPods & calibration" },
];

export const checklist: { id: string; group: ChecklistGroupId; title: string; detail: string }[] = [
  {
    id: "macos",
    group: "prepare",
    title: "Check the Mac runs macOS 14 Sonoma or later",
    detail: "Apple menu → About This Mac. Older versions can't read AirPods head tracking.",
  },
  {
    id: "airpods",
    group: "prepare",
    title: "Have AirPods with head tracking",
    detail: "AirPods Pro (any generation), AirPods (3rd generation or later), AirPods Max, or Beats with head tracking.",
  },
  {
    id: "sound-output",
    group: "prepare",
    title: "Connect the AirPods and pick them as the sound output",
    detail: "Control Center → Sound → choose the AirPods. HeadsUp reads motion only from the current output.",
  },
  {
    id: "download",
    group: "install",
    title: "Download HeadsUp and move it to Applications",
    detail: "Unzip the download and drag HeadsUp.app into the Applications folder.",
  },
  {
    id: "first-open",
    group: "install",
    title: "Open it once past the security warning",
    detail: "Right-click HeadsUp → Open → Open. On newer macOS: System Settings → Privacy & Security → Open Anyway.",
  },
  {
    id: "menu-bar",
    group: "install",
    title: "Find the HeadsUp icon in the menu bar",
    detail: "HeadsUp has no Dock icon. Its menu-bar panel shows the status and opens Settings.",
  },
  {
    id: "accessibility",
    group: "permissions",
    title: "Allow Accessibility",
    detail: "Required to move the pointer and click. Privacy & Security → Accessibility → turn on HeadsUp.",
  },
  {
    id: "motion",
    group: "permissions",
    title: "Allow Motion & Fitness",
    detail: "Required. macOS asks the first time the AirPods send motion: click Allow.",
  },
  {
    id: "voice",
    group: "permissions",
    title: "Optional: allow Microphone and Speech Recognition",
    detail: "Only for voice search. macOS asks the first time voice input starts.",
  },
  {
    id: "camera",
    group: "permissions",
    title: "Optional: turn on blink gestures and allow the Camera",
    detail: "Settings → Blink gestures. Double blink clicks, triple blink presses Escape. Off by default.",
  },
  {
    id: "calibrate",
    group: "calibrate",
    title: "Calibrate: look at each dot until its ring fills",
    detail: "Center, the four corners, then the center again. Hold still about 1.5 seconds per dot.",
  },
  {
    id: "test-click",
    group: "calibrate",
    title: "Try a nod click and a tilt-left pause",
    detail: "Nod on something harmless, like an empty part of the desktop. Tilt left and hold 1.5 s to pause and resume.",
  },
  {
    id: "caregiver-shortcut",
    group: "calibrate",
    title: "Learn the caregiver shortcut ⌃⌥⌘H",
    detail: "Control-Option-Command-H pauses or resumes HeadsUp from the keyboard at any time.",
  },
];

export const permissionsSection = {
  eyebrow: "Permissions",
  titleStart: "What HeadsUp asks",
  titleEmphasis: "and why.",
  body: "Every permission is managed in System Settings → Privacy & Security. You can turn any of them off again later.",
  fixTitle: "The switch is on, but it still doesn't work?",
  fixSteps: [
    "Quit HeadsUp from its menu-bar panel.",
    "In Privacy & Security, select HeadsUp in the list and click − to remove it.",
    "Click +, choose Applications → HeadsUp, and turn it on again.",
    "Open HeadsUp again.",
  ],
};

export const permissions: { name: string; required: boolean; why: string; where: string }[] = [
  {
    name: "Accessibility",
    required: true,
    why: "Moves the pointer, clicks, scrolls and types in other apps.",
    where: "Privacy & Security → Accessibility",
  },
  {
    name: "Motion & Fitness",
    required: true,
    why: "Reads head movement from the AirPods.",
    where: "Privacy & Security → Motion & Fitness",
  },
  {
    name: "Microphone",
    required: false,
    why: "Voice search: speak into search fields.",
    where: "Privacy & Security → Microphone",
  },
  {
    name: "Speech Recognition",
    required: false,
    why: "Turns speech into text, on the Mac when supported.",
    where: "Privacy & Security → Speech Recognition",
  },
  {
    name: "Camera",
    required: false,
    why: "Blink gestures only. Measures how open the eyes are; nothing is saved.",
    where: "Privacy & Security → Camera",
  },
];

export const troubleshootingSection = {
  eyebrow: "Troubleshooting",
  titleStart: "Something not",
  titleEmphasis: "working?",
  body: "Describe the problem in a few words, for example “clicks” or “no sound”.",
  searchLabel: "Search problems",
  searchPlaceholder: "e.g. pointer drifts",
  suggestionsLabel: "Common topics",
  suggestions: ["pointer", "clicks", "voice", "sound", "blink", "scroll"],
  noResults: "No matching problems. Try fewer or different words.",
  clear: "Clear search",
};

export const troubleshooting: { id: string; problem: string; keywords: string[]; steps: string[] }[] = [
  {
    id: "pointer-still",
    problem: "The pointer doesn't move",
    keywords: ["pointer", "cursor", "frozen", "stuck", "motion", "airpods"],
    steps: [
      "Check that Motion & Fitness is allowed for HeadsUp.",
      "Check the AirPods are connected and selected as the sound output. Take them out and put them back in if needed.",
      "Make sure HeadsUp isn't paused: tilt left and hold, or press ⌃⌥⌘H.",
      "Recenter: tilt right and hold, or look at the middle of the screen and hold still.",
    ],
  },
  {
    id: "no-clicks",
    problem: "The pointer moves but clicks don't work",
    keywords: ["click", "clicks", "nod", "accessibility", "permission"],
    steps: [
      "The Accessibility permission is missing or stale. Remove HeadsUp from the Accessibility list and add it again.",
      "Quit and reopen HeadsUp afterwards.",
      "If you build HeadsUp from source, every rebuild can need this again (see “permissions reset after rebuilding”).",
    ],
  },
  {
    id: "nods-missed",
    problem: "Nods aren't recognized",
    keywords: ["nod", "click", "gesture", "sensitive", "detect"],
    steps: [
      "Settings → Gestures: lower Nod/shake speed and Nod size.",
      "Open Settings → Advanced → Live readout. The gesture log lists every nod as confirmed or rejected, with the reason.",
      "Make the nod a quick, small down-up movement rather than a slow bow.",
    ],
  },
  {
    id: "drift",
    problem: "The pointer slowly drifts",
    keywords: ["drift", "pointer", "center", "off", "offset", "recenter"],
    steps: [
      "This is normal over time: head tracking isn't eye tracking.",
      "Tilt right and hold to recenter.",
      "If it keeps happening, recalibrate from the menu-bar panel.",
    ],
  },
  {
    id: "too-fast",
    problem: "The pointer is too fast, too slow or jumpy",
    keywords: ["pointer", "speed", "fast", "slow", "jumpy", "jitter", "sensitivity", "smooth"],
    steps: [
      "Settings → Movement → Sensitivity: Calmer for less travel per head turn, Faster for more.",
      "Raise Smoothing if the pointer is jittery.",
      "Optional: turn on Practice after calibration; it suggests a sensitivity after three targets.",
    ],
  },
  {
    id: "wrong-way",
    problem: "The pointer moves the wrong way",
    keywords: ["pointer", "reversed", "inverted", "wrong", "direction", "backwards"],
    steps: ["Settings → Advanced: use the Invert yaw, pitch or roll toggles.", "Recalibrate afterwards."],
  },
  {
    id: "no-sound",
    problem: "No confirmation sounds",
    keywords: ["sound", "audio", "cue", "quiet", "mute", "volume"],
    steps: [
      "Check the AirPods are the sound output.",
      "Settings → Sound: turn Mute cues off and raise Cue volume.",
    ],
  },
  {
    id: "voice",
    problem: "Voice input doesn't start",
    keywords: ["voice", "speech", "microphone", "dictation", "search", "talk"],
    steps: [
      "Allow Microphone and Speech Recognition for HeadsUp.",
      "Voice only starts after you nod-click into a search field (or any text field, if chosen in Settings → Voice input).",
      "Password fields never start listening. Some apps don't expose their fields to macOS, so voice can't start there.",
    ],
  },
  {
    id: "scroll",
    problem: "Scrolling is too fast, too slow or doesn't happen",
    keywords: ["scroll", "scrolling", "edge", "page", "speed"],
    steps: [
      "Settings → Scrolling → Scroll speed.",
      "Edge push distance sets how far past the top or bottom edge to look before scrolling starts.",
      "Check Edge-push scrolling is on.",
    ],
  },
  {
    id: "blinks-missed",
    problem: "Blinks aren't counted",
    keywords: ["blink", "camera", "eyes", "glasses", "double", "triple"],
    steps: [
      "Check Settings → Blink gestures is on and the camera status says “Camera on”. Blinks only act while HeadsUp is tracking.",
      "Watch the live indicator in that section: it should show “Eyes open” and count your blinks.",
      "Raise the Eye-closed threshold (helps with glasses), face the camera, and avoid strong light behind you.",
    ],
  },
  {
    id: "blinks-accidental",
    problem: "Ordinary blinks cause clicks",
    keywords: ["blink", "accidental", "click", "camera", "triple", "double"],
    steps: [
      "Settings → Blink gestures: raise Shortest blink so quick, natural blinks are ignored.",
      "Lower Time between blinks so only blinks in quick succession count.",
      "If triple blinks click instead of cancelling, raise Time between blinks a little.",
    ],
  },
  {
    id: "camera-denied",
    problem: "The camera is denied or not found",
    keywords: ["camera", "denied", "blink", "permission", "webcam"],
    steps: [
      "System Settings → Privacy & Security → Camera → turn on HeadsUp.",
      "Back in Settings → Blink gestures, choose Try again.",
      "If no camera is found, connect one or select it as the default camera and choose Try again.",
    ],
  },
  {
    id: "rebuild",
    problem: "Permissions reset after rebuilding from source",
    keywords: ["rebuild", "xcode", "developer", "accessibility", "permission", "source", "signing"],
    steps: [
      "Source builds are ad-hoc signed, so macOS treats each build as a new app.",
      "Run tccutil reset Accessibility com.hackthechange.HeadsUp and allow it again.",
      "For a stable grant, set DEVELOPMENT_TEAM in project.yml.",
    ],
  },
];

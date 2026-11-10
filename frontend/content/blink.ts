/** Copy for the optional blink gestures section and its in-browser trainer. */

export type BlinkGestureId = "double" | "triple";

export const blink: {
  eyebrow: string;
  titleStart: string;
  titleEmphasis: string;
  body: string;
  items: { id: BlinkGestureId; name: string; action: string; body: string }[];
  safeguardsTitle: string;
  safeguards: string[];
  privacy: string;
  enable: string;
} = {
  eyebrow: "Blink gestures",
  titleStart: "Or simply",
  titleEmphasis: "blink.",
  body: "For days when nodding is tiring. Turn on Blink gestures in Settings and your Mac's camera watches for deliberate blinks. Nod and shake keep working too.",
  items: [
    {
      id: "double",
      name: "Double blink",
      action: "Click",
      body: "Two firm blinks in a row click where the pointer is. HeadsUp waits half a second for a possible third blink first.",
    },
    {
      id: "triple",
      name: "Triple blink",
      action: "Back / Escape",
      body: "Three blinks press Escape. A triple blink never clicks first, so cancelling is always safe.",
    },
  ],
  safeguardsTitle: "Ordinary blinks never click",
  safeguards: [
    "A single blink, a quick flutter or resting your eyes is ignored.",
    "Only the person in front of the Mac counts: with two similar faces in view, blinks are ignored.",
    "A short cooldown after each action stops repeats, and pausing HeadsUp turns the camera off.",
  ],
  privacy:
    "Video is analyzed on your Mac only to measure how open your eyes are. Nothing is saved or sent, and faces are never identified. Blink gestures are off until you turn them on.",
  enable: "Settings → Blink gestures",
};

export const trainer = {
  title: "Try the rhythm",
  body: "Press and hold the button for each blink, or focus it and hold the Space bar. It follows the same timing rules as the app. No camera involved.",
  hold: "Hold to blink",
  holding: "Eyes closed…",
  windowLabel: "Time between blinks",
  windowHelp: "How long HeadsUp waits for the next blink. A double blink clicks after this wait.",
  minLabel: "Shortest blink",
  minHelp: "Shorter presses count as a flutter and are ignored.",
  reset: "Reset",
  timelineLabel: "Last six seconds",
  historyLabel: "What HeadsUp would do",
  idle: "Waiting for a blink",
  messages: {
    blink1: "One blink. Blink again to click.",
    blink2: "Two blinks. Wait to click, or blink once more to cancel.",
    select: "Double blink: click!",
    cancel: "Triple blink: Escape!",
    expired: "A single blink: ignored, as it should be.",
    tooShort: "Too quick: that was a flutter. Hold a little longer.",
    tooLong: "Too long: that's resting your eyes, not a blink.",
    cooldown: "Cooling down after the last action.",
    reset: "Sequence dropped.",
  },
};

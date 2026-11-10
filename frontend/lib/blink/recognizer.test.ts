import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { BlinkSequenceRecognizer, commandOf, DEFAULT_BLINK_CONFIG, type BlinkEvent } from "./recognizer";

type Range = [number, number];
const inside = (ranges: Range[], t: number) => ranges.some(([a, b]) => t >= a && t <= b);

/**
 * Feeds 30 Hz samples from `from` to `until`: closed inside `closed`, null (face lost)
 * inside `lost`, and no samples at all inside `gaps`. Returns every event with its time.
 */
function run(
  r: BlinkSequenceRecognizer,
  closed: Range[],
  { lost = [], gaps = [], from = 0, until }: { lost?: Range[]; gaps?: Range[]; from?: number; until: number },
): { event: BlinkEvent; t: number }[] {
  const events: { event: BlinkEvent; t: number }[] = [];
  const frames = Math.round((until - from) * 30);
  for (let i = 0; i <= frames; i++) {
    const t = from + i / 30;
    if (inside(gaps, t)) continue;
    const sample = inside(lost, t) ? null : inside(closed, t);
    const event = r.process(sample, t);
    if (event) events.push({ event, t });
  }
  return events;
}

const commands = (events: { event: BlinkEvent }[]) => events.map((e) => commandOf(e.event)).filter(Boolean);
const types = (events: { event: BlinkEvent }[]) => events.map((e) => e.event.type);

const double: Range[] = [
  [0.21, 0.39],
  [0.61, 0.79],
];
const triple: Range[] = [...double, [1.01, 1.19]];

describe("BlinkSequenceRecognizer", () => {
  it("uses the app's defaults", () => {
    assert.deepEqual(new BlinkSequenceRecognizer().config, { ...DEFAULT_BLINK_CONFIG });
  });

  it("selects once, after the full window, for a double blink", () => {
    const events = run(new BlinkSequenceRecognizer(), double, { until: 2 });
    assert.deepEqual(commands(events), ["select"]);
    assert.deepEqual(types(events), ["blink", "blink", "select"]);
    const select = events.find((e) => e.event.type === "select");
    // The second blink reopens at 0.8 s; the eyes must then stay open for 0.5 s.
    assert.ok(select && Math.abs(select.t - 1.3) < 0.04, `select at ${select?.t}`);
  });

  it("cancels on a triple blink without selecting first", () => {
    const events = run(new BlinkSequenceRecognizer(), triple, { until: 3 });
    assert.deepEqual(commands(events), ["cancel"]);
  });

  it("counts a slow third blink that starts inside the window", () => {
    const events = run(new BlinkSequenceRecognizer(), [...double, [1.22, 1.52]], { until: 3 });
    assert.deepEqual(commands(events), ["cancel"]);
  });

  it("never acts on a single blink", () => {
    const r = new BlinkSequenceRecognizer();
    const events = run(r, [[0.21, 0.39]], { until: 2 });
    assert.deepEqual(types(events), ["blink", "expired"]);
    assert.equal(r.blinkCount, 0);
  });

  it("explains closures that are too short or too long", () => {
    const [short, ...restShort] = run(new BlinkSequenceRecognizer(), [[0.2, 0.24]], { until: 1 });
    assert.equal(restShort.length, 0);
    assert.ok(short?.event.type === "rejected" && short.event.reason === "tooShort" && short.event.duration < 0.1);

    const [long, ...restLong] = run(new BlinkSequenceRecognizer(), [[0.2, 1.5]], { until: 2 });
    assert.equal(restLong.length, 0, "reported once, while the eyes are still closed");
    assert.ok(long?.event.type === "rejected" && long.event.reason === "tooLong" && long.t < 1);
  });

  it("abandons two blinks followed by resting eyes", () => {
    const events = run(new BlinkSequenceRecognizer(), [...double, [1.01, 2.0]], { until: 4 });
    assert.deepEqual(commands(events), []);
  });

  it("does not select when a quick flutter follows two blinks", () => {
    const events = run(new BlinkSequenceRecognizer(), [...double, [1.0, 1.04]], { until: 3 });
    assert.deepEqual(commands(events), []);
  });

  it("swallows blinks during the cooldown, then works again", () => {
    const r = new BlinkSequenceRecognizer();
    const first = run(r, [...double, [1.41, 1.59], [1.81, 1.99]], { until: 3 });
    assert.deepEqual(commands(first), ["select"]);
    assert.ok(types(first).includes("cooldown"));
    const second = run(
      r,
      [
        [3.21, 3.39],
        [3.61, 3.79],
      ],
      { from: 3 + 1 / 30, until: 5 },
    );
    assert.deepEqual(commands(second), ["select"]);
  });

  it("resets on lost tracking or a frame gap", () => {
    const lost = run(new BlinkSequenceRecognizer(), double, { lost: [[0.5, 0.52]], until: 3 });
    assert.deepEqual(commands(lost), []);
    assert.ok(lost.some((e) => e.event.type === "reset" && e.event.reason === "trackingLost"));

    const gap = run(
      new BlinkSequenceRecognizer(),
      [
        [0.21, 0.39],
        [0.91, 1.09],
      ],
      { gaps: [[0.45, 0.85]], until: 3 },
    );
    assert.deepEqual(commands(gap), []);
    assert.ok(gap.some((e) => e.event.type === "reset" && e.event.reason === "frameGap"));
  });

  it("treats blinks too far apart as separate singles", () => {
    const events = run(
      new BlinkSequenceRecognizer(),
      [
        [0.21, 0.39],
        [1.01, 1.19],
      ],
      { until: 3 },
    );
    assert.deepEqual(types(events), ["blink", "expired", "blink", "expired"]);
  });

  it("never acts on a minute of ordinary blinking", () => {
    const closures: Range[] = [];
    const lengths = [0.12, 0.2, 0.3, 0.15];
    const gaps = [2.0, 3.5, 2.6, 4.0];
    for (let t = 1, i = 0; t < 60; t += gaps[i % 4]!, i++) closures.push([t, t + lengths[i % 4]!]);
    const r = new BlinkSequenceRecognizer();
    assert.deepEqual(commands(run(r, closures, { until: 62 })), []);
    assert.ok(r.totalBlinks > 10);
  });

  it("follows a custom window", () => {
    // Blinks 0.65 s apart (eyes open) only form a sequence with a longer window.
    const spaced: Range[] = [
      [0.21, 0.39],
      [1.06, 1.24],
    ];
    assert.deepEqual(commands(run(new BlinkSequenceRecognizer(), spaced, { until: 3 })), []);
    assert.deepEqual(commands(run(new BlinkSequenceRecognizer({ sequenceWindow: 0.8 }), spaced, { until: 3 })), ["select"]);
  });

  it("keeps maxClosure at least minClosure", () => {
    const r = new BlinkSequenceRecognizer({ minClosure: 0.3, maxClosure: 0.2 });
    assert.equal(r.config.maxClosure, 0.3);
  });
});

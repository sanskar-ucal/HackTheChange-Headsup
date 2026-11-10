import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { troubleshooting } from "../content/setup";
import { normalize, score, search, tokenize, type SearchField } from "./search";

type Entry = { title: string; tags: string[] };
const fields = (e: Entry): SearchField[] => [
  { text: e.title, weight: 3 },
  { text: e.tags.join(" "), weight: 1 },
];
const entries: Entry[] = [
  { title: "Scrolling is slow", tags: ["edge", "page"] },
  { title: "Pointer drifts", tags: ["recenter", "scroll"] },
  { title: "No sound", tags: ["audio", "volume"] },
];

describe("normalize / tokenize", () => {
  it("lowercases, strips accents and punctuation", () => {
    assert.equal(normalize("  Café — Pointer's DRIFT!  "), "cafe pointer s drift");
    assert.deepEqual(tokenize("Re-center, please"), ["re", "center", "please"]);
    assert.deepEqual(tokenize("   "), []);
  });
});

describe("score", () => {
  it("requires every query word", () => {
    assert.equal(score(["no", "sound"], fields(entries[2]!)), 3.75 + 3.75);
    assert.equal(score(["no", "pointer"], fields(entries[2]!)), 0);
  });

  it("matches word prefixes, preferring whole words", () => {
    assert.equal(score(["scroll"], fields(entries[0]!)), 3, "prefix of “scrolling” in the title");
    assert.equal(score(["scroll"], fields(entries[1]!)), 1.25, "whole word in the tags");
    assert.equal(score(["roll"], fields(entries[0]!)), 0, "no infix matches");
  });
});

describe("search", () => {
  it("returns everything, in order, for an empty query", () => {
    assert.deepEqual(search(entries, "  ", fields), entries);
  });

  it("ranks title matches above tag matches", () => {
    assert.deepEqual(
      search(entries, "scroll", fields).map((e) => e.title),
      ["Scrolling is slow", "Pointer drifts"],
    );
  });

  it("keeps the original order for ties and drops non-matches", () => {
    const tied: Entry[] = [
      { title: "A", tags: ["camera"] },
      { title: "B", tags: ["voice"] },
      { title: "C", tags: ["camera"] },
    ];
    assert.deepEqual(search(tied, "camera", fields).map((e) => e.title), ["A", "C"]);
  });
});

describe("troubleshooting content", () => {
  const help = (q: string) =>
    search(troubleshooting, q, (t) => [
      { text: t.problem, weight: 3 },
      { text: t.keywords.join(" "), weight: 2 },
      { text: t.steps.join(" "), weight: 1 },
    ]).map((t) => t.id);

  it("has unique ids and non-empty steps", () => {
    assert.equal(new Set(troubleshooting.map((t) => t.id)).size, troubleshooting.length);
    for (const t of troubleshooting) assert.ok(t.steps.length > 0, t.id);
  });

  it("finds the right entry for common phrasings", () => {
    assert.equal(help("clicks don't work")[0], "no-clicks");
    assert.equal(help("no sound")[0], "no-sound");
    assert.equal(help("pointer drifts")[0], "drift");
    assert.ok(help("blink").includes("blinks-missed"));
    assert.ok(help("glasses").includes("blinks-missed"));
  });
});

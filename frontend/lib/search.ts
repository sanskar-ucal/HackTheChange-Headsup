/**
 * Tiny, dependency-free search for short help entries (the troubleshooting list).
 * Every query word must match the start of some word in the entry; matches in heavier
 * fields (e.g. the title) rank higher. Ties keep the original order.
 */

export interface SearchField {
  text: string;
  weight: number;
}

/** Lowercase, strip accents and turn punctuation into spaces. */
export function normalize(text: string): string {
  return text
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim();
}

export function tokenize(text: string): string[] {
  const normalized = normalize(text);
  return normalized ? normalized.split(" ") : [];
}

/** Score of one entry for the query words, or 0 if any word is missing. */
export function score(words: string[], fields: SearchField[]): number {
  if (words.length === 0) return 0;
  const tokenized = fields.map((f) => ({ tokens: tokenize(f.text), weight: f.weight }));
  let total = 0;
  for (const word of words) {
    let best = 0;
    for (const field of tokenized) {
      for (const token of field.tokens) {
        if (!token.startsWith(word)) continue;
        // A whole-word match counts a little more than a prefix match.
        best = Math.max(best, field.weight * (token === word ? 1.25 : 1));
      }
    }
    if (best === 0) return 0;
    total += best;
  }
  return total;
}

/**
 * Entries matching every word of `query`, best first. An empty query returns all
 * entries in their original order.
 */
export function search<T>(entries: readonly T[], query: string, fields: (entry: T) => SearchField[]): T[] {
  const words = tokenize(query);
  if (words.length === 0) return [...entries];
  return entries
    .map((entry, index) => ({ entry, index, score: score(words, fields(entry)) }))
    .filter((r) => r.score > 0)
    .sort((a, b) => b.score - a.score || a.index - b.index)
    .map((r) => r.entry);
}

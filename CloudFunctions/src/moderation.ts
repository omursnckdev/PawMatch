/**
 * Lightweight profanity/abuse filter (§7 item 5). Deliberately conservative to
 * avoid false positives on normal pet chatter — the caller flags repeat
 * offenders for manual review rather than hard-blocking every message.
 */
const BLOCKLIST = [
  "fuck",
  "shit",
  "bitch",
  "asshole",
  "cunt",
  "nigger",
  "faggot",
  "retard",
];

export function messageIsAbusive(text: string): boolean {
  const normalized = text.toLowerCase();
  return BLOCKLIST.some((word) => {
    const pattern = new RegExp(`\\b${word}\\b`, "i");
    return pattern.test(normalized);
  });
}

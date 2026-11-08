/**
 * Pure rules of the yearly DP leaderboard (no I/O) so they can be unit tested in isolation.
 */

/** Positions shown by default, and the most a client may ask for. */
export const DEFAULT_TOP = 10;
export const MAX_TOP = 50;

/**
 * Ledger sources that never count towards the yearly DP. The opening balance is
 * DP carried over from before the app, not earned in the season.
 */
export const EXCLUDED_SOURCES = ['OPENING'] as const;

export interface DpTotal {
  memberId: string;
  fullName: string;
  dpTotal: number;
}

export type Ranked<T extends DpTotal> = T & { position: number };

/**
 * Competition ranking ("1224"): members on the same DP share a position and the
 * next position skips the tied ones. Members without positive DP are not ranked.
 * Ties are listed by name, then id, so the order is stable between calls.
 */
export function rankByDp<T extends DpTotal>(rows: readonly T[]): Ranked<T>[] {
  const sorted = rows
    .filter((r) => r.dpTotal > 0)
    .sort((a, b) => b.dpTotal - a.dpTotal || a.fullName.localeCompare(b.fullName, 'vi') || a.memberId.localeCompare(b.memberId));
  const out: Ranked<T>[] = [];
  sorted.forEach((row, i) => {
    const position = i > 0 && sorted[i - 1].dpTotal === row.dpTotal ? out[i - 1].position : i + 1;
    out.push({ ...row, position });
  });
  return out;
}

/** Everyone whose position is within the top N, so a tie on the last place keeps all tied members. */
export function withinTop<T extends DpTotal>(ranked: readonly Ranked<T>[], top: number): Ranked<T>[] {
  return ranked.filter((r) => r.position <= top);
}

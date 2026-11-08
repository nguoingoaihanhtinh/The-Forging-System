/**
 * How to date a rank held by a member who has no history row for it (legacy
 * data from before the time-in-rank rule):
 *  - ledger: when the DP ledger last reached the rank's threshold (closest to reality);
 *  - joined: the join date (what the engine falls back to today - most lenient);
 *  - now:    today (the member waits the full period again - strictest).
 */
export type SyncStrategy = 'ledger' | 'joined' | 'now';

export const SYNC_STRATEGIES: readonly SyncStrategy[] = ['ledger', 'joined', 'now'];

export interface RankDateInputs {
  joinedAt: Date;
  /** Moment the ledger last crossed the threshold, null when it cannot be derived. */
  ledgerAt: Date | null;
  now: Date;
}

/** The chosen date, never before the join date nor in the future. */
export function pickRankSince(strategy: SyncStrategy, input: RankDateInputs): Date {
  const raw = strategy === 'now' ? input.now : strategy === 'joined' ? input.joinedAt : (input.ledgerAt ?? input.joinedAt);
  return new Date(Math.min(Math.max(raw.getTime(), input.joinedAt.getTime()), input.now.getTime()));
}

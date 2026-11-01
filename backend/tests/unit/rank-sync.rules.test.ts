import { describe, expect, it } from 'vitest';
import { pickRankSince } from '../../src/modules/ranks/rank-sync.rules';

const joinedAt = new Date('2026-01-10T00:00:00Z');
const now = new Date('2026-11-01T00:00:00Z');
const ledgerAt = new Date('2026-08-05T00:00:00Z');

describe('rank sync: which date a legacy rank gets (RK-05)', () => {
  it('ledger uses the moment the DP ledger reached the threshold', () => {
    expect(pickRankSince('ledger', { joinedAt, ledgerAt, now })).toEqual(ledgerAt);
  });

  it('ledger falls back to the join date when the ledger says nothing', () => {
    expect(pickRankSince('ledger', { joinedAt, ledgerAt: null, now })).toEqual(joinedAt);
  });

  it('joined always uses the join date, now always uses today', () => {
    expect(pickRankSince('joined', { joinedAt, ledgerAt, now })).toEqual(joinedAt);
    expect(pickRankSince('now', { joinedAt, ledgerAt, now })).toEqual(now);
  });

  it('never dates a rank before joining or in the future', () => {
    const early = new Date('2025-01-01T00:00:00Z');
    const late = new Date('2027-01-01T00:00:00Z');
    expect(pickRankSince('ledger', { joinedAt, ledgerAt: early, now })).toEqual(joinedAt);
    expect(pickRankSince('ledger', { joinedAt, ledgerAt: late, now })).toEqual(now);
  });
});

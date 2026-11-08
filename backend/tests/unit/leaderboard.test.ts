import { afterEach, describe, expect, it, vi } from 'vitest';
import type { AppError } from '../../src/common/errors/app-error';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import type { LeaderboardRepository, MemberYearlyDp, SeasonRow } from '../../src/modules/leaderboard/leaderboard.repository';
import { rankByDp, withinTop } from '../../src/modules/leaderboard/leaderboard.rules';
import { LeaderboardService } from '../../src/modules/leaderboard/leaderboard.service';

const row = (memberId: string, dpTotal: number, fullName = memberId): MemberYearlyDp => ({
  memberId,
  fullName,
  avatarUrl: null,
  rankCode: null,
  rankName: null,
  dpTotal,
});

describe('rankByDp', () => {
  it('shares a position between tied members and skips the next one', () => {
    const ranked = rankByDp([row('a', 300), row('b', 500), row('c', 300), row('d', 100)]);
    expect(ranked.map((r) => [r.memberId, r.position])).toEqual([
      ['b', 1],
      ['a', 2],
      ['c', 2],
      ['d', 4],
    ]);
  });

  it('orders ties by name, then id, so the list is stable', () => {
    const ranked = rankByDp([row('2', 100, 'Bình'), row('1', 100, 'Bình'), row('3', 100, 'An')]);
    expect(ranked.map((r) => r.memberId)).toEqual(['3', '1', '2']);
  });

  it('leaves out members without positive DP', () => {
    expect(rankByDp([row('a', 0), row('b', -20), row('c', 10)]).map((r) => r.memberId)).toEqual(['c']);
  });

  it('does not mutate the input', () => {
    const input = [row('a', 1), row('b', 2)];
    rankByDp(input);
    expect(input.map((r) => r.memberId)).toEqual(['a', 'b']);
  });
});

describe('withinTop', () => {
  it('keeps every member tied on the last position of the top', () => {
    const ranked = rankByDp([row('a', 90), row('b', 80), row('c', 80), row('d', 80), row('e', 10)]);
    // positions: a=1, b/c/d=2, e=5
    expect(withinTop(ranked, 2).map((r) => r.memberId)).toEqual(['a', 'b', 'c', 'd']);
    expect(withinTop(ranked, 1).map((r) => r.memberId)).toEqual(['a']);
  });

  it('excludes a tie group that starts beyond the top', () => {
    const ranked = rankByDp([row('a', 90), row('b', 80), row('c', 80)]);
    expect(withinTop(ranked, 1).map((r) => r.memberId)).toEqual(['a']);
  });
});

describe('LeaderboardService.yearly', () => {
  afterEach(() => resetClock());

  const season = (over: Partial<SeasonRow> = {}): SeasonRow => ({
    id: 's1',
    seasonYear: 2026,
    startsAt: new Date('2025-12-31T17:00:00Z'),
    endsAt: new Date('2026-12-31T17:00:00Z'),
    status: 'ACTIVE',
    ...over,
  });
  const make = (s: SeasonRow | null, totals: MemberYearlyDp[] = []) => {
    const repo = {
      findSeason: vi.fn().mockResolvedValue(s),
      yearlyDpTotals: vi.fn().mockResolvedValue(totals),
    };
    return { repo, service: new LeaderboardService(repo as unknown as LeaderboardRepository) };
  };

  it('defaults to the current local year, even just before the UTC new year', async () => {
    // 2026-12-31 18:00 UTC is already 2027-01-01 in Ho Chi Minh City.
    setClock(fixedClock(new Date('2026-12-31T18:00:00Z')));
    const { repo, service } = make(season({ seasonYear: 2027 }));
    await service.yearly(undefined);
    expect(repo.findSeason).toHaveBeenCalledWith(2027);
  });

  it('marks the viewer and reports their place even outside the top', async () => {
    const { service } = make(season(), [row('a', 300), row('b', 200), row('me', 100)]);
    const board = await service.yearly(2026, 2, 'me');
    expect(board.items.map((i) => [i.memberId, i.isMe])).toEqual([
      ['a', false],
      ['b', false],
    ]);
    expect(board.me).toEqual({ position: 3, dpTotal: 100 });
    expect(board.totalRanked).toBe(3);
  });

  it('gives staff no `me` block', async () => {
    const { service } = make(season(), [row('a', 300)]);
    const board = await service.yearly(2026, 10, null);
    expect(board.me).toBeNull();
    expect(board.items[0].isMe).toBe(false);
  });

  it('returns an empty board for an upcoming season without reading the ledger', async () => {
    const { repo, service } = make(season({ status: 'UPCOMING' }));
    const board = await service.yearly(2026);
    expect(board.items).toEqual([]);
    expect(repo.yearlyDpTotals).not.toHaveBeenCalled();
  });

  it('rejects a year without a season', async () => {
    const { service } = make(null);
    await expect(service.yearly(1999)).rejects.toMatchObject({ status: 404, code: 'LEADERBOARD_SEASON_NOT_FOUND' } satisfies Partial<AppError>);
  });

  it('maps the rank of each entry', async () => {
    const { service } = make(season(), [{ ...row('a', 10), rankCode: 'THE_FORGED', rankName: 'Người được tôi luyện' }]);
    const board = await service.yearly(2026);
    expect(board.items[0].rank).toEqual({ code: 'THE_FORGED', name: 'Người được tôi luyện' });
  });
});

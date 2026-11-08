import { AppError } from '../../common/errors/app-error';
import { clock } from '../../common/utils/clock';
import { zonedParts } from '../../common/utils/time';
import type { LeaderboardRepository } from './leaderboard.repository';
import { DEFAULT_TOP, rankByDp, withinTop } from './leaderboard.rules';

export interface LeaderboardEntry {
  position: number;
  memberId: string;
  fullName: string;
  avatarUrl: string | null;
  rank: { code: string; name: string } | null;
  dpTotal: number;
  isMe: boolean;
}

export interface YearlyLeaderboard {
  season: { year: number; startsAt: Date; endsAt: Date; status: string };
  /** Positions the board was cut at; a tie on the last one keeps every tied member. */
  top: number;
  /** How many active members have DP this season (the whole board, not just the top). */
  totalRanked: number;
  items: LeaderboardEntry[];
  /** The viewer's own place, also when it is outside the top. Null for staff and unranked members. */
  me: { position: number; dpTotal: number } | null;
}

export class LeaderboardService {
  constructor(private readonly repo: LeaderboardRepository) {}

  /** Yearly DP board; `viewerId` is the member looking at it, or null for staff. */
  async yearly(year: number | undefined, top: number = DEFAULT_TOP, viewerId: string | null = null): Promise<YearlyLeaderboard> {
    const seasonYear = year ?? zonedParts(clock.now()).year;
    const season = await this.repo.findSeason(seasonYear);
    if (!season) {
      throw new AppError(404, 'LEADERBOARD_SEASON_NOT_FOUND', `Chưa có mùa giải năm ${seasonYear}`);
    }
    const view = { year: season.seasonYear, startsAt: season.startsAt, endsAt: season.endsAt, status: season.status };
    if (season.status === 'UPCOMING') return { season: view, top, totalRanked: 0, items: [], me: null };

    const ranked = rankByDp(await this.repo.yearlyDpTotals(season.startsAt, season.endsAt));
    const mine = viewerId ? ranked.find((r) => r.memberId === viewerId) : undefined;
    return {
      season: view,
      top,
      totalRanked: ranked.length,
      items: withinTop(ranked, top).map((r) => ({
        position: r.position,
        memberId: r.memberId,
        fullName: r.fullName,
        avatarUrl: r.avatarUrl,
        rank: r.rankCode ? { code: r.rankCode, name: r.rankName ?? r.rankCode } : null,
        dpTotal: r.dpTotal,
        isMe: r.memberId === viewerId,
      })),
      me: mine ? { position: mine.position, dpTotal: mine.dpTotal } : null,
    };
  }
}

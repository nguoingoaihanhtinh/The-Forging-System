import { sql } from '../../db/sql';
import { EXCLUDED_SOURCES } from './leaderboard.rules';

export interface SeasonRow {
  id: string;
  seasonYear: number;
  startsAt: Date;
  endsAt: Date;
  status: 'UPCOMING' | 'ACTIVE' | 'CLOSED';
}

export interface MemberYearlyDp {
  memberId: string;
  fullName: string;
  avatarUrl: string | null;
  rankCode: string | null;
  rankName: string | null;
  dpTotal: number;
}

export class LeaderboardRepository {
  findSeason(year: number): Promise<SeasonRow | null> {
    return sql.one<SeasonRow>(
      `SELECT id, season_year, starts_at, ends_at, status
         FROM leaderboard_seasons WHERE season_year = $1`,
      [year],
    );
  }

  /**
   * Net DP per active member over the season [startsAt, endsAt).
   *
   * A reversal counts in the season of the transaction it cancels, not the one it
   * was posted in, so a mistaken award nets to zero in its own year even when it
   * is corrected after New Year. `pt.occurred_at >= $1` is implied by that and
   * lets the covering index narrow the scan.
   */
  yearlyDpTotals(startsAt: Date, endsAt: Date): Promise<MemberYearlyDp[]> {
    return sql.many<MemberYearlyDp>(
      `WITH ledger AS (
         SELECT pt.member_id, pt.dp_amount
           FROM point_transactions pt
           LEFT JOIN point_transactions orig ON orig.id = pt.reversal_of_id
          WHERE pt.status = 'POSTED' AND pt.dp_amount <> 0
            AND pt.occurred_at >= $1
            AND COALESCE(orig.occurred_at, pt.occurred_at) >= $1
            AND COALESCE(orig.occurred_at, pt.occurred_at) < $2
            AND COALESCE(orig.source, pt.source) <> ALL($3::text[])
       )
       SELECT m.user_id AS member_id, u.full_name, u.avatar_url,
              r.code AS rank_code, COALESCE(r.name_vi, r.name_en) AS rank_name,
              SUM(l.dp_amount)::int AS dp_total
         FROM ledger l
         JOIN members m ON m.user_id = l.member_id AND m.status = 'ACTIVE' AND m.duplicate_of_member_id IS NULL
         JOIN users u ON u.id = m.user_id
         LEFT JOIN ranks r ON r.id = m.current_rank_id
        GROUP BY m.user_id, u.full_name, u.avatar_url, r.code, r.name_vi, r.name_en
       HAVING SUM(l.dp_amount) > 0`,
      [startsAt, endsAt, [...EXCLUDED_SOURCES]],
    );
  }
}

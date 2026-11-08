import { sql } from '../../db/sql';

export interface MemberWithoutRankDate {
  memberId: string;
  joinedAt: Date;
  dpBalance: number;
  rankId: string;
  rankOrder: number;
  rankName: string;
  dpThreshold: number;
}

export interface CancelledTrial {
  trialId: string;
  memberId: string;
  targetRankName: string;
}

/** Marker written by migration 0003 / the sync into rank_trial_requests.result_note. */
export const TRIAL_REMOVED_NOTE = 'Hạng này không còn Rank Trial (quy tắc lên hạng v4).';

const OPEN_TRIALS_WITHOUT_GATE = `FROM rank_trial_requests t
  JOIN ranks r ON r.id = t.target_rank_id
 WHERE NOT r.requires_trial AND t.status IN ('PENDING', 'SCHEDULED')`;

/** Data-fix queries for RK-05 (legacy rank dates and trials of ranks that no longer need one). */
export class RankSyncRepository {
  /** Members whose latest history row for their current rank is missing or revoked: the engine dates them by join date. */
  membersWithoutRankDate(): Promise<MemberWithoutRankDate[]> {
    return sql.many(
      `SELECT m.user_id AS member_id, m.joined_at, m.dp_balance, r.id AS rank_id, r.rank_order, r.name_en AS rank_name, r.dp_threshold
         FROM members m
         JOIN ranks r ON r.id = m.current_rank_id
        WHERE NOT EXISTS (
          SELECT 1 FROM (
            SELECT is_revoked FROM member_rank_history h
             WHERE h.member_id = m.user_id AND h.to_rank_id = m.current_rank_id
             ORDER BY earned_at DESC, id LIMIT 1) latest
           WHERE NOT latest.is_revoked)
        ORDER BY m.joined_at, m.user_id`,
    );
  }

  /**
   * When the member's DP running total last reached `threshold` and stayed there
   * until now (a dip below it restarts the clock). Null if it never did.
   */
  ledgerReachedAt(memberId: string, threshold: number): Promise<Date | null> {
    return sql.scalar<Date>(
      `WITH running AS (
         SELECT occurred_at, created_at, id,
                SUM(dp_amount) OVER (ORDER BY occurred_at, created_at, id) AS bal
           FROM point_transactions WHERE member_id = $1 AND status = 'POSTED')
       SELECT MIN(r.occurred_at) FROM running r
        WHERE r.bal >= $2
          AND NOT EXISTS (SELECT 1 FROM running x WHERE x.bal < $2 AND (x.occurred_at, x.created_at, x.id) > (r.occurred_at, r.created_at, r.id))`,
      [memberId, threshold],
    );
  }

  listOpenTrialsWithoutGate(): Promise<CancelledTrial[]> {
    return sql.many(
      `SELECT t.id AS trial_id, t.member_id, r.name_en AS target_rank_name ${OPEN_TRIALS_WITHOUT_GATE} ORDER BY t.requested_at`,
    );
  }

  /** Closes the still-open trials of ranks that need none (same effect as migration 0003). */
  cancelOpenTrialsWithoutGate(): Promise<CancelledTrial[]> {
    return sql.many(
      `UPDATE rank_trial_requests t
          SET status = 'CANCELLED', result_note = COALESCE(t.result_note, $1), evaluated_at = now(), updated_at = now()
         FROM ranks r
        WHERE r.id = t.target_rank_id AND NOT r.requires_trial AND t.status IN ('PENDING', 'SCHEDULED')
        RETURNING t.id AS trial_id, t.member_id, r.name_en AS target_rank_name`,
      [TRIAL_REMOVED_NOTE],
    );
  }

  /**
   * Members whose latest trial was closed because the rank has no trial any more
   * and who still sit one rank below it: they may now qualify without waiting for a DP change.
   */
  membersAwaitingRecheck(): Promise<CancelledTrial[]> {
    return sql.many(
      `SELECT DISTINCT ON (t.member_id) t.id AS trial_id, t.member_id, tr.name_en AS target_rank_name
         FROM rank_trial_requests t
         JOIN ranks tr ON tr.id = t.target_rank_id
         JOIN members m ON m.user_id = t.member_id
         JOIN ranks cr ON cr.id = m.current_rank_id
        WHERE t.status = 'CANCELLED' AND t.result_note LIKE 'Hạng này không còn Rank Trial%'
          AND cr.rank_order + 1 = tr.rank_order
        ORDER BY t.member_id, t.evaluated_at DESC NULLS LAST, t.id`,
    );
  }

  currentRankOrder(memberId: string): Promise<number | null> {
    return sql.scalar<number>(
      `SELECT r.rank_order FROM members m JOIN ranks r ON r.id = m.current_rank_id WHERE m.user_id = $1`,
      [memberId],
    );
  }
}

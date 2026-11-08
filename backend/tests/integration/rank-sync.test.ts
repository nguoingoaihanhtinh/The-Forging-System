import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { RankRepository } from '../../src/modules/ranks/rank.repository';
import { RankSyncRepository } from '../../src/modules/ranks/rank-sync.repository';
import { RankSyncService } from '../../src/modules/ranks/rank-sync.service';
import { bootTestApp, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('rank data sync (RK-05)', () => {
  let ctx: TestContext;
  let sync: RankSyncService;
  let memberId: string;
  let rank: Record<number, string>;

  beforeAll(async () => {
    ctx = await bootTestApp();
    const s = ctx.services;
    sync = new RankSyncService(new RankSyncRepository(), new RankRepository(), s.ranks, s.notifications, s.audit);
    const rows = await ownerQuery<{ id: string; rank_order: number }>(`SELECT id, rank_order FROM ranks`);
    rank = Object.fromEntries(rows.map((r) => [r.rank_order, r.id]));
  });

  beforeEach(async () => {
    memberId = (await registerMember(ctx.api)).userId;
  });

  /** A learner created before the time-in-rank rule: holds rank III, joined 10 months ago, no history row for it. */
  const legacyAtRankThree = async () => {
    await ownerQuery(
      `UPDATE members SET current_rank_id = $2, peak_rank_id = $2, joined_at = now() - interval '10 months' WHERE user_id = $1`,
      [memberId, rank[3]],
    );
  };
  const historyFor = (order: number) =>
    ownerQuery<{ earned_via: string; earned_at: Date; reason: string }>(
      `SELECT earned_via, earned_at, reason FROM member_rank_history WHERE member_id = $1 AND to_rank_id = $2 ORDER BY earned_at`,
      [memberId, rank[order]],
    );

  it('reports without writing anything unless applied', async () => {
    await legacyAtRankThree();
    const report = await sync.run(ctx.tenantId, { strategy: 'joined', apply: false });
    expect(report.applied).toBe(false);
    expect(report.backfilled.map((b) => b.memberId)).toContain(memberId);
    expect(await historyFor(3)).toHaveLength(0);
  });

  it('dates a legacy rank by the chosen strategy and then leaves it alone', async () => {
    await legacyAtRankThree();
    const report = await sync.run(ctx.tenantId, { strategy: 'now', apply: true });
    expect(report.errors).toEqual([]);
    expect(report.backfilled.find((b) => b.memberId === memberId)?.rank).toBeTruthy();

    const rows = await historyFor(3);
    expect(rows).toHaveLength(1);
    expect(rows[0].earned_via).toBe('MANUAL');
    expect(Date.now() - rows[0].earned_at.getTime()).toBeLessThan(60_000); // "now": the full waiting period starts today

    // Second run: the member now has a dated row, nothing more to do.
    const again = await sync.run(ctx.tenantId, { strategy: 'now', apply: true });
    expect(again.backfilled.map((b) => b.memberId)).not.toContain(memberId);
    expect(await historyFor(3)).toHaveLength(1);
  });

  it('ledger strategy uses when the DP ledger last reached the rank threshold', async () => {
    await legacyAtRankThree();
    const threshold = (await ownerQuery<{ dp_threshold: number }>(`SELECT dp_threshold FROM ranks WHERE rank_order = 3`))[0].dp_threshold;
    await ownerQuery(
      `INSERT INTO point_transactions (tenant_id, member_id, source, dp_amount, status, occurred_at, reason)
       SELECT tenant_id, user_id, 'MANUAL_ADJUSTMENT', $2, 'POSTED', now() - interval '3 months', 'fixture' FROM members WHERE user_id = $1`,
      [memberId, threshold],
    );
    await sync.run(ctx.tenantId, { strategy: 'ledger', apply: true });
    const [row] = await historyFor(3);
    const months = (Date.now() - row.earned_at.getTime()) / (30.44 * 86_400_000);
    expect(months).toBeGreaterThan(2.8);
    expect(months).toBeLessThan(3.2);
  });

  it('closes open trials of ranks without a trial and promotes members who now qualify', async () => {
    // Rank II -> III needs no trial any more; a stale request is still open.
    await ownerQuery(`UPDATE members SET current_rank_id = $2, peak_rank_id = $2 WHERE user_id = $1`, [memberId, rank[2]]);
    await ownerQuery(
      `INSERT INTO member_rank_history (tenant_id, member_id, to_rank_id, earned_via, reason, dp_at_change, earned_at)
       SELECT tenant_id, user_id, $2, 'AUTO_UPGRADE', 'fixture', 0, now() - interval '5 months' FROM members WHERE user_id = $1`,
      [memberId, rank[2]],
    );
    const course = (await ownerQuery<{ id: string }>(`SELECT id FROM courses WHERE code = 'FOUNDATION'`))[0].id;
    await ownerQuery(
      `INSERT INTO course_enrollments (tenant_id, member_id, course_id, status, completed_at)
       SELECT tenant_id, user_id, $2, 'COMPLETED', now() FROM members WHERE user_id = $1`,
      [memberId, course],
    );
    const threshold = (await ownerQuery<{ dp_threshold: number }>(`SELECT dp_threshold FROM ranks WHERE rank_order = 3`))[0].dp_threshold;
    await ownerQuery(
      `INSERT INTO point_transactions (tenant_id, member_id, source, dp_amount, status, reason)
       SELECT tenant_id, user_id, 'MANUAL_ADJUSTMENT', $2, 'POSTED', 'fixture' FROM members WHERE user_id = $1`,
      [memberId, threshold],
    );
    await ownerQuery(
      `INSERT INTO rank_trial_requests (tenant_id, member_id, target_rank_id, approver_role, eligibility_snapshot)
       SELECT tenant_id, user_id, $2, 'COACH', '{}'::jsonb FROM members WHERE user_id = $1`,
      [memberId, rank[3]],
    );

    const report = await sync.run(ctx.tenantId, { strategy: 'joined', apply: true });
    expect(report.errors).toEqual([]);
    expect(report.trialsCancelled).toBeGreaterThanOrEqual(1);
    const mine = report.rechecked.find((r) => r.memberId === memberId);
    expect(mine).toMatchObject({ fromOrder: 2, toOrder: 3 });
    const trial = (await ownerQuery<{ status: string }>(`SELECT status FROM rank_trial_requests WHERE member_id = $1`, [memberId]))[0];
    expect(trial.status).toBe('CANCELLED');
  });
});

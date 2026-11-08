import { clock } from '../../common/utils/clock';
import { db } from '../../db/database';
import type { AuditService } from '../audit/audit.service';
import { NotificationEvent } from '../notifications/notification.events';
import type { NotifierPort } from '../notifications/notification.service';
import type { RankPort } from './rank.service';
import type { RankRepository } from './rank.repository';
import { pickRankSince } from './rank-sync.rules';
import type { SyncStrategy } from './rank-sync.rules';
import type { CancelledTrial, RankSyncRepository } from './rank-sync.repository';

export interface RankSyncOptions {
  strategy: SyncStrategy;
  /** false = report only, nothing is written. */
  apply: boolean;
}

export interface RankSyncReport {
  strategy: SyncStrategy;
  applied: boolean;
  /** Members given a back-dated "rank earned" row. */
  backfilled: Array<{ memberId: string; rank: string; earnedAt: Date }>;
  /** Open trials of ranks that need none, closed now. */
  trialsCancelled: number;
  /** Members re-checked against the rules; they were promoted when `toOrder` differs from `fromOrder`. */
  rechecked: Array<{ memberId: string; fromOrder: number | null; toOrder: number | null }>;
  errors: Array<{ memberId: string; message: string }>;
}

const BACKFILL_REASON = 'Đồng bộ ngày đạt hạng từ dữ liệu cũ (quy tắc lên hạng v4).';

/**
 * RK-05: brings data created before the "time in current rank" rule in line with it.
 *  1. members holding a rank with no (valid) history row get one, dated by the chosen strategy;
 *  2. open Rank Trials of ranks that no longer need one are closed;
 *  3. members whose trial was closed (now or by migration 0003) are re-checked so they
 *     are promoted straight away instead of at their next DP change, and told if not.
 * Safe to re-run: each step only touches rows that still need it.
 */
export class RankSyncService {
  constructor(
    private readonly sync: RankSyncRepository,
    private readonly ranks: RankRepository,
    private readonly rankPort: RankPort,
    private readonly notifier: NotifierPort,
    private readonly audit: AuditService,
  ) {}

  async run(tenantId: string, options: RankSyncOptions): Promise<RankSyncReport> {
    const tx = <T>(fn: () => Promise<T>) => db.tenantTx(tenantId, fn);
    const report: RankSyncReport = {
      strategy: options.strategy,
      applied: options.apply,
      backfilled: [],
      trialsCancelled: 0,
      rechecked: [],
      errors: [],
    };

    // 1. back-date the rank entry of members without history
    for (const member of await tx(() => this.sync.membersWithoutRankDate())) {
      try {
        const earnedAt = await tx(async () => {
          const ledgerAt =
            options.strategy === 'ledger' && member.dpThreshold > 0
              ? await this.sync.ledgerReachedAt(member.memberId, member.dpThreshold)
              : null;
          const at = pickRankSince(options.strategy, { joinedAt: member.joinedAt, ledgerAt, now: clock.now() });
          if (options.apply) {
            await this.ranks.insertHistory({
              memberId: member.memberId,
              fromRankId: null,
              toRankId: member.rankId,
              earnedVia: 'MANUAL',
              reason: BACKFILL_REASON,
              dpAtChange: member.dpBalance,
              earnedAt: at,
            });
            await this.audit.record({
              actorId: null,
              action: 'RANK_DATE_SYNCED',
              entityType: 'MEMBER',
              entityId: member.memberId,
              after: { rank: member.rankName, earnedAt: at.toISOString(), strategy: options.strategy },
              reason: BACKFILL_REASON,
            });
          }
          return at;
        });
        report.backfilled.push({ memberId: member.memberId, rank: member.rankName, earnedAt });
      } catch (err) {
        report.errors.push({ memberId: member.memberId, message: err instanceof Error ? err.message : String(err) });
      }
    }

    // 2. close open trials of ranks without a trial gate
    const closed = await tx(() => (options.apply ? this.sync.cancelOpenTrialsWithoutGate() : this.sync.listOpenTrialsWithoutGate()));
    report.trialsCancelled = closed.length;

    // 3. re-check everyone whose trial was closed, now or earlier
    const awaiting = new Map<string, CancelledTrial>();
    for (const t of [...closed, ...(await tx(() => this.sync.membersAwaitingRecheck()))]) awaiting.set(t.memberId, t);
    for (const trial of awaiting.values()) {
      try {
        report.rechecked.push(await tx(() => this.recheck(trial, options.apply)));
      } catch (err) {
        report.errors.push({ memberId: trial.memberId, message: err instanceof Error ? err.message : String(err) });
      }
    }
    return report;
  }

  private async recheck(trial: CancelledTrial, apply: boolean) {
    const fromOrder = await this.sync.currentRankOrder(trial.memberId);
    if (!apply) return { memberId: trial.memberId, fromOrder, toOrder: fromOrder };
    await this.rankPort.reevaluate(trial.memberId);
    const toOrder = await this.sync.currentRankOrder(trial.memberId);
    // Promoted members already got RANK_EARNED; the others just learn the trial is gone.
    if (toOrder === fromOrder) {
      await this.notifier.notifyMember({
        userId: trial.memberId,
        event: NotificationEvent.RANK_TRIAL_CANCELLED,
        title: 'RANK TRIAL ĐƯỢC BỎ',
        body: `${trial.targetRankName} không còn yêu cầu Rank Trial. Bạn chỉ cần đủ DP, thời gian ở hạng hiện tại và khóa học để tự động lên hạng.`,
        dedupeKey: `rank-trial-cancelled:${trial.trialId}`,
      });
    }
    return { memberId: trial.memberId, fromOrder, toOrder };
  }
}

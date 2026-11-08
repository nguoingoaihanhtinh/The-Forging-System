import 'dotenv/config';
import { lookupTenantByCode } from '../src/common/middlewares/tenant.middleware';
import { env } from '../src/config/env';
import { buildContainer } from '../src/container';
import { db } from '../src/db/database';
import { RankRepository } from '../src/modules/ranks/rank.repository';
import { RankSyncRepository } from '../src/modules/ranks/rank-sync.repository';
import { SYNC_STRATEGIES } from '../src/modules/ranks/rank-sync.rules';
import type { SyncStrategy } from '../src/modules/ranks/rank-sync.rules';
import { RankSyncService } from '../src/modules/ranks/rank-sync.service';

/**
 * RK-05 data fix for rank dates and Rank Trials of ranks that no longer need one.
 * Report only unless --apply is given; safe to run again.
 *
 *   npx tsx scripts/sync-rank-dates.ts                       # report, strategy "ledger"
 *   npx tsx scripts/sync-rank-dates.ts --strategy=joined     # date by join date
 *   npx tsx scripts/sync-rank-dates.ts --apply               # write the changes
 *
 * Strategies: ledger (default, when the DP ledger last reached the rank threshold),
 * joined (join date, most lenient) or now (today, strictest).
 */
async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const apply = args.includes('--apply');
  const strategy = (args.find((a) => a.startsWith('--strategy='))?.split('=')[1] ?? 'ledger') as SyncStrategy;
  if (!SYNC_STRATEGIES.includes(strategy)) throw new Error(`--strategy must be one of: ${SYNC_STRATEGIES.join(', ')}`);

  const tenant = await lookupTenantByCode(env.DEFAULT_TENANT_CODE);
  const { services } = buildContainer();
  const service = new RankSyncService(new RankSyncRepository(), new RankRepository(), services.ranks, services.notifications, services.audit);
  const report = await service.run(tenant.id, { strategy, apply });

  const log = (line: string) => console.log(line); // eslint-disable-line no-console
  log(`${apply ? 'APPLIED' : 'DRY RUN (nothing written, add --apply to write)'} - strategy "${strategy}"`);
  log(`rank dates: ${report.backfilled.length} member(s) dated`);
  for (const b of report.backfilled) log(`  ${b.memberId}  ${b.rank}  since ${b.earnedAt.toISOString().slice(0, 10)}`);
  log(`open trials of ranks without a trial: ${report.trialsCancelled} ${apply ? 'closed' : 'to close'}`);
  const promoted = report.rechecked.filter((r) => r.toOrder !== r.fromOrder);
  log(`re-checked: ${report.rechecked.length} member(s)${apply ? `, ${promoted.length} promoted` : ''}`);
  for (const p of promoted) log(`  ${p.memberId}  rank ${p.fromOrder} -> ${p.toOrder}`);
  if (report.errors.length) {
    log(`errors: ${report.errors.length}`);
    for (const e of report.errors) log(`  ${e.memberId}: ${e.message}`);
    process.exitCode = 1;
  }
  await db.close();
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});

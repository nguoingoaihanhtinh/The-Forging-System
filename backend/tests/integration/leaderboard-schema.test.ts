import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { bootTestApp, ownerQuery, registerMember } from '../helpers/test-app';

describe('leaderboard seasons and winners schema (LB-01)', () => {
  let tenantId: string;
  let seasonId: string;
  let memberA: string;
  let memberB: string;
  const YEAR = 2099; // far from any real season so the fixture never collides with the current one

  const season = (year: number, extra = '') =>
    ownerQuery(
      `INSERT INTO leaderboard_seasons (tenant_id, season_year, starts_at, ends_at ${extra ? ', status, closed_at' : ''})
       VALUES ($1, $2, '2099-01-01', '2100-01-01' ${extra})`,
      [tenantId, year],
    );
  const winner = (member: string, position: number, dp: number) =>
    ownerQuery(
      `INSERT INTO leaderboard_season_winners (tenant_id, season_id, member_id, rank_position, dp_total)
       VALUES ($1, $2, $3, $4, $5)`,
      [tenantId, seasonId, member, position, dp],
    );

  beforeAll(async () => {
    const { api } = await bootTestApp();
    tenantId = (await ownerQuery<{ id: string }>(`SELECT id FROM tenants WHERE code = 'hvp'`))[0].id;
    await season(YEAR);
    seasonId = (await ownerQuery<{ id: string }>(`SELECT id FROM leaderboard_seasons WHERE season_year = $1`, [YEAR]))[0].id;
    memberA = (await registerMember(api)).userId;
    memberB = (await registerMember(api)).userId;
  });
  afterAll(async () => {
    await ownerQuery(`DELETE FROM leaderboard_season_winners WHERE season_id = $1`, [seasonId]);
    await ownerQuery(`DELETE FROM leaderboard_seasons WHERE season_year = $1`, [YEAR]);
  });

  it('creates the season in progress for the academy, on local calendar-year bounds', async () => {
    const [row] = await ownerQuery<{ year: number; start_local: string; end_local: string; status: string }>(
      `SELECT season_year AS year,
              to_char(starts_at AT TIME ZONE 'Asia/Ho_Chi_Minh', 'YYYY-MM-DD HH24:MI') AS start_local,
              to_char(ends_at AT TIME ZONE 'Asia/Ho_Chi_Minh', 'YYYY-MM-DD HH24:MI') AS end_local,
              status
         FROM leaderboard_seasons
        WHERE tenant_id = $1 AND season_year = extract(year from (now() AT TIME ZONE 'Asia/Ho_Chi_Minh'))::int`,
      [tenantId],
    );
    expect(row.status).toBe('ACTIVE');
    expect(row.start_local).toBe(`${row.year}-01-01 00:00`);
    expect(row.end_local).toBe(`${row.year + 1}-01-01 00:00`);
  });

  it('allows one season per tenant and year and keeps the dates and status coherent', async () => {
    await expect(season(YEAR)).rejects.toThrow();
    await expect(
      ownerQuery(`INSERT INTO leaderboard_seasons (tenant_id, season_year, starts_at, ends_at) VALUES ($1, 2098, '2099-01-01', '2098-01-01')`, [tenantId]),
    ).rejects.toThrow(); // ends before it starts
    await expect(season(2097, `, 'CLOSED', NULL`)).rejects.toThrow(); // CLOSED needs closed_at
    await expect(season(2096, `, 'ACTIVE', now()`)).rejects.toThrow(); // closed_at only when CLOSED
  });

  it('keeps winners within positions 1-10 with one row per member and season', async () => {
    await expect(winner(memberA, 0, 100)).rejects.toThrow();
    await expect(winner(memberA, 11, 100)).rejects.toThrow();
    await expect(winner(memberA, 1, -5)).rejects.toThrow();
    await winner(memberA, 1, 1200);
    await expect(winner(memberA, 2, 900)).rejects.toThrow(); // same member twice in a season
  });

  it('lets tied members share a position', async () => {
    await winner(memberB, 1, 1200);
    const rows = await ownerQuery<{ rank_position: number }>(`SELECT rank_position FROM leaderboard_season_winners WHERE season_id = $1`, [seasonId]);
    expect(rows.map((r) => r.rank_position)).toEqual([1, 1]);
  });

  it('only marks a prize AWARDED together with the time it was handed over', async () => {
    const [{ prize_status }] = await ownerQuery<{ prize_status: string }>(
      `SELECT prize_status FROM leaderboard_season_winners WHERE season_id = $1 AND member_id = $2`,
      [seasonId, memberA],
    );
    expect(prize_status).toBe('PENDING');
    await expect(
      ownerQuery(`UPDATE leaderboard_season_winners SET prize_status = 'AWARDED' WHERE season_id = $1 AND member_id = $2`, [seasonId, memberA]),
    ).rejects.toThrow();
    await ownerQuery(
      `UPDATE leaderboard_season_winners SET prize_status = 'AWARDED', awarded_at = now() WHERE season_id = $1 AND member_id = $2`,
      [seasonId, memberA],
    );
  });

  it('adds the covering index for DP per member in a time range', async () => {
    const [row] = await ownerQuery<{ indexdef: string }>(`SELECT indexdef FROM pg_indexes WHERE indexname = 'ix_point_tx_posted_dp_by_time'`);
    expect(row.indexdef).toContain('occurred_at');
    expect(row.indexdef).toContain('INCLUDE (member_id, dp_amount)');
    expect(row.indexdef).toContain(`status = 'POSTED'`);
  });
});

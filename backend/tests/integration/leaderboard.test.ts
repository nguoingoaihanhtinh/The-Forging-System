import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('yearly DP leaderboard (LB-02)', () => {
  let ctx: TestContext;
  const YEAR = 2098; // far from any real season so the fixture never collides with the current one
  const m: Record<'a' | 'b' | 'c' | 'frozen' | 'zero' | 'opening', { token: string; userId: string }> = {} as never;
  let coachToken: string;

  const tx = async (member: string, dp: number, at: string, source = 'SESSION', reversalOf: string | null = null) =>
    (
      await ownerQuery<{ id: string }>(
        `INSERT INTO point_transactions (tenant_id, member_id, source, dp_amount, note, occurred_at, reversal_of_id, reason)
         VALUES ($1, $2, $3, $4, 'lb-02 fixture', $5, $6, 'lb-02 fixture') RETURNING id`,
        [ctx.tenantId, member, source, dp, at, reversalOf],
      )
    )[0].id;
  const board = (token: string, query = '') => ctx.api.get(`/api/v1/leaderboard/dp?year=${YEAR}${query}`).set(bearer(token));

  beforeAll(async () => {
    ctx = await bootTestApp();
    await ownerQuery(
      `INSERT INTO leaderboard_seasons (tenant_id, season_year, starts_at, ends_at)
       VALUES ($1, $2, make_timestamptz($2, 1, 1, 0, 0, 0, 'Asia/Ho_Chi_Minh'), make_timestamptz($2 + 1, 1, 1, 0, 0, 0, 'Asia/Ho_Chi_Minh'))`,
      [ctx.tenantId, YEAR],
    );
    for (const key of ['a', 'b', 'c', 'frozen', 'zero', 'opening'] as const) {
      m[key] = await registerMember(ctx.api, { fullName: `LB ${key}` });
    }
    const staff = await createStaff({ role: 'COACH', fullName: 'LB Coach', phone: nextPhone() });
    coachToken = (await login(ctx.api, staff.phone)).token;

    // a and b tie on 300; c has 100 after a reversed award; the others must not appear.
    await tx(m.a.userId, 300, `${YEAR}-03-01T05:00:00Z`);
    await tx(m.b.userId, 200, `${YEAR}-04-01T05:00:00Z`);
    await tx(m.b.userId, 100, `${YEAR}-05-01T05:00:00Z`);
    await tx(m.c.userId, 100, `${YEAR}-06-01T05:00:00Z`);
    const wrong = await tx(m.c.userId, 50, `${YEAR}-06-02T05:00:00Z`);
    await tx(m.c.userId, -50, `${YEAR}-06-03T05:00:00Z`, 'REVERSAL', wrong);
    await tx(m.frozen.userId, 999, `${YEAR}-07-01T05:00:00Z`);
    await ownerQuery(`UPDATE members SET status = 'FROZEN', status_since = now() WHERE user_id = $1`, [m.frozen.userId]);
    await tx(m.zero.userId, 40, `${YEAR}-08-01T05:00:00Z`);
    await tx(m.zero.userId, -40, `${YEAR}-08-02T05:00:00Z`, 'MANUAL_ADJUSTMENT');
    await tx(m.opening.userId, 700, `${YEAR}-01-02T05:00:00Z`, 'OPENING');
  });
  afterAll(async () => {
    await ownerQuery(`DELETE FROM leaderboard_seasons WHERE season_year = $1`, [YEAR]);
  });

  it('ranks active members by net DP and shares a position on a tie', async () => {
    const res = await board(m.a.token);
    expect(res.status).toBe(200);
    const items = res.body.data.items as { position: number; fullName: string; dpTotal: number }[];
    expect(items.map((i) => [i.position, i.fullName, i.dpTotal])).toEqual([
      [1, 'LB a', 300],
      [1, 'LB b', 300],
      [3, 'LB c', 100],
    ]);
    expect(res.body.data.totalRanked).toBe(3);
  });

  it('leaves out frozen members, the opening balance and members whose DP nets to zero', async () => {
    const names = ((await board(m.a.token)).body.data.items as { fullName: string }[]).map((i) => i.fullName);
    expect(names).not.toContain('LB frozen');
    expect(names).not.toContain('LB opening');
    expect(names).not.toContain('LB zero');
  });

  it('nets a reversal against the season of the original transaction', async () => {
    // Reverse an award from the previous season; it must not eat into this season's DP.
    const old = await tx(m.a.userId, 80, `${YEAR - 1}-12-20T05:00:00Z`);
    await tx(m.a.userId, -80, `${YEAR}-02-01T05:00:00Z`, 'REVERSAL', old);
    const a = ((await board(m.a.token)).body.data.items as { fullName: string; dpTotal: number }[]).find((i) => i.fullName === 'LB a');
    expect(a?.dpTotal).toBe(300);
  });

  it('cuts at a position but keeps members tied on it, and reports the viewer outside the top', async () => {
    const res = await board(m.c.token, '&top=1');
    expect((res.body.data.items as unknown[]).length).toBe(2);
    expect(res.body.data.me).toEqual({ position: 3, dpTotal: 100 });
    expect((res.body.data.items as { isMe: boolean }[]).some((i) => i.isMe)).toBe(false);
  });

  it('gives staff the board without a `me` block', async () => {
    const res = await board(coachToken);
    expect(res.status).toBe(200);
    expect(res.body.data.me).toBeNull();
  });

  it('answers 404 for a year without a season and 400 for a bad query', async () => {
    const missing = await ctx.api.get('/api/v1/leaderboard/dp?year=2097').set(bearer(m.a.token));
    expect(missing.status).toBe(404);
    expect(missing.body.error.code).toBe('LEADERBOARD_SEASON_NOT_FOUND');
    expect((await board(m.a.token, '&top=0')).status).toBe(400);
  });

  it('requires a signed-in user', async () => {
    expect((await ctx.api.get(`/api/v1/leaderboard/dp?year=${YEAR}`)).status).toBe(401);
  });
});

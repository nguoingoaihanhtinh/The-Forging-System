import { afterEach, beforeAll, describe, expect, it } from 'vitest';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

// Mon 2026-11-02, 17:30 local (UTC+7).
const NOW = new Date('2026-11-02T10:30:00Z');

describe("today's sessions a member can check into (CHK-02)", () => {
  let ctx: TestContext;
  let member: { token: string; userId: string };
  let q1Desk: string;
  let q7Desk: string;
  let admin: string;
  let coachId: string;
  let coachToken: string;
  let q1: string;
  let q7: string;
  const ids: Record<string, string> = {};

  const mine = (token = member.token) => ctx.api.get('/api/v1/me/checkin/sessions').set(bearer(token));
  const forMember = (token: string, memberId = member.userId) =>
    ctx.api.get(`/api/v1/members/${memberId}/checkin/sessions`).set(bearer(token));
  const byTitle = (res: { body: { data: { sessions: Array<{ title: string; checkin: { state: string } }> } } }) =>
    Object.fromEntries(res.body.data.sessions.map((s) => [s.title, s.checkin.state]));

  async function makeClass(name: string, branchId: string) {
    return (
      await ownerQuery<{ id: string }>(
        `INSERT INTO classes (tenant_id, branch_id, name, session_type_code, weekdays, start_time, duration_minutes)
         VALUES ($1, $2, $3, 'GROUP', '{1}', '18:00', 60) RETURNING id`,
        [ctx.tenantId, branchId, name],
      )
    )[0].id;
  }
  async function enroll(classId: string) {
    await ownerQuery(
      `INSERT INTO class_enrollments (tenant_id, class_id, member_id, start_date, status) VALUES ($1, $2, $3, '2026-01-01', 'ACTIVE')`,
      [ctx.tenantId, classId, member.userId],
    );
  }
  async function makeSession(title: string, classId: string | null, branchId: string, startIso: string, minutes = 60, status = 'SCHEDULED') {
    const start = new Date(startIso);
    ids[title] = (
      await ownerQuery<{ id: string }>(
        `INSERT INTO sessions (tenant_id, class_id, branch_id, session_type_code, coach_id, title, starts_at, ends_at, status)
         VALUES ($1, $2, $3, 'GROUP', $4, $5, $6, $7, $8) RETURNING id`,
        [ctx.tenantId, classId, branchId, coachId, title, start, new Date(start.getTime() + minutes * 60_000), status],
      )
    )[0].id;
  }
  const setStatus = (status: string) =>
    ownerQuery(`UPDATE members SET status = $2, status_since = now() WHERE user_id = $1`, [member.userId, status]);

  beforeAll(async () => {
    ctx = await bootTestApp();
    const staff = async (role: 'RECEPTIONIST' | 'ADMIN' | 'COACH', branchCode: string) => {
      const s = await createStaff({ role, fullName: role, phone: nextPhone(), branchCode });
      return { token: (await login(ctx.api, s.phone)).token, userId: s.userId };
    };
    q1Desk = (await staff('RECEPTIONIST', 'Q1')).token;
    q7Desk = (await staff('RECEPTIONIST', 'Q7')).token;
    admin = (await staff('ADMIN', 'Q1')).token;
    const coach = await staff('COACH', 'Q1');
    coachToken = coach.token;
    coachId = coach.userId;
    member = await registerMember(ctx.api);
    const id = async (code: string) => (await ownerQuery<{ id: string }>(`SELECT id FROM branches WHERE code = $1`, [code]))[0].id;
    q1 = await id('Q1');
    q7 = await id('Q7');

    const pkg = (await ownerQuery<{ id: string }>(`SELECT id FROM package_types WHERE code = 'BOOK_1'`))[0].id;
    await ownerQuery(
      `INSERT INTO memberships (tenant_id, member_id, package_type_id, start_date, end_date, total_sessions, used_sessions, status)
       VALUES ($1, $2, $3, '2026-10-01', '2026-12-31', 36, 4, 'ACTIVE')`,
      [ctx.tenantId, member.userId, pkg],
    );

    const evening = await makeClass('Evening class', q1);
    const clash = await makeClass('Clash class', q1);
    const riverside = await makeClass('Riverside class', q7);
    const notMine = await makeClass('Not enrolled', q1);
    for (const c of [evening, clash, riverside]) await enroll(c);
    await makeSession('Evening', evening, q1, '2026-11-02T11:00:00Z'); // 18:00-19:00 local
    await makeSession('Clash', clash, q1, '2026-11-02T11:30:00Z'); // 18:30-19:30, overlaps Evening
    await makeSession('Riverside', riverside, q7, '2026-11-02T13:00:00Z'); // 20:00-21:00 local
    await makeSession('Cancelled', evening, q1, '2026-11-02T08:00:00Z', 60, 'CANCELLED');
    await makeSession('Tomorrow', evening, q1, '2026-11-03T11:00:00Z');
    await makeSession('Not mine', notMine, q1, '2026-11-02T11:00:00Z');
  });
  afterEach(async () => {
    resetClock();
    await setStatus('ACTIVE');
    await ownerQuery(`DELETE FROM attendances WHERE member_id = $1`, [member.userId]);
  });

  it('is limited to the right roles', async () => {
    expect((await ctx.api.get('/api/v1/me/checkin/sessions')).status).toBe(401);
    expect((await mine(coachToken)).status).toBe(403);
    expect((await mine(q1Desk)).status).toBe(403);
    expect((await forMember(member.token)).status).toBe(403);
    expect((await forMember(coachToken)).status).toBe(403);
    expect((await ctx.api.get('/api/v1/members/not-a-uuid/checkin/sessions').set(bearer(q1Desk))).status).toBe(400);
  });

  it("lists today's sessions of the member, in order, without cancelled, other days or other classes", async () => {
    setClock(fixedClock(NOW));
    const res = await mine();
    expect(res.status).toBe(200);
    expect(res.body.data.date).toBe('2026-11-02');
    expect(res.body.data.eligibility).toEqual({ canCheckin: true, code: null, message: null });
    expect(res.body.data.sessions.map((s: { title: string }) => s.title)).toEqual(['Evening', 'Clash', 'Riverside']);
    expect(res.body.data.sessions[0]).toMatchObject({
      sessionId: ids.Evening,
      sessionType: 'GROUP',
      branch: { id: q1 },
      coach: { id: coachId },
    });
  });

  it('opens 45 minutes before the start and closes 30 minutes after it', async () => {
    setClock(fixedClock(NOW)); // 17:30
    expect(byTitle(await mine())).toEqual({ Evening: 'OPEN', Clash: 'OPEN', Riverside: 'NOT_YET_OPEN' });
    const evening = (await mine()).body.data.sessions[0].checkin;
    expect(evening).toMatchObject({ canCheckin: true, reason: null, opensAt: '2026-11-02T10:15:00.000Z', closesAt: '2026-11-02T11:30:00.000Z' });

    setClock(fixedClock(new Date('2026-11-02T11:45:00Z'))); // 18:45
    expect(byTitle(await mine())).toMatchObject({ Evening: 'CLOSED', Clash: 'OPEN' });
  });

  it('lets the front desk check a latecomer in until the session ends', async () => {
    setClock(fixedClock(new Date('2026-11-02T11:45:00Z'))); // 18:45, Evening self-window closed
    expect(byTitle(await forMember(q1Desk))).toEqual({ Evening: 'OPEN', Clash: 'OPEN' });
    setClock(fixedClock(new Date('2026-11-02T12:05:00Z'))); // 19:05, Evening is over
    expect(byTitle(await forMember(q1Desk)).Evening).toBe('CLOSED');
  });

  it('shows a receptionist only their branch and an admin every branch', async () => {
    setClock(fixedClock(NOW));
    expect(Object.keys(byTitle(await forMember(q1Desk)))).toEqual(['Evening', 'Clash']);
    expect(Object.keys(byTitle(await forMember(q7Desk)))).toEqual(['Riverside']);
    expect(Object.keys(byTitle(await forMember(admin)))).toEqual(['Evening', 'Clash', 'Riverside']);
    const missing = '00000000-0000-4000-8000-000000000000';
    expect((await forMember(admin, missing)).status).toBe(404);
  });

  it('marks a session already checked into and blocks the one that runs at the same time', async () => {
    setClock(fixedClock(NOW));
    await ownerQuery(
      `INSERT INTO attendances (tenant_id, session_id, member_id, checkin_at, attendance_status) VALUES ($1, $2, $3, now(), 'AWAITING_COACH')`,
      [ctx.tenantId, ids.Evening, member.userId],
    );
    const res = await mine();
    expect(byTitle(res)).toEqual({ Evening: 'CHECKED_IN', Clash: 'OVERLAPS_CHECKED_IN', Riverside: 'NOT_YET_OPEN' });
    expect(res.body.data.sessions[0].checkin).toMatchObject({ canCheckin: false, reason: 'ALREADY_CHECKED_IN' });
    expect(res.body.data.sessions[0].checkin.checkedInAt).toBeTruthy();
    expect(res.body.data.sessions[1].checkin).toMatchObject({ canCheckin: false, reason: 'OVERLAPS_CHECKED_IN' });
  });

  it('still offers a session whose attendance row was only pre-created', async () => {
    setClock(fixedClock(NOW));
    await ownerQuery(`INSERT INTO attendances (tenant_id, session_id, member_id, attendance_status) VALUES ($1, $2, $3, 'UPCOMING')`, [ctx.tenantId, ids.Evening, member.userId]);
    expect(byTitle(await mine()).Evening).toBe('OPEN');
  });

  it('blocks an inactive or frozen account with its reason', async () => {
    setClock(fixedClock(NOW));
    await setStatus('FROZEN');
    let res = await mine();
    expect(res.body.data.eligibility).toMatchObject({ canCheckin: false, code: 'ACCOUNT_RESTRICTED' });
    expect(res.body.data.sessions[0].checkin).toMatchObject({ state: 'BLOCKED', canCheckin: false, reason: 'ACCOUNT_RESTRICTED' });
    await setStatus('INACTIVE');
    res = await mine();
    expect(res.body.data.eligibility.code).toBe('ACCOUNT_INACTIVE');
  });

  it('blocks a member whose package is over', async () => {
    setClock(fixedClock(NOW));
    await ownerQuery(`UPDATE memberships SET used_sessions = 36 WHERE member_id = $1`, [member.userId]);
    try {
      const res = await mine();
      expect(res.body.data.eligibility).toMatchObject({ canCheckin: false, code: 'MEMBERSHIP_INVALID' });
      expect(res.body.data.sessions.every((s: { checkin: { state: string } }) => s.checkin.state === 'BLOCKED')).toBe(true);
    } finally {
      await ownerQuery(`UPDATE memberships SET used_sessions = 4 WHERE member_id = $1`, [member.userId]);
    }
  });

  it('returns an empty list when nothing is scheduled today', async () => {
    setClock(fixedClock(new Date('2026-11-10T10:30:00Z')));
    const res = await mine();
    expect(res.body.data.sessions).toEqual([]);
    expect(res.body.data.eligibility.canCheckin).toBe(true); // the package runs to 2026-12-31
  });
});

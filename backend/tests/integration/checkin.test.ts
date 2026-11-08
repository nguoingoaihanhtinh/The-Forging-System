import { afterEach, beforeAll, describe, expect, it } from 'vitest';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

// Mon 2026-11-02, 17:50 local (UTC+7): the 18:00 session (opens 17:15) and the 18:30 one (opens 17:45) are both open.
const NOW = '2026-11-02T10:50:00Z';

describe('member check-in (CHK-03)', () => {
  let ctx: TestContext;
  let member: { token: string; userId: string };
  let q1Desk: string;
  let q7Desk: string;
  let coachId: string;
  let q1: string;
  let q7: string;
  let packageId: string;
  const ids: Record<string, string> = {};

  const at = (iso: string) => setClock(fixedClock(new Date(iso)));
  const codeOf = async (token: string, branchId: string) =>
    (await ctx.api.get(`/api/v1/branches/${branchId}/checkin-code`).set(bearer(token))).body.data as { payload: string; shortCode: string };
  const checkin = (body: object, token = member.token) => ctx.api.post('/api/v1/me/checkin').set(bearer(token)).send(body);
  const used = async () => (await ownerQuery<{ used_sessions: number }>(`SELECT used_sessions FROM memberships WHERE id = $1`, [packageId]))[0].used_sessions;
  const attendance = async (title: string) =>
    (
      await ownerQuery<{ attendance_status: string; membership_id: string | null; checkin_at: Date | null; checked_in_by: string | null }>(
        `SELECT attendance_status, membership_id, checkin_at, checked_in_by FROM attendances WHERE session_id = $1 AND member_id = $2`,
        [ids[title], member.userId],
      )
    )[0];

  async function makeClass(name: string, branchId: string) {
    const id = (
      await ownerQuery<{ id: string }>(
        `INSERT INTO classes (tenant_id, branch_id, name, session_type_code, weekdays, start_time, duration_minutes)
         VALUES ($1, $2, $3, 'GROUP', '{1}', '18:00', 60) RETURNING id`,
        [ctx.tenantId, branchId, name],
      )
    )[0].id;
    await ownerQuery(`INSERT INTO class_enrollments (tenant_id, class_id, member_id, start_date, status) VALUES ($1, $2, $3, '2026-01-01', 'ACTIVE')`, [
      ctx.tenantId,
      id,
      member.userId,
    ]);
    return id;
  }
  async function makeSession(title: string, classId: string, branchId: string, startIso: string) {
    const start = new Date(startIso);
    ids[title] = (
      await ownerQuery<{ id: string }>(
        `INSERT INTO sessions (tenant_id, class_id, branch_id, session_type_code, coach_id, title, starts_at, ends_at)
         VALUES ($1, $2, $3, 'GROUP', $4, $5, $6, $7) RETURNING id`,
        [ctx.tenantId, classId, branchId, coachId, title, start, new Date(start.getTime() + 3_600_000)],
      )
    )[0].id;
  }
  const resetSessions = () => ownerQuery(`DELETE FROM attendances WHERE member_id = $1`, [member.userId]);

  beforeAll(async () => {
    ctx = await bootTestApp();
    const staff = async (role: 'RECEPTIONIST' | 'COACH', branchCode: string) => {
      const s = await createStaff({ role, fullName: role, phone: nextPhone(), branchCode });
      return { token: (await login(ctx.api, s.phone)).token, userId: s.userId };
    };
    q1Desk = (await staff('RECEPTIONIST', 'Q1')).token;
    q7Desk = (await staff('RECEPTIONIST', 'Q7')).token;
    coachId = (await staff('COACH', 'Q1')).userId;
    member = await registerMember(ctx.api);
    const id = async (code: string) => (await ownerQuery<{ id: string }>(`SELECT id FROM branches WHERE code = $1`, [code]))[0].id;
    q1 = await id('Q1');
    q7 = await id('Q7');

    const pkg = (await ownerQuery<{ id: string }>(`SELECT id FROM package_types WHERE code = 'BOOK_1'`))[0].id;
    packageId = (
      await ownerQuery<{ id: string }>(
        `INSERT INTO memberships (tenant_id, member_id, package_type_id, start_date, end_date, total_sessions, used_sessions, status)
         VALUES ($1, $2, $3, '2026-10-01', '2026-12-31', 36, 4, 'ACTIVE') RETURNING id`,
        [ctx.tenantId, member.userId, pkg],
      )
    )[0].id;

    await makeSession('Evening', await makeClass('Evening class', q1), q1, '2026-11-02T11:00:00Z');
    await makeSession('Clash', await makeClass('Clash class', q1), q1, '2026-11-02T11:30:00Z');
    await makeSession('Riverside', await makeClass('Riverside class', q7), q7, '2026-11-02T13:00:00Z');
  });
  afterEach(async () => {
    resetClock();
    await resetSessions();
    await ownerQuery(`UPDATE memberships SET used_sessions = 4 WHERE id = $1`, [packageId]);
  });

  it('is for members only and needs exactly one of payload or shortCode', async () => {
    at(NOW);
    expect((await ctx.api.post('/api/v1/me/checkin').send({ payload: 'x' })).status).toBe(401);
    expect((await checkin({ payload: 'x' }, q1Desk)).status).toBe(403);
    expect((await checkin({})).status).toBe(400);
    expect((await checkin({ payload: 'HVP|Q1|1|1|aaaaaaaaaaaaaaaa', shortCode: '123456' })).status).toBe(400);
    expect((await checkin({ shortCode: '12345' })).status).toBe(400);
    expect((await checkin({ payload: 'x', sessionId: 'nope' })).status).toBe(400);
  });

  it('checks in, charges one session of the package and waits for the coach', async () => {
    at(NOW);
    // Q1 has two open sessions that overlap: the member picks Evening.
    const code = await codeOf(q1Desk, q1);
    const res = await checkin({ payload: code.payload, sessionId: ids.Evening });
    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({
      status: 'CHECKED_IN',
      alreadyCheckedIn: false,
      sessionsRemaining: 31,
      session: { sessionId: ids.Evening, branch: { id: q1 } },
    });
    expect(await used()).toBe(5);
    const row = await attendance('Evening');
    expect(row).toMatchObject({ attendance_status: 'AWAITING_COACH', membership_id: packageId, checked_in_by: null });
    expect(row.checkin_at).toBeTruthy();
    const audit = await ownerQuery<{ action: string }>(`SELECT action FROM audit_logs WHERE entity_type = 'ATTENDANCE' ORDER BY id DESC LIMIT 1`);
    expect(audit[0].action).toBe('CHECKIN');
  });

  it('answers a second scan with the first check-in and does not charge again', async () => {
    at(NOW);
    const code = await codeOf(q1Desk, q1);
    expect((await checkin({ payload: code.payload, sessionId: ids.Evening })).status).toBe(201);
    const again = await checkin({ payload: code.payload, sessionId: ids.Evening });
    expect(again.status).toBe(200);
    expect(again.body.data).toMatchObject({ alreadyCheckedIn: true, sessionsRemaining: 31 });
    expect(await used()).toBe(5);
    // Without naming the session the member still gets the same answer.
    expect((await checkin({ payload: code.payload })).body.data).toMatchObject({ alreadyCheckedIn: true });
    expect(await used()).toBe(5);
  });

  it('asks which session when several are open at the branch', async () => {
    at(NOW);
    const res = await checkin({ payload: (await codeOf(q1Desk, q1)).payload });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('CHOOSE_SESSION');
    expect(res.body.data.sessions.map((s: { title: string }) => s.title)).toEqual(['Evening', 'Clash']);
    expect(await used()).toBe(4);
    expect(await attendance('Evening')).toBeUndefined();
  });

  it('blocks the session that overlaps one already checked into', async () => {
    at(NOW);
    const code = await codeOf(q1Desk, q1);
    await checkin({ payload: code.payload, sessionId: ids.Evening });
    const res = await checkin({ payload: code.payload, sessionId: ids.Clash });
    expect([res.status, res.body.error.code]).toEqual([422, 'OVERLAPS_CHECKED_IN']);
    expect(await used()).toBe(5);
  });

  it('refuses a session picked at another branch than the code, telling where to go', async () => {
    at(NOW);
    const res = await checkin({ payload: (await codeOf(q1Desk, q1)).payload, sessionId: ids.Riverside });
    expect([res.status, res.body.error.code]).toEqual([422, 'CHECKIN_WRONG_BRANCH']);
    expect(res.body.error.message).toContain('Riverside');
    expect(await used()).toBe(4);
  });

  it('refuses outside the check-in window with the opening time', async () => {
    at('2026-11-02T12:00:00Z'); // 19:00: Riverside opens 19:15
    const code = await codeOf(q7Desk, q7);
    const early = await checkin({ payload: code.payload });
    expect([early.status, early.body.error.code]).toEqual([422, 'NOT_YET_OPEN']);
    expect(early.body.error.details.opensAt).toBe('2026-11-02T12:15:00.000Z');
    at('2026-11-02T13:40:00Z'); // 20:40: closed since 20:30
    const late = await checkin({ payload: (await codeOf(q7Desk, q7)).payload });
    expect([late.status, late.body.error.code]).toEqual([422, 'CHECKIN_CLOSED']);
  });

  it('rejects an expired or invalid code', async () => {
    at(NOW);
    const { payload } = await codeOf(q1Desk, q1);
    at('2026-11-02T10:52:00Z'); // two minutes later: the code has rotated out of its grace window
    const expired = await checkin({ payload, sessionId: ids.Evening });
    expect([expired.status, expired.body.error.code]).toEqual([422, 'CHECKIN_CODE_EXPIRED']);
    const junk = await checkin({ payload: 'hello' });
    expect([junk.status, junk.body.error.code]).toEqual([400, 'CHECKIN_CODE_INVALID']);
    expect(await used()).toBe(4);
  });

  it('accepts the 6 digits typed instead of the QR', async () => {
    at('2026-11-02T12:40:00Z'); // 19:40: only Riverside is open, at Q7
    const { shortCode } = await codeOf(q7Desk, q7);
    const res = await checkin({ shortCode });
    expect(res.status).toBe(201);
    expect(res.body.data.session.sessionId).toBe(ids.Riverside);
    expect((await checkin({ shortCode: '000000' })).body.error.code).toBe('CHECKIN_CODE_INVALID');
  });

  it('checks in again after the coach marked a pre-created attendance absent', async () => {
    at(NOW);
    await ownerQuery(`INSERT INTO attendances (tenant_id, session_id, member_id, attendance_status) VALUES ($1, $2, $3, 'ABSENT')`, [ctx.tenantId, ids.Evening, member.userId]);
    const res = await checkin({ payload: (await codeOf(q1Desk, q1)).payload, sessionId: ids.Evening });
    expect(res.status).toBe(201);
    expect((await attendance('Evening')).attendance_status).toBe('AWAITING_COACH');
    expect(await used()).toBe(5);
  });

  it('refuses a member whose package has no sessions left and writes nothing', async () => {
    at(NOW);
    await ownerQuery(`UPDATE memberships SET used_sessions = 36 WHERE id = $1`, [packageId]);
    const res = await checkin({ payload: (await codeOf(q1Desk, q1)).payload, sessionId: ids.Evening });
    expect([res.status, res.body.error.code]).toEqual([422, 'MEMBERSHIP_INVALID']);
    expect(await used()).toBe(36);
    expect(await attendance('Evening')).toBeUndefined();
  });

  it('refuses a frozen account', async () => {
    at(NOW);
    await ownerQuery(`UPDATE members SET status = 'FROZEN', status_since = now() WHERE user_id = $1`, [member.userId]);
    try {
      const res = await checkin({ payload: (await codeOf(q1Desk, q1)).payload, sessionId: ids.Evening });
      expect([res.status, res.body.error.code]).toEqual([422, 'ACCOUNT_RESTRICTED']);
    } finally {
      await ownerQuery(`UPDATE members SET status = 'ACTIVE' WHERE user_id = $1`, [member.userId]);
    }
  });
});

import { afterEach, beforeAll, describe, expect, it } from 'vitest';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import { env } from '../../src/config/env';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

// Mon 2026-11-02, 18:45 local (UTC+7): the self check-in window of the 18:00 session closed at 18:30, the session runs to 19:00.
const LATE = '2026-11-02T11:45:00Z';
const PHOTO = `${env.PUBLIC_BASE_URL.replace(/\/$/, '')}/files/evidence/desk.jpg`;

describe('front-desk check-in (CHK-04)', () => {
  let ctx: TestContext;
  let member: { token: string; userId: string };
  let other: { token: string; userId: string };
  let q1Desk: { token: string; userId: string };
  let q7Desk: { token: string; userId: string };
  let admin: string;
  let coach: string;
  let packageId: string;
  const ids: Record<string, string> = {};

  const at = (iso: string) => setClock(fixedClock(new Date(iso)));
  const assist = (token: string, body: object, memberId = member.userId) =>
    ctx.api.post(`/api/v1/members/${memberId}/checkin`).set(bearer(token)).send(body);
  const used = async () => (await ownerQuery<{ used_sessions: number }>(`SELECT used_sessions FROM memberships WHERE id = $1`, [packageId]))[0].used_sessions;
  const attendance = async (title: string) =>
    (
      await ownerQuery<{ attendance_status: string; checked_in_by: string | null; checkin_evidence_url: string | null; membership_id: string | null }>(
        `SELECT attendance_status, checked_in_by, checkin_evidence_url, membership_id FROM attendances WHERE session_id = $1 AND member_id = $2`,
        [ids[title], member.userId],
      )
    )[0];

  async function enrolledSession(title: string, branchId: string, startIso: string, who = member.userId) {
    const classId = (
      await ownerQuery<{ id: string }>(
        `INSERT INTO classes (tenant_id, branch_id, name, session_type_code, weekdays, start_time, duration_minutes)
         VALUES ($1, $2, $3, 'GROUP', '{1}', '18:00', 60) RETURNING id`,
        [ctx.tenantId, branchId, title],
      )
    )[0].id;
    await ownerQuery(`INSERT INTO class_enrollments (tenant_id, class_id, member_id, start_date, status) VALUES ($1, $2, $3, '2026-01-01', 'ACTIVE')`, [ctx.tenantId, classId, who]);
    const start = new Date(startIso);
    const coachId = (await ownerQuery<{ id: string }>(`SELECT user_id AS id FROM user_roles WHERE role_code = 'COACH' LIMIT 1`))[0].id;
    ids[title] = (
      await ownerQuery<{ id: string }>(
        `INSERT INTO sessions (tenant_id, class_id, branch_id, session_type_code, coach_id, title, starts_at, ends_at)
         VALUES ($1, $2, $3, 'GROUP', $4, $5, $6, $7) RETURNING id`,
        [ctx.tenantId, classId, branchId, coachId, title, start, new Date(start.getTime() + 3_600_000)],
      )
    )[0].id;
  }

  beforeAll(async () => {
    ctx = await bootTestApp();
    const staff = async (role: 'RECEPTIONIST' | 'ADMIN' | 'COACH', branchCode: string) => {
      const s = await createStaff({ role, fullName: role, phone: nextPhone(), branchCode });
      return { token: (await login(ctx.api, s.phone)).token, userId: s.userId };
    };
    q1Desk = await staff('RECEPTIONIST', 'Q1');
    q7Desk = await staff('RECEPTIONIST', 'Q7');
    admin = (await staff('ADMIN', 'Q1')).token;
    coach = (await staff('COACH', 'Q1')).token;
    member = await registerMember(ctx.api);
    other = await registerMember(ctx.api);
    const id = async (code: string) => (await ownerQuery<{ id: string }>(`SELECT id FROM branches WHERE code = $1`, [code]))[0].id;
    const q1 = await id('Q1');
    const q7 = await id('Q7');
    const pkg = (await ownerQuery<{ id: string }>(`SELECT id FROM package_types WHERE code = 'BOOK_1'`))[0].id;
    packageId = (
      await ownerQuery<{ id: string }>(
        `INSERT INTO memberships (tenant_id, member_id, package_type_id, start_date, end_date, total_sessions, used_sessions, status)
         VALUES ($1, $2, $3, '2026-10-01', '2026-12-31', 36, 4, 'ACTIVE') RETURNING id`,
        [ctx.tenantId, member.userId, pkg],
      )
    )[0].id;
    await enrolledSession('Evening', q1, '2026-11-02T11:00:00Z');
    await enrolledSession('Riverside', q7, '2026-11-02T11:00:00Z');
    await enrolledSession('Not mine', q1, '2026-11-02T11:00:00Z', other.userId);
  });
  afterEach(async () => {
    resetClock();
    await ownerQuery(`DELETE FROM attendances WHERE member_id = $1`, [member.userId]);
    await ownerQuery(`UPDATE memberships SET used_sessions = 4 WHERE id = $1`, [packageId]);
  });

  it('is for front-desk staff only and validates the body', async () => {
    at(LATE);
    const body = { sessionId: ids.Evening, evidenceUrl: PHOTO };
    expect((await ctx.api.post(`/api/v1/members/${member.userId}/checkin`).send(body)).status).toBe(401);
    expect((await assist(member.token, body)).status).toBe(403);
    expect((await assist(coach, body)).status).toBe(403);
    expect((await assist(q1Desk.token, {})).status).toBe(400);
    expect((await assist(q1Desk.token, { ...body, extra: 1 })).status).toBe(400);
    expect((await assist(q1Desk.token, body, 'not-a-uuid')).status).toBe(400);
  });

  it('requires a photo stored by this system', async () => {
    at(LATE);
    const none = await assist(q1Desk.token, { sessionId: ids.Evening });
    expect([none.status, none.body.error.code]).toEqual([400, 'CHECKIN_EVIDENCE_REQUIRED']);
    const foreign = await assist(q1Desk.token, { sessionId: ids.Evening, evidenceUrl: 'https://evil.test/a.jpg' });
    expect([foreign.status, foreign.body.error.code]).toEqual([400, 'INVALID_CHECKIN_EVIDENCE']);
    expect(await used()).toBe(4);
  });

  it('checks a latecomer in after the self window, recording who did it and the photo', async () => {
    at(LATE);
    const res = await assist(q1Desk.token, { sessionId: ids.Evening, evidenceUrl: PHOTO });
    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ status: 'CHECKED_IN', alreadyCheckedIn: false, sessionsRemaining: 31 });
    expect(await attendance('Evening')).toEqual({
      attendance_status: 'AWAITING_COACH',
      checked_in_by: q1Desk.userId,
      checkin_evidence_url: PHOTO,
      membership_id: packageId,
    });
    expect(await used()).toBe(5);
    const audit = await ownerQuery<{ action: string; actor_id: string }>(`SELECT action, actor_id FROM audit_logs WHERE entity_type = 'ATTENDANCE' ORDER BY id DESC LIMIT 1`);
    expect(audit[0]).toEqual({ action: 'CHECKIN_ASSISTED', actor_id: q1Desk.userId });
  });

  it('does not check in twice or charge twice', async () => {
    at(LATE);
    const body = { sessionId: ids.Evening, evidenceUrl: PHOTO };
    expect((await assist(q1Desk.token, body)).status).toBe(201);
    const again = await assist(q1Desk.token, body);
    expect(again.status).toBe(200);
    expect(again.body.data.alreadyCheckedIn).toBe(true);
    expect(await used()).toBe(5);
  });

  it("keeps a receptionist to their branch's sessions while an admin can use any", async () => {
    at(LATE);
    const body = { sessionId: ids.Riverside, evidenceUrl: PHOTO };
    expect((await assist(q1Desk.token, body)).status).toBe(403); // Riverside is at Q7
    expect(await used()).toBe(4);
    expect((await assist(q7Desk.token, body)).status).toBe(201);
    await ownerQuery(`DELETE FROM attendances WHERE member_id = $1`, [member.userId]);
    await ownerQuery(`UPDATE memberships SET used_sessions = 4 WHERE id = $1`, [packageId]);
    expect((await assist(admin, body)).status).toBe(201);
  });

  it("refuses a session that is not on this member's list, and an unknown member", async () => {
    at(LATE);
    const foreign = await assist(q1Desk.token, { sessionId: ids['Not mine'], evidenceUrl: PHOTO });
    expect([foreign.status, foreign.body.error.code]).toEqual([404, 'CHECKIN_SESSION_NOT_ELIGIBLE']);
    const ghost = await assist(admin, { sessionId: ids.Evening, evidenceUrl: PHOTO }, '00000000-0000-4000-8000-000000000000');
    expect(ghost.status).toBe(404);
  });

  it('stops once the session is over, and for accounts the rules block', async () => {
    at('2026-11-02T12:05:00Z'); // 19:05, the session ended at 19:00
    const over = await assist(q1Desk.token, { sessionId: ids.Evening, evidenceUrl: PHOTO });
    expect([over.status, over.body.error.code]).toEqual([422, 'CHECKIN_CLOSED']);

    at(LATE);
    await ownerQuery(`UPDATE members SET status = 'FROZEN', status_since = now() WHERE user_id = $1`, [member.userId]);
    try {
      const frozen = await assist(q1Desk.token, { sessionId: ids.Evening, evidenceUrl: PHOTO });
      expect([frozen.status, frozen.body.error.code]).toEqual([422, 'ACCOUNT_RESTRICTED']);
    } finally {
      await ownerQuery(`UPDATE members SET status = 'ACTIVE' WHERE user_id = $1`, [member.userId]);
    }
    expect(await used()).toBe(4);
  });
});

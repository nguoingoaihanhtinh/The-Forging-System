import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('courses and lessons (CAT-01)', () => {
  let ctx: TestContext;
  let member: { token: string; userId: string };
  let shortMember: { token: string; userId: string };
  let coach: string;
  let foundation: string;
  const ADVANCED_LESSON = 36;

  beforeAll(async () => {
    ctx = await bootTestApp();
    member = await registerMember(ctx.api);
    shortMember = await registerMember(ctx.api);
    coach = (await login(ctx.api, (await createStaff({ role: 'COACH', fullName: 'Coach', phone: nextPhone() })).phone)).token;
    foundation = (await ownerQuery<{ id: string }>(`SELECT id FROM courses WHERE code = 'FOUNDATION'`))[0].id;
    await ownerQuery(`UPDATE lesson_plans SET is_advanced = true WHERE course_id = $1 AND lesson_no = $2`, [foundation, ADVANCED_LESSON]);
    await ownerQuery(
      `INSERT INTO memberships (tenant_id, member_id, package_type_id, start_date, end_date, status)
       SELECT p.tenant_id, $1, p.id, current_date, current_date + 30, 'ACTIVE' FROM package_types p WHERE p.code = 'GT_1M'`,
      [shortMember.userId],
    );
  });
  afterAll(async () => {
    await ownerQuery(`UPDATE lesson_plans SET is_advanced = false WHERE course_id = $1 AND lesson_no = $2`, [foundation, ADVANCED_LESSON]);
  });

  it('requires authentication', async () => {
    expect((await ctx.api.get('/api/v1/courses')).status).toBe(401);
  });

  it('lists the five courses in curriculum order with NOT_STARTED progress', async () => {
    const res = await ctx.api.get('/api/v1/courses').set(bearer(member.token));
    expect(res.status).toBe(200);
    expect(res.body.data.map((c: { code: string }) => c.code)).toEqual([
      'FOUNDATION',
      'THE_STANDARD',
      'THE_PERSON',
      'THE_FIGHTER',
      'THE_EXAMPLE',
    ]);
    expect(res.body.data[0]).toMatchObject({
      id: foundation,
      durationWeeks: 12,
      totalLessons: 36,
      progress: { status: 'NOT_STARTED', lessonsCompleted: 0 },
    });
  });

  it('reports enrolment progress and ignores dropped enrolments', async () => {
    await ownerQuery(
      `INSERT INTO course_enrollments (tenant_id, member_id, course_id, status, lessons_completed)
       SELECT tenant_id, $1, id, 'IN_PROGRESS', 7 FROM courses WHERE id = $2`,
      [member.userId, foundation],
    );
    const res = await ctx.api.get(`/api/v1/courses/${foundation}`).set(bearer(member.token));
    expect(res.body.data.progress).toEqual({ status: 'IN_PROGRESS', lessonsCompleted: 7 });
    await ownerQuery(`UPDATE course_enrollments SET status = 'DROPPED' WHERE member_id = $1`, [member.userId]);
    const dropped = await ctx.api.get(`/api/v1/courses/${foundation}`).set(bearer(member.token));
    expect(dropped.body.data.progress).toEqual({ status: 'NOT_STARTED', lessonsCompleted: 0 });
  });

  it('returns the course with its lessons in order', async () => {
    const res = await ctx.api.get(`/api/v1/courses/${foundation}`).set(bearer(member.token));
    expect(res.status).toBe(200);
    expect(res.body.data.lessons).toHaveLength(36);
    expect(res.body.data.lessons[0]).toMatchObject({ lessonNo: 1, weekNo: 1, isAdvanced: false });
    expect(res.body.data.lessons[35]).toMatchObject({ lessonNo: ADVANCED_LESSON, isAdvanced: true });
  });

  it('returns lesson detail with objectives and content', async () => {
    const res = await ctx.api.get(`/api/v1/courses/${foundation}/lessons/1`).set(bearer(member.token));
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ courseId: foundation, lessonNo: 1 });
    expect(res.body.data).toHaveProperty('objectives');
    expect(res.body.data).toHaveProperty('content');
  });

  it('hides advanced lessons from members on a 1-month package', async () => {
    const course = await ctx.api.get(`/api/v1/courses/${foundation}`).set(bearer(shortMember.token));
    expect(course.body.data.lessons).toHaveLength(35);
    expect(course.body.data.lessons.some((l: { isAdvanced: boolean }) => l.isAdvanced)).toBe(false);
    const lesson = await ctx.api.get(`/api/v1/courses/${foundation}/lessons/${ADVANCED_LESSON}`).set(bearer(shortMember.token));
    expect([lesson.status, lesson.body.error.code]).toEqual([404, 'NOT_FOUND']);
  });

  it('shows everything to staff, without learner progress', async () => {
    const res = await ctx.api.get(`/api/v1/courses/${foundation}`).set(bearer(coach));
    expect(res.status).toBe(200);
    expect(res.body.data.progress).toBeNull();
    expect(res.body.data.lessons).toHaveLength(36);
    expect((await ctx.api.get(`/api/v1/courses/${foundation}/lessons/${ADVANCED_LESSON}`).set(bearer(coach))).status).toBe(200);
  });

  it('validates ids and answers 404 for unknown courses or lessons', async () => {
    expect((await ctx.api.get('/api/v1/courses/not-a-uuid').set(bearer(member.token))).status).toBe(400);
    expect((await ctx.api.get(`/api/v1/courses/${foundation}/lessons/0`).set(bearer(member.token))).status).toBe(400);
    expect((await ctx.api.get(`/api/v1/courses/${foundation}/lessons/999`).set(bearer(member.token))).status).toBe(404);
    const missing = '00000000-0000-4000-8000-000000000000';
    expect((await ctx.api.get(`/api/v1/courses/${missing}`).set(bearer(member.token))).status).toBe(404);
  });
});

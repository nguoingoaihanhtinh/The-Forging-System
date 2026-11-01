import { beforeAll, describe, expect, it } from 'vitest';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('admin lesson management (CAT-02)', () => {
  let ctx: TestContext;
  let admin: string;
  let adminId: string;
  let coach: string;
  let member: string;
  let course: string;

  const lessonsUrl = () => `/api/v1/admin/courses/${course}/lessons`;
  const lessonCount = async () =>
    (await ownerQuery<{ total_lessons: number }>(`SELECT total_lessons FROM courses WHERE id = $1`, [course]))[0].total_lessons;
  const visibleLessons = async () =>
    (await ctx.api.get(`/api/v1/courses/${course}`).set(bearer(member))).body.data.lessons as Array<{ lessonNo: number; title: string }>;

  beforeAll(async () => {
    ctx = await bootTestApp();
    const a = await createStaff({ role: 'ADMIN', fullName: 'Admin', phone: nextPhone() });
    adminId = a.userId;
    admin = (await login(ctx.api, a.phone)).token;
    coach = (await login(ctx.api, (await createStaff({ role: 'COACH', fullName: 'Coach', phone: nextPhone() })).phone)).token;
    member = (await registerMember(ctx.api)).token;
    course = (await ownerQuery<{ id: string }>(`SELECT id FROM courses WHERE code = 'THE_STANDARD'`))[0].id;
  });

  it('is admin only', async () => {
    const body = { title: 'JAB (1)' };
    expect((await ctx.api.post(lessonsUrl()).send(body)).status).toBe(401);
    expect((await ctx.api.post(lessonsUrl()).set(bearer(member)).send(body)).status).toBe(403);
    expect((await ctx.api.post(lessonsUrl()).set(bearer(coach)).send(body)).status).toBe(403);
    expect((await ctx.api.patch(`${lessonsUrl()}/1`).set(bearer(coach)).send({ title: 'x' })).status).toBe(403);
    expect((await ctx.api.delete(`${lessonsUrl()}/1`).set(bearer(coach))).status).toBe(403);
  });

  it('adds a lesson with the next free number and keeps total_lessons in step', async () => {
    expect(await lessonCount()).toBe(36);
    const res = await ctx.api
      .post(lessonsUrl())
      .set(bearer(admin))
      .send({ title: 'Bonus drill', subtitle: 'Extra', weekNo: 12, objectives: 'Stay sharp', content: { drills: ['shadow'] }, isAdvanced: true });
    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({
      courseId: course,
      lessonNo: 37,
      weekNo: 12,
      title: 'Bonus drill',
      subtitle: 'Extra',
      objectives: 'Stay sharp',
      content: { drills: ['shadow'] },
      isAssessment: false,
      isGraduation: false,
      isAdvanced: true,
    });
    expect(res.body.data).not.toHaveProperty('deletedAt');
    expect(await lessonCount()).toBe(37);
  });

  it('accepts an explicit lesson number but refuses a live duplicate', async () => {
    const dup = await ctx.api.post(lessonsUrl()).set(bearer(admin)).send({ lessonNo: 1, title: 'Again' });
    expect([dup.status, dup.body.error.code]).toEqual([409, 'LESSON_EXISTS']);
    const next = await ctx.api.post(lessonsUrl()).set(bearer(admin)).send({ lessonNo: 50, title: 'Fifty' });
    expect([next.status, next.body.data.lessonNo]).toEqual([201, 50]);
  });

  it('edits only the fields that are sent', async () => {
    const res = await ctx.api.patch(`${lessonsUrl()}/1`).set(bearer(admin)).send({ title: 'New title', subtitle: null, isAssessment: true });
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ lessonNo: 1, title: 'New title', subtitle: null, isAssessment: true, weekNo: 1 });
    const seen = await ctx.api.get(`/api/v1/courses/${course}/lessons/1`).set(bearer(member));
    expect(seen.body.data).toMatchObject({ title: 'New title', isAssessment: true });
  });

  it('soft-deletes: learners lose the lesson, the row and its number stay', async () => {
    const before = await lessonCount();
    expect((await ctx.api.delete(`${lessonsUrl()}/2`).set(bearer(admin))).status).toBe(204);
    expect(await lessonCount()).toBe(before - 1);
    expect((await visibleLessons()).some((l) => l.lessonNo === 2)).toBe(false);
    expect((await ctx.api.get(`/api/v1/courses/${course}/lessons/2`).set(bearer(member))).status).toBe(404);
    const rows = await ownerQuery<{ deleted_at: Date | null }>(
      `SELECT deleted_at FROM lesson_plans WHERE course_id = $1 AND lesson_no = 2`,
      [course],
    );
    expect(rows).toHaveLength(1);
    expect(rows[0].deleted_at).not.toBeNull();
    // A deleted lesson can be neither edited nor deleted again.
    expect((await ctx.api.patch(`${lessonsUrl()}/2`).set(bearer(admin)).send({ title: 'x' })).status).toBe(404);
    expect((await ctx.api.delete(`${lessonsUrl()}/2`).set(bearer(admin))).status).toBe(404);
  });

  it('re-creating a deleted lesson number revives the same row', async () => {
    const [{ id }] = await ownerQuery<{ id: string }>(`SELECT id FROM lesson_plans WHERE course_id = $1 AND lesson_no = 2`, [course]);
    const before = await lessonCount();
    const res = await ctx.api.post(lessonsUrl()).set(bearer(admin)).send({ lessonNo: 2, title: 'Second wind' });
    expect([res.status, res.body.data.id]).toEqual([201, id]);
    expect(res.body.data).toMatchObject({ title: 'Second wind', subtitle: null, isAdvanced: false });
    expect(await lessonCount()).toBe(before + 1);
    expect((await visibleLessons()).find((l) => l.lessonNo === 2)?.title).toBe('Second wind');
  });

  it('writes the audit trail', async () => {
    const actions = await ownerQuery<{ action: string; actor_id: string }>(
      `SELECT action, actor_id FROM audit_logs WHERE entity_type = 'lesson_plan' ORDER BY id`,
    );
    expect(actions.map((a) => a.action)).toEqual(['LESSON_CREATE', 'LESSON_CREATE', 'LESSON_UPDATE', 'LESSON_DELETE', 'LESSON_RESTORE']);
    expect(new Set(actions.map((a) => a.actor_id))).toEqual(new Set([adminId]));
  });

  it('validates input and unknown targets', async () => {
    const post = (body: object) => ctx.api.post(lessonsUrl()).set(bearer(admin)).send(body);
    expect((await post({})).status).toBe(400);
    expect((await post({ title: '   ' })).status).toBe(400);
    expect((await post({ title: 'x', lessonNo: 0 })).status).toBe(400);
    expect((await post({ title: 'x', weekNo: 99 })).status).toBe(400);
    expect((await ctx.api.patch(`${lessonsUrl()}/1`).set(bearer(admin)).send({})).status).toBe(400);
    expect((await ctx.api.patch(`${lessonsUrl()}/999`).set(bearer(admin)).send({ title: 'x' })).status).toBe(404);
    const missing = '00000000-0000-4000-8000-000000000000';
    expect((await ctx.api.post(`/api/v1/admin/courses/${missing}/lessons`).set(bearer(admin)).send({ title: 'x' })).status).toBe(404);
  });
});

import { beforeAll, describe, expect, it } from 'vitest';
import {
  bearer,
  bootTestApp,
  createStaff,
  login,
  nextPhone,
  ownerQuery,
  registerMember,
} from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('POST /admin/members/merge (MEM-19: front desk may merge duplicates)', () => {
  let ctx: TestContext;
  let receptionToken: string;
  let adminToken: string;
  let coachToken: string;

  beforeAll(async () => {
    ctx = await bootTestApp();
    receptionToken = (
      await login(
        ctx.api,
        (await createStaff({ role: 'RECEPTIONIST', fullName: 'Lễ tân', phone: nextPhone() })).phone,
      )
    ).token;
    adminToken = (
      await login(
        ctx.api,
        (await createStaff({ role: 'ADMIN', fullName: 'Admin', phone: nextPhone() })).phone,
      )
    ).token;
    coachToken = (
      await login(ctx.api, (await createStaff({ role: 'COACH', fullName: 'HLV', phone: nextPhone() })).phone)
    ).token;
  });

  const merge = (token: string | null, keepId: string, dropId: string) => {
    const req = ctx.api.post('/api/v1/admin/members/merge').send({ keepId, dropId });
    return token ? req.set(bearer(token)) : req;
  };
  const duplicateOf = async (id: string) =>
    (
      await ownerQuery<{ duplicate_of_member_id: string | null }>(
        `SELECT duplicate_of_member_id FROM members WHERE user_id = $1`,
        [id],
      )
    )[0].duplicate_of_member_id;

  it('lets a receptionist merge two accounts', async () => {
    const keep = await registerMember(ctx.api);
    const drop = await registerMember(ctx.api);
    const res = await merge(receptionToken, keep.userId, drop.userId);
    expect(res.status).toBe(204);
    expect(await duplicateOf(drop.userId)).toBe(keep.userId);
  });

  it('still lets an admin merge', async () => {
    const keep = await registerMember(ctx.api);
    const drop = await registerMember(ctx.api);
    expect((await merge(adminToken, keep.userId, drop.userId)).status).toBe(204);
  });

  it('refuses members, coaches and anonymous callers without touching the accounts', async () => {
    const keep = await registerMember(ctx.api);
    const drop = await registerMember(ctx.api);
    expect((await merge(keep.token, keep.userId, drop.userId)).status).toBe(403);
    expect((await merge(coachToken, keep.userId, drop.userId)).status).toBe(403);
    expect((await merge(null, keep.userId, drop.userId)).status).toBe(401);
    expect(await duplicateOf(drop.userId)).toBeNull();
  });

  it('validates the body', async () => {
    const res = await ctx.api
      .post('/api/v1/admin/members/merge')
      .set(bearer(receptionToken))
      .send({ keepId: 'x' });
    expect(res.status).toBe(400);
  });
});

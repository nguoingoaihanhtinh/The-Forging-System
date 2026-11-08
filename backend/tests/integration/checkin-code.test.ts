import { afterEach, beforeAll, describe, expect, it } from 'vitest';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import { bearer, bootTestApp, createStaff, login, nextPhone, ownerQuery, registerMember } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('rotating branch check-in code (CHK-01)', () => {
  let ctx: TestContext;
  let q1Desk: string;
  let q7Desk: string;
  let admin: string;
  let coach: string;
  let member: string;
  let q1: string;
  let q7: string;

  const codeUrl = (branchId: string) => `/api/v1/branches/${branchId}/checkin-code`;
  const fetchCode = async (token: string, branchId = q1) => (await ctx.api.get(codeUrl(branchId)).set(bearer(token))).body.data;
  const verify = (payload: string) => ctx.tx(() => ctx.services.checkinCodes.verifyPayload(payload));

  beforeAll(async () => {
    ctx = await bootTestApp();
    const staff = async (role: 'RECEPTIONIST' | 'ADMIN' | 'COACH', branchCode: string) =>
      (await login(ctx.api, (await createStaff({ role, fullName: role, phone: nextPhone(), branchCode })).phone)).token;
    q1Desk = await staff('RECEPTIONIST', 'Q1');
    q7Desk = await staff('RECEPTIONIST', 'Q7');
    admin = await staff('ADMIN', 'Q1');
    coach = await staff('COACH', 'Q1');
    member = (await registerMember(ctx.api)).token;
    const id = async (code: string) => (await ownerQuery<{ id: string }>(`SELECT id FROM branches WHERE code = $1`, [code]))[0].id;
    q1 = await id('Q1');
    q7 = await id('Q7');
  });
  afterEach(() => resetClock());

  it('is for front-desk staff only', async () => {
    expect((await ctx.api.get(codeUrl(q1))).status).toBe(401);
    expect((await ctx.api.get(codeUrl(q1)).set(bearer(member))).status).toBe(403);
    expect((await ctx.api.get(codeUrl(q1)).set(bearer(coach))).status).toBe(403);
    expect((await ctx.api.get(codeUrl('nope')).set(bearer(q1Desk))).status).toBe(400);
  });

  it('gives a receptionist only their own branch, an admin any branch', async () => {
    expect((await ctx.api.get(codeUrl(q7)).set(bearer(q1Desk))).status).toBe(403);
    expect((await ctx.api.get(codeUrl(q1)).set(bearer(q1Desk))).status).toBe(200);
    expect((await ctx.api.get(codeUrl(q7)).set(bearer(q7Desk))).status).toBe(200);
    expect((await ctx.api.get(codeUrl(q7)).set(bearer(admin))).status).toBe(200);
  });

  it('returns the payload, the 6 digits and the timing the screen needs', async () => {
    setClock(fixedClock(new Date('2026-11-02T09:00:10.000Z')));
    const data = await fetchCode(q1Desk);
    expect(data).toMatchObject({ branchId: q1, branchCode: 'Q1', qrVersion: '1', ttlSeconds: 30 });
    expect(data.payload).toMatch(/^HVP\|Q1\|1\|\d+\|[0-9a-f]{16}$/);
    expect(data.shortCode).toMatch(/^\d{6}$/);
    expect(data.serverTime).toBe('2026-11-02T09:00:10.000Z');
    expect(data.expiresAt).toBe('2026-11-02T09:00:30.000Z');
  });

  it('keeps the same code within a window and changes it in the next', async () => {
    setClock(fixedClock(new Date('2026-11-02T09:00:01.000Z')));
    const first = await fetchCode(q1Desk);
    setClock(fixedClock(new Date('2026-11-02T09:00:20.000Z')));
    expect((await fetchCode(q1Desk)).payload).toBe(first.payload);
    setClock(fixedClock(new Date('2026-11-02T09:00:31.000Z')));
    expect((await fetchCode(q1Desk)).payload).not.toBe(first.payload);
  });

  it('gives each branch its own code and a secret that is created once and never shown', async () => {
    setClock(fixedClock(new Date('2026-11-02T09:05:00.000Z')));
    const a = await fetchCode(admin, q1);
    const b = await fetchCode(admin, q7);
    expect(a.payload).not.toBe(b.payload);
    expect(JSON.stringify(a)).not.toContain('secret');
    const secrets = await ownerQuery<{ checkin_secret: string }>(`SELECT checkin_secret FROM branches WHERE code = 'Q1'`);
    await fetchCode(admin, q1);
    expect((await ownerQuery<{ checkin_secret: string }>(`SELECT checkin_secret FROM branches WHERE code = 'Q1'`))[0].checkin_secret).toBe(secrets[0].checkin_secret);
  });

  it('verifies a scanned code, tolerates one window of delay and then expires it', async () => {
    setClock(fixedClock(new Date('2026-11-02T10:00:05.000Z')));
    const { payload } = await fetchCode(q1Desk);
    expect(await verify(payload)).toEqual({ branchId: q1, branchCode: 'Q1' });
    setClock(fixedClock(new Date('2026-11-02T10:00:40.000Z')));
    expect((await verify(payload)).branchCode).toBe('Q1');
    setClock(fixedClock(new Date('2026-11-02T10:01:20.000Z')));
    await expect(verify(payload)).rejects.toMatchObject({ code: 'CHECKIN_CODE_EXPIRED', status: 422 });
  });

  it('rejects garbage and codes of another version, branch or signature', async () => {
    setClock(fixedClock(new Date('2026-11-02T11:00:05.000Z')));
    const { payload } = await fetchCode(q1Desk);
    await expect(verify('hello')).rejects.toMatchObject({ code: 'CHECKIN_CODE_INVALID', status: 400 });
    await expect(verify('HVP|Q1|1')).rejects.toMatchObject({ code: 'CHECKIN_CODE_INVALID' });
    await expect(verify(payload.replace('Q1', 'Q9'))).rejects.toMatchObject({ code: 'CHECKIN_CODE_INVALID' });
    await expect(verify(payload.slice(0, -1) + (payload.endsWith('0') ? '1' : '0'))).rejects.toMatchObject({ code: 'CHECKIN_CODE_INVALID' });
  });

  it('kills every earlier code when the branch QR is rotated', async () => {
    setClock(fixedClock(new Date('2026-11-02T12:00:05.000Z')));
    const { payload } = await fetchCode(q1Desk);
    expect((await ctx.api.post(`/api/v1/admin/branches/${q1}/qr/rotate`).set(bearer(admin)).send({})).status).toBe(200);
    await expect(verify(payload)).rejects.toMatchObject({ code: 'CHECKIN_CODE_INVALID' });
    const fresh = await fetchCode(q1Desk);
    expect(fresh.qrVersion).toBe('2');
    expect((await verify(fresh.payload)).branchId).toBe(q1);
  });

  it('verifies the 6 digits typed for a branch', async () => {
    setClock(fixedClock(new Date('2026-11-02T13:00:05.000Z')));
    const { shortCode } = await fetchCode(q1Desk);
    await expect(ctx.tx(() => ctx.services.checkinCodes.verifyShortCode(q1, shortCode))).resolves.toBeUndefined();
    await expect(ctx.tx(() => ctx.services.checkinCodes.verifyShortCode(q7, shortCode))).rejects.toMatchObject({ code: 'CHECKIN_CODE_INVALID' });
    await expect(ctx.tx(() => ctx.services.checkinCodes.verifyShortCode(q1, '12345'))).rejects.toMatchObject({ code: 'CHECKIN_CODE_INVALID' });
  });

  it('refuses to issue a code for an inactive branch', async () => {
    await ownerQuery(`UPDATE branches SET is_active = false WHERE id = $1`, [q7]);
    try {
      const res = await ctx.api.get(codeUrl(q7)).set(bearer(admin));
      expect([res.status, res.body.error.code]).toEqual([422, 'BRANCH_INACTIVE']);
    } finally {
      await ownerQuery(`UPDATE branches SET is_active = true WHERE id = $1`, [q7]);
    }
  });
});

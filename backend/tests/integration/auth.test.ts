import { afterEach, beforeAll, describe, expect, it } from 'vitest';
import { resetClock, setClock } from '../../src/common/utils/clock';
import { bearer, bootTestApp, DEFAULT_PASSWORD, login, nextEmail, nextPhone, ownerQuery, registerMember, registerOtp } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('auth', () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await bootTestApp();
  });
  afterEach(() => resetClock());

  const register = (body: Record<string, unknown>) =>
    ctx.api.post('/api/v1/auth/register').send({ fullName: 'Nguyễn Văn A', email: nextEmail(), password: DEFAULT_PASSWORD, ...body });

  it('registers a learner with an SMS OTP, initialises rank I and logs in with phone or email', async () => {
    const phone = nextPhone();
    const otp = await registerOtp(ctx.api, `+84 ${phone.slice(1)}`);
    expect(otp.maskedDestination).toBe(`${phone.slice(0, 3)}****${phone.slice(-3)}`);
    const reg = await register({ phone, email: 'nguyen.a@example.com', otpRequestId: otp.requestId, otp: otp.devPin });
    expect(reg.status).toBe(201);
    expect(reg.body.data.user.appRole).toBe('student');

    const [row] = await ownerQuery<{ phone_verified_at: Date | null }>(`SELECT phone_verified_at FROM users WHERE id = $1`, [reg.body.data.user.id]);
    expect(row.phone_verified_at).not.toBeNull();

    const byPhone = await login(ctx.api, phone);
    const byEmail = await login(ctx.api, 'NGUYEN.A@example.com');
    expect(byPhone.user.id).toBe(byEmail.user.id);

    const rank = await ctx.api.get('/api/v1/me/rank').set(bearer(byPhone.token));
    expect(rank.status).toBe(200);
    expect(rank.body.data.current.rankOrder).toBe(1);
    expect(rank.body.data.next.rankOrder).toBe(2);

    // The OTP is single use.
    const replay = await register({ phone, otpRequestId: otp.requestId, otp: otp.devPin });
    expect(replay.status).toBe(400);
  });

  it('rejects registration without a valid OTP for that phone number', async () => {
    const phone = nextPhone();
    const missing = await register({ phone });
    expect(missing.status).toBe(400);

    const otp = await registerOtp(ctx.api, phone);
    const wrong = await register({ phone, otpRequestId: otp.requestId, otp: otp.devPin === '000000' ? '111111' : '000000' });
    expect(wrong.status).toBe(400);
    expect(wrong.body.error.code).toBe('OTP_INVALID');

    const otherPhone = await register({ phone: nextPhone(), otpRequestId: otp.requestId, otp: otp.devPin });
    expect(otherPhone.body.error.code).toBe('OTP_INVALID');

    setClock({ now: () => new Date(Date.now() + 6 * 60_000) }); // TTL is 5 minutes
    const expired = await register({ phone, otpRequestId: otp.requestId, otp: otp.devPin });
    expect(expired.body.error.code).toBe('OTP_INVALID');
  });

  it('rejects an invalid phone number when requesting an OTP', async () => {
    const res = await ctx.api.post('/api/v1/auth/register/otp').send({ phone: '12345' });
    expect(res.status).toBe(400);
  });

  it('refuses an OTP for a phone number that already has an account', async () => {
    const { phone } = await registerMember(ctx.api);
    const res = await ctx.api.post('/api/v1/auth/register/otp').send({ phone });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('PHONE_TAKEN');
  });

  it('allows only one account per e-mail, keeping the OTP for a retry', async () => {
    const { email } = await registerMember(ctx.api);
    const phone = nextPhone();
    const otp = await registerOtp(ctx.api, phone);
    const again = await register({ phone, email, otpRequestId: otp.requestId, otp: otp.devPin });
    expect(again.status).toBe(409);
    expect(again.body.error.code).toBe('EMAIL_TAKEN');
    const retry = await register({ phone, otpRequestId: otp.requestId, otp: otp.devPin });
    expect(retry.status).toBe(201);
  });

  it('rejects wrong credentials and weak passwords', async () => {
    const { phone } = await registerMember(ctx.api);
    const bad = await ctx.api.post('/api/v1/auth/login').send({ identifier: phone, password: 'wrong-password' });
    expect(bad.status).toBe(401);
    const newPhone = nextPhone();
    const otp = await registerOtp(ctx.api, newPhone);
    const weak = await register({ phone: newPhone, password: 'abcdefgh', otpRequestId: otp.requestId, otp: otp.devPin });
    expect(weak.status).toBe(400);
  });

  it('rotates refresh tokens (single use)', async () => {
    const { phone } = await registerMember(ctx.api);
    const first = await login(ctx.api, phone);
    const rotated = await ctx.api.post('/api/v1/auth/refresh').send({ refreshToken: first.refreshToken });
    expect(rotated.status).toBe(200);
    const replay = await ctx.api.post('/api/v1/auth/refresh').send({ refreshToken: first.refreshToken });
    expect(replay.status).toBe(401);
  });

  it('resets a password with phone + SMS PIN', async () => {
    const { phone } = await registerMember(ctx.api);
    const forgot = await ctx.api.post('/api/v1/auth/password/forgot').send({ phone: `+84${phone.slice(1)}` });
    expect(forgot.status).toBe(200);
    const { requestId, devPin } = forgot.body.data;
    expect(devPin).toHaveLength(6);

    const wrong = await ctx.api.post('/api/v1/auth/password/verify-pin').send({ requestId, pin: devPin === '000000' ? '111111' : '000000' });
    expect(wrong.status).toBe(400);
    const verified = await ctx.api.post('/api/v1/auth/password/verify-pin').send({ requestId, pin: devPin });
    expect(verified.status).toBe(200);

    const reset = await ctx.api
      .post('/api/v1/auth/password/reset')
      .send({ requestId, resetToken: verified.body.data.resetToken, password: 'NewPass123', passwordConfirm: 'NewPass123' });
    expect(reset.status).toBe(204);
    await login(ctx.api, phone, 'NewPass123');
  });

  it('rejects an unknown phone number on forgot password', async () => {
    const res = await ctx.api.post('/api/v1/auth/password/forgot').send({ phone: nextPhone() });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('PHONE_NOT_REGISTERED');
  });

  it('locks the PIN after the maximum number of wrong attempts', async () => {
    const { phone } = await registerMember(ctx.api);
    const { requestId, devPin } = (await ctx.api.post('/api/v1/auth/password/forgot').send({ phone })).body.data;
    const wrongPin = devPin === '000000' ? '111111' : '000000';
    for (let i = 0; i < 5; i++) {
      const res = await ctx.api.post('/api/v1/auth/password/verify-pin').send({ requestId, pin: wrongPin });
      expect(res.status).toBe(400);
    }
    const right = await ctx.api.post('/api/v1/auth/password/verify-pin').send({ requestId, pin: devPin });
    expect(right.status).toBe(400);
    expect(right.body.error.code).toBe('PIN_INVALID');
  });

  it('blocks INACTIVE members from signing in but lets FROZEN members in', async () => {
    const { phone, userId } = await registerMember(ctx.api);
    await ctx.tx(() => ctx.services.members.changeStatus({ memberId: userId, status: 'FROZEN', reason: 'test', by: null, via: 'BATCH' }));
    await login(ctx.api, phone);
    await ctx.tx(async () => {
      await ctx.services.members.changeStatus({ memberId: userId, status: 'INACTIVE', reason: 'test', by: null, via: 'BATCH' });
    });
    const res = await ctx.api.post('/api/v1/auth/login').send({ identifier: phone, password: DEFAULT_PASSWORD });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('ACCOUNT_INACTIVE');
  });
});

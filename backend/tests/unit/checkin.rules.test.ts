import { describe, expect, it } from 'vitest';
import { checkinWindow, evaluateMemberGate, evaluateSessions } from '../../src/modules/checkin/checkin.rules';
import type { MemberGate, SessionInput } from '../../src/modules/checkin/checkin.rules';

const SETTINGS = { opensBeforeMinutes: 45, closesAfterMinutes: 30 };
const OK_GATE: MemberGate = { ok: true, code: null, message: null };
const at = (hhmm: string) => new Date(`2026-11-02T${hhmm}:00Z`);
const session = (id: string, start: string, end: string, over: Partial<SessionInput> = {}): SessionInput => ({
  id,
  startsAt: at(start),
  endsAt: at(end),
  opensAt: null,
  closesAt: null,
  attendanceStatus: null,
  ...over,
});
const verdictOf = (s: SessionInput[], now: string, mode: 'SELF' | 'ASSISTED' = 'SELF', gate = OK_GATE) =>
  evaluateSessions(s, gate, SETTINGS, mode, at(now));

describe('check-in rules: member gate (CHK-02)', () => {
  const base = { totalSessions: 36, usedSessions: 10, endDate: '2026-12-01' };

  it('lets a member with a valid package through', () => {
    expect(evaluateMemberGate({ status: 'ACTIVE', membership: base, today: '2026-11-02' })).toEqual({ ok: true, code: null, message: null });
  });

  it('blocks inactive and frozen accounts with their own codes', () => {
    expect(evaluateMemberGate({ status: 'INACTIVE', membership: base, today: '2026-11-02' }).code).toBe('ACCOUNT_INACTIVE');
    expect(evaluateMemberGate({ status: 'FROZEN', membership: base, today: '2026-11-02' }).code).toBe('ACCOUNT_RESTRICTED');
  });

  it('blocks a member without a package, with an ended package or without sessions left', () => {
    const code = (membership: Parameters<typeof evaluateMemberGate>[0]['membership']) =>
      evaluateMemberGate({ status: 'ACTIVE', membership, today: '2026-11-02' }).code;
    expect(code(null)).toBe('MEMBERSHIP_INVALID');
    expect(code({ ...base, endDate: '2026-11-01' })).toBe('MEMBERSHIP_INVALID');
    expect(code({ ...base, usedSessions: 36 })).toBe('MEMBERSHIP_INVALID');
  });

  it('accepts the last day of a package and packages with unlimited sessions', () => {
    const code = (membership: Parameters<typeof evaluateMemberGate>[0]['membership']) =>
      evaluateMemberGate({ status: 'ACTIVE', membership, today: '2026-11-02' }).code;
    expect(code({ ...base, endDate: '2026-11-02' })).toBeNull();
    expect(code({ totalSessions: null, usedSessions: 500, endDate: '2026-12-01' })).toBeNull();
  });
});

describe('check-in rules: window (CHK-02)', () => {
  const s = session('a', '18:00', '19:00');

  it('opens 45 minutes before and closes 30 minutes after the start', () => {
    expect(checkinWindow(s, SETTINGS, 'SELF')).toEqual({ opensAt: at('17:15'), closesAt: at('18:30') });
  });

  it('prefers the window set on the session itself', () => {
    const w = checkinWindow({ ...s, opensAt: at('17:00'), closesAt: at('18:10') }, SETTINGS, 'SELF');
    expect(w).toEqual({ opensAt: at('17:00'), closesAt: at('18:10') });
  });

  it('keeps front-desk check-in open until the session ends', () => {
    expect(checkinWindow(s, SETTINGS, 'ASSISTED').closesAt).toEqual(at('19:00'));
    // never earlier than the self window when the session override is later than the end
    expect(checkinWindow({ ...s, closesAt: at('19:30') }, SETTINGS, 'ASSISTED').closesAt).toEqual(at('19:30'));
  });
});

describe('check-in rules: verdict per session (CHK-02)', () => {
  const a = session('a', '18:00', '19:00');

  it('is open inside the window', () => {
    expect(verdictOf([a], '17:15')[0]).toMatchObject({ state: 'OPEN', canCheckin: true, reason: null });
    expect(verdictOf([a], '18:30')[0].state).toBe('OPEN'); // the closing minute still counts
  });

  it('is not open before the window and closed after it', () => {
    expect(verdictOf([a], '17:14')[0]).toMatchObject({ state: 'NOT_YET_OPEN', canCheckin: false, reason: 'NOT_YET_OPEN' });
    expect(verdictOf([a], '18:31')[0]).toMatchObject({ state: 'CLOSED', canCheckin: false, reason: 'CHECKIN_CLOSED' });
  });

  it('lets the front desk help a latecomer until the session ends, not after', () => {
    expect(verdictOf([a], '18:45', 'SELF')[0].state).toBe('CLOSED');
    expect(verdictOf([a], '18:45', 'ASSISTED')[0].state).toBe('OPEN');
    expect(verdictOf([a], '19:01', 'ASSISTED')[0].state).toBe('CLOSED');
  });

  it('reports a session already checked into, whatever the coach decided', () => {
    for (const status of ['AWAITING_COACH', 'CONFIRMED_PASS', 'CONFIRMED_FAIL']) {
      expect(verdictOf([{ ...a, attendanceStatus: status }], '18:10')[0]).toMatchObject({
        state: 'CHECKED_IN',
        canCheckin: false,
        reason: 'ALREADY_CHECKED_IN',
      });
    }
  });

  it('treats a pre-created or coach-absent attendance as not checked in yet', () => {
    expect(verdictOf([{ ...a, attendanceStatus: 'UPCOMING' }], '18:10')[0].state).toBe('OPEN');
    expect(verdictOf([{ ...a, attendanceStatus: 'ABSENT' }], '18:10')[0].state).toBe('OPEN');
  });

  it('blocks every session with the member-level reason, except the one already checked into', () => {
    const gate: MemberGate = { ok: false, code: 'MEMBERSHIP_INVALID', message: 'hết hạn' };
    const done = session('done', '12:00', '13:00', { attendanceStatus: 'AWAITING_COACH' });
    const result = verdictOf([done, a], '18:10', 'SELF', gate);
    expect(result[0].state).toBe('CHECKED_IN');
    expect(result[1]).toMatchObject({ state: 'BLOCKED', canCheckin: false, reason: 'MEMBERSHIP_INVALID', message: 'hết hạn' });
  });

  it('allows only one of two sessions that run at the same time', () => {
    const clash = session('clash', '18:30', '19:30');
    const [first, second] = verdictOf([{ ...a, attendanceStatus: 'AWAITING_COACH' }, clash], '18:40');
    expect(first.state).toBe('CHECKED_IN');
    expect(second).toMatchObject({ state: 'OVERLAPS_CHECKED_IN', canCheckin: false, reason: 'OVERLAPS_CHECKED_IN' });
    // Nothing checked into yet: both are offered, the member picks one.
    expect(verdictOf([a, clash], '18:25').map((v) => v.state)).toEqual(['OPEN', 'OPEN']);
  });

  it('allows back-to-back sessions of the same day', () => {
    const next = session('next', '19:00', '20:00');
    const result = verdictOf([{ ...a, attendanceStatus: 'CONFIRMED_PASS' }, next], '18:50');
    expect(result[1].state).toBe('OPEN'); // 19:00 starts exactly when 18:00-19:00 ends
  });
});

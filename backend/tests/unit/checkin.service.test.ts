import { afterEach, describe, expect, it, vi } from 'vitest';
import { badRequest } from '../../src/common/errors/app-error';
import type { AppError } from '../../src/common/errors/app-error';
import { fixedClock, resetClock, setClock } from '../../src/common/utils/clock';
import type { CheckinCodePort } from '../../src/modules/checkin/checkin-code.service';
import type { CheckinSessionService, CheckinSessionView } from '../../src/modules/checkin/checkin-session.service';
import type { AttendanceRow, CheckinRepository } from '../../src/modules/checkin/checkin.repository';
import { CheckinService } from '../../src/modules/checkin/checkin.service';
import type { CheckinState } from '../../src/modules/checkin/checkin.rules';
import type { AuditService } from '../../src/modules/audit/audit.service';

const NOW = new Date('2026-11-02T11:00:00Z'); // 18:00 local
const MEMBER = 'member-1';

function view(id: string, branch: string, state: CheckinState = 'OPEN', over: Partial<CheckinSessionView['checkin']> = {}): CheckinSessionView {
  return {
    sessionId: id,
    classId: null,
    title: id,
    sessionType: 'GROUP',
    isExam: false,
    startsAt: new Date('2026-11-02T11:00:00Z'),
    endsAt: new Date('2026-11-02T12:00:00Z'),
    branch: { id: branch, name: `Branch ${branch}` },
    coach: { id: 'coach', fullName: 'Coach' },
    checkin: {
      state,
      canCheckin: state === 'OPEN',
      reason: state === 'OPEN' ? null : state === 'CHECKED_IN' ? 'ALREADY_CHECKED_IN' : state === 'CLOSED' ? 'CHECKIN_CLOSED' : 'NOT_YET_OPEN',
      message: state === 'OPEN' ? null : 'refused',
      opensAt: new Date('2026-11-02T10:15:00Z'),
      closesAt: new Date('2026-11-02T11:30:00Z'),
      checkedInAt: state === 'CHECKED_IN' ? new Date('2026-11-02T10:50:00Z') : null,
      ...over,
    },
  };
}

function setup(sessions: CheckinSessionView[], opts: { attendance?: AttendanceRow | null; charge?: boolean; insertConflict?: boolean } = {}) {
  const repo = {
    lockAttendance: vi.fn().mockResolvedValue(opts.attendance ?? null),
    insertCheckin: vi.fn().mockResolvedValue(opts.insertConflict ? null : 'att-new'),
    markCheckedIn: vi.fn().mockResolvedValue(1),
    charge: vi.fn().mockResolvedValue(opts.charge === false ? null : { id: 'ms-1', totalSessions: 36, usedSessions: 5 }),
    setAttendanceMembership: vi.fn().mockResolvedValue(1),
    touchActivity: vi.fn().mockResolvedValue(1),
    memberGate: vi.fn().mockResolvedValue({ status: 'ACTIVE', totalSessions: 36, usedSessions: 5, endDate: null, hasActiveMembership: true }),
  };
  const codes = {
    verifyPayload: vi.fn().mockImplementation(async (text: string) => {
      if (!text.startsWith('HVP|')) throw badRequest('invalid', undefined, 'CHECKIN_CODE_INVALID');
      return { branchId: text.split('|')[1], branchCode: text.split('|')[1] };
    }),
    verifyShortCode: vi.fn().mockImplementation(async (branchId: string, code: string) => {
      if (!(branchId === 'q7' && code === '123456')) throw badRequest('invalid', undefined, 'CHECKIN_CODE_INVALID');
    }),
  };
  const sessionService = {
    listToday: vi.fn().mockResolvedValue({ date: '2026-11-02', eligibility: { canCheckin: true, code: null, message: null }, sessions }),
  };
  const audit = { record: vi.fn().mockResolvedValue(undefined) };
  const service = new CheckinService(
    repo as unknown as CheckinRepository,
    codes as unknown as CheckinCodePort,
    sessionService as unknown as CheckinSessionService,
    audit as unknown as AuditService,
  );
  setClock(fixedClock(NOW));
  return { service, repo, codes, audit };
}
const scan = (branch: string, extra: object = {}) => ({ payload: `HVP|${branch}|1|1|aaaaaaaaaaaaaaaa`, ...extra });
const codeOf = async (p: Promise<unknown>) => ((await p.catch((e: unknown) => e)) as AppError).code;

describe('check-in flow (CHK-03)', () => {
  afterEach(() => resetClock());

  it('checks the member into the only open session at the scanned branch', async () => {
    const { service, repo, audit } = setup([view('s1', 'q1'), view('other', 'q7')]);
    const out = await service.checkIn(MEMBER, scan('q1'));
    expect(out).toMatchObject({ status: 'CHECKED_IN', alreadyCheckedIn: false, checkedInAt: NOW, sessionsRemaining: 31 });
    expect(out.status === 'CHECKED_IN' && out.session).toMatchObject({ sessionId: 's1', branch: { id: 'q1' } });
    expect(repo.insertCheckin).toHaveBeenCalledWith('s1', MEMBER, { at: NOW, checkedInBy: null, evidenceUrl: null });
    expect(repo.charge).toHaveBeenCalledWith(MEMBER, '2026-11-02');
    expect(repo.setAttendanceMembership).toHaveBeenCalledWith('att-new', 'ms-1');
    expect(repo.touchActivity).toHaveBeenCalledWith(MEMBER, NOW);
    expect(audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'CHECKIN', actorId: MEMBER, entityId: 'att-new' }));
  });

  it('turns a pre-created attendance row into the check-in instead of adding a second one', async () => {
    const { service, repo } = setup([view('s1', 'q1')], { attendance: { id: 'att-9', attendanceStatus: 'UPCOMING', checkinAt: null } });
    await service.checkIn(MEMBER, scan('q1'));
    expect(repo.markCheckedIn).toHaveBeenCalledWith('att-9', expect.objectContaining({ at: NOW }));
    expect(repo.insertCheckin).not.toHaveBeenCalled();
    expect(repo.setAttendanceMembership).toHaveBeenCalledWith('att-9', 'ms-1');
  });

  it('asks which session when several are open, writing nothing', async () => {
    const { service, repo } = setup([view('s1', 'q1'), view('s2', 'q1')]);
    const out = await service.checkIn(MEMBER, scan('q1'));
    expect(out.status).toBe('CHOOSE_SESSION');
    expect(out.status === 'CHOOSE_SESSION' && out.sessions.map((s) => s.sessionId)).toEqual(['s1', 's2']);
    expect(repo.insertCheckin).not.toHaveBeenCalled();
    expect(repo.charge).not.toHaveBeenCalled();
  });

  it('checks into the session picked from that list', async () => {
    const { service, repo } = setup([view('s1', 'q1'), view('s2', 'q1')]);
    const out = await service.checkIn(MEMBER, scan('q1', { sessionId: 's2' }));
    expect(out.status === 'CHECKED_IN' && out.session.sessionId).toBe('s2');
    expect(repo.insertCheckin).toHaveBeenCalledWith('s2', MEMBER, expect.anything());
  });

  it('answers a repeat scan with the first check-in, without charging again', async () => {
    const { service, repo } = setup([view('s1', 'q1', 'CHECKED_IN')]);
    const out = await service.checkIn(MEMBER, scan('q1'));
    expect(out).toMatchObject({ status: 'CHECKED_IN', alreadyCheckedIn: true, sessionsRemaining: 31 });
    expect(out.status === 'CHECKED_IN' && out.checkedInAt).toEqual(new Date('2026-11-02T10:50:00Z'));
    expect(repo.charge).not.toHaveBeenCalled();
    expect(repo.insertCheckin).not.toHaveBeenCalled();
  });

  it('treats a request that loses the race for the row as a repeat', async () => {
    const done: AttendanceRow = { id: 'att-1', attendanceStatus: 'AWAITING_COACH', checkinAt: new Date('2026-11-02T10:59:59Z') };
    const { service, repo } = setup([view('s1', 'q1')], { insertConflict: true });
    repo.lockAttendance.mockResolvedValueOnce(null).mockResolvedValueOnce(done);
    const out = await service.checkIn(MEMBER, scan('q1'));
    expect(out).toMatchObject({ alreadyCheckedIn: true });
    expect(repo.charge).not.toHaveBeenCalled();
  });

  it('refuses a scan at another branch than the sessions, naming where to go', async () => {
    const { service } = setup([view('s1', 'q7')]);
    const err = (await service.checkIn(MEMBER, scan('q1')).catch((e: unknown) => e)) as AppError;
    expect([err.status, err.code]).toEqual([422, 'CHECKIN_WRONG_BRANCH']);
    expect(err.message).toContain('Branch q7');
  });

  it('refuses a session picked at the wrong branch', async () => {
    const { service } = setup([view('s1', 'q1'), view('s2', 'q7')]);
    expect(await codeOf(service.checkIn(MEMBER, scan('q1', { sessionId: 's2' })))).toBe('CHECKIN_WRONG_BRANCH');
  });

  it('refuses when there is no session today, or the session is not the member\'s', async () => {
    expect(await codeOf(setup([]).service.checkIn(MEMBER, scan('q1')))).toBe('NO_SESSION_TODAY');
    const { service } = setup([view('s1', 'q1')]);
    const err = (await service.checkIn(MEMBER, scan('q1', { sessionId: 'someone-elses' })).catch((e: unknown) => e)) as AppError;
    expect([err.status, err.code]).toEqual([404, 'CHECKIN_SESSION_NOT_ELIGIBLE']);
  });

  it('explains why the nearest session is refused when none is open', async () => {
    expect(await codeOf(setup([view('s1', 'q1', 'CLOSED')]).service.checkIn(MEMBER, scan('q1')))).toBe('CHECKIN_CLOSED');
    expect(await codeOf(setup([view('s1', 'q1', 'NOT_YET_OPEN')]).service.checkIn(MEMBER, scan('q1')))).toBe('NOT_YET_OPEN');
    const blocked = view('s1', 'q1', 'BLOCKED', { reason: 'MEMBERSHIP_INVALID', message: 'Gói hết hạn' });
    const err = (await setup([blocked]).service.checkIn(MEMBER, scan('q1')).catch((e: unknown) => e)) as AppError;
    expect([err.code, err.message]).toEqual(['MEMBERSHIP_INVALID', 'Gói hết hạn']);
  });

  it('gives back nothing written when the package cannot be charged', async () => {
    const { service, repo } = setup([view('s1', 'q1')], { charge: false });
    expect(await codeOf(service.checkIn(MEMBER, scan('q1')))).toBe('MEMBERSHIP_INVALID');
    expect(repo.setAttendanceMembership).not.toHaveBeenCalled(); // the request transaction then rolls the attendance back
  });

  it('passes an invalid or expired code through', async () => {
    const { service, repo } = setup([view('s1', 'q1')]);
    expect(await codeOf(service.checkIn(MEMBER, { payload: 'junk' }))).toBe('CHECKIN_CODE_INVALID');
    expect(repo.insertCheckin).not.toHaveBeenCalled();
  });

  it('finds the branch of a typed code among the branches the member has sessions at', async () => {
    const { service, codes } = setup([view('s1', 'q1'), view('s2', 'q7')]);
    const out = await service.checkIn(MEMBER, { shortCode: '123456' });
    expect(out.status === 'CHECKED_IN' && out.session.sessionId).toBe('s2');
    expect(codes.verifyShortCode).toHaveBeenCalledWith('q1', '123456');
    expect(codes.verifyShortCode).toHaveBeenCalledWith('q7', '123456');
  });

  it('rejects a typed code that matches none of those branches', async () => {
    const { service, repo } = setup([view('s1', 'q1'), view('s2', 'q7')]);
    expect(await codeOf(service.checkIn(MEMBER, { shortCode: '654321' }))).toBe('CHECKIN_CODE_INVALID');
    expect(repo.insertCheckin).not.toHaveBeenCalled();
  });
});

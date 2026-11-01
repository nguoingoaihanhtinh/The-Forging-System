import { AppError } from '../../common/errors/app-error';
import { clock } from '../../common/utils/clock';
import { logger } from '../../common/utils/logger';
import { localDate } from '../../common/utils/time';
import type { AuditService } from '../audit/audit.service';
import type { CheckinCodePort } from './checkin-code.service';
import type { CheckinSessionService, CheckinSessionView, TodayCheckin } from './checkin-session.service';
import { errorForVerdict, membershipInvalidError, noSessionTodayError, sessionNotEligibleError, wrongBranchError } from './checkin.errors';
import type { AttendanceRow, CheckinRepository } from './checkin.repository';
import { isCheckedIn } from './checkin.rules';

export interface CheckinInput {
  /** Text read from the branch QR. */
  payload?: string;
  /** The 6 digits typed instead of scanning. Exactly one of payload / shortCode. */
  shortCode?: string;
  /** Which session, when the member has several open at the branch. */
  sessionId?: string;
}

export interface CheckedIn {
  status: 'CHECKED_IN';
  /** True when the member had already checked in: nothing was charged or written. */
  alreadyCheckedIn: boolean;
  checkedInAt: Date;
  session: Pick<CheckinSessionView, 'sessionId' | 'title' | 'startsAt' | 'endsAt' | 'branch'>;
  /** Sessions left on the package (null = unlimited or no package to report). */
  sessionsRemaining: number | null;
  message: string;
}

/** Several sessions are open at this branch: the app asks which one and sends the same code again with `sessionId`. */
export interface ChooseSession {
  status: 'CHOOSE_SESSION';
  sessions: CheckinSessionView[];
}

export type CheckinOutcome = CheckedIn | ChooseSession;

const SUCCESS = 'Check-in thành công. Buổi tập đang chờ Coach xác nhận - điểm chỉ được cộng sau khi Coach xác nhận.';
const ALREADY = 'Bạn đã check-in buổi này rồi.';

const summaryOf = (s: CheckinSessionView): CheckedIn['session'] => ({
  sessionId: s.sessionId,
  title: s.title,
  startsAt: s.startsAt,
  endsAt: s.endsAt,
  branch: s.branch,
});

/** CHK-03: a member scans (or types) the branch code and is checked into the right session of today. */
export class CheckinService {
  constructor(
    private readonly repo: CheckinRepository,
    private readonly codes: CheckinCodePort,
    private readonly sessions: CheckinSessionService,
    private readonly audit: AuditService,
  ) {}

  async checkIn(memberId: string, input: CheckinInput): Promise<CheckinOutcome> {
    try {
      return await this.run(memberId, input);
    } catch (err) {
      // The request transaction rolls back on a refusal, so rejected attempts are kept in the log, not the database.
      if (err instanceof AppError) logger.warn({ memberId, code: err.code }, 'check-in refused');
      throw err;
    }
  }

  private async run(memberId: string, input: CheckinInput): Promise<CheckinOutcome> {
    const today = await this.sessions.listToday(memberId, 'SELF');
    const branchId = await this.resolveBranch(input, today.sessions);
    const picked = this.pick(today, branchId, input.sessionId);
    if (picked.status === 'CHOOSE_SESSION') return picked;

    const session = picked.session;
    if (session.checkin.state === 'CHECKED_IN') return this.already(memberId, session, null);
    if (!session.checkin.canCheckin) throw errorForVerdict(session.checkin);
    return this.record({ memberId, session, by: null, evidenceUrl: null });
  }

  /**
   * Writes the check-in: attendance row waiting for the coach, one session off the ACTIVE package
   * (given back if the coach marks the member absent), activity timestamp, audit entry.
   * The caller has already decided the session is open; front-desk check-in (CHK-04) reuses this.
   */
  async record(input: { memberId: string; session: CheckinSessionView; by: string | null; evidenceUrl: string | null }): Promise<CheckedIn> {
    const { memberId, session, by, evidenceUrl } = input;
    const now = clock.now();
    const write = { at: now, checkedInBy: by, evidenceUrl };

    const existing = await this.repo.lockAttendance(session.sessionId, memberId);
    if (existing && isCheckedIn(existing.attendanceStatus)) return this.already(memberId, session, existing);
    let attendanceId: string;
    if (existing) {
      await this.repo.markCheckedIn(existing.id, write);
      attendanceId = existing.id;
    } else {
      const inserted = await this.repo.insertCheckin(session.sessionId, memberId, write);
      if (!inserted) {
        // Another request of the same member got there between our read and write.
        return this.already(memberId, session, await this.repo.lockAttendance(session.sessionId, memberId));
      }
      attendanceId = inserted;
    }

    const charged = await this.repo.charge(memberId, localDate(now));
    if (!charged) throw membershipInvalidError(); // rolls the attendance back with it
    await this.repo.setAttendanceMembership(attendanceId, charged.id);
    await this.repo.touchActivity(memberId, now);
    await this.audit.record({
      actorId: by ?? memberId,
      action: by ? 'CHECKIN_ASSISTED' : 'CHECKIN',
      entityType: 'ATTENDANCE',
      entityId: attendanceId,
      after: { sessionId: session.sessionId, branchId: session.branch.id, membershipId: charged.id, evidence: Boolean(evidenceUrl) },
    });
    return {
      status: 'CHECKED_IN',
      alreadyCheckedIn: false,
      checkedInAt: now,
      session: summaryOf(session),
      sessionsRemaining: charged.totalSessions === null ? null : Math.max(0, charged.totalSessions - charged.usedSessions),
      message: SUCCESS,
    };
  }

  /** The branch the member is at: from the scanned QR, or from the typed code tried against today's branches. */
  private async resolveBranch(input: CheckinInput, sessions: readonly CheckinSessionView[]): Promise<string> {
    if (input.payload) return (await this.codes.verifyPayload(input.payload)).branchId;

    const wanted = input.sessionId ? sessions.find((s) => s.sessionId === input.sessionId) : undefined;
    if (input.sessionId && !wanted) throw sessionNotEligibleError();
    const branchIds = wanted ? [wanted.branch.id] : [...new Set(sessions.map((s) => s.branch.id))];
    if (branchIds.length === 0) throw noSessionTodayError();
    // A typed code carries no branch: it must match one of the branches the member has a session at today.
    for (const id of branchIds.slice(0, -1)) {
      try {
        await this.codes.verifyShortCode(id, input.shortCode as string);
        return id;
      } catch (err) {
        if (!(err instanceof AppError && err.code === 'CHECKIN_CODE_INVALID')) throw err;
      }
    }
    const last = branchIds[branchIds.length - 1];
    await this.codes.verifyShortCode(last, input.shortCode as string);
    return last;
  }

  /** The session to check into at `branchId`, or the list to choose from when several are open. */
  private pick(today: TodayCheckin, branchId: string, sessionId?: string): { status: 'ONE'; session: CheckinSessionView } | ChooseSession {
    const all = today.sessions;
    if (sessionId) {
      const session = all.find((s) => s.sessionId === sessionId);
      if (!session) throw sessionNotEligibleError();
      if (session.branch.id !== branchId) throw wrongBranchError([session.branch]);
      return { status: 'ONE', session };
    }

    const here = all.filter((s) => s.branch.id === branchId);
    const open = here.filter((s) => s.checkin.canCheckin);
    if (open.length === 1) return { status: 'ONE', session: open[0] };
    if (open.length > 1) return { status: 'CHOOSE_SESSION', sessions: open };

    if (here.length === 0) {
      if (all.length === 0) throw noSessionTodayError();
      throw wrongBranchError([...new Map(all.map((s) => [s.branch.id, s.branch])).values()]);
    }
    // Nothing open here: report the one already done, otherwise explain why the nearest session is refused.
    const done = here.find((s) => s.checkin.state === 'CHECKED_IN');
    if (done) return { status: 'ONE', session: done };
    const now = clock.now().getTime();
    const nearest = [...here].sort((a, b) => Math.abs(a.startsAt.getTime() - now) - Math.abs(b.startsAt.getTime() - now))[0];
    return { status: 'ONE', session: nearest };
  }

  private async already(memberId: string, session: CheckinSessionView, row: AttendanceRow | null): Promise<CheckedIn> {
    const checkedInAt = row?.checkinAt ?? session.checkin.checkedInAt ?? clock.now();
    return {
      status: 'CHECKED_IN',
      alreadyCheckedIn: true,
      checkedInAt,
      session: summaryOf(session),
      sessionsRemaining: await this.remaining(memberId),
      message: ALREADY,
    };
  }

  private async remaining(memberId: string): Promise<number | null> {
    const gate = await this.repo.memberGate(memberId);
    if (!gate || !gate.hasActiveMembership || gate.totalSessions === null) return null;
    return Math.max(0, gate.totalSessions - (gate.usedSessions ?? 0));
  }
}

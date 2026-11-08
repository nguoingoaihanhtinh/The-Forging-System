import { notFound } from '../../common/errors/app-error';
import { clock } from '../../common/utils/clock';
import { addDays, localDate, startOfLocalDay } from '../../common/utils/time';
import { env } from '../../config/env';
import type { SettingsService } from '../settings/settings.service';
import type { CheckinRepository, MemberGateRow, TodaySessionRow } from './checkin.repository';
import { evaluateMemberGate, evaluateSessions } from './checkin.rules';
import type { CheckinMode, MemberGate, SessionVerdict } from './checkin.rules';

export interface CheckinSessionView {
  sessionId: string;
  classId: string | null;
  title: string | null;
  sessionType: string;
  isExam: boolean;
  startsAt: Date;
  endsAt: Date;
  branch: { id: string; name: string };
  coach: { id: string; fullName: string };
  checkin: {
    state: SessionVerdict['state'];
    canCheckin: boolean;
    reason: SessionVerdict['reason'];
    message: string | null;
    opensAt: Date;
    closesAt: Date;
    checkedInAt: Date | null;
  };
}

export interface TodayCheckin {
  /** Local date the list is for. */
  date: string;
  /** Whether the member may check in at all (account status and package), whichever session. */
  eligibility: Pick<MemberGate, 'code' | 'message'> & { canCheckin: boolean };
  sessions: CheckinSessionView[];
}

const gateOf = (row: MemberGateRow, today: string): MemberGate =>
  evaluateMemberGate({
    status: row.status,
    membership: row.hasActiveMembership
      ? { totalSessions: row.totalSessions, usedSessions: row.usedSessions ?? 0, endDate: row.endDate }
      : null,
    today,
  });

/** CHK-02: the sessions of today a member can check into, with the reason when one cannot be. */
export class CheckinSessionService {
  constructor(
    private readonly repo: CheckinRepository,
    private readonly settings: SettingsService,
  ) {}

  /**
   * `branchId` limits the list to one branch (a receptionist only checks members in at their own branch);
   * clashes between sessions are still judged across all branches.
   */
  async listToday(memberId: string, mode: CheckinMode, options: { branchId?: string | null } = {}): Promise<TodayCheckin> {
    const now = clock.now();
    const today = localDate(now);
    const gateRow = await this.repo.memberGate(memberId);
    if (!gateRow) throw notFound('Học viên');

    const rows = await this.repo.todaySessions(memberId, startOfLocalDay(today), startOfLocalDay(addDays(today, 1)), env.APP_TIMEZONE);
    const gate = gateOf(gateRow, today);
    const verdicts = evaluateSessions(
      rows.map((r) => ({ id: r.sessionId, startsAt: r.startsAt, endsAt: r.endsAt, opensAt: r.opensAt, closesAt: r.closesAt, attendanceStatus: r.attendanceStatus })),
      gate,
      {
        opensBeforeMinutes: await this.settings.getNumber('checkin.opens_before_minutes'),
        closesAfterMinutes: await this.settings.getNumber('checkin.closes_after_minutes'),
      },
      mode,
      now,
    );
    const byId = new Map(verdicts.map((v) => [v.sessionId, v]));
    const view = (r: TodaySessionRow): CheckinSessionView => {
      const v = byId.get(r.sessionId)!;
      return {
        sessionId: r.sessionId,
        classId: r.classId,
        title: r.title,
        sessionType: r.sessionType,
        isExam: r.isExam,
        startsAt: r.startsAt,
        endsAt: r.endsAt,
        branch: { id: r.branchId, name: r.branchName },
        coach: { id: r.coachId, fullName: r.coachName },
        checkin: {
          state: v.state,
          canCheckin: v.canCheckin,
          reason: v.reason,
          message: v.message,
          opensAt: v.opensAt,
          closesAt: v.closesAt,
          checkedInAt: r.checkinAt,
        },
      };
    };
    return {
      date: today,
      eligibility: { canCheckin: gate.ok, code: gate.code, message: gate.message },
      sessions: rows.filter((r) => !options.branchId || r.branchId === options.branchId).map(view),
    };
  }
}

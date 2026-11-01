import { isValid, usageOf } from '../memberships/membership.rules';

/**
 * Pure check-in rules (no I/O): which of a member's sessions today can be checked into, and why not.
 * Shared by the "today's sessions" lists (CHK-02) and the check-in itself (CHK-03, CHK-04).
 */

/** SELF = the member scans the branch code; ASSISTED = front-desk staff checks in on the member's behalf. */
export type CheckinMode = 'SELF' | 'ASSISTED';

export type CheckinState =
  | 'OPEN'
  | 'NOT_YET_OPEN'
  | 'CLOSED'
  | 'CHECKED_IN'
  | 'OVERLAPS_CHECKED_IN'
  | 'BLOCKED';

export type CheckinReason =
  | 'ALREADY_CHECKED_IN'
  | 'ACCOUNT_INACTIVE'
  | 'ACCOUNT_RESTRICTED'
  | 'MEMBERSHIP_INVALID'
  | 'OVERLAPS_CHECKED_IN'
  | 'NOT_YET_OPEN'
  | 'CHECKIN_CLOSED';

export interface CheckinWindowSettings {
  opensBeforeMinutes: number;
  closesAfterMinutes: number;
}

/** Whether the member may check in at all, whatever the session. */
export interface MemberGate {
  ok: boolean;
  code: Extract<CheckinReason, 'ACCOUNT_INACTIVE' | 'ACCOUNT_RESTRICTED' | 'MEMBERSHIP_INVALID'> | null;
  message: string | null;
}

export const MESSAGES = {
  ACCOUNT_INACTIVE: 'Tài khoản không hoạt động. Toàn bộ DP, hạng và HVP Marks vẫn được lưu — liên hệ lễ tân để kích hoạt lại gói tập.',
  ACCOUNT_RESTRICTED: 'Tài khoản đang đóng băng (chế độ chỉ xem). Gia hạn hoặc liên hệ lễ tân để mở lại check-in.',
  MEMBERSHIP_INVALID: 'Gói tập của bạn đã hết hạn hoặc hết số buổi. Vui lòng gia hạn để tiếp tục.',
  ALREADY_CHECKED_IN: 'Bạn đã check-in buổi này.',
  OVERLAPS_CHECKED_IN: 'Bạn đã check-in một buổi khác cùng khung giờ.',
  NOT_YET_OPEN: 'Chưa đến giờ check-in của buổi này.',
  CHECKIN_CLOSED_SELF: 'Đã hết giờ check-in. Vui lòng nhờ lễ tân check-in hộ.',
  CHECKIN_CLOSED_ASSISTED: 'Buổi tập đã kết thúc, không thể check-in.',
} as const;

/** Account status first (inactive beats frozen), then the package: it must have days and sessions left. */
export function evaluateMemberGate(input: {
  status: string;
  membership: { totalSessions: number | null; usedSessions: number; endDate: string | null } | null;
  /** Today as YYYY-MM-DD in the academy's timezone. */
  today: string;
}): MemberGate {
  if (input.status === 'INACTIVE') return { ok: false, code: 'ACCOUNT_INACTIVE', message: MESSAGES.ACCOUNT_INACTIVE };
  if (input.status === 'FROZEN') return { ok: false, code: 'ACCOUNT_RESTRICTED', message: MESSAGES.ACCOUNT_RESTRICTED };
  if (!input.membership || !isValid(usageOf(input.membership, input.today))) {
    return { ok: false, code: 'MEMBERSHIP_INVALID', message: MESSAGES.MEMBERSHIP_INVALID };
  }
  return { ok: true, code: null, message: null };
}

export interface SessionInput {
  id: string;
  startsAt: Date;
  endsAt: Date;
  /** Per-session overrides; null = use the academy defaults. */
  opensAt: Date | null;
  closesAt: Date | null;
  attendanceStatus: string | null;
}

/**
 * When check-in is open for a session. Self check-in follows the session's own window or the
 * defaults (opens before the start, closes after it); front-desk staff may still check a member
 * in until the session ends, as the way out for latecomers.
 */
export function checkinWindow(
  session: Pick<SessionInput, 'startsAt' | 'endsAt' | 'opensAt' | 'closesAt'>,
  settings: CheckinWindowSettings,
  mode: CheckinMode,
): { opensAt: Date; closesAt: Date } {
  const opensAt = session.opensAt ?? new Date(session.startsAt.getTime() - settings.opensBeforeMinutes * 60_000);
  const selfClosesAt = session.closesAt ?? new Date(session.startsAt.getTime() + settings.closesAfterMinutes * 60_000);
  const closesAt = mode === 'ASSISTED' && session.endsAt > selfClosesAt ? session.endsAt : selfClosesAt;
  return { opensAt, closesAt };
}

/** A check-in is on record once the member is waiting for the coach or has been judged. */
export const isCheckedIn = (attendanceStatus: string | null): boolean =>
  attendanceStatus === 'AWAITING_COACH' || attendanceStatus === 'CONFIRMED_PASS' || attendanceStatus === 'CONFIRMED_FAIL';

const overlaps = (a: Pick<SessionInput, 'startsAt' | 'endsAt'>, b: Pick<SessionInput, 'startsAt' | 'endsAt'>) =>
  a.startsAt < b.endsAt && b.startsAt < a.endsAt;

export interface SessionVerdict {
  sessionId: string;
  state: CheckinState;
  canCheckin: boolean;
  reason: CheckinReason | null;
  message: string | null;
  opensAt: Date;
  closesAt: Date;
}

/**
 * Verdict per session. Precedence: already checked in, then the member-level gate, then a clash
 * with a session already checked into, then the time window.
 */
export function evaluateSessions(
  sessions: readonly SessionInput[],
  gate: MemberGate,
  settings: CheckinWindowSettings,
  mode: CheckinMode,
  now: Date,
): SessionVerdict[] {
  const checkedIn = sessions.filter((s) => isCheckedIn(s.attendanceStatus));
  return sessions.map((s): SessionVerdict => {
    const { opensAt, closesAt } = checkinWindow(s, settings, mode);
    const verdict = (state: CheckinState, reason: CheckinReason | null, message: string | null): SessionVerdict => ({
      sessionId: s.id,
      state,
      canCheckin: state === 'OPEN',
      reason,
      message,
      opensAt,
      closesAt,
    });

    if (isCheckedIn(s.attendanceStatus)) return verdict('CHECKED_IN', 'ALREADY_CHECKED_IN', MESSAGES.ALREADY_CHECKED_IN);
    if (!gate.ok) return verdict('BLOCKED', gate.code, gate.message);
    if (checkedIn.some((other) => other.id !== s.id && overlaps(s, other))) {
      return verdict('OVERLAPS_CHECKED_IN', 'OVERLAPS_CHECKED_IN', MESSAGES.OVERLAPS_CHECKED_IN);
    }
    if (now < opensAt) return verdict('NOT_YET_OPEN', 'NOT_YET_OPEN', MESSAGES.NOT_YET_OPEN);
    if (now > closesAt) {
      return verdict('CLOSED', 'CHECKIN_CLOSED', mode === 'ASSISTED' ? MESSAGES.CHECKIN_CLOSED_ASSISTED : MESSAGES.CHECKIN_CLOSED_SELF);
    }
    return verdict('OPEN', null, null);
  });
}

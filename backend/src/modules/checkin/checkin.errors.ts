import { AppError, unprocessable } from '../../common/errors/app-error';
import { MESSAGES } from './checkin.rules';
import type { CheckinReason, SessionVerdict } from './checkin.rules';

/**
 * Business errors of the check-in flow: HTTP 422 with a stable `code` the app switches on.
 * Codes of a refused session are the `CheckinReason` values; the rest are below.
 * (Invalid / expired codes come from CheckinCodeService: CHECKIN_CODE_INVALID, CHECKIN_CODE_EXPIRED.)
 */
export const CheckinErrorCode = {
  NO_SESSION_TODAY: 'NO_SESSION_TODAY',
  WRONG_BRANCH: 'CHECKIN_WRONG_BRANCH',
  SESSION_NOT_ELIGIBLE: 'CHECKIN_SESSION_NOT_ELIGIBLE',
} as const;

const FALLBACK: Record<CheckinReason, string> = {
  ALREADY_CHECKED_IN: MESSAGES.ALREADY_CHECKED_IN,
  ACCOUNT_INACTIVE: MESSAGES.ACCOUNT_INACTIVE,
  ACCOUNT_RESTRICTED: MESSAGES.ACCOUNT_RESTRICTED,
  MEMBERSHIP_INVALID: MESSAGES.MEMBERSHIP_INVALID,
  OVERLAPS_CHECKED_IN: MESSAGES.OVERLAPS_CHECKED_IN,
  NOT_YET_OPEN: MESSAGES.NOT_YET_OPEN,
  CHECKIN_CLOSED: MESSAGES.CHECKIN_CLOSED_SELF,
};

/** The error for a session whose verdict says it cannot be checked into. */
export function errorForVerdict(verdict: Pick<SessionVerdict, 'reason' | 'message' | 'opensAt' | 'closesAt'>): AppError {
  const reason = verdict.reason ?? 'CHECKIN_CLOSED';
  const details =
    reason === 'NOT_YET_OPEN' ? { opensAt: verdict.opensAt } : reason === 'CHECKIN_CLOSED' ? { closesAt: verdict.closesAt } : undefined;
  return unprocessable(verdict.message ?? FALLBACK[reason], reason, details);
}

export const membershipInvalidError = (): AppError => unprocessable(MESSAGES.MEMBERSHIP_INVALID, 'MEMBERSHIP_INVALID');

export const noSessionTodayError = (): AppError =>
  unprocessable('Hôm nay bạn không có buổi tập nào để check-in.', CheckinErrorCode.NO_SESSION_TODAY);

/** The code is real but the member's session(s) happen in other branch(es). */
export function wrongBranchError(branches: ReadonlyArray<{ id: string; name: string }>): AppError {
  const names = branches.map((b) => b.name).join(', ');
  return unprocessable(`Buổi tập của bạn diễn ra tại ${names}. Vui lòng quét mã tại chi nhánh đó.`, CheckinErrorCode.WRONG_BRANCH, {
    branches,
  });
}

/** A session id that is not among the member's sessions of today (also hides other members' sessions). */
export const sessionNotEligibleError = (): AppError =>
  new AppError(404, CheckinErrorCode.SESSION_NOT_ELIGIBLE, 'Không tìm thấy buổi tập này trong các buổi hôm nay của bạn.');

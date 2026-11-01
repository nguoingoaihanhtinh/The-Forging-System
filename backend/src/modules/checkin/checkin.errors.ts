import { AppError } from '../../common/errors/app-error';
import { MESSAGES } from './checkin.rules';
import type { SessionVerdict } from './checkin.rules';

/**
 * What the app should offer next when a check-in is refused, so it does not have to guess from the code:
 *  RESCAN        scan the code on the front-desk screen again
 *  WAIT          come back later (the window opens at `details.opensAt`)
 *  ASK_FRONT_DESK  ask the front desk for help (they can check the member in)
 *  RENEW_PACKAGE   the package needs renewing
 *  GO_TO_BRANCH    the session is at another branch (`details.branches`)
 *  ATTACH_PHOTO    front desk must attach a photo of the member
 *  NONE            nothing to do; just show the message
 */
export type CheckinAction = 'RESCAN' | 'WAIT' | 'ASK_FRONT_DESK' | 'RENEW_PACKAGE' | 'GO_TO_BRANCH' | 'ATTACH_PHOTO' | 'NONE';

interface ErrorDef {
  status: 400 | 403 | 404 | 422;
  message: string;
  action: CheckinAction;
}

/**
 * Every business error of the check-in feature, in one place. The response is
 * `{ error: { code, message, details: { action, ...extra } } }`; the app switches on `code`.
 * Keep docs/api/checkin.md in step (a test fails when a code is missing there).
 */
export const CHECKIN_ERRORS = {
  // the code that was scanned or typed
  CHECKIN_CODE_INVALID: { status: 400, message: 'Mã QR không hợp lệ. Vui lòng quét mã trên màn hình phòng tập.', action: 'RESCAN' },
  CHECKIN_CODE_EXPIRED: { status: 422, message: 'Mã QR đã hết hạn, vui lòng quét lại mã mới trên màn hình phòng tập.', action: 'RESCAN' },
  // which session
  NO_SESSION_TODAY: { status: 422, message: 'Hôm nay bạn không có buổi tập nào để check-in.', action: 'NONE' },
  CHECKIN_WRONG_BRANCH: { status: 422, message: 'Buổi tập của bạn diễn ra ở chi nhánh khác. Vui lòng quét mã tại chi nhánh đó.', action: 'GO_TO_BRANCH' },
  CHECKIN_SESSION_NOT_ELIGIBLE: { status: 404, message: 'Không tìm thấy buổi tập này trong các buổi hôm nay của bạn.', action: 'NONE' },
  OVERLAPS_CHECKED_IN: { status: 422, message: MESSAGES.OVERLAPS_CHECKED_IN, action: 'NONE' },
  // time window
  NOT_YET_OPEN: { status: 422, message: MESSAGES.NOT_YET_OPEN, action: 'WAIT' },
  CHECKIN_CLOSED: { status: 422, message: MESSAGES.CHECKIN_CLOSED_SELF, action: 'ASK_FRONT_DESK' },
  // the member
  ACCOUNT_INACTIVE: { status: 422, message: MESSAGES.ACCOUNT_INACTIVE, action: 'ASK_FRONT_DESK' },
  ACCOUNT_RESTRICTED: { status: 422, message: MESSAGES.ACCOUNT_RESTRICTED, action: 'ASK_FRONT_DESK' },
  MEMBERSHIP_INVALID: { status: 422, message: MESSAGES.MEMBERSHIP_INVALID, action: 'RENEW_PACKAGE' },
  // front desk
  CHECKIN_EVIDENCE_REQUIRED: { status: 400, message: 'Vui lòng chụp ảnh minh chứng khi check-in hộ.', action: 'ATTACH_PHOTO' },
  INVALID_CHECKIN_EVIDENCE: { status: 400, message: 'Ảnh minh chứng không hợp lệ.', action: 'ATTACH_PHOTO' },
  CHECKIN_BRANCH_FORBIDDEN: { status: 403, message: 'Bạn chỉ thao tác được với chi nhánh của mình.', action: 'NONE' },
  BRANCH_INACTIVE: { status: 422, message: 'Chi nhánh đang ngừng hoạt động.', action: 'NONE' },
} as const satisfies Record<string, ErrorDef>;

export type CheckinErrorCode = keyof typeof CHECKIN_ERRORS;

export const CHECKIN_ERROR_CODES = Object.keys(CHECKIN_ERRORS) as CheckinErrorCode[];

/** Builds the error for `code`; `message` replaces the default text and `details` adds to `{ action }`. */
export function checkinError(code: CheckinErrorCode, extra: { message?: string; details?: Record<string, unknown> } = {}): AppError {
  const def: ErrorDef = CHECKIN_ERRORS[code];
  return new AppError(def.status, code, extra.message ?? def.message, { action: def.action, ...extra.details });
}

/**
 * The error for a session whose verdict says it cannot be checked into. A repeat check-in (ALREADY_CHECKED_IN)
 * is never an error - callers answer it before getting here - so it falls back like a missing reason.
 */
export function errorForVerdict(verdict: Pick<SessionVerdict, 'reason' | 'message' | 'opensAt' | 'closesAt'>): AppError {
  const reason = verdict.reason && verdict.reason !== 'ALREADY_CHECKED_IN' ? verdict.reason : 'CHECKIN_CLOSED';
  const details = reason === 'NOT_YET_OPEN' ? { opensAt: verdict.opensAt } : reason === 'CHECKIN_CLOSED' ? { closesAt: verdict.closesAt } : undefined;
  return checkinError(reason, { message: verdict.message ?? undefined, details });
}

export const membershipInvalidError = (): AppError => checkinError('MEMBERSHIP_INVALID');

export const noSessionTodayError = (): AppError => checkinError('NO_SESSION_TODAY');

/** The code is real but the member's session(s) happen at other branch(es). */
export function wrongBranchError(branches: ReadonlyArray<{ id: string; name: string }>): AppError {
  const names = branches.map((b) => b.name).join(', ');
  return checkinError('CHECKIN_WRONG_BRANCH', {
    message: `Buổi tập của bạn diễn ra tại ${names}. Vui lòng quét mã tại chi nhánh đó.`,
    details: { branches },
  });
}

/** A session id that is not among the member's sessions of today (also hides other members' sessions). */
export const sessionNotEligibleError = (): AppError => checkinError('CHECKIN_SESSION_NOT_ELIGIBLE');

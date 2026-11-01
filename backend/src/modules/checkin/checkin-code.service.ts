import { randomBytes } from 'node:crypto';
import { notFound } from '../../common/errors/app-error';
import { clock } from '../../common/utils/clock';
import { RoleGroup } from '../../shared/roles';
import type { SettingsService } from '../settings/settings.service';
import { buildPayload, checkPayload, checkShortCode, parsePayload, shortCodeOf, windowEndsAt, windowOf } from './checkin-code';
import type { BranchCodeKey } from './checkin-code';
import { checkinError } from './checkin.errors';
import type { CheckinRepository, CodeBranch } from './checkin.repository';

/** What the front-desk screen needs to draw the current code. */
export interface CurrentCode {
  branchId: string;
  branchCode: string;
  qrVersion: string;
  /** Text to encode into the QR. */
  payload: string;
  /** 6 digits for members who cannot scan. */
  shortCode: string;
  ttlSeconds: number;
  /** When this code stops being displayed; the screen asks for the next one then. */
  expiresAt: string;
  /** Server time, so the screen counts down against the server clock, not the tablet's. */
  serverTime: string;
}

export interface VerifiedCode {
  branchId: string;
  branchCode: string;
}

/** Port other modules (the check-in itself, CHK-03) use to validate what a member scanned or typed. */
export interface CheckinCodePort {
  verifyPayload(text: string): Promise<VerifiedCode>;
  verifyShortCode(branchId: string, code: string): Promise<void>;
}

export interface CodeViewer {
  roles: readonly string[];
  /** Branch of the signed-in staff member. */
  branchId: string | null;
}

const isAdmin = (roles: readonly string[]) => roles.some((r) => (RoleGroup.ADMINS as readonly string[]).includes(r));

export class CheckinCodeService implements CheckinCodePort {
  constructor(
    private readonly repo: CheckinRepository,
    private readonly settings: SettingsService,
  ) {}

  /** The code to show right now. Front-desk staff only get their own branch's code; admins any. */
  async current(branchId: string, viewer: CodeViewer): Promise<CurrentCode> {
    const branch = await this.repo.findBranch(branchId);
    if (!branch) throw notFound('Chi nhánh');
    if (!isAdmin(viewer.roles) && viewer.branchId !== branch.id) {
      throw checkinError('CHECKIN_BRANCH_FORBIDDEN', { message: 'Bạn chỉ lấy được mã check-in của chi nhánh mình.' });
    }
    if (!branch.isActive) throw checkinError('BRANCH_INACTIVE');

    const key = await this.keyOf(branch, true);
    const ttlSeconds = await this.ttl();
    const now = clock.now();
    const window = windowOf(now.getTime(), ttlSeconds);
    return {
      branchId: branch.id,
      branchCode: branch.code,
      qrVersion: key.qrVersion,
      payload: buildPayload(key, window),
      shortCode: shortCodeOf(key, window),
      ttlSeconds,
      expiresAt: new Date(windowEndsAt(window, ttlSeconds)).toISOString(),
      serverTime: now.toISOString(),
    };
  }

  /** Validates a scanned QR text; resolves the branch it belongs to or throws a stable error code. */
  async verifyPayload(text: string): Promise<VerifiedCode> {
    const parsed = parsePayload(text);
    if (!parsed) throw checkinError('CHECKIN_CODE_INVALID');
    const branch = await this.repo.findBranchByCode(parsed.branchCode);
    // A branch that never issued a code has no secret: nothing it printed can be valid.
    if (!branch || !branch.isActive || !branch.checkinSecret) throw checkinError('CHECKIN_CODE_INVALID');
    const result = checkPayload(await this.keyOf(branch, false), parsed, await this.ttl(), clock.now().getTime());
    if (result === 'INVALID') throw checkinError('CHECKIN_CODE_INVALID');
    if (result === 'EXPIRED') throw checkinError('CHECKIN_CODE_EXPIRED');
    return { branchId: branch.id, branchCode: branch.code };
  }

  /** Validates the 6 digits typed for a given branch (manual entry). */
  async verifyShortCode(branchId: string, code: string): Promise<void> {
    const branch = await this.repo.findBranch(branchId);
    if (!branch || !branch.isActive || !branch.checkinSecret) throw checkinError('CHECKIN_CODE_INVALID');
    if (!checkShortCode(await this.keyOf(branch, false), code, await this.ttl(), clock.now().getTime())) {
      throw checkinError('CHECKIN_CODE_INVALID');
    }
  }

  private async keyOf(branch: CodeBranch, create: boolean): Promise<BranchCodeKey> {
    let secret = branch.checkinSecret;
    if (!secret && create) secret = await this.repo.ensureSecret(branch.id, randomBytes(32).toString('hex'));
    return { branchId: branch.id, branchCode: branch.code, qrVersion: branch.qrVersion ?? '1', secret: secret as string };
  }

  private ttl(): Promise<number> {
    return this.settings.getNumber('checkin.code_ttl_seconds');
  }
}

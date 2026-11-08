import { readFileSync } from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { AppError } from '../../src/common/errors/app-error';
import { CHECKIN_ERROR_CODES, CHECKIN_ERRORS, checkinError, errorForVerdict, wrongBranchError } from '../../src/modules/checkin/checkin.errors';
import type { CheckinReason } from '../../src/modules/checkin/checkin.rules';

const DOC = readFileSync(path.resolve(__dirname, '../../../docs/api/checkin.md'), 'utf8');
const opensAt = new Date('2026-11-02T10:15:00Z');
const closesAt = new Date('2026-11-02T11:30:00Z');

describe('check-in error catalogue (CHK-05)', () => {
  it('defines each error once, with a Vietnamese message, an allowed status and an action', () => {
    expect(new Set(CHECKIN_ERROR_CODES).size).toBe(CHECKIN_ERROR_CODES.length);
    for (const code of CHECKIN_ERROR_CODES) {
      const def = CHECKIN_ERRORS[code];
      expect([400, 403, 404, 422]).toContain(def.status);
      expect(def.message.length).toBeGreaterThan(10);
      expect(code).toMatch(/^[A-Z_]+$/);
    }
  });

  it('builds an AppError carrying the status, code, message and the action for the app', () => {
    const err = checkinError('MEMBERSHIP_INVALID');
    expect(err).toBeInstanceOf(AppError);
    expect([err.status, err.code, err.details]).toEqual([422, 'MEMBERSHIP_INVALID', { action: 'RENEW_PACKAGE' }]);
    expect(err.message).toContain('gia hạn');
  });

  it('lets a caller refine the message and add details without losing the action', () => {
    const err = checkinError('NOT_YET_OPEN', { message: 'Mở lúc 17:15', details: { opensAt } });
    expect([err.message, err.details]).toEqual(['Mở lúc 17:15', { action: 'WAIT', opensAt }]);
  });

  it('turns every refusal reason of a session into a catalogued error', () => {
    const refusals: Array<Exclude<CheckinReason, 'ALREADY_CHECKED_IN'>> = [
      'ACCOUNT_INACTIVE',
      'ACCOUNT_RESTRICTED',
      'MEMBERSHIP_INVALID',
      'OVERLAPS_CHECKED_IN',
      'NOT_YET_OPEN',
      'CHECKIN_CLOSED',
    ];
    for (const reason of refusals) {
      const err = errorForVerdict({ reason, message: null, opensAt, closesAt });
      expect(err.code).toBe(reason);
      expect(CHECKIN_ERROR_CODES).toContain(err.code);
    }
  });

  it('adds the time the app needs: when it opens, when it closed', () => {
    expect(errorForVerdict({ reason: 'NOT_YET_OPEN', message: null, opensAt, closesAt }).details).toEqual({ action: 'WAIT', opensAt });
    expect(errorForVerdict({ reason: 'CHECKIN_CLOSED', message: 'hết giờ', closesAt, opensAt }).details).toEqual({ action: 'ASK_FRONT_DESK', closesAt });
    expect(errorForVerdict({ reason: 'CHECKIN_CLOSED', message: 'hết giờ', closesAt, opensAt }).message).toBe('hết giờ');
  });

  it('never reports a repeat check-in as an error', () => {
    // ALREADY_CHECKED_IN is answered with a normal result before an error is built; if it ever got here it is not its own code.
    expect(errorForVerdict({ reason: 'ALREADY_CHECKED_IN', message: null, opensAt, closesAt }).code).toBe('CHECKIN_CLOSED');
    expect(CHECKIN_ERROR_CODES).not.toContain('ALREADY_CHECKED_IN');
  });

  it('names the branches to go to', () => {
    const err = wrongBranchError([{ id: 'b7', name: 'HVP Boxing - Riverside' }]);
    expect([err.status, err.code]).toEqual([422, 'CHECKIN_WRONG_BRANCH']);
    expect(err.message).toContain('Riverside');
    expect(err.details).toEqual({ action: 'GO_TO_BRANCH', branches: [{ id: 'b7', name: 'HVP Boxing - Riverside' }] });
  });

  it('is documented for the app: every code appears in docs/api/checkin.md with its status and action', () => {
    for (const code of CHECKIN_ERROR_CODES) {
      const row = DOC.split('\n').find((line) => line.startsWith(`| \`${code}\``));
      expect(row, `${code} is missing from the error table of docs/api/checkin.md`).toBeDefined();
      expect(row).toContain(`| ${CHECKIN_ERRORS[code].status} |`);
      expect(row).toContain(`\`${CHECKIN_ERRORS[code].action}\``);
    }
  });
});

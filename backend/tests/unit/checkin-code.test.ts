import { describe, expect, it } from 'vitest';
import {
  buildPayload,
  checkPayload,
  checkShortCode,
  parsePayload,
  shortCodeOf,
  windowEndsAt,
  windowOf,
} from '../../src/modules/checkin/checkin-code';
import type { BranchCodeKey, ParsedPayload } from '../../src/modules/checkin/checkin-code';

const TTL = 30;
const key: BranchCodeKey = { branchId: 'b-1', branchCode: 'Q1', qrVersion: '1', secret: 'secret-one' };
const T0 = Date.UTC(2026, 10, 2, 9, 0, 0); // window start aligned to 30s
const parsed = (k: BranchCodeKey, window: number): ParsedPayload => parsePayload(buildPayload(k, window))!;

describe('rotating check-in code (CHK-01)', () => {
  it('slices time into ttl-long windows', () => {
    const w = windowOf(T0, TTL);
    expect(windowOf(T0 + 29_999, TTL)).toBe(w);
    expect(windowOf(T0 + 30_000, TTL)).toBe(w + 1);
    expect(windowEndsAt(w, TTL)).toBe(T0 + 30_000);
  });

  it('round-trips a payload and accepts it inside its window', () => {
    const w = windowOf(T0, TTL);
    const payload = buildPayload(key, w);
    expect(payload.startsWith('HVP|Q1|1|')).toBe(true);
    expect(checkPayload(key, parsePayload(payload)!, TTL, T0 + 5_000)).toBe('OK');
  });

  it('still accepts the code during the next window (network delay) but not after', () => {
    const w = windowOf(T0, TTL);
    const p = parsed(key, w);
    expect(checkPayload(key, p, TTL, T0 + 35_000)).toBe('OK'); // one window later
    expect(checkPayload(key, p, TTL, T0 + 65_000)).toBe('EXPIRED'); // two windows later
  });

  it('rejects a code from the future', () => {
    const p = parsed(key, windowOf(T0, TTL) + 5);
    expect(checkPayload(key, p, TTL, T0)).toBe('INVALID');
  });

  it('rejects tampered, foreign or rotated codes', () => {
    const w = windowOf(T0, TTL);
    const p = parsed(key, w);
    expect(checkPayload(key, { ...p, signature: '0'.repeat(16) }, TTL, T0)).toBe('INVALID');
    expect(checkPayload(key, { ...p, window: w + 1 }, TTL, T0)).toBe('INVALID'); // window changed, signature no longer fits
    expect(checkPayload({ ...key, secret: 'other-secret' }, p, TTL, T0)).toBe('INVALID');
    expect(checkPayload({ ...key, branchId: 'b-2' }, p, TTL, T0)).toBe('INVALID');
    // The branch QR was rotated (version bumped): everything issued before is dead.
    expect(checkPayload({ ...key, qrVersion: '2' }, p, TTL, T0)).toBe('INVALID');
  });

  it('only parses well-formed payloads', () => {
    expect(parsePayload('HVP|Q1|1|123|' + 'a'.repeat(16))).toEqual({ branchCode: 'Q1', qrVersion: '1', window: 123, signature: 'a'.repeat(16) });
    for (const bad of ['', 'HVP|Q1|1', 'XYZ|Q1|1|123|' + 'a'.repeat(16), 'HVP|Q1|1|abc|' + 'a'.repeat(16), 'HVP|Q1|1|123|short', 'HVP|Q1|1|123|' + 'G'.repeat(16)]) {
      expect(parsePayload(bad)).toBeNull();
    }
    // The old static payload printed by BR-03 is not a valid rotating code.
    expect(parsePayload('HVP|Q1|1')).toBeNull();
  });

  it('derives a stable 6-digit code per branch and window', () => {
    const w = windowOf(T0, TTL);
    const code = shortCodeOf(key, w);
    expect(code).toMatch(/^\d{6}$/);
    expect(shortCodeOf(key, w)).toBe(code);
    expect(shortCodeOf(key, w + 1)).not.toBe(code);
    expect(shortCodeOf({ ...key, secret: 'other' }, w)).not.toBe(code);
  });

  it('checks a typed code against the current and previous window', () => {
    const w = windowOf(T0, TTL);
    expect(checkShortCode(key, shortCodeOf(key, w), TTL, T0 + 1_000)).toBe(true);
    expect(checkShortCode(key, ` ${shortCodeOf(key, w)} `, TTL, T0 + 1_000)).toBe(true); // surrounding spaces from a text field
    expect(checkShortCode(key, shortCodeOf(key, w), TTL, T0 + 35_000)).toBe(true);
    expect(checkShortCode(key, shortCodeOf(key, w), TTL, T0 + 65_000)).toBe(false);
    expect(checkShortCode(key, '000000x', TTL, T0)).toBe(false);
  });
});

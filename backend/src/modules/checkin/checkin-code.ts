import { createHmac, timingSafeEqual } from 'node:crypto';

/**
 * Rotating branch check-in code (pure, no I/O).
 *
 * The front-desk screen shows `HVP|<branch>|<version>|<window>|<signature>` as a QR (plus a
 * 6-digit code for typing). `window` is the time slice `floor(now / ttl)`; the signature is an
 * HMAC over branch, QR version and window with a per-branch secret, so nothing is stored per
 * code and many members can use the same code (it is not single-use - one check-in per member
 * per session is enforced elsewhere).
 *
 * A code is accepted during its own window and the one right after it, which absorbs network delay.
 */

export const PAYLOAD_PREFIX = 'HVP';
/** How many whole windows after its own a code still verifies. */
export const GRACE_WINDOWS = 1;

const SIGNATURE_HEX = /^[0-9a-f]{16}$/;

export interface BranchCodeKey {
  branchId: string;
  /** Branch code as printed in the payload, e.g. `Q1`. */
  branchCode: string;
  qrVersion: string;
  secret: string;
}

export interface ParsedPayload {
  branchCode: string;
  qrVersion: string;
  window: number;
  signature: string;
}

export type CodeCheck = 'OK' | 'EXPIRED' | 'INVALID';

export const windowOf = (nowMs: number, ttlSeconds: number): number => Math.floor(nowMs / (ttlSeconds * 1000));

/** When the code of `window` stops being shown (the next window starts). */
export const windowEndsAt = (window: number, ttlSeconds: number): number => (window + 1) * ttlSeconds * 1000;

function mac(key: BranchCodeKey, window: number): Buffer {
  return createHmac('sha256', key.secret).update(`${key.branchId}|${key.qrVersion}|${window}`).digest();
}

const signatureOf = (key: BranchCodeKey, window: number): string => mac(key, window).subarray(0, 8).toString('hex');

/** 6 digits for manual entry, derived from the same HMAC (different bytes than the signature). */
export function shortCodeOf(key: BranchCodeKey, window: number): string {
  return String(mac(key, window).readUInt32BE(8) % 1_000_000).padStart(6, '0');
}

export function buildPayload(key: BranchCodeKey, window: number): string {
  return [PAYLOAD_PREFIX, key.branchCode, key.qrVersion, window, signatureOf(key, window)].join('|');
}

/** Splits a scanned text into its parts; null when it is not shaped like one of our codes. */
export function parsePayload(text: string): ParsedPayload | null {
  const parts = text.trim().split('|');
  if (parts.length !== 5 || parts[0] !== PAYLOAD_PREFIX) return null;
  const [, branchCode, qrVersion, windowText, signature] = parts;
  if (!branchCode || !qrVersion || !/^\d{1,12}$/.test(windowText) || !SIGNATURE_HEX.test(signature)) return null;
  return { branchCode, qrVersion, window: Number(windowText), signature };
}

function sameText(a: string, b: string): boolean {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

/** Verifies a parsed payload for `key` at time `nowMs`. */
export function checkPayload(key: BranchCodeKey, parsed: ParsedPayload, ttlSeconds: number, nowMs: number): CodeCheck {
  // A rotated QR (new version) or a forged / foreign code never matches the signature.
  if (parsed.qrVersion !== key.qrVersion) return 'INVALID';
  if (!sameText(parsed.signature, signatureOf(key, parsed.window))) return 'INVALID';
  const age = windowOf(nowMs, ttlSeconds) - parsed.window;
  if (age < -1) return 'INVALID'; // from the future: only a skewed clock can explain one window
  return age > GRACE_WINDOWS ? 'EXPIRED' : 'OK';
}

/** Verifies a typed 6-digit code against the current window and the grace windows before it. */
export function checkShortCode(key: BranchCodeKey, input: string, ttlSeconds: number, nowMs: number): boolean {
  const current = windowOf(nowMs, ttlSeconds);
  let match = false;
  for (let w = current; w >= current - GRACE_WINDOWS; w--) {
    if (sameText(input.trim(), shortCodeOf(key, w))) match = true; // no early exit: constant work
  }
  return match;
}

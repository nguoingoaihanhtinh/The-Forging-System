import { env } from '../../config/env';
import { logger } from '../../common/utils/logger';

export type OtpPurpose = 'REGISTER' | 'PASSWORD_RESET';

/** Strategy for delivering one-time PINs by SMS. */
export interface OtpSender {
  send(phone: string, pin: string, purpose: OtpPurpose, ttlMinutes: number): Promise<void>;
}

/** Development sender: writes the PIN to the log instead of sending it. */
export class ConsoleOtpSender implements OtpSender {
  async send(phone: string, pin: string, purpose: OtpPurpose): Promise<void> {
    logger.info({ phone, purpose }, `[otp:console] PIN ${pin}`);
  }
}

/**
 * SMS text per purpose. Without diacritics (1 SMS = 160 chars) and it must match
 * the customer-care template registered with eSMS for the brandname, word for word.
 */
export const otpSmsText = (purpose: OtpPurpose, pin: string, ttlMinutes: number) =>
  purpose === 'REGISTER'
    ? `${pin} la ma xac thuc dang ky HVP cua ban. Ma co hieu luc ${ttlMinutes} phut.`
    : `${pin} la ma dat lai mat khau HVP cua ban. Ma co hieu luc ${ttlMinutes} phut.`;

export interface EsmsConfig {
  apiKey: string;
  secretKey: string;
  /** SMS fallback sender name. */
  brandname: string;
  zaloOaId: string;
  /** Approved ZNS OTP template with a single `otp` param, shared by every purpose. */
  zaloTemplateId: string;
  sandbox: boolean;
}

/**
 * Sends the PIN through eSMS.vn multichannel: Zalo ZNS first, and eSMS falls back to
 * a brandname customer-care SMS (SmsType 2) with the same PIN when Zalo cannot deliver.
 */
export class EsmsOtpSender implements OtpSender {
  constructor(private readonly cfg: EsmsConfig) {}

  async send(phone: string, pin: string, purpose: OtpPurpose, ttlMinutes: number): Promise<void> {
    const sandbox = this.cfg.sandbox ? '1' : '0';
    const res = await fetch('https://rest.esms.vn/MainService.svc/json/MultiChannelMessage/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ApiKey: this.cfg.apiKey,
        SecretKey: this.cfg.secretKey,
        Phone: phone,
        // eSMS requires this exact list and order: Data[0] is the ZNS item, Data[1] the SMS one.
        Channels: ['zalo', 'sms'],
        Data: [
          { TempID: this.cfg.zaloTemplateId, Params: [pin], OAID: this.cfg.zaloOaId, Sandbox: sandbox },
          { Content: otpSmsText(purpose, pin, ttlMinutes), SmsType: '2', Brandname: this.cfg.brandname, IsUnicode: '0', Sandbox: sandbox },
        ],
      }),
    });
    const body = (await res.json().catch(() => null)) as { CodeResult?: string; ErrorMessage?: string } | null;
    // Runs after commit: a failure is logged and the user can request a new code.
    if (body?.CodeResult !== '100') logger.error({ phone, purpose, status: res.status, body }, 'esms: OTP failed');
  }
}

export function createOtpSender(): OtpSender {
  if (env.OTP_PROVIDER === 'esms') {
    return new EsmsOtpSender({
      apiKey: env.ESMS_API_KEY!,
      secretKey: env.ESMS_SECRET_KEY!,
      brandname: env.ESMS_BRANDNAME!,
      zaloOaId: env.ESMS_ZALO_OA_ID!,
      zaloTemplateId: env.ESMS_ZALO_TEMPLATE_ID!,
      sandbox: env.ESMS_SANDBOX,
    });
  }
  return new ConsoleOtpSender();
}

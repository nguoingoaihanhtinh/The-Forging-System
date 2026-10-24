import { afterEach, describe, expect, it, vi } from 'vitest';
import { logger } from '../../src/common/utils/logger';
import { EsmsOtpSender } from '../../src/modules/auth/otp.sender';

describe('EsmsOtpSender', () => {
  afterEach(() => vi.restoreAllMocks());

  const stubFetch = (body: unknown) => vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response(JSON.stringify(body), { status: 200 }));

  const sender = (sandbox: boolean) =>
    new EsmsOtpSender({ apiKey: 'key', secretKey: 'secret', brandname: 'HVP', zaloOaId: 'oa-1', zaloTemplateId: 'tpl-1', sandbox });

  it('sends the PIN by Zalo ZNS with a brandname SMS fallback', async () => {
    const fetchMock = stubFetch({ CodeResult: '100', SMSID: 'x' });
    const error = vi.spyOn(logger, 'error');
    await sender(true).send('0912345678', '123456', 'REGISTER', 5);

    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toContain('MultiChannelMessage');
    expect(JSON.parse(init!.body as string)).toEqual({
      ApiKey: 'key',
      SecretKey: 'secret',
      Phone: '0912345678',
      Channels: ['zalo', 'sms'],
      Data: [
        { TempID: 'tpl-1', Params: ['123456'], OAID: 'oa-1', Sandbox: '1' },
        {
          Content: '123456 la ma xac thuc dang ky HVP cua ban. Ma co hieu luc 5 phut.',
          SmsType: '2',
          Brandname: 'HVP',
          IsUnicode: '0',
          Sandbox: '1',
        },
      ],
    });
    expect(error).not.toHaveBeenCalled();
  });

  it('logs an error when eSMS rejects the request', async () => {
    stubFetch({ CodeResult: '104', ErrorMessage: 'Brand name code is not exist' });
    const error = vi.spyOn(logger, 'error').mockImplementation(() => undefined as never);
    await sender(false).send('0912345678', '123456', 'PASSWORD_RESET', 5);
    expect(error).toHaveBeenCalledOnce();
  });
});

import { describe, expect, it, vi } from 'vitest';
import { FCM_BATCH_SIZE, FcmPushProvider, parseServiceAccount } from '../../src/modules/notifications/push.provider';
import type { FcmMessaging } from '../../src/modules/notifications/push.provider';

const MESSAGE = { title: 'RANK EARNED', body: 'Bạn đã lên hạng', data: { event: 'RANK_EARNED', notificationId: 'n1' } };
const tokens = (n: number) => Array.from({ length: n }, (_, i) => `t${i}`);
const ok = { success: true };
const dead = { success: false, error: { code: 'messaging/registration-token-not-registered' } };

function provider(sendEach: FcmMessaging['sendEachForMulticast']) {
  const load = vi.fn(() => ({ sendEachForMulticast: sendEach }));
  return { provider: new FcmPushProvider(load), load };
}

describe('FcmPushProvider', () => {
  it('sends the title, body and string data with high priority', async () => {
    const send = vi.fn().mockResolvedValue({ responses: [ok] });
    await provider(send).provider.send(['t0'], MESSAGE);
    expect(send).toHaveBeenCalledWith(
      expect.objectContaining({
        tokens: ['t0'],
        notification: { title: 'RANK EARNED', body: 'Bạn đã lên hạng' },
        data: { event: 'RANK_EARNED', notificationId: 'n1' },
        android: { priority: 'high' },
      }),
    );
  });

  it('does not call Firebase when there is no device', async () => {
    const send = vi.fn();
    const { provider: p, load } = provider(send);
    expect(await p.send([], MESSAGE)).toEqual({ invalidTokens: [] });
    expect(load).not.toHaveBeenCalled();
  });

  it('loads Firebase once and reuses it', async () => {
    const send = vi.fn().mockResolvedValue({ responses: [ok] });
    const { provider: p, load } = provider(send);
    await p.send(['a'], MESSAGE);
    await p.send(['b'], MESSAGE);
    expect(load).toHaveBeenCalledTimes(1);
  });

  it('reports only the tokens FCM says are dead', async () => {
    const send = vi.fn().mockResolvedValue({
      responses: [ok, dead, { success: false, error: { code: 'messaging/invalid-registration-token' } }, { success: false, error: { code: 'messaging/internal-error' } }],
    });
    const res = await provider(send).provider.send(['a', 'b', 'c', 'd'], MESSAGE);
    expect(res.invalidTokens).toEqual(['b', 'c']);
  });

  it('splits more than 500 devices into several calls and maps dead tokens back to their batch', async () => {
    const send = vi
      .fn()
      .mockResolvedValueOnce({ responses: Array.from({ length: FCM_BATCH_SIZE }, (_, i) => (i === 3 ? dead : ok)) })
      .mockResolvedValueOnce({ responses: [dead, ok] });
    const all = tokens(FCM_BATCH_SIZE + 2);
    const res = await provider(send).provider.send(all, MESSAGE);
    expect(send).toHaveBeenCalledTimes(2);
    expect((send.mock.calls[0][0] as { tokens: string[] }).tokens).toHaveLength(FCM_BATCH_SIZE);
    expect(res.invalidTokens).toEqual([all[3], all[FCM_BATCH_SIZE]]);
  });

  it('keeps the dead tokens already found when a later batch fails outright', async () => {
    const send = vi
      .fn()
      .mockResolvedValueOnce({ responses: Array.from({ length: FCM_BATCH_SIZE }, (_, i) => (i === 0 ? dead : ok)) })
      .mockRejectedValueOnce(new Error('network down'));
    const all = tokens(FCM_BATCH_SIZE + 1);
    const res = await provider(send).provider.send(all, MESSAGE);
    expect(res.invalidTokens).toEqual([all[0]]);
  });
});

describe('parseServiceAccount', () => {
  const key = { project_id: 'hvp', client_email: 'svc@hvp.iam.gserviceaccount.com', private_key: '-----BEGIN PRIVATE KEY-----\\nabc\\n-----END PRIVATE KEY-----\\n' };

  it('accepts a complete key', () => {
    expect(parseServiceAccount(JSON.stringify(key))).toMatchObject({ project_id: 'hvp' });
  });

  it('rejects text that is not JSON, without echoing it', () => {
    expect(() => parseServiceAccount('not json {')).toThrow('FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON');
  });

  it.each(['project_id', 'client_email', 'private_key'])('rejects a key without %s', (field) => {
    const partial: Record<string, string> = { ...key };
    delete partial[field];
    expect(() => parseServiceAccount(JSON.stringify(partial))).toThrow(`missing "${field}"`);
  });
});

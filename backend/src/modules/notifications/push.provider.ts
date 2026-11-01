import { createRequire } from 'node:module';
import { env } from '../../config/env';
import { logger } from '../../common/utils/logger';

export interface PushMessage {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export interface PushResult {
  /** Tokens the provider reported as permanently invalid (to be disabled). */
  invalidTokens: string[];
}

/** Strategy interface for push delivery (console in dev, FCM in production). */
export interface PushProvider {
  send(tokens: string[], message: PushMessage): Promise<PushResult>;
}

export class ConsolePushProvider implements PushProvider {
  async send(tokens: string[], message: PushMessage): Promise<PushResult> {
    logger.info({ tokens: tokens.length, title: message.title }, `[push:console] ${message.title} - ${message.body}`);
    return { invalidTokens: [] };
  }
}

/** The slice of firebase-admin's Messaging that the provider uses. */
export interface FcmMessaging {
  sendEachForMulticast: (message: unknown) => Promise<{ responses: { success: boolean; error?: { code?: string } }[] }>;
}

/** FCM allows at most 500 tokens in one multicast. */
export const FCM_BATCH_SIZE = 500;

/** FCM error codes meaning the token will never work again (app uninstalled, token rotated). */
const DEAD_TOKEN_CODES = new Set(['messaging/registration-token-not-registered', 'messaging/invalid-registration-token']);

/**
 * Firebase Cloud Messaging via firebase-admin. Credentials come from
 * FIREBASE_SERVICE_ACCOUNT_JSON (the key file's content) or, failing that, from
 * the file named by GOOGLE_APPLICATION_CREDENTIALS.
 */
export class FcmPushProvider implements PushProvider {
  private messaging: FcmMessaging | null = null;

  /** `loadMessaging` is injectable so tests do not need Firebase. */
  constructor(private readonly loadMessaging: () => FcmMessaging = loadFirebaseMessaging) {}

  async send(tokens: string[], message: PushMessage): Promise<PushResult> {
    const invalidTokens: string[] = [];
    if (tokens.length === 0) return { invalidTokens };
    this.messaging ??= this.loadMessaging();
    for (let from = 0; from < tokens.length; from += FCM_BATCH_SIZE) {
      const batch = tokens.slice(from, from + FCM_BATCH_SIZE);
      try {
        const res = await this.messaging.sendEachForMulticast({
          tokens: batch,
          notification: { title: message.title, body: message.body },
          data: message.data ?? {},
          android: { priority: 'high' },
          apns: { payload: { aps: { sound: 'default' } } },
        });
        let failed = 0;
        res.responses.forEach((r, i) => {
          if (r.success) return;
          failed++;
          const code = r.error?.code ?? 'unknown';
          if (DEAD_TOKEN_CODES.has(code)) invalidTokens.push(batch[i]);
          else logger.warn({ code }, 'push: FCM could not deliver to a device');
        });
        if (failed > 0) logger.info({ failed, sent: batch.length - failed }, 'push: FCM batch finished with failures');
      } catch (err) {
        // One failed batch (network, quota) must not lose the dead tokens found in the others.
        logger.error({ err, tokens: batch.length }, 'push: FCM batch failed');
      }
    }
    return { invalidTokens };
  }
}

/** Parses the service-account key given inline; throws a readable error when it is not usable. */
export function parseServiceAccount(raw: string): Record<string, unknown> {
  let key: unknown;
  try {
    key = JSON.parse(raw);
  } catch {
    throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON');
  }
  const obj = key as Record<string, unknown> | null;
  for (const field of ['project_id', 'client_email', 'private_key']) {
    if (!obj || typeof obj[field] !== 'string' || !obj[field]) {
      throw new Error(`FIREBASE_SERVICE_ACCOUNT_JSON is missing "${field}"`);
    }
  }
  return obj as Record<string, unknown>;
}

function loadFirebaseMessaging(): FcmMessaging {
  const req = createRequire(__filename);
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const admin = req('firebase-admin') as any;
  if (!admin.apps.length) {
    if (env.FIREBASE_SERVICE_ACCOUNT_JSON) {
      admin.initializeApp({ credential: admin.credential.cert(parseServiceAccount(env.FIREBASE_SERVICE_ACCOUNT_JSON)) });
    } else {
      admin.initializeApp(); // application default credentials: GOOGLE_APPLICATION_CREDENTIALS
    }
  }
  return admin.messaging() as FcmMessaging;
}

export function createPushProvider(): PushProvider {
  if (env.PUSH_PROVIDER !== 'fcm') return new ConsolePushProvider();
  if (!env.FIREBASE_SERVICE_ACCOUNT_JSON && !env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error('PUSH_PROVIDER=fcm needs FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS');
  }
  if (env.FIREBASE_SERVICE_ACCOUNT_JSON) parseServiceAccount(env.FIREBASE_SERVICE_ACCOUNT_JSON); // a bad key stops the server at startup, not at the first push
  return new FcmPushProvider();
}

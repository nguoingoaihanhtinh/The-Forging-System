import pino from 'pino';
import { env, isProd } from '../../config/env';

// pino-pretty is a devDependency; the runtime image omits it even when NODE_ENV=development.
function hasPrettyTransport(): boolean {
  try {
    require.resolve('pino-pretty');
    return true;
  } catch {
    return false;
  }
}

export const logger = pino({
  level: env.NODE_ENV === 'test' ? 'silent' : env.LOG_LEVEL,
  ...(isProd || !hasPrettyTransport() ? {} : { transport: { target: 'pino-pretty', options: { colorize: true, singleLine: true } } }),
  redact: ['req.headers.authorization', 'password', 'passwordHash', 'token'],
});

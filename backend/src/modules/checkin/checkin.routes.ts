import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { authOf, created, handle, ok } from '../../common/http/handler';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { isTest } from '../../config/env';
import { Role, RoleGroup } from '../../shared/roles';
import type { CheckinCodeService } from './checkin-code.service';
import type { CheckinSessionService } from './checkin-session.service';
import type { CheckinService } from './checkin.service';

const branchParam = z.object({ branchId: z.string().uuid() });
const memberParam = z.object({ memberId: z.string().uuid() });
const assistedBody = z
  .object({ sessionId: z.string().uuid(), evidenceUrl: z.string().trim().max(1000).optional() })
  .strict();
const checkinBody = z
  .object({
    payload: z.string().trim().min(1).max(200).optional(),
    shortCode: z.string().trim().regex(/^\d{6}$/, 'The code is 6 digits').optional(),
    sessionId: z.string().uuid().optional(),
  })
  .strict()
  .refine((b) => Boolean(b.payload) !== Boolean(b.shortCode), { message: 'Send exactly one of payload or shortCode' });

/**
 * Check-in APIs. CHK-01: the rotating code the front-desk screen shows. CHK-02: the sessions a member can check
 * into today. CHK-03: the member's own check-in. CHK-04: front desk checking a member in.
 */
export function checkinRoutes(codes: CheckinCodeService, sessions: CheckinSessionService, checkin: CheckinService): Router {
  const r = Router();
  r.use(requireAuth);
  // Typed 6-digit codes can be guessed by trial: cap attempts per member (disabled in tests).
  const attempts = rateLimit({
    windowMs: 60_000,
    limit: 15,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) => req.ctx.auth?.userId ?? 'anonymous',
    skip: () => isTest,
  });

  r.get(
    '/branches/:branchId/checkin-code',
    requireRoles(...RoleGroup.FRONT_DESK),
    validate({ params: branchParam }),
    handle(async (req) => {
      const { roles, branchId } = authOf(req);
      return ok(await codes.current(req.params.branchId, { roles, branchId }));
    }),
  );

  r.get(
    '/me/checkin/sessions',
    requireRoles(Role.MEMBER),
    handle(async (req) => ok(await sessions.listToday(authOf(req).userId, 'SELF'))),
  );
  r.post(
    '/me/checkin',
    requireRoles(Role.MEMBER),
    attempts,
    validate({ body: checkinBody }),
    handle(async (req) => {
      const outcome = await checkin.checkIn(authOf(req).userId, req.body);
      // 201 only when this call recorded the check-in; a repeat or a "which session?" answer is a plain 200.
      return outcome.status === 'CHECKED_IN' && !outcome.alreadyCheckedIn ? created(outcome) : ok(outcome);
    }),
  );
  r.post(
    '/members/:memberId/checkin',
    requireRoles(...RoleGroup.FRONT_DESK),
    validate({ params: memberParam, body: assistedBody }),
    handle(async (req) => {
      const { userId, roles, branchId } = authOf(req);
      const outcome = await checkin.checkInFor(req.params.memberId, req.body, { userId, roles, branchId });
      return outcome.alreadyCheckedIn ? ok(outcome) : created(outcome);
    }),
  );
  // Front desk checking a member in: staff see their own branch's sessions, admins every branch.
  r.get(
    '/members/:memberId/checkin/sessions',
    requireRoles(...RoleGroup.FRONT_DESK),
    validate({ params: memberParam }),
    handle(async (req) => {
      const { roles, branchId } = authOf(req);
      const isAdmin = roles.some((role) => (RoleGroup.ADMINS as readonly string[]).includes(role));
      return ok(await sessions.listToday(req.params.memberId, 'ASSISTED', { branchId: isAdmin ? null : branchId }));
    }),
  );
  return r;
}

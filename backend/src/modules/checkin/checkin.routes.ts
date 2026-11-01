import { Router } from 'express';
import { z } from 'zod';
import { authOf, handle, ok } from '../../common/http/handler';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { Role, RoleGroup } from '../../shared/roles';
import type { CheckinCodeService } from './checkin-code.service';
import type { CheckinSessionService } from './checkin-session.service';

const branchParam = z.object({ branchId: z.string().uuid() });
const memberParam = z.object({ memberId: z.string().uuid() });

/** Check-in APIs. CHK-01: the rotating code the front-desk screen shows. CHK-02: the sessions a member can check into today. */
export function checkinRoutes(codes: CheckinCodeService, sessions: CheckinSessionService): Router {
  const r = Router();
  r.use(requireAuth);

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

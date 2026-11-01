import { Router } from 'express';
import { z } from 'zod';
import { authOf, handle, ok } from '../../common/http/handler';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { RoleGroup } from '../../shared/roles';
import type { CheckinCodeService } from './checkin-code.service';

const branchParam = z.object({ branchId: z.string().uuid() });

/** Check-in APIs. CHK-01: the rotating code the front-desk screen shows. */
export function checkinRoutes(codes: CheckinCodeService): Router {
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
  return r;
}

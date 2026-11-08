import { Router } from 'express';
import { z } from 'zod';
import { authOf, handle, ok } from '../../common/http/handler';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { Role, RoleGroup } from '../../shared/roles';
import { DEFAULT_TOP, MAX_TOP } from './leaderboard.rules';
import type { LeaderboardService } from './leaderboard.service';

const boardQuery = z.object({
  year: z.coerce.number().int().min(2000).max(2200).optional(),
  top: z.coerce.number().int().min(1).max(MAX_TOP).default(DEFAULT_TOP),
});

export function leaderboardRoutes(service: LeaderboardService): Router {
  const r = Router();
  r.use(requireAuth);

  // Open to every signed-in member and to staff; only a member gets a `me` block.
  r.get(
    '/leaderboard/dp',
    requireRoles(Role.MEMBER, ...RoleGroup.STAFF),
    validate({ query: boardQuery }),
    handle(async (req) => {
      const q = req.query as unknown as z.infer<typeof boardQuery>;
      const auth = authOf(req);
      const viewerId = auth.roles.includes(Role.MEMBER) ? auth.userId : null;
      return ok(await service.yearly(q.year, q.top, viewerId));
    }),
  );
  return r;
}

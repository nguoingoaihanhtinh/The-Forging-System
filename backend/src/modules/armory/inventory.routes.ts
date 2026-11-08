import { Router } from 'express';
import { z } from 'zod';
import { authOf, created, handle, ok } from '../../common/http/handler';
import { pageMeta, paginationQuery, toPage } from '../../common/http/pagination';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { RoleGroup } from '../../shared/roles';
import type { InventoryService } from './inventory.service';

export const inventoryBody = z.object({
  rewardId: z.string().uuid(), movementType: z.enum(['IN', 'OUT']),
  quantity: z.number().int().min(1).max(2_147_483_647), reason: z.string().trim().min(3).max(500),
}).strict();
export const inventoryQuery = paginationQuery.extend({
  rewardId: z.string().uuid().optional(), movementType: z.enum(['IN', 'OUT']).optional(), actorId: z.string().uuid().optional(),
  from: z.string().datetime({ offset: true }).optional(), to: z.string().datetime({ offset: true }).optional(),
}).strict().refine((query) => !query.from || !query.to || new Date(query.from) <= new Date(query.to), {
  path: ['to'], message: 'Thời gian kết thúc phải sau hoặc bằng thời gian bắt đầu.',
});
export const inventoryRewardQuery = paginationQuery.extend({
  q: z.string().trim().min(1).max(100).optional(),
}).strict();

export function inventoryRoutes(service: InventoryService): Router {
  const r = Router();
  r.use('/staff/armory/inventory', requireAuth, requireRoles(...RoleGroup.FRONT_DESK));
  r.get('/staff/armory/rewards', requireAuth, requireRoles(...RoleGroup.FRONT_DESK),
    validate({ query: inventoryRewardQuery }), handle(async (req) => {
      const query = req.query as unknown as z.infer<typeof inventoryRewardQuery>;
      const page = toPage(query);
      const result = await service.rewards(query, page.limit, page.offset);
      return ok(result.items, pageMeta(page, result.total));
    }));
  r.post('/staff/armory/inventory/movements', validate({ body: inventoryBody }), handle(async (req) =>
    created(await service.adjust(req.body, authOf(req).userId))));
  r.get('/staff/armory/inventory/movements', validate({ query: inventoryQuery }), handle(async (req) => {
    const query = req.query as unknown as z.infer<typeof inventoryQuery>;
    const page = toPage(query);
    const result = await service.history(query, page.limit, page.offset);
    return ok(result.items, pageMeta(page, result.total));
  }));
  return r;
}

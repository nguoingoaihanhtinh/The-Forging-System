import { Router } from 'express';
import { z } from 'zod';
import { authOf, handle, ok } from '../../common/http/handler';
import { requireAuth } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import type { CourseService } from './course.service';

const courseParam = z.object({ courseId: z.string().uuid() });
const lessonParam = courseParam.extend({ lessonNo: z.coerce.number().int().min(1).max(999) });

/** Curriculum read APIs: any signed-in user reads; progress is only filled in for learners. */
export function courseRoutes(service: CourseService): Router {
  const r = Router();
  r.use(requireAuth);

  r.get('/courses', handle(async (req) => ok(await service.list(authOf(req)))));
  r.get(
    '/courses/:courseId',
    validate({ params: courseParam }),
    handle(async (req) => ok(await service.get(authOf(req), req.params.courseId))),
  );
  r.get(
    '/courses/:courseId/lessons/:lessonNo',
    validate({ params: lessonParam }),
    handle(async (req) => {
      const { courseId, lessonNo } = req.params as unknown as z.infer<typeof lessonParam>;
      return ok(await service.getLesson(authOf(req), courseId, lessonNo));
    }),
  );
  return r;
}

import { Router } from 'express';
import { z } from 'zod';
import { authOf, created, handle, noContent, ok } from '../../common/http/handler';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { RoleGroup } from '../../shared/roles';
import type { CourseService } from './course.service';

const courseParam = z.object({ courseId: z.string().uuid() });
const lessonParam = courseParam.extend({ lessonNo: z.coerce.number().int().min(1).max(999) });

const lessonFields = {
  title: z.string().trim().min(1).max(200),
  subtitle: z.string().trim().max(200).nullable(),
  weekNo: z.number().int().min(1).max(52).nullable(),
  objectives: z.string().trim().max(2000).nullable(),
  content: z.record(z.unknown()).nullable(),
  isAssessment: z.boolean(),
  isGraduation: z.boolean(),
  isAdvanced: z.boolean(),
};
const createLessonBody = z.object({
  lessonNo: z.number().int().min(1).max(999).optional(),
  title: lessonFields.title,
  subtitle: lessonFields.subtitle.optional(),
  weekNo: lessonFields.weekNo.optional(),
  objectives: lessonFields.objectives.optional(),
  content: lessonFields.content.optional(),
  isAssessment: lessonFields.isAssessment.optional(),
  isGraduation: lessonFields.isGraduation.optional(),
  isAdvanced: lessonFields.isAdvanced.optional(),
});
const patchLessonBody = z
  .object(lessonFields)
  .partial()
  .refine((b) => Object.keys(b).length > 0, { message: 'Provide at least one field to update' });

/**
 * Curriculum APIs. Reads (CAT-01): any signed-in user, progress only filled in for learners.
 * Lesson management (CAT-02): admins only, under /admin/courses.
 */
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

  r.post(
    '/admin/courses/:courseId/lessons',
    requireRoles(...RoleGroup.ADMINS),
    validate({ params: courseParam, body: createLessonBody }),
    handle(async (req) => created(await service.createLesson(req.params.courseId, req.body, authOf(req).userId))),
  );
  r.patch(
    '/admin/courses/:courseId/lessons/:lessonNo',
    requireRoles(...RoleGroup.ADMINS),
    validate({ params: lessonParam, body: patchLessonBody }),
    handle(async (req) => {
      const { courseId, lessonNo } = req.params as unknown as z.infer<typeof lessonParam>;
      return ok(await service.updateLesson(courseId, lessonNo, req.body, authOf(req).userId));
    }),
  );
  r.delete(
    '/admin/courses/:courseId/lessons/:lessonNo',
    requireRoles(...RoleGroup.ADMINS),
    validate({ params: lessonParam }),
    handle(async (req) => {
      const { courseId, lessonNo } = req.params as unknown as z.infer<typeof lessonParam>;
      await service.deleteLesson(courseId, lessonNo, authOf(req).userId);
      return noContent();
    }),
  );
  return r;
}

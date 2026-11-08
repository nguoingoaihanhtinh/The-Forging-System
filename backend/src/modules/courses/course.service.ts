import { conflict, notFound } from '../../common/errors/app-error';
import { Role } from '../../shared/roles';
import type { AuditService } from '../audit/audit.service';
import type { CourseRepository } from './course.repository';
import type {
  CourseDetailView,
  CourseProgress,
  CourseRow,
  CourseView,
  LessonAdminView,
  LessonDetail,
  LessonFields,
  LessonRecord,
} from './course.types';

/** Packages of this many days or fewer are "1-month" packages: advanced lessons stay hidden. */
const SHORT_PACKAGE_MAX_DAYS = 31;

/** Learners (and only learners) have an enrolment and the 1-month restriction; staff read everything. */
const isLearner = (roles: readonly string[]) => roles.length === 1 && roles[0] === Role.MEMBER;

export interface Viewer {
  userId: string;
  roles: readonly string[];
}

function progressOf(row: CourseRow): CourseProgress {
  if (!row.enrollmentStatus) return { status: 'NOT_STARTED', lessonsCompleted: 0 };
  return {
    status: row.enrollmentStatus === 'COMPLETED' ? 'COMPLETED' : 'IN_PROGRESS',
    lessonsCompleted: row.lessonsCompleted ?? 0,
  };
}

function present(row: CourseRow, learner: boolean): CourseView {
  const { enrollmentStatus: _status, lessonsCompleted: _done, ...course } = row;
  return { ...course, progress: learner ? progressOf(row) : null };
}

export type LessonCreateInput = Partial<LessonFields> & { title: string; lessonNo?: number };

function withDefaults(input: LessonCreateInput): LessonFields {
  return {
    title: input.title,
    subtitle: input.subtitle ?? null,
    weekNo: input.weekNo ?? null,
    objectives: input.objectives ?? null,
    content: input.content ?? null,
    isAssessment: input.isAssessment ?? false,
    isGraduation: input.isGraduation ?? false,
    isAdvanced: input.isAdvanced ?? false,
  };
}

/** Drops the soft-delete marker: admins never see deleted lessons through the API. */
function presentLesson(row: LessonRecord): LessonAdminView {
  const { deletedAt: _deleted, ...lesson } = row;
  return lesson;
}

export class CourseService {
  constructor(
    private readonly repo: CourseRepository,
    private readonly audit: AuditService,
  ) {}

  async list(viewer: Viewer): Promise<CourseView[]> {
    const learner = isLearner(viewer.roles);
    const rows = await this.repo.listCourses(learner ? viewer.userId : null);
    return rows.map((r) => present(r, learner));
  }

  async get(viewer: Viewer, courseId: string): Promise<CourseDetailView> {
    const learner = isLearner(viewer.roles);
    const row = await this.repo.findCourse(courseId, learner ? viewer.userId : null);
    if (!row) throw notFound('Khóa học');
    const lessons = await this.repo.listLessons(courseId, await this.canSeeAdvanced(viewer));
    return { ...present(row, learner), lessons };
  }

  async getLesson(viewer: Viewer, courseId: string, lessonNo: number): Promise<LessonDetail> {
    const course = await this.repo.findCourse(courseId, null);
    if (!course) throw notFound('Khóa học');
    // A hidden advanced lesson is indistinguishable from a missing one.
    const lesson = await this.repo.findLesson(courseId, lessonNo, await this.canSeeAdvanced(viewer));
    if (!lesson) throw notFound('Bài học');
    return lesson;
  }

  // ---- admin lesson management (CAT-02) ----

  /** Adds a lesson; re-using the number of a deleted lesson revives that row. */
  async createLesson(courseId: string, input: LessonCreateInput, by: string): Promise<LessonAdminView> {
    await this.requireCourse(courseId);
    const lessonNo = input.lessonNo ?? (await this.repo.nextLessonNo(courseId));
    const existing = await this.repo.findLessonRecord(courseId, lessonNo);
    if (existing && !existing.deletedAt) {
      throw conflict(`Bài học số ${lessonNo} đã tồn tại trong khóa này.`, 'LESSON_EXISTS');
    }
    const fields = withDefaults(input);
    const row = existing
      ? await this.repo.reviveLesson(courseId, lessonNo, fields)
      : await this.repo.insertLesson(courseId, lessonNo, fields);
    await this.repo.syncTotalLessons(courseId);
    await this.audit.record({
      actorId: by,
      action: existing ? 'LESSON_RESTORE' : 'LESSON_CREATE',
      entityType: 'lesson_plan',
      entityId: row.id,
      before: existing ? presentLesson(existing) : undefined,
      after: presentLesson(row),
    });
    return presentLesson(row);
  }

  async updateLesson(courseId: string, lessonNo: number, patch: Partial<LessonFields>, by: string): Promise<LessonAdminView> {
    await this.requireCourse(courseId);
    const before = await this.requireLiveLesson(courseId, lessonNo);
    const row = await this.repo.updateLesson(courseId, lessonNo, patch);
    if (!row) throw notFound('Bài học');
    await this.audit.record({
      actorId: by,
      action: 'LESSON_UPDATE',
      entityType: 'lesson_plan',
      entityId: row.id,
      before: presentLesson(before),
      after: presentLesson(row),
    });
    return presentLesson(row);
  }

  /** Soft delete: the row stays for history, learners stop seeing it. */
  async deleteLesson(courseId: string, lessonNo: number, by: string): Promise<void> {
    await this.requireCourse(courseId);
    const before = await this.requireLiveLesson(courseId, lessonNo);
    await this.repo.softDeleteLesson(courseId, lessonNo);
    await this.repo.syncTotalLessons(courseId);
    await this.audit.record({
      actorId: by,
      action: 'LESSON_DELETE',
      entityType: 'lesson_plan',
      entityId: before.id,
      before: presentLesson(before),
    });
  }

  private async requireCourse(courseId: string): Promise<void> {
    if (!(await this.repo.findCourse(courseId, null))) throw notFound('Khóa học');
  }

  private async requireLiveLesson(courseId: string, lessonNo: number): Promise<LessonRecord> {
    const row = await this.repo.findLessonRecord(courseId, lessonNo);
    if (!row || row.deletedAt) throw notFound('Bài học');
    return row;
  }

  private async canSeeAdvanced(viewer: Viewer): Promise<boolean> {
    if (!isLearner(viewer.roles)) return true;
    return !(await this.repo.hasShortActivePackage(viewer.userId, SHORT_PACKAGE_MAX_DAYS));
  }
}

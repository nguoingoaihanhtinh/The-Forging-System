import { notFound } from '../../common/errors/app-error';
import { Role } from '../../shared/roles';
import type { CourseRepository } from './course.repository';
import type { CourseDetailView, CourseProgress, CourseRow, CourseView, LessonDetail } from './course.types';

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

export class CourseService {
  constructor(private readonly repo: CourseRepository) {}

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

  private async canSeeAdvanced(viewer: Viewer): Promise<boolean> {
    if (!isLearner(viewer.roles)) return true;
    return !(await this.repo.hasShortActivePackage(viewer.userId, SHORT_PACKAGE_MAX_DAYS));
  }
}

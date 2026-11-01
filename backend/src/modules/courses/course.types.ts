export type CourseProgressStatus = 'NOT_STARTED' | 'IN_PROGRESS' | 'COMPLETED';

export interface CourseProgress {
  status: CourseProgressStatus;
  lessonsCompleted: number;
}

export interface Course {
  id: string;
  code: string;
  name: string;
  durationWeeks: number;
  totalLessons: number;
  description: string | null;
}

/** A course as seen by a learner; `progress` is null for staff (they have no enrolment). */
export interface CourseView extends Course {
  progress: CourseProgress | null;
}

export interface LessonSummary {
  lessonNo: number;
  weekNo: number | null;
  title: string;
  subtitle: string | null;
  isAssessment: boolean;
  isGraduation: boolean;
  isAdvanced: boolean;
}

export interface LessonDetail extends LessonSummary {
  courseId: string;
  objectives: string | null;
  content: unknown;
}

/** A lesson as returned to admins: the detail plus its id. */
export interface LessonAdminView extends LessonDetail {
  id: string;
}

/** Writable lesson fields (everything an admin can set; lessonNo is the identity, not a field). */
export interface LessonFields {
  title: string;
  subtitle: string | null;
  weekNo: number | null;
  objectives: string | null;
  content: Record<string, unknown> | null;
  isAssessment: boolean;
  isGraduation: boolean;
  isAdvanced: boolean;
}

/** A lesson row including soft-deleted ones. */
export interface LessonRecord extends LessonAdminView {
  deletedAt: Date | null;
}

export interface CourseDetailView extends CourseView {
  lessons: LessonSummary[];
}

/** Raw course row joined with the member's enrolment (null columns when not enrolled). */
export interface CourseRow extends Course {
  enrollmentStatus: 'IN_PROGRESS' | 'COMPLETED' | null;
  lessonsCompleted: number | null;
}

import { sql } from '../../db/sql';
import type { CourseRow, LessonDetail, LessonFields, LessonRecord, LessonSummary } from './course.types';

const COURSE_COLUMNS = `c.id, c.code, c.name, c.duration_weeks, c.total_lessons, c.description,
  e.status AS enrollment_status, e.lessons_completed`;

// A course is "ordered" by the package that unlocks it (BOOK I..V); courses without a package go last.
const COURSE_FROM = `courses c
  LEFT JOIN course_enrollments e ON e.course_id = c.id AND e.member_id = $1 AND e.status <> 'DROPPED'`;
const COURSE_ORDER = `(SELECT MIN(p.sort_order) FROM package_types p WHERE p.unlocks_course_id = c.id) NULLS LAST, c.name`;

const LESSON_SUMMARY_COLUMNS = `lesson_no, week_no, title, subtitle, is_assessment, is_graduation, is_advanced`;
const LESSON_RECORD_COLUMNS = `id, course_id, ${LESSON_SUMMARY_COLUMNS}, objectives, content, deleted_at`;

const LESSON_COLUMNS: Record<keyof LessonFields, string> = {
  title: 'title',
  subtitle: 'subtitle',
  weekNo: 'week_no',
  objectives: 'objectives',
  content: 'content',
  isAssessment: 'is_assessment',
  isGraduation: 'is_graduation',
  isAdvanced: 'is_advanced',
};

const jsonOrNull = (value: unknown): string | null => (value === null || value === undefined ? null : JSON.stringify(value));

export class CourseRepository {
  /** `memberId` null (staff) joins no enrolment: the uuid never matches. */
  listCourses(memberId: string | null): Promise<CourseRow[]> {
    return sql.many(`SELECT ${COURSE_COLUMNS} FROM ${COURSE_FROM} WHERE c.is_active ORDER BY ${COURSE_ORDER}`, [memberId]);
  }

  findCourse(id: string, memberId: string | null): Promise<CourseRow | null> {
    return sql.one(`SELECT ${COURSE_COLUMNS} FROM ${COURSE_FROM} WHERE c.id = $2 AND c.is_active`, [memberId, id]);
  }

  listLessons(courseId: string, includeAdvanced: boolean): Promise<LessonSummary[]> {
    return sql.many(
      `SELECT ${LESSON_SUMMARY_COLUMNS} FROM lesson_plans
        WHERE course_id = $1 AND deleted_at IS NULL AND ($2 OR NOT is_advanced)
        ORDER BY lesson_no`,
      [courseId, includeAdvanced],
    );
  }

  findLesson(courseId: string, lessonNo: number, includeAdvanced: boolean): Promise<LessonDetail | null> {
    return sql.one(
      `SELECT course_id, ${LESSON_SUMMARY_COLUMNS}, objectives, content FROM lesson_plans
        WHERE course_id = $1 AND lesson_no = $2 AND deleted_at IS NULL AND ($3 OR NOT is_advanced)`,
      [courseId, lessonNo, includeAdvanced],
    );
  }

  // ---- admin writes (CAT-02) ----

  /** The row for (course, lesson number) even when soft-deleted. */
  findLessonRecord(courseId: string, lessonNo: number): Promise<LessonRecord | null> {
    return sql.one(`SELECT ${LESSON_RECORD_COLUMNS} FROM lesson_plans WHERE course_id = $1 AND lesson_no = $2`, [
      courseId,
      lessonNo,
    ]);
  }

  /** Next free lesson number; deleted rows still hold their number. */
  async nextLessonNo(courseId: string): Promise<number> {
    return (await sql.scalar<number>(`SELECT COALESCE(MAX(lesson_no), 0) + 1 FROM lesson_plans WHERE course_id = $1`, [courseId])) ?? 1;
  }

  insertLesson(courseId: string, lessonNo: number, f: LessonFields): Promise<LessonRecord> {
    return sql.one(
      `INSERT INTO lesson_plans (tenant_id, course_id, lesson_no, week_no, title, subtitle, objectives, content,
                                 is_assessment, is_graduation, is_advanced)
       VALUES (current_setting('app.current_tenant_id')::uuid, $1, $2, $3, $4, $5, $6, $7::jsonb, $8, $9, $10)
       RETURNING ${LESSON_RECORD_COLUMNS}`,
      [courseId, lessonNo, f.weekNo, f.title, f.subtitle, f.objectives, jsonOrNull(f.content), f.isAssessment, f.isGraduation, f.isAdvanced],
    ) as Promise<LessonRecord>;
  }

  /** Writes all fields of an existing row and clears deleted_at (re-creating a deleted lesson number). */
  reviveLesson(courseId: string, lessonNo: number, f: LessonFields): Promise<LessonRecord> {
    return sql.one(
      `UPDATE lesson_plans
          SET week_no = $3, title = $4, subtitle = $5, objectives = $6, content = $7::jsonb,
              is_assessment = $8, is_graduation = $9, is_advanced = $10, deleted_at = NULL, updated_at = now()
        WHERE course_id = $1 AND lesson_no = $2
        RETURNING ${LESSON_RECORD_COLUMNS}`,
      [courseId, lessonNo, f.weekNo, f.title, f.subtitle, f.objectives, jsonOrNull(f.content), f.isAssessment, f.isGraduation, f.isAdvanced],
    ) as Promise<LessonRecord>;
  }

  /** Updates only the keys present in `patch` (null clears a nullable column) on a live lesson. */
  updateLesson(courseId: string, lessonNo: number, patch: Partial<LessonFields>): Promise<LessonRecord | null> {
    const keys = (Object.keys(patch) as Array<keyof LessonFields>).filter((k) => patch[k] !== undefined);
    const sets = keys.map((k, n) => `${LESSON_COLUMNS[k]} = $${n + 3}${k === 'content' ? '::jsonb' : ''}`);
    return sql.one(
      `UPDATE lesson_plans SET ${[...sets, 'updated_at = now()'].join(', ')}
        WHERE course_id = $1 AND lesson_no = $2 AND deleted_at IS NULL
        RETURNING ${LESSON_RECORD_COLUMNS}`,
      [courseId, lessonNo, ...keys.map((k) => (k === 'content' ? jsonOrNull(patch.content ?? null) : patch[k]))],
    );
  }

  softDeleteLesson(courseId: string, lessonNo: number): Promise<number> {
    return sql.exec(
      `UPDATE lesson_plans SET deleted_at = now(), updated_at = now()
        WHERE course_id = $1 AND lesson_no = $2 AND deleted_at IS NULL`,
      [courseId, lessonNo],
    );
  }

  /** Keeps courses.total_lessons equal to the number of live lessons. */
  syncTotalLessons(courseId: string): Promise<number> {
    return sql.exec(
      `UPDATE courses
          SET total_lessons = (SELECT COUNT(*) FROM lesson_plans WHERE course_id = $1 AND deleted_at IS NULL),
              updated_at = now()
        WHERE id = $1`,
      [courseId],
    );
  }

  /** True when the member's current membership is a 1-month package (advanced lessons are hidden). */
  async hasShortActivePackage(memberId: string, maxDays: number): Promise<boolean> {
    const hit = await sql.scalar<boolean>(
      `SELECT EXISTS (
         SELECT 1 FROM memberships m JOIN package_types p ON p.id = m.package_type_id
          WHERE m.member_id = $1 AND m.status = 'ACTIVE' AND p.duration_days IS NOT NULL AND p.duration_days <= $2)`,
      [memberId, maxDays],
    );
    return hit === true;
  }
}

import { sql } from '../../db/sql';
import type { CourseRow, LessonDetail, LessonSummary } from './course.types';

const COURSE_COLUMNS = `c.id, c.code, c.name, c.duration_weeks, c.total_lessons, c.description,
  e.status AS enrollment_status, e.lessons_completed`;

// A course is "ordered" by the package that unlocks it (BOOK I..V); courses without a package go last.
const COURSE_FROM = `courses c
  LEFT JOIN course_enrollments e ON e.course_id = c.id AND e.member_id = $1 AND e.status <> 'DROPPED'`;
const COURSE_ORDER = `(SELECT MIN(p.sort_order) FROM package_types p WHERE p.unlocks_course_id = c.id) NULLS LAST, c.name`;

const LESSON_SUMMARY_COLUMNS = `lesson_no, week_no, title, subtitle, is_assessment, is_graduation, is_advanced`;

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
        WHERE course_id = $1 AND ($2 OR NOT is_advanced)
        ORDER BY lesson_no`,
      [courseId, includeAdvanced],
    );
  }

  findLesson(courseId: string, lessonNo: number, includeAdvanced: boolean): Promise<LessonDetail | null> {
    return sql.one(
      `SELECT course_id, ${LESSON_SUMMARY_COLUMNS}, objectives, content FROM lesson_plans
        WHERE course_id = $1 AND lesson_no = $2 AND ($3 OR NOT is_advanced)`,
      [courseId, lessonNo, includeAdvanced],
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

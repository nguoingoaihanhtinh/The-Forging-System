-- =====================================================================
-- 0009 - Soft delete for lesson plans (CAT-02)
--   * An admin "deletes" a lesson by stamping deleted_at; the row stays so that
--     attendances / session history that point at it keep working.
--   * (course_id, lesson_no) stays unique across deleted rows too: re-creating a
--     deleted lesson number revives the row instead of adding a second one.
-- =====================================================================

alter table lesson_plans add column deleted_at timestamptz;

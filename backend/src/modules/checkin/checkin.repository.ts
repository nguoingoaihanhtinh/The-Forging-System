import { sql } from '../../db/sql';

export interface CodeBranch {
  id: string;
  code: string;
  name: string;
  isActive: boolean;
  qrVersion: string | null;
  checkinSecret: string | null;
}

/** A session of the member's, with what the check-in rules need. */
export interface TodaySessionRow {
  sessionId: string;
  classId: string | null;
  title: string | null;
  sessionType: string;
  isExam: boolean;
  startsAt: Date;
  endsAt: Date;
  branchId: string;
  branchName: string;
  coachId: string;
  coachName: string;
  opensAt: Date | null;
  closesAt: Date | null;
  attendanceStatus: string | null;
  checkinAt: Date | null;
}

export interface MemberGateRow {
  status: string;
  /** The ACTIVE package, if any. */
  totalSessions: number | null;
  usedSessions: number | null;
  endDate: string | null;
  hasActiveMembership: boolean;
}

const COLUMNS = `id, code, name, is_active, qr_version, checkin_secret`;

export class CheckinRepository {
  findBranch(id: string): Promise<CodeBranch | null> {
    return sql.one(`SELECT ${COLUMNS} FROM branches WHERE id = $1`, [id]);
  }

  findBranchByCode(code: string): Promise<CodeBranch | null> {
    return sql.one(`SELECT ${COLUMNS} FROM branches WHERE code = $1`, [code]);
  }

  /** Stores `candidate` unless a secret already exists; returns the one in force (safe under concurrent first use). */
  async ensureSecret(branchId: string, candidate: string): Promise<string> {
    const secret = await sql.scalar<string>(
      `UPDATE branches SET checkin_secret = COALESCE(checkin_secret, $2) WHERE id = $1 RETURNING checkin_secret`,
      [branchId, candidate],
    );
    return secret as string;
  }

  /**
   * Sessions starting in [from, to) that belong to the member: an attendance row exists, or the member is
   * enrolled in the session's class on that local date (same rule as the learner schedule, CLS-04).
   * Cancelled and completed sessions are left out.
   */
  todaySessions(memberId: string, from: Date, to: Date, timezone: string): Promise<TodaySessionRow[]> {
    return sql.many(
      `SELECT s.id AS session_id, s.class_id, s.title, s.session_type_code AS session_type, s.is_exam,
              s.starts_at, s.ends_at, b.id AS branch_id, b.name AS branch_name, u.id AS coach_id, u.full_name AS coach_name,
              s.checkin_opens_at AS opens_at, s.checkin_closes_at AS closes_at, a.attendance_status, a.checkin_at
         FROM sessions s
         JOIN branches b ON b.id = s.branch_id
         JOIN users u ON u.id = s.coach_id
         LEFT JOIN attendances a ON a.session_id = s.id AND a.member_id = $1
        WHERE s.starts_at >= $2 AND s.starts_at < $3
          AND s.status IN ('SCHEDULED', 'IN_PROGRESS')
          AND (a.id IS NOT NULL OR EXISTS (
                SELECT 1 FROM class_enrollments e
                 WHERE e.class_id = s.class_id AND e.member_id = $1 AND e.status <> 'CANCELLED'
                   AND (s.starts_at AT TIME ZONE $4)::date >= e.start_date
                   AND (e.end_date IS NULL OR (s.starts_at AT TIME ZONE $4)::date <= e.end_date)))
        ORDER BY s.starts_at, s.id`,
      [memberId, from, to, timezone],
    );
  }

  /** Account status and the ACTIVE package of a member; null when the member does not exist. */
  memberGate(memberId: string): Promise<MemberGateRow | null> {
    return sql.one(
      `SELECT m.status, ms.total_sessions, ms.used_sessions, to_char(ms.end_date, 'YYYY-MM-DD') AS end_date,
              (ms.id IS NOT NULL) AS has_active_membership
         FROM members m
         LEFT JOIN memberships ms ON ms.member_id = m.user_id AND ms.status = 'ACTIVE'
        WHERE m.user_id = $1`,
      [memberId],
    );
  }
}

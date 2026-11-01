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

export interface AttendanceRow {
  id: string;
  attendanceStatus: string;
  checkinAt: Date | null;
}

export interface ChargedMembership {
  id: string;
  totalSessions: number | null;
  usedSessions: number;
}

export interface CheckinWrite {
  at: Date;
  /** Front-desk user who checked the member in; null for self check-in. */
  checkedInBy: string | null;
  evidenceUrl: string | null;
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

  /** The member's attendance row of a session, locked until the transaction ends (serialises double scans). */
  lockAttendance(sessionId: string, memberId: string): Promise<AttendanceRow | null> {
    return sql.one(
      `SELECT id, attendance_status, checkin_at FROM attendances WHERE session_id = $1 AND member_id = $2 FOR UPDATE`,
      [sessionId, memberId],
    );
  }

  /** New attendance already waiting for the coach; null when another request created the row first. */
  async insertCheckin(sessionId: string, memberId: string, w: CheckinWrite): Promise<string | null> {
    const row = await sql.one<{ id: string }>(
      `INSERT INTO attendances (tenant_id, session_id, member_id, checkin_at, checkin_evidence_url, checked_in_by, attendance_status)
       VALUES (current_setting('app.current_tenant_id')::uuid, $1, $2, $3, $4, $5, 'AWAITING_COACH')
       ON CONFLICT (session_id, member_id) DO NOTHING
       RETURNING id`,
      [sessionId, memberId, w.at, w.evidenceUrl, w.checkedInBy],
    );
    return row?.id ?? null;
  }

  /** Turns a pre-created (UPCOMING) or coach-absent row into a check-in. */
  markCheckedIn(attendanceId: string, w: CheckinWrite): Promise<number> {
    return sql.exec(
      `UPDATE attendances
          SET attendance_status = 'AWAITING_COACH', checkin_at = $2, checkin_evidence_url = $3, checked_in_by = $4, updated_at = now()
        WHERE id = $1`,
      [attendanceId, w.at, w.evidenceUrl, w.checkedInBy],
    );
  }

  /**
   * Takes one session off the member's ACTIVE package, atomically (a package without sessions or days left
   * is not touched). Packages without a session limit just count the use. Null when there is nothing to charge.
   */
  charge(memberId: string, today: string): Promise<ChargedMembership | null> {
    return sql.one(
      `UPDATE memberships
          SET used_sessions = used_sessions + 1, updated_at = now()
        WHERE member_id = $1 AND status = 'ACTIVE'
          AND (total_sessions IS NULL OR used_sessions < total_sessions)
          AND (end_date IS NULL OR end_date >= $2::date)
        RETURNING id, total_sessions, used_sessions`,
      [memberId, today],
    );
  }

  setAttendanceMembership(attendanceId: string, membershipId: string): Promise<number> {
    return sql.exec(`UPDATE attendances SET membership_id = $2 WHERE id = $1`, [attendanceId, membershipId]);
  }

  /** Real activity (not a login) feeds the inactivity batch. */
  touchActivity(memberId: string, at: Date): Promise<number> {
    return sql.exec(`UPDATE members SET last_activity_at = $2, updated_at = now() WHERE user_id = $1`, [memberId, at]);
  }
}

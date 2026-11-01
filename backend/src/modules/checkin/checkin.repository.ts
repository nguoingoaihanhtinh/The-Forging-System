import { sql } from '../../db/sql';

export interface CodeBranch {
  id: string;
  code: string;
  name: string;
  isActive: boolean;
  qrVersion: string | null;
  checkinSecret: string | null;
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
}

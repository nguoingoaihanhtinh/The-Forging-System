-- =====================================================================
-- 0010 - Snapshot of the member's standing when a rank is earned (RK-04)
--   * member_rank_history.snapshot = { dp, fromRank, monthsInFromRank } at the
--     moment of promotion, so "how long did they stay in the previous rank"
--     can be read back later even if the rules or the data change.
--   * Nullable on purpose: rows written before this migration, the initial
--     badge and demotions carry no snapshot.
-- =====================================================================

alter table member_rank_history add column snapshot jsonb;

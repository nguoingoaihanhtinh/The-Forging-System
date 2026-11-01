-- =====================================================================
-- 0011 - Secret behind the rotating branch check-in code (CHK-01)
--   * branches.checkin_secret signs the short-lived QR / manual codes shown at
--     the front desk. It is created on first use by the application (so
--     existing and new branches need no backfill) and never leaves the server.
--   * Rotating the branch QR (qr_version bump) already invalidates old codes,
--     because the version is part of what is signed.
-- =====================================================================

alter table branches add column checkin_secret text;

-- =====================================================================
-- 0005 - OTP moves from e-mail to SMS
--   email_verifications becomes phone_verifications: one row per OTP sent
--   to a phone number that has no account yet (local 0XXXXXXXXX form).
-- =====================================================================
alter table email_verifications rename to phone_verifications;
alter table phone_verifications rename column email to phone;
alter table phone_verifications alter column phone type text;
alter index ix_email_verifications_email rename to ix_phone_verifications_phone;

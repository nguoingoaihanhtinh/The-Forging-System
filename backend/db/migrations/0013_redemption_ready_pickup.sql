-- GFT-03: reception approval separates a redemption request from pickup.
-- READY_PICKUP still reserves stock and holds Marks until delivery/rejection.

alter table redemptions drop constraint if exists redemptions_status_check;
alter table redemptions add constraint redemptions_status_check
  check (status in ('PENDING_PICKUP','READY_PICKUP','DELIVERED','REJECTED','CANCELLED','EXPIRED'));

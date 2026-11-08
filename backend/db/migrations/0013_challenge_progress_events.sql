-- CHL-05: Each confirmed attendance may advance a participation once.
-- The source uniqueness makes event delivery/retry idempotent.
create table challenge_progress_events (
  id                       uuid primary key default gen_random_uuid(),
  tenant_id                uuid not null references tenants(id),
  challenge_participation_id uuid not null references challenge_participations(id),
  source_type              text not null check (source_type in ('ATTENDANCE_CONFIRMED')),
  source_id                uuid not null,
  delta                    int not null check (delta > 0),
  occurred_at              timestamptz not null,
  created_at               timestamptz not null default now(),
  unique (challenge_participation_id, source_type, source_id)
);

create index ix_challenge_progress_events_source
  on challenge_progress_events (source_type, source_id);

alter table challenge_progress_events enable row level security;
create policy tenant_isolation on challenge_progress_events
  using (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
  with check (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

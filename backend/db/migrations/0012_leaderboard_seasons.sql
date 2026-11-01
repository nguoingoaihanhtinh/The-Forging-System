-- =====================================================================
-- 0012 - Yearly DP leaderboard: seasons, Top 10 winners, DP-by-time index (LB-01)
--
--   leaderboard_seasons          one row per tenant and calendar year. The
--                                bounds are a half-open interval
--                                [starts_at, ends_at) in the academy's local
--                                time (Asia/Ho_Chi_Minh), so a point
--                                transaction belongs to a season when its
--                                occurred_at falls inside it.
--   leaderboard_season_winners   who won a prize when a season was closed.
--                                Competition ranking: members tied on DP share
--                                a position, so a season can hold more than ten
--                                rows when the 10th place is tied (LB-02 decides
--                                who is in). dp_total is frozen at closing and
--                                is the number the prize was decided on.
--   ix_point_tx_posted_dp_by_time covering index for "DP earned per member in a
--                                time range", the query behind the leaderboard.
--
-- Nothing here ranks anybody: the board itself is a query (LB-02). Which
-- sources count towards the yearly DP and how reversals are netted is also
-- decided there.
-- =====================================================================

create table leaderboard_seasons (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references tenants(id),
  season_year  smallint not null check (season_year between 2000 and 2200),
  starts_at    timestamptz not null,
  ends_at      timestamptz not null,
  status       text not null default 'ACTIVE' check (status in ('UPCOMING', 'ACTIVE', 'CLOSED')),
  closed_at    timestamptz,
  closed_by    uuid references users(id),            -- null = closed by the system
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (tenant_id, season_year),
  check (ends_at > starts_at),
  check ((status = 'CLOSED') = (closed_at is not null))
);

create table leaderboard_season_winners (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references tenants(id),
  season_id     uuid not null references leaderboard_seasons(id),
  member_id     uuid not null references members(user_id),
  rank_position smallint not null check (rank_position between 1 and 10),
  dp_total      int not null check (dp_total >= 0),
  prize         text,                                -- what the member wins, as agreed with the academy
  prize_status  text not null default 'PENDING' check (prize_status in ('PENDING', 'AWARDED', 'CANCELLED')),
  awarded_by    uuid references users(id),
  awarded_at    timestamptz,
  note          text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (season_id, member_id),
  check ((prize_status = 'AWARDED') = (awarded_at is not null))
);
create index ix_lb_winners_season on leaderboard_season_winners (season_id, rank_position);
create index ix_lb_winners_member on leaderboard_season_winners (member_id);

alter table leaderboard_seasons enable row level security;
create policy tenant_isolation on leaderboard_seasons
  using (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
  with check (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

alter table leaderboard_season_winners enable row level security;
create policy tenant_isolation on leaderboard_season_winners
  using (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
  with check (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

-- Yearly DP = SUM(dp_amount) of POSTED transactions in [starts_at, ends_at) per member.
-- The partial index skips pending / rejected rows and the many zero-DP ones (redemptions, Marks-only).
create index ix_point_tx_posted_dp_by_time on point_transactions (occurred_at)
  include (member_id, dp_amount)
  where status = 'POSTED' and dp_amount <> 0;

-- The season in progress exists from day one; later years are created by the closing / yearly job (LB-02 and after).
insert into leaderboard_seasons (tenant_id, season_year, starts_at, ends_at, status)
select t.id,
       y.season_year,
       make_timestamptz(y.season_year, 1, 1, 0, 0, 0, 'Asia/Ho_Chi_Minh'),
       make_timestamptz(y.season_year + 1, 1, 1, 0, 0, 0, 'Asia/Ho_Chi_Minh'),
       'ACTIVE'
  from tenants t
 cross join (select extract(year from (now() at time zone 'Asia/Ho_Chi_Minh'))::int as season_year) y
on conflict (tenant_id, season_year) do nothing;

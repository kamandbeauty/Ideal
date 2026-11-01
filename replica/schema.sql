-- کاخ شازده (Prince's Palace) — schema v1, core-loop slice
-- Postgres 15+. One database, one writer (the API), no client-side SQL access.
-- Conventions: uuid pks, timestamptz in UTC, integer cents + currency code,
-- money-like counters as bigint with a >= 0 check, append-only ledger.
-- Royal Kingdom's schema is not public; this is built from replica/recon.md only.

-- gen_random_uuid() is core since Postgres 13; no extension needed.

-- ---------------------------------------------------------------------------
-- enums
-- ---------------------------------------------------------------------------
create type platform_t        as enum ('ios','android');
create type auth_provider_t   as enum ('guest','google_play_games','game_center','apple','facebook');
create type level_type_t      as enum ('normal','hard','super_hard','kingdom','dark_kingdom');
create type attempt_result_t  as enum ('win','lose','quit');
create type booster_place_t   as enum ('pre_level','in_game');
create type chest_source_t    as enum ('district','level','event');
create type store_t           as enum ('app_store','play_store');
create type tx_state_t        as enum ('pending','granted','refunded','failed');
create type currency_t        as enum ('coins','potions');
create type ledger_reason_t   as enum ('level_reward','task_spend','district_refund','extra_moves',
                                        'booster_purchase','life_refill','chest_claim','iap_grant',
                                        'iap_refund','admin_adjust');

-- ---------------------------------------------------------------------------
-- identity
-- ---------------------------------------------------------------------------
create table players (
  id               uuid primary key default gen_random_uuid(),
  display_name     text not null check (char_length(display_name) between 3 and 20),
  avatar_id        text not null default 'avatar_01',
  coins            bigint not null default 0 check (coins >= 0),
  potions          bigint not null default 0 check (potions >= 0),
  lives            smallint not null default 5 check (lives >= 0),
  max_lives        smallint not null default 5 check (max_lives between 1 and 8),
  lives_updated_at timestamptz not null default now(),   -- refill is computed from this
  level_number     integer not null default 1 check (level_number >= 1),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz                            -- soft delete, purged after 30 days
);
create unique index players_name_lower_uniq on players (lower(display_name)) where deleted_at is null;

create table devices (
  id           uuid primary key default gen_random_uuid(),
  player_id    uuid not null references players(id) on delete cascade,
  install_id   text not null,                 -- client-generated, survives reinstall only in backup
  platform     platform_t not null,
  app_version  text not null,
  os_version   text,
  first_seen_at timestamptz not null default now(),
  last_seen_at  timestamptz not null default now()
);
create unique index devices_install_uniq on devices (install_id);
create index devices_player_idx on devices (player_id);

create table auth_identities (
  id         uuid primary key default gen_random_uuid(),
  player_id  uuid not null references players(id) on delete cascade,
  provider   auth_provider_t not null,
  subject    text not null,                  -- provider's stable user id
  created_at timestamptz not null default now(),
  unique (provider, subject)                 -- one identity maps to exactly one player
);
create index auth_identities_player_idx on auth_identities (player_id);

create table refresh_tokens (
  id          uuid primary key default gen_random_uuid(),
  player_id   uuid not null references players(id) on delete cascade,
  device_id   uuid references devices(id) on delete cascade,
  token_hash  text not null,
  expires_at  timestamptz not null,
  revoked_at  timestamptz,
  created_at  timestamptz not null default now()
);
create unique index refresh_tokens_hash_uniq on refresh_tokens (token_hash);
create index refresh_tokens_player_idx on refresh_tokens (player_id) where revoked_at is null;

create table player_settings (
  player_id     uuid primary key references players(id) on delete cascade,
  music_on      boolean not null default true,
  sfx_on        boolean not null default true,
  haptics_on    boolean not null default true,
  push_on       boolean not null default true,
  updated_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- content: kingdoms, districts, tasks, levels  (server-driven, no client CDN edits)
-- ---------------------------------------------------------------------------
create table kingdoms (
  id                 uuid primary key default gen_random_uuid(),
  slug               text not null unique,
  order_index        integer not null unique check (order_index >= 1),
  title              text not null,
  unlocked_after_level integer not null default 1,
  created_at         timestamptz not null default now()
);

create table districts (
  id           uuid primary key default gen_random_uuid(),
  kingdom_id   uuid not null references kingdoms(id) on delete cascade,
  order_index  integer not null check (order_index >= 1),
  title        text not null,
  chest_reward jsonb not null default '{}'::jsonb,   -- {coins, potions, boosters:{kind:count}}
  unique (kingdom_id, order_index)
);

create table tasks (
  id            uuid primary key default gen_random_uuid(),
  district_id   uuid not null references districts(id) on delete cascade,
  order_index   integer not null check (order_index >= 1),
  title         text not null,
  potion_cost   integer not null check (potion_cost > 0),
  build_asset   text not null,                        -- Addressables key, not a path
  unique (district_id, order_index)
);
create index tasks_district_idx on tasks (district_id);

create table levels (
  id             uuid primary key default gen_random_uuid(),
  number         integer not null unique check (number >= 1),
  type           level_type_t not null default 'normal',
  kingdom_id     uuid references kingdoms(id) on delete set null,
  move_limit     smallint not null check (move_limit between 5 and 100),
  stages         smallint not null default 1 check (stages between 1 and 5),
  board          jsonb not null,                       -- grid, obstacles, goals, boss layout
  goals          jsonb not null,                       -- [{kind:'clear',item:'box',count:12}]
  reward_potions integer not null default 0 check (reward_potions >= 0),
  reward_coins   integer not null default 0 check (reward_coins >= 0),
  released_batch integer not null default 1,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now()
);
create index levels_kingdom_idx on levels (kingdom_id);
create index levels_batch_idx on levels (released_batch) where is_active;

create table level_batches (
  id         uuid primary key default gen_random_uuid(),
  batch_no   integer not null unique,
  level_from integer not null,
  level_to   integer not null,
  released_at timestamptz not null default now(),
  check (level_to >= level_from)
);

create table episodes (
  id          uuid primary key default gen_random_uuid(),
  kingdom_id  uuid not null references kingdoms(id) on delete cascade,
  title       text not null,
  media_key   text not null unique,                   -- CDN object key, signed on read
  duration_ms integer not null check (duration_ms > 0)
);
create index episodes_kingdom_idx on episodes (kingdom_id);

create table booster_catalog (
  id                   uuid primary key default gen_random_uuid(),
  kind                 text not null unique,           -- hammer, battle_ram, drill, wizard_hat, bomber_plane, rocket, dynamite, electro_ball
  display_name         text not null,
  placement            booster_place_t not null,
  price_coins          integer check (price_coins >= 0),
  unlocked_after_level integer not null default 1
);

create table magic_pots (
  id           uuid primary key default gen_random_uuid(),
  tier         smallint not null check (tier between 1 and 5),
  threshold    integer not null check (threshold > 0),   -- levels to fill
  rewards      jsonb not null,
  unlocked_after_level integer not null default 32,
  unique (tier)
);

-- ---------------------------------------------------------------------------
-- player progress
-- ---------------------------------------------------------------------------
create table level_progress (
  player_id       uuid not null references players(id) on delete cascade,
  level_id        uuid not null references levels(id) on delete cascade,
  attempts_count  integer not null default 0,
  best_moves_left smallint,
  first_cleared_at timestamptz,
  last_played_at  timestamptz not null default now(),
  primary key (player_id, level_id)
);
create index level_progress_level_idx on level_progress (level_id);

create table district_progress (
  player_id       uuid not null references players(id) on delete cascade,
  district_id     uuid not null references districts(id) on delete cascade,
  unlocked_at     timestamptz not null default now(),
  completed_at    timestamptz,
  chest_claimed_at timestamptz,
  primary key (player_id, district_id)
);
create index district_progress_district_idx on district_progress (district_id);

create table task_completions (
  player_id    uuid not null references players(id) on delete cascade,
  task_id      uuid not null references tasks(id) on delete cascade,
  potions_spent integer not null check (potions_spent > 0),
  completed_at timestamptz not null default now(),
  primary key (player_id, task_id)                     -- the potion sink cannot double-charge
);
create index task_completions_task_idx on task_completions (task_id);

create table booster_inventory (
  player_id  uuid not null references players(id) on delete cascade,
  booster_id uuid not null references booster_catalog(id) on delete cascade,
  count      integer not null default 0 check (count >= 0),
  primary key (player_id, booster_id)
);

create table episode_views (
  player_id  uuid not null references players(id) on delete cascade,
  episode_id uuid not null references episodes(id) on delete cascade,
  watched_at timestamptz not null default now(),
  primary key (player_id, episode_id)
);

create table magic_pot_progress (
  player_id uuid not null references players(id) on delete cascade,
  pot_id    uuid not null references magic_pots(id) on delete cascade,
  progress  integer not null default 0 check (progress >= 0),
  claimed_at timestamptz,
  primary key (player_id, pot_id)
);

-- ---------------------------------------------------------------------------
-- attempts  (server-seeded, deterministic, replayable)
-- ---------------------------------------------------------------------------
create table attempts (
  id              uuid primary key default gen_random_uuid(),
  player_id       uuid not null references players(id) on delete cascade,
  level_id        uuid not null references levels(id) on delete restrict,
  seed            bigint not null,                     -- board RNG seed, issued by the server
  started_at      timestamptz not null default now(),
  ended_at        timestamptz,
  result          attempt_result_t,
  moves_used      smallint check (moves_used >= 0),
  extra_moves_bought smallint not null default 0,
  boosters_used   text[] not null default '{}',
  potions_awarded integer not null default 0,
  coins_awarded   integer not null default 0,
  verified        boolean not null default false,      -- server replayed the move log
  replay_hash     text,
  client_version  text not null,
  check (ended_at is null or ended_at >= started_at),
  check (ended_at is null or result is not null)
);
create index attempts_player_idx on attempts (player_id, started_at desc);
create index attempts_open_idx on attempts (player_id) where ended_at is null;
create index attempts_level_idx on attempts (level_id);

create table attempt_moves (
  attempt_id uuid not null references attempts(id) on delete cascade,
  seq        smallint not null check (seq >= 0),
  kind       text not null check (kind in ('swap','booster','extra_moves','shuffle')),
  payload    jsonb not null,                            -- {"from":[r,c],"to":[r,c]} etc
  client_ms  integer not null check (client_ms >= 0),
  primary key (attempt_id, seq)
);

-- ---------------------------------------------------------------------------
-- money: catalog, purchases, append-only ledger
-- ---------------------------------------------------------------------------
create table products (
  id          uuid primary key default gen_random_uuid(),
  sku         text not null unique,
  kind        text not null check (kind in ('coin_pack','bundle')),
  coins       integer not null default 0 check (coins >= 0),
  boosters    jsonb not null default '{}'::jsonb,
  price_cents integer not null check (price_cents >= 0),
  currency    char(3) not null default 'EUR',
  badge       text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

create table transactions (
  id                   uuid primary key default gen_random_uuid(),
  player_id            uuid not null references players(id) on delete restrict,
  product_id           uuid not null references products(id) on delete restrict,
  store                store_t not null,
  store_transaction_id text not null,
  state                tx_state_t not null default 'pending',
  purchased_at         timestamptz not null default now(),
  granted_at           timestamptz,
  refunded_at          timestamptz,
  receipt_ref          text,                            -- reference into RevenueCat, not the blob
  unique (store, store_transaction_id)                  -- webhook replays land here, not in the wallet
);
create index transactions_player_idx on transactions (player_id, purchased_at desc);
create index transactions_state_idx on transactions (state) where state = 'pending';

create table chest_grants (
  id         uuid primary key default gen_random_uuid(),
  player_id  uuid not null references players(id) on delete cascade,
  source     chest_source_t not null,
  source_id  uuid not null,                             -- district/level id
  rewards    jsonb not null,
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (player_id, source, source_id)                 -- one chest per source per player
);
create index chest_grants_player_idx on chest_grants (player_id, claimed_at);

create table ledger_entries (
  id            bigserial primary key,
  player_id     uuid not null references players(id) on delete restrict,
  currency      currency_t not null,
  delta         bigint not null check (delta <> 0),
  balance_after bigint not null check (balance_after >= 0),
  reason        ledger_reason_t not null,
  ref_type      text,
  ref_id        uuid,
  created_at    timestamptz not null default now()
);
create index ledger_player_idx on ledger_entries (player_id, created_at desc);
create index ledger_ref_idx on ledger_entries (ref_type, ref_id);

create function ledger_append_only() returns trigger language plpgsql as $$
begin
  raise exception 'ledger_entries is append-only';
end $$;

create trigger ledger_no_update before update or delete on ledger_entries
for each row execute function ledger_append_only();

create table push_tokens (
  id         uuid primary key default gen_random_uuid(),
  player_id  uuid not null references players(id) on delete cascade,
  token      text not null unique,                 -- FCM or APNs token
  platform   platform_t not null,
  created_at timestamptz not null default now(),
  last_used_at timestamptz
);
create index push_tokens_player_idx on push_tokens (player_id);

-- every wallet-touching route takes an Idempotency-Key: retries must not double-spend.
create table idempotency_keys (
  player_id    uuid not null references players(id) on delete cascade,
  key          text not null,
  route        text not null,
  request_hash text not null,
  response     jsonb not null,
  created_at   timestamptz not null default now(),
  primary key (player_id, key)
);
create index idempotency_age_idx on idempotency_keys (created_at);

-- ---------------------------------------------------------------------------
-- ops
-- ---------------------------------------------------------------------------
create table server_config (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);

create table admin_actions (
  id         bigserial primary key,
  actor      text not null,                 -- operator email / service name
  action     text not null,
  target     text,
  detail     jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- views the API leans on
-- ---------------------------------------------------------------------------
create view player_wallet as
  select p.id as player_id, p.coins, p.potions, p.lives, p.max_lives,
         p.lives_updated_at,
         least(p.max_lives,
               p.lives + floor(extract(epoch from (now() - p.lives_updated_at)) / 1800)::smallint
         ) as lives_now
  from players p;

-- ledger must always reconcile with the wallet: run this nightly.
create view ledger_drift as
  select p.id as player_id,
         p.coins, coalesce(sum(l.delta) filter (where l.currency = 'coins'), 0)   as ledger_coins,
         p.potions, coalesce(sum(l.delta) filter (where l.currency = 'potions'), 0) as ledger_potions
  from players p left join ledger_entries l on l.player_id = p.id
  group by p.id, p.coins, p.potions
  having p.coins <> coalesce(sum(l.delta) filter (where l.currency = 'coins'), 0)
      or p.potions <> coalesce(sum(l.delta) filter (where l.currency = 'potions'), 0);

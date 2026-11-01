-- Constraints smoke test for replica/schema.sql.
-- Runs inside a transaction and rolls back: safe to execute on any database
-- that already has the schema. Exits non-zero (via RAISE) on the first broken rule.
--
--   psql -v ON_ERROR_STOP=1 -f replica/schema.sql
--   psql -v ON_ERROR_STOP=1 -f replica/db/smoke.sql

begin;

-- minimal content so the foreign keys are real
insert into kingdoms (slug, order_index, title) values ('test-city', 1, 'شهر آزمایش');
insert into districts (kingdom_id, order_index, title)
  select id, 1, 'دیستریکت آزمایش' from kingdoms where slug = 'test-city';
insert into tasks (district_id, order_index, title, potion_cost, build_asset)
  select id, 1, 'ساختن حوض', 25, 'ch01_build_pool' from districts limit 1;
insert into levels (number, type, move_limit, board, goals, reward_potions, reward_coins)
  values (1, 'normal', 20, '{"grid":"9x9"}'::jsonb, '[{"kind":"clear","item":"crate","count":6}]'::jsonb, 12, 20);
insert into players (display_name) values ('Smoke Test');
insert into products (sku, kind, coins, price_cents) values ('coins_small', 'coin_pack', 500, 199);

-- 1. lives are computed from lives_updated_at, never scheduled
do $$
declare n smallint;
begin
  select lives_now into n from player_wallet limit 1;
  if n <> 5 then raise exception 'lives_now expected 5, got %', n; end if;
end $$;

-- 2. the wallet cannot go negative
do $$
begin
  begin
    update players set coins = -1;
    raise exception 'negative coins were accepted';
  exception when check_violation then null;
  end;
end $$;

-- 3. the ledger is append-only
insert into ledger_entries (player_id, currency, delta, balance_after, reason)
  select id, 'coins', 20, 20, 'admin_adjust' from players limit 1;

-- the wallet column is written in the same transaction as the ledger row
update players set coins = 20;

do $$
begin
  begin
    update ledger_entries set delta = 21;
    raise exception 'ledger update was allowed';
  exception when others then
    if sqlerrm <> 'ledger_entries is append-only' then raise; end if;
  end;
end $$;

-- 4. one store transaction cannot be granted twice
insert into transactions (player_id, product_id, store, store_transaction_id)
  select p.id, pr.id, 'play_store', 'GPA.0000-test'
  from players p, products pr limit 1;

do $$
begin
  begin
    insert into transactions (player_id, product_id, store, store_transaction_id)
      select p.id, pr.id, 'play_store', 'GPA.0000-test'
      from players p, products pr limit 1;
    raise exception 'duplicate store transaction was accepted';
  exception when unique_violation then null;
  end;
end $$;

-- 5. a district chest cannot be claimed twice
insert into chest_grants (player_id, source, source_id, rewards)
  select p.id, 'district', d.id, '{"coins":100,"potions":10}'::jsonb
  from players p, districts d limit 1;

do $$
begin
  begin
    insert into chest_grants (player_id, source, source_id, rewards)
      select p.id, 'district', d.id, '{"coins":100}'::jsonb
      from players p, districts d limit 1;
    raise exception 'duplicate chest claim was accepted';
  exception when unique_violation then null;
  end;
end $$;

-- 6. the potion sink cannot double-charge one task
insert into task_completions (player_id, task_id, potions_spent)
  select p.id, t.id, t.potion_cost from players p, tasks t limit 1;

do $$
begin
  begin
    insert into task_completions (player_id, task_id, potions_spent)
      select p.id, t.id, t.potion_cost from players p, tasks t limit 1;
    raise exception 'double task completion was accepted';
  exception when unique_violation then null;
  end;
end $$;

-- 7. an attempt cannot be finished without a result, nor end before it started
do $$
begin
  begin
    insert into attempts (player_id, level_id, seed, client_version, ended_at)
      select p.id, l.id, 42, '0.0.1-test', now() from players p, levels l limit 1;
    raise exception 'attempt closed without a result was accepted';
  exception when check_violation then null;
  end;
end $$;

-- 8. wallet and ledger agree while the smoke data is in place
do $$
declare drift int;
begin
  select count(*) into drift from ledger_drift where player_id in (select id from players);
  if drift <> 0 then raise exception 'wallet/ledger drift detected on % player(s)', drift; end if;
end $$;

select 'schema smoke: all 8 checks passed' as result;

rollback;

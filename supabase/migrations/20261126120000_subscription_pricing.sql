-- Pricing configuration only. No purchase, payment confirmation or entitlement is created here.
create table public.app_admins (user_id uuid primary key references auth.users(id) on delete cascade, created_at timestamptz not null default now());
create table public.subscription_plans (
 id uuid primary key default gen_random_uuid(),
 title text not null check (length(btrim(title)) between 1 and 100),
 duration_days integer not null check (duration_days between 1 and 1095),
 unit_price_toman bigint not null check (unit_price_toman between 1 and 1000000000),
 active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.subscription_plan_audit (id uuid primary key default gen_random_uuid(),plan_id uuid not null references public.subscription_plans(id),actor_id uuid not null references auth.users(id),old_values jsonb,new_values jsonb not null,created_at timestamptz not null default now());
alter table public.subscription_plan_audit enable row level security;
revoke all on public.subscription_plan_audit from public,anon,authenticated;
alter table public.app_admins enable row level security;
alter table public.subscription_plans enable row level security;
revoke all on public.app_admins,public.subscription_plans from public,anon,authenticated;

create function public.is_app_admin() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.app_admins where user_id=auth.uid());
$$;
create function public.list_subscription_plans_admin() returns table(id uuid,title text,duration_days integer,unit_price_toman bigint,active boolean)
language plpgsql stable security definer set search_path='' as $$ begin
 if not public.is_app_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 return query select p.id,p.title,p.duration_days,p.unit_price_toman,p.active from public.subscription_plans p order by p.created_at desc,p.id;
end $$;
create function public.save_subscription_plan(plan_id uuid,p_title text,p_days integer,p_price bigint,p_active boolean) returns uuid
language plpgsql security definer set search_path='' as $$
declare pid uuid; prior public.subscription_plans%rowtype; begin
 if not public.is_app_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 if p_title is null or length(btrim(p_title)) not between 1 and 100 or p_days is null or p_days not between 1 and 1095 or p_price is null or p_price not between 1 and 1000000000 or p_active is null then raise exception 'Invalid plan'; end if;
 if plan_id is null then
  insert into public.subscription_plans(title,duration_days,unit_price_toman,active) values(btrim(p_title),p_days,p_price,p_active) returning id into pid;
 else
  select * into prior from public.subscription_plans where id=plan_id for update;
  if not found then raise exception 'Plan not found'; end if;
  update public.subscription_plans set title=btrim(p_title),duration_days=p_days,unit_price_toman=p_price,active=p_active,updated_at=now() where id=plan_id returning id into pid;
  if not found then raise exception 'Plan not found'; end if;
 end if;
 insert into public.subscription_plan_audit(plan_id,actor_id,old_values,new_values) select pid,auth.uid(),case when plan_id is null then null else to_jsonb(prior) end,to_jsonb(p) from public.subscription_plans p where p.id=pid;
 return pid;
end $$;
create function public.quote_subscription_plans(b uuid) returns table(plan_id uuid,title text,duration_days integer,unit_count bigint,unit_price_toman bigint,total_toman bigint)
language plpgsql stable security definer set search_path='' as $$ begin
 if auth.uid() is null or not public.has_building_role(b,array['manager']::public.building_role[]) then raise exception 'Not authorized' using errcode='42501'; end if;
 return query select p.id,p.title,p.duration_days,c.n,p.unit_price_toman,c.n*p.unit_price_toman from public.subscription_plans p cross join lateral (select count(*) n from public.units u where u.building_id=b) c where p.active order by p.duration_days,p.id;
end $$;
revoke all on function public.is_app_admin(),public.list_subscription_plans_admin(),public.save_subscription_plan(uuid,text,integer,bigint,boolean),public.quote_subscription_plans(uuid) from public,anon;
grant execute on function public.is_app_admin(),public.list_subscription_plans_admin(),public.save_subscription_plan(uuid,text,integer,bigint,boolean),public.quote_subscription_plans(uuid) to authenticated;

-- Foundation only: no financial operations are exposed until the accounting stage.
create extension if not exists pgcrypto;
create type public.building_role as enum ('manager','accountant','resident','owner','maintenance');
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '' check (length(full_name) <= 120),
 created_at timestamptz not null default now()
);
create table public.buildings (
 id uuid primary key default gen_random_uuid(),
 name text not null check (length(btrim(name)) between 1 and 120),
 address text not null default '' check (length(address) <= 500),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
create table public.building_members (
 id uuid primary key default gen_random_uuid(),
 building_id uuid not null references public.buildings(id),
 user_id uuid not null references auth.users(id),
 role public.building_role not null,
 created_at timestamptz not null default now(),
 unique(building_id,user_id,role)
);
create table public.units (
 id uuid primary key default gen_random_uuid(),
 building_id uuid not null references public.buildings(id),
 number text not null check (length(btrim(number)) between 1 and 40),
 block text not null default '', floor text not null default '',
 area numeric(10,2) not null default 0 check (area >= 0),
 occupants integer not null default 0 check (occupants >= 0),
 parking integer not null default 0 check (parking >= 0),
 storage integer not null default 0 check (storage >= 0),
 notes text not null default '', created_at timestamptz not null default now(),
 unique(building_id,number), unique(building_id,id)
);
create table public.unit_residents (
 id uuid primary key default gen_random_uuid(),
 building_id uuid not null references public.buildings(id),
 unit_id uuid not null,
 user_id uuid references auth.users(id),
 full_name text not null check (length(btrim(full_name)) between 1 and 120),
 phone text not null default '' check (length(phone) <= 30),
 kind text not null check (kind in ('owner','tenant')),
 starts_on date, ends_on date,
 check (ends_on is null or starts_on is null or ends_on >= starts_on),
 foreign key (building_id,unit_id) references public.units(building_id,id)
);
create index on public.building_members(user_id,building_id);
create index on public.unit_residents(user_id,building_id,unit_id);
create index on public.units(building_id);
-- Privileged helpers have a fixed search_path and only return authorization facts.
create function public.has_building_role(b uuid, roles public.building_role[]) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.building_members m where m.building_id=b and m.user_id=auth.uid() and m.role=any(roles));
$$;
create function public.is_unit_resident(b uuid, u uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.unit_residents r join public.building_members m on m.building_id=r.building_id and m.user_id=r.user_id and m.role in ('resident','owner') where r.building_id=b and r.unit_id=u and r.user_id=auth.uid() and (r.starts_on is null or r.starts_on<=current_date) and (r.ends_on is null or r.ends_on>=current_date));
$$;
revoke all on function public.has_building_role(uuid,public.building_role[]) from public;
revoke all on function public.is_unit_resident(uuid,uuid) from public;
grant execute on function public.has_building_role(uuid,public.building_role[]) to authenticated;
grant execute on function public.is_unit_resident(uuid,uuid) to authenticated;
alter table public.profiles enable row level security;
alter table public.buildings enable row level security;
alter table public.building_members enable row level security;
alter table public.units enable row level security;
alter table public.unit_residents enable row level security;
create policy profile_self on public.profiles for all to authenticated using (id=auth.uid()) with check (id=auth.uid());
create policy buildings_read on public.buildings for select to authenticated using (public.has_building_role(id,enum_range(null::public.building_role)));
create policy buildings_update on public.buildings for update to authenticated using (public.has_building_role(id,array['manager']::public.building_role[])) with check (public.has_building_role(id,array['manager']::public.building_role[]));
create policy members_read on public.building_members for select to authenticated using (user_id=auth.uid() or public.has_building_role(building_id,array['manager']::public.building_role[]));
create policy units_read on public.units for select to authenticated using (public.has_building_role(building_id,array['manager','accountant']::public.building_role[]) or public.is_unit_resident(building_id,id));
create policy units_insert on public.units for insert to authenticated with check (public.has_building_role(building_id,array['manager']::public.building_role[]));
create policy units_update on public.units for update to authenticated using (public.has_building_role(building_id,array['manager']::public.building_role[])) with check (public.has_building_role(building_id,array['manager']::public.building_role[]));
create policy residents_read on public.unit_residents for select to authenticated using (public.has_building_role(building_id,array['manager','accountant']::public.building_role[]) or user_id=auth.uid());
create policy residents_insert on public.unit_residents for insert to authenticated with check (public.has_building_role(building_id,array['manager']::public.building_role[]) and user_id is null);
create policy residents_update on public.unit_residents for update to authenticated using (public.has_building_role(building_id,array['manager']::public.building_role[])) with check (public.has_building_role(building_id,array['manager']::public.building_role[]) and user_id is null);
-- The creator and manager membership are created atomically; direct membership writes are denied.
create function public.create_building(p_name text,p_address text default '') returns uuid
language plpgsql security definer set search_path = '' as $$
declare new_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if length(btrim(coalesce(p_name,''))) not between 1 and 120 or length(coalesce(p_address,''))>500 then raise exception 'Invalid building details'; end if;
 insert into public.buildings(name,address,created_by) values (btrim(p_name),coalesce(p_address,''),auth.uid()) returning id into new_id;
 insert into public.building_members(building_id,user_id,role) values(new_id,auth.uid(),'manager');
 return new_id;
end $$;
revoke all on function public.create_building(text,text) from public;
grant execute on function public.create_building(text,text) to authenticated;

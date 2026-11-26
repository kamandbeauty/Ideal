-- Facilities module: all amounts in integer tomans; no file storage in this migration.
create table public.common_spaces (
 id uuid primary key default gen_random_uuid(), building_id uuid not null references public.buildings(id),
 name text not null check(length(btrim(name)) between 1 and 120), description text not null default '' check(length(description)<=2000),
 status text not null default 'active' check(status in ('active','inactive','maintenance')),
 caretaker text not null default '' check(length(caretaker)<=120), last_inspected_on date, next_service_on date,
 created_at timestamptz not null default now(), unique(building_id,id)
);
create table public.reservation_rules (
 id uuid primary key default gen_random_uuid(), building_id uuid not null, space_id uuid not null unique,
 allowed_days smallint[] not null check(cardinality(allowed_days)>0 and allowed_days <@ array[0,1,2,3,4,5,6]::smallint[]),
 opens_at time not null, closes_at time not null, capacity integer not null check(capacity between 1 and 10000),
 fee bigint not null default 0 check(fee>=0 and fee<=1000000000000), max_active_per_unit integer not null default 1 check(max_active_per_unit between 1 and 100),
 requires_approval boolean not null default true, check(opens_at<closes_at), foreign key(building_id,space_id) references public.common_spaces(building_id,id)
);
create table public.space_reservations (
 id uuid primary key default gen_random_uuid(), building_id uuid not null, space_id uuid not null, unit_id uuid not null,
 requested_by uuid not null references auth.users(id), starts_at timestamptz not null, ends_at timestamptz not null,
 guests integer not null check(guests>0), fee_snapshot bigint not null check(fee_snapshot>=0),
 status text not null check(status in ('pending','approved','rejected','cancelled')), created_at timestamptz not null default now(), check(starts_at<ends_at),
 foreign key(building_id,space_id) references public.common_spaces(building_id,id), foreign key(building_id,unit_id) references public.units(building_id,id)
);
create index on public.space_reservations(building_id,space_id,starts_at,ends_at);
create table public.contractors (
 id uuid primary key default gen_random_uuid(), building_id uuid not null references public.buildings(id),
 name text not null check(length(btrim(name)) between 1 and 120), phone text not null default '' check(length(phone)<=30),
 specialty text not null default '' check(length(specialty)<=120), company text not null default '' check(length(company)<=200), notes text not null default '' check(length(notes)<=2000), unique(building_id,id)
);
create table public.assets (
 id uuid primary key default gen_random_uuid(), building_id uuid not null references public.buildings(id), name text not null check(length(btrim(name)) between 1 and 120),
 category text not null default '' check(length(category)<=120), serial_number text not null default '' check(length(serial_number)<=120), purchased_on date,
 purchase_price bigint check(purchase_price>=0 and purchase_price<=1000000000000), warranty_until date, location text not null default '' check(length(location)<=200),
 status text not null default 'active' check(status in ('active','maintenance','retired')), description text not null default '' check(length(description)<=2000), unique(building_id,id)
);
create table public.service_schedules (
 id uuid primary key default gen_random_uuid(), building_id uuid not null, asset_id uuid not null, title text not null check(length(btrim(title)) between 1 and 120),
 interval_days integer not null check(interval_days between 1 and 3650), next_due_on date not null, active boolean not null default true,
 foreign key(building_id,asset_id) references public.assets(building_id,id)
);
create table public.maintenance_requests (
 id uuid primary key default gen_random_uuid(), building_id uuid not null references public.buildings(id), unit_id uuid,
 asset_id uuid, space_id uuid, contractor_id uuid, requested_by uuid not null references auth.users(id), title text not null check(length(btrim(title)) between 1 and 150),
 category text not null check(category in ('elevator','parking','plumbing','electrical','cleaning','mechanical','other')),
 description text not null check(length(btrim(description)) between 1 and 3000), priority text not null default 'normal' check(priority in ('low','normal','high','urgent')),
 status text not null default 'new' check(status in ('new','review','approved','in_progress','completed','rejected')),
 manager_response text not null default '' check(length(manager_response)<=2000), assigned_to text not null default '' check(length(assigned_to)<=120),
 created_at timestamptz not null default now(), completed_at timestamptz, unique(building_id,id),
 foreign key(building_id,unit_id) references public.units(building_id,id), foreign key(building_id,asset_id) references public.assets(building_id,id),
 foreign key(building_id,space_id) references public.common_spaces(building_id,id), foreign key(building_id,contractor_id) references public.contractors(building_id,id)
);
create table public.maintenance_costs (
 id uuid primary key default gen_random_uuid(), building_id uuid not null, maintenance_id uuid not null, expense_id uuid not null unique,
 created_at timestamptz not null default now(), foreign key(building_id,maintenance_id) references public.maintenance_requests(building_id,id),
 foreign key(building_id,expense_id) references public.expenses(building_id,id)
);
create index on public.maintenance_requests(building_id,status,created_at);
create index on public.service_schedules(building_id,next_due_on) where active;
create function public.has_active_unit(b uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.unit_residents r where r.building_id=b and r.user_id=auth.uid() and public.is_unit_resident(b,r.unit_id));
$$;
revoke all on function public.has_active_unit(uuid) from public,anon;
grant execute on function public.has_active_unit(uuid) to authenticated;
do $$ declare t text; begin foreach t in array array['common_spaces','reservation_rules','space_reservations','contractors','assets','service_schedules','maintenance_requests','maintenance_costs'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated',t);
 execute format('grant select on public.%I to authenticated',t);
 end loop; end $$;
create policy spaces_read on public.common_spaces for select to authenticated using (public.has_building_role(building_id,array['manager','accountant','maintenance']::public.building_role[]) or (status='active' and public.has_active_unit(building_id)));
create policy rules_read on public.reservation_rules for select to authenticated using (public.has_building_role(building_id,array['manager','accountant','maintenance']::public.building_role[]) or (public.has_active_unit(building_id) and exists(select 1 from public.common_spaces s where s.id=space_id and s.building_id=reservation_rules.building_id and s.status='active')));
create policy reservations_read on public.space_reservations for select to authenticated using (public.has_building_role(building_id,array['manager']::public.building_role[]) or public.is_unit_resident(building_id,unit_id));
create policy contractors_read on public.contractors for select to authenticated using (public.has_building_role(building_id,array['manager','accountant']::public.building_role[]));
create policy assets_read on public.assets for select to authenticated using (public.has_building_role(building_id,array['manager','accountant','maintenance']::public.building_role[]));
create policy schedules_read on public.service_schedules for select to authenticated using (public.has_building_role(building_id,array['manager','maintenance']::public.building_role[]));
create policy maintenance_read on public.maintenance_requests for select to authenticated using (public.has_building_role(building_id,array['manager']::public.building_role[]) or (unit_id is not null and public.is_unit_resident(building_id,unit_id)));
create policy costs_read on public.maintenance_costs for select to authenticated using (public.has_building_role(building_id,array['manager','accountant']::public.building_role[]));
-- Catalog edits are only available to a building manager. Financial and workflow tables are RPC-only.
do $$ declare t text; begin foreach t in array array['common_spaces','reservation_rules','contractors','assets','service_schedules'] loop
 execute format('grant insert,update on public.%I to authenticated',t);
 execute format('create policy manager_insert on public.%I for insert to authenticated with check(public.has_building_role(building_id,array[''manager'']::public.building_role[]))',t);
 execute format('create policy manager_update on public.%I for update to authenticated using(public.has_building_role(building_id,array[''manager'']::public.building_role[])) with check(public.has_building_role(building_id,array[''manager'']::public.building_role[]))',t);
 end loop; end $$;
-- Exclusive lock per space makes availability validation and insertion atomic even across requests.
-- Slots use Tehran civil time and must fit wholly within one allowed local day.
create function public.reserve_space(b uuid,s uuid,u uuid,starts timestamptz,ends timestamptz,guest_count integer) returns uuid
language plpgsql security definer set search_path='' as $$
declare r public.reservation_rules%rowtype; sid uuid; local_start timestamp; local_end timestamp; begin
 if auth.uid() is null or not public.is_unit_resident(b,u) then raise exception 'Not authorized' using errcode='42501'; end if;
 if starts is null or ends is null or starts<=now() or ends<=starts or guest_count is null then raise exception 'Invalid reservation'; end if;
 perform pg_advisory_xact_lock(hashtextextended(s::text,3));
 if not exists(select 1 from public.common_spaces where building_id=b and id=s and status='active') then raise exception 'Space is unavailable'; end if;
 select * into r from public.reservation_rules where building_id=b and space_id=s;
 if not found then raise exception 'No reservation rules'; end if;
 if r.fee<>0 then raise exception 'Paid reservations are not supported'; end if;
 local_start:=starts at time zone 'Asia/Tehran'; local_end:=ends at time zone 'Asia/Tehran';
 if local_start::date<>local_end::date or not extract(dow from local_start)::smallint=any(r.allowed_days) or local_start::time<r.opens_at or local_end::time>r.closes_at or guest_count<1 or guest_count>r.capacity then raise exception 'Reservation violates rules'; end if;
 if (select count(*) from public.space_reservations x where x.building_id=b and x.space_id=s and x.unit_id=u and x.status in ('pending','approved') and x.ends_at>now())>=r.max_active_per_unit then raise exception 'Unit reservation limit reached'; end if;
 if exists(select 1 from public.space_reservations x where x.building_id=b and x.space_id=s and x.status in ('pending','approved') and x.starts_at<ends and x.ends_at>starts) then raise exception 'Time slot is already reserved'; end if;
 insert into public.space_reservations(building_id,space_id,unit_id,requested_by,starts_at,ends_at,guests,fee_snapshot,status)
 values(b,s,u,auth.uid(),starts,ends,guest_count,r.fee,case when r.requires_approval then 'pending' else 'approved' end) returning id into sid;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id) values(b,auth.uid(),'reserve','common_space',sid); return sid;
end $$;
-- Convert Tehran civil time in PostgreSQL using the server timezone database.
create function public.reserve_space_local(b uuid,s uuid,u uuid,local_date date,start_time time,end_time time,guest_count integer) returns uuid
language plpgsql security definer set search_path='' as $$ begin
 if local_date is null or start_time is null or end_time is null or end_time<=start_time then raise exception 'Invalid local slot'; end if;
 return public.reserve_space(b,s,u,(local_date+start_time) at time zone 'Asia/Tehran',(local_date+end_time) at time zone 'Asia/Tehran',guest_count);
end $$;
create function public.review_reservation(b uuid,reservation uuid,decision text) returns void language plpgsql security definer set search_path='' as $$
declare r public.space_reservations%rowtype; begin
 perform public.require_finance_manager(b); if decision not in ('approved','rejected') or decision is null then raise exception 'Invalid decision'; end if;
 select * into r from public.space_reservations where building_id=b and id=reservation for update;
 if not found or r.status<>'pending' then raise exception 'Reservation is not pending'; end if;
 update public.space_reservations set status=decision where id=r.id;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id,details) values(b,auth.uid(),decision,'reservation',r.id,jsonb_build_object('status',decision));
end $$;
create function public.create_maintenance_request(b uuid,u uuid,title text,category text,description text,priority text) returns uuid language plpgsql security definer set search_path='' as $$
declare rid uuid; begin
 if auth.uid() is null or not (public.has_building_role(b,array['manager']::public.building_role[]) or (u is not null and public.is_unit_resident(b,u))) then raise exception 'Not authorized' using errcode='42501'; end if;
 if u is not null and not exists(select 1 from public.units where building_id=b and id=u) then raise exception 'Invalid unit'; end if;
 insert into public.maintenance_requests(building_id,unit_id,requested_by,title,category,description,priority) values(b,u,auth.uid(),btrim(title),category,btrim(description),priority) returning id into rid;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id) values(b,auth.uid(),'create','maintenance',rid); return rid;
end $$;
create function public.update_maintenance_request(b uuid,rid uuid,new_status text,response text,assignee text) returns void language plpgsql security definer set search_path='' as $$
begin perform public.require_finance_manager(b);
 if new_status not in ('new','review','approved','in_progress','completed','rejected') or new_status is null then raise exception 'Invalid status'; end if;
 update public.maintenance_requests set status=new_status,manager_response=coalesce(response,''),assigned_to=coalesce(assignee,''),completed_at=case when new_status='completed' then coalesce(completed_at,now()) else null end where id=rid and building_id=b;
 if not found then raise exception 'Request not found'; end if;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id,details) values(b,auth.uid(),'update','maintenance',rid,jsonb_build_object('status',new_status));
end $$;
-- Reuse the accounting RPC within the same database transaction; a failed link rolls back the expense and its journal entry.
create function public.record_maintenance_cost(b uuid,rid uuid,a uuid,title text,amount bigint,request_id uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare v_expense_id uuid; existing public.maintenance_costs%rowtype; begin
 perform public.require_finance_manager(b);
 perform 1 from public.maintenance_requests where id=rid and building_id=b for update;
 if not found then raise exception 'Request not found'; end if;
 v_expense_id:=public.record_expense(b,a,title,amount,request_id);
 select * into existing from public.maintenance_costs c where c.expense_id=v_expense_id;
 if found then if existing.building_id<>b or existing.maintenance_id<>rid then raise exception 'Expense already linked to another request'; end if; return v_expense_id; end if;
 insert into public.maintenance_costs(building_id,maintenance_id,expense_id) values(b,rid,v_expense_id);
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id,details) values(b,auth.uid(),'record_cost','maintenance',rid,jsonb_build_object('expense_id',v_expense_id)); return v_expense_id;
end $$;
revoke all on function public.reserve_space(uuid,uuid,uuid,timestamptz,timestamptz,integer) from public,anon;
revoke all on function public.reserve_space_local(uuid,uuid,uuid,date,time,time,integer) from public,anon;
revoke all on function public.review_reservation(uuid,uuid,text) from public,anon;
revoke all on function public.create_maintenance_request(uuid,uuid,text,text,text,text) from public,anon;
revoke all on function public.update_maintenance_request(uuid,uuid,text,text,text) from public,anon;
revoke all on function public.record_maintenance_cost(uuid,uuid,uuid,text,bigint,uuid) from public,anon;
grant execute on function public.reserve_space(uuid,uuid,uuid,timestamptz,timestamptz,integer) to authenticated;
grant execute on function public.reserve_space_local(uuid,uuid,uuid,date,time,time,integer) to authenticated;
grant execute on function public.review_reservation(uuid,uuid,text) to authenticated;
grant execute on function public.create_maintenance_request(uuid,uuid,text,text,text,text) to authenticated;
grant execute on function public.update_maintenance_request(uuid,uuid,text,text,text) to authenticated;
grant execute on function public.record_maintenance_cost(uuid,uuid,uuid,text,bigint,uuid) to authenticated;

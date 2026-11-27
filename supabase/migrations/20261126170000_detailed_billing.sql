-- Additive migration: detailed billing is separate from cash expenses.
-- Responsibility is a label on each charge; the existing ledger remains per unit.
alter table public.units
 add column landline text not null default '' check(length(landline)<=30),
 add column is_vacant boolean not null default false,
 add column default_owner_charge bigint not null default 0 check(default_owner_charge between 0 and 1000000000000),
 add column default_resident_charge bigint not null default 0 check(default_resident_charge between 0 and 1000000000000);
alter table public.charge_periods add column request_id uuid, add column request_payload jsonb, add unique(building_id,request_id);
create table public.charge_period_items (
 id uuid primary key default gen_random_uuid(),
 building_id uuid not null, period_id uuid not null,
 position integer not null check(position between 1 and 50),
 title text not null check(length(btrim(title)) between 1 and 120),
 category text not null check(category in ('monthly','water','electricity','gas','cleaning','insurance','maintenance','other')),
 note text not null default '' check(length(note)<=1000),
 responsibility text not null check(responsibility in ('owner','resident')),
 method text not null check(method in ('equal','area','people','parking','storage','default')),
 total_amount bigint not null check(total_amount between 1 and 1000000000000),
 selected_units uuid[] check(selected_units is null or cardinality(selected_units)>0),
 unique(period_id,position),
 foreign key(building_id,period_id) references public.charge_periods(building_id,id)
);
create index on public.charge_period_items(building_id,period_id);
alter table public.charge_period_items enable row level security;
revoke all on public.charge_period_items from public,anon,authenticated;
grant select on public.charge_period_items to authenticated;
create policy charge_items_staff_read on public.charge_period_items for select to authenticated using(public.has_building_role(building_id,array['manager','accountant']::public.building_role[]));

-- One atomic operation creates a unit and optional unlinked owner/tenant contacts.
create function public.create_unit_with_contacts(b uuid, details jsonb, owner_name text, owner_phone text, tenant_name text, tenant_phone text)
returns uuid language plpgsql security invoker set search_path='' as $$
declare uid uuid; begin
 if auth.uid() is null or not public.has_building_role(b,array['manager']::public.building_role[]) then raise exception 'Not authorized' using errcode='42501'; end if;
 if coalesce(btrim(owner_name),'')='' and coalesce(btrim(owner_phone),'')<>'' or coalesce(btrim(tenant_name),'')='' and coalesce(btrim(tenant_phone),'')<>'' then raise exception 'Contact name required'; end if;
 insert into public.units(building_id,number,block,floor,area,occupants,parking,storage,parking_number,storage_number,notes,landline,is_vacant,default_owner_charge,default_resident_charge)
 values(b,btrim(details->>'number'),coalesce(details->>'block',''),coalesce(details->>'floor',''),(details->>'area')::numeric,(details->>'occupants')::integer,(details->>'parking')::integer,(details->>'storage')::integer,coalesce(details->>'parking_number',''),coalesce(details->>'storage_number',''),coalesce(details->>'notes',''),coalesce(details->>'landline',''),coalesce((details->>'is_vacant')::boolean,false),coalesce((details->>'default_owner_charge')::bigint,0),coalesce((details->>'default_resident_charge')::bigint,0)) returning id into uid;
 if coalesce(btrim(owner_name),'')<>'' then insert into public.unit_residents(building_id,unit_id,full_name,phone,kind) values(b,uid,btrim(owner_name),coalesce(btrim(owner_phone),''),'owner'); end if;
 if coalesce(btrim(tenant_name),'')<>'' then insert into public.unit_residents(building_id,unit_id,full_name,phone,kind) values(b,uid,btrim(tenant_name),coalesce(btrim(tenant_phone),''),'tenant'); end if;
 return uid;
end $$;
revoke all on function public.create_unit_with_contacts(uuid,jsonb,text,text,text,text) from public,anon;
grant execute on function public.create_unit_with_contacts(uuid,jsonb,text,text,text,text) to authenticated;

create function public.create_detailed_charge_period(b uuid, title text, issued_on date, due_on date, items jsonb, request_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare p uuid; old_payload jsonb; payload jsonb; item jsonb; targets uuid[]; count_targets integer; total bigint:=0; item_amount bigint; idx integer:=0; begin
 perform public.require_finance_manager(b);
 if request_id is null or jsonb_typeof(items) is distinct from 'array' then raise exception 'Invalid charge items'; end if;
 if jsonb_array_length(items) not between 1 and 50 then raise exception 'A period must contain 1 to 50 items'; end if;
 payload:=jsonb_build_object('title',btrim(title),'issued_on',issued_on,'due_on',due_on,'items',items);
 perform pg_advisory_xact_lock(hashtextextended(b::text||request_id::text,12));
 select cp.id,cp.request_payload into p,old_payload from public.charge_periods cp where cp.building_id=b and cp.request_id=create_detailed_charge_period.request_id;
 if found then if old_payload is distinct from payload then raise exception 'Request already used with different charge details'; end if; return p; end if;
 insert into public.charge_periods(building_id,title,issued_on,due_on,created_by,request_id,request_payload) values(b,btrim(title),issued_on,due_on,auth.uid(),request_id,payload) returning id into p;
 for item in select value from jsonb_array_elements(items) loop
  idx:=idx+1;
  if jsonb_typeof(item) is distinct from 'object' then raise exception 'Invalid item'; end if;
  item_amount:=(item->>'amount')::bigint;
  if item_amount is null or item_amount not between 1 and 1000000000000 then raise exception 'Invalid item amount'; end if;
  total:=total+item_amount;
  if total>1000000000000 then raise exception 'Period total exceeds maximum'; end if;
  targets:=null;
  if item ? 'units' and item->'units'<>'null'::jsonb then
   if jsonb_typeof(item->'units') is distinct from 'array' then raise exception 'Invalid unit selection'; end if;
   select array_agg(distinct v::uuid order by v::uuid) into targets from jsonb_array_elements_text(item->'units') as v;
   if targets is null or array_position(targets,null) is not null or cardinality(targets)<>jsonb_array_length(item->'units') then raise exception 'Select unique units'; end if;
   select count(*) into count_targets from public.units u where u.building_id=b and u.id=any(targets);
   if count_targets<>cardinality(targets) then raise exception 'Invalid selected unit'; end if;
  end if;
  insert into public.charge_period_items(building_id,period_id,position,title,category,note,responsibility,method,total_amount,selected_units)
  values(b,p,idx,btrim(item->>'title'),item->>'category',coalesce(item->>'note',''),item->>'responsibility',item->>'method',item_amount,targets);
 end loop;
 -- Existing rule is retained for backwards-compatible period queries; detailed
 -- periods use charge_period_items, not the placeholder equal distribution.
 insert into public.charge_rules(building_id,period_id,total_amount,equal_weight) values(b,p,total,100);
 perform public.preview_charge_period(p);
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id) values(b,auth.uid(),'create','charge_period',p);
 return p;
end $$;
revoke all on function public.create_detailed_charge_period(uuid,text,date,date,jsonb,uuid) from public,anon;
grant execute on function public.create_detailed_charge_period(uuid,text,date,date,jsonb,uuid) to authenticated;

create or replace function public.preview_charge_period(p uuid) returns table(unit_id uuid, amount bigint, metrics jsonb)
language plpgsql security definer set search_path='' as $$ declare b uuid; r public.charge_rules%rowtype; begin
 select cp.building_id into b from public.charge_periods cp where cp.id=p;
 if b is null then raise exception 'Period not found'; end if; perform public.require_finance_manager(b);
 if (select status from public.charge_periods where id=p)<>'draft' then raise exception 'Only draft periods can be previewed'; end if;
 if exists(select 1 from public.charge_period_items ci where ci.period_id=p) then
  -- A detailed allocation must be possible for every item; fail rather than
  -- silently dropping an item or moving its charge to unrelated units.
  if exists(
   select 1 from public.charge_period_items ci
   left join lateral (
    select count(*) as cnt,coalesce(sum(case ci.method when 'equal' then 1 when 'area' then u.area when 'people' then u.occupants when 'parking' then u.parking when 'storage' then u.storage when 'default' then case ci.responsibility when 'owner' then u.default_owner_charge else u.default_resident_charge end end),0) as metric
    from public.units u where u.building_id=b and (ci.selected_units is null or u.id=any(ci.selected_units))
   ) m on true where ci.period_id=p and (m.cnt=0 or m.metric<=0 or (ci.selected_units is not null and m.cnt<>cardinality(ci.selected_units)) or (ci.method='default' and m.metric<>ci.total_amount))
  ) then raise exception 'A charge item has invalid units, zero total metric, or changed default charges'; end if;
  return query with eligible as (
   select ci.id as item_id,ci.position,ci.title,ci.category,ci.note,ci.responsibility,ci.method,ci.total_amount,u.id as uid,u.area,u.occupants,u.parking,u.storage,
    case ci.method when 'equal' then 1::numeric when 'area' then u.area when 'people' then u.occupants::numeric when 'parking' then u.parking::numeric when 'storage' then u.storage::numeric when 'default' then case ci.responsibility when 'owner' then u.default_owner_charge::numeric else u.default_resident_charge::numeric end end as weight
   from public.charge_period_items ci join public.units u on u.building_id=ci.building_id and (ci.selected_units is null or u.id=any(ci.selected_units))
   where ci.period_id=p and ci.building_id=b
  ), exacts as (
   select e.*,case when e.method='default' then e.weight else e.total_amount::numeric*e.weight/sum(e.weight) over(partition by e.item_id) end as exact from eligible e
  ), floors as (
   select e.*,floor(e.exact)::bigint as base from exacts e
  ), ranked as (
   select f.*,row_number() over(partition by f.item_id order by f.exact-f.base desc,f.uid) as rank,sum(f.base) over(partition by f.item_id) as base_sum from floors f
  ), shares as (
   select x.*,(x.base+case when x.rank<=x.total_amount-x.base_sum then 1 else 0 end)::bigint as share from ranked x
  )
  select sh.uid,sum(sh.share)::bigint,jsonb_build_object('area',max(sh.area),'occupants',max(sh.occupants),'parking',max(sh.parking),'storage',max(sh.storage),'lines',
    jsonb_agg(jsonb_build_object('title',sh.title,'category',sh.category,'note',sh.note,'responsibility',sh.responsibility,'method',sh.method,'total',sh.total_amount,'amount',sh.share) order by sh.position))
  from shares sh group by sh.uid order by sh.uid;
  return;
 end if;
 select * into strict r from public.charge_rules where period_id=p;
 if not exists(select 1 from public.units u where u.building_id=b) then raise exception 'No units'; end if;
 if (r.area_weight>0 and (select sum(u.area) from public.units u where u.building_id=b)=0) or
    (r.people_weight>0 and (select sum(u.occupants) from public.units u where u.building_id=b)=0) or
    (r.parking_weight>0 and (select sum(u.parking) from public.units u where u.building_id=b)=0) or
    (r.storage_weight>0 and (select sum(u.storage) from public.units u where u.building_id=b)=0) then raise exception 'A weighted criterion has zero total'; end if;
 return query with weights as (select u.id,u.area,u.occupants,u.parking,u.storage,
  r.total_amount::numeric*(r.equal_weight/100/count(*) over () + coalesce(r.area_weight/100*u.area/nullif(sum(u.area) over (),0),0) + coalesce(r.people_weight/100*u.occupants/nullif(sum(u.occupants) over (),0),0) + coalesce(r.parking_weight/100*u.parking/nullif(sum(u.parking) over (),0),0) + coalesce(r.storage_weight/100*u.storage/nullif(sum(u.storage) over (),0),0)) as exact
  from public.units u where u.building_id=b), rounded as (select *,floor(exact)::bigint as base from weights), ranked as (select *,row_number() over(order by exact-base desc,id) as rank, sum(base) over () as base_sum from rounded)
  select id,(base+case when rank<=r.total_amount-base_sum then 1 else 0 end)::bigint,jsonb_build_object('area',area,'occupants',occupants,'parking',parking,'storage',storage) from ranked order by id;
end $$;
-- Return only the selected invoice's immutable item snapshot (or legacy summary).
create function public.invoice_charge_lines(b uuid, invoice uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare i public.invoices%rowtype; c public.unit_charges%rowtype; r public.charge_rules%rowtype; begin
 select * into i from public.invoices where building_id=b and id=invoice and status not in ('draft','cancelled');
 if not found or auth.uid() is null or not (public.has_building_role(b,array['manager','accountant']::public.building_role[]) or public.is_unit_resident(b,i.unit_id)) then raise exception 'Not authorized' using errcode='42501'; end if;
 select * into strict c from public.unit_charges where building_id=b and id=i.charge_id;
 if c.metrics ? 'lines' then return c.metrics->'lines'; end if;
 select * into strict r from public.charge_rules where building_id=b and period_id=i.period_id;
 return jsonb_build_array(jsonb_build_object('title','شارژ دوره','category','monthly','note','','responsibility','unit','method','mixed','total',r.total_amount,'amount',i.principal,
 'weights',jsonb_build_object('equal',r.equal_weight,'area',r.area_weight,'people',r.people_weight,'parking',r.parking_weight,'storage',r.storage_weight)));
end $$;
revoke all on function public.invoice_charge_lines(uuid,uuid) from public,anon;
grant execute on function public.invoice_charge_lines(uuid,uuid) to authenticated;

-- Additional context is kept on the staff-only cash document, not in a resident's
-- account profile. The original accounting RPCs still enforce amounts and allocation.
alter table public.financial_transactions
 add column category text not null default 'other' check(category in ('monthly','water','electricity','gas','cleaning','insurance','maintenance','other')),
 add column entry_details jsonb;
create function public.record_expense_details(b uuid,a uuid,title text,amount bigint,request_id uuid,category text,note text,expense_on date)
returns uuid language plpgsql security definer set search_path='' as $$
declare e uuid; existing public.financial_transactions%rowtype; payload jsonb; stamp timestamptz; begin
 perform public.require_finance_manager(b);
 if category is null or category not in ('monthly','water','electricity','gas','cleaning','insurance','maintenance','other') or length(coalesce(note,''))>1000 or expense_on is null or expense_on>(now() at time zone 'Asia/Tehran')::date or expense_on<'1900-01-01'::date or request_id is null then raise exception 'Invalid expense details'; end if;
 payload:=jsonb_build_object('kind','expense','category',category,'note',coalesce(note,''),'date',expense_on);
 perform pg_advisory_xact_lock(hashtextextended(b::text||request_id::text,2));
 select * into existing from public.financial_transactions ft where ft.building_id=b and ft.reference_type='expense_request' and ft.reference_id=request_id;
 if found then
  if existing.entry_details is distinct from payload then raise exception 'Request already used with different expense details'; end if;
  return public.record_expense(b,a,title,amount,request_id);
 end if;
 e:=public.record_expense(b,a,title,amount,request_id);
 stamp:=case when expense_on=(now() at time zone 'Asia/Tehran')::date then now() else (expense_on::timestamp+interval '12 hours') at time zone 'Asia/Tehran' end;
 update public.expenses set occurred_at=stamp where id=e and building_id=b;
 update public.financial_transactions ft set category=record_expense_details.category,entry_details=payload,occurred_at=stamp where ft.id=e and ft.building_id=b;
 return e;
end $$;
revoke all on function public.record_expense_details(uuid,uuid,text,bigint,uuid,text,text,date) from public,anon;
grant execute on function public.record_expense_details(uuid,uuid,text,bigint,uuid,text,text,date) to authenticated;

create function public.record_payment_details(b uuid,u uuid,a uuid,amount bigint,method text,request_id uuid,payer_kind text,payer_name text,note text,payment_on date)
returns uuid language plpgsql security definer set search_path='' as $$
declare pay uuid; old_pay public.payments%rowtype; old_details jsonb; payload jsonb; stamp timestamptz; begin
 perform public.require_finance_manager(b);
 if payer_kind is null or payer_kind not in ('owner','resident','other') or length(coalesce(payer_name,''))>120 or length(coalesce(note,''))>1000 or payment_on is null or payment_on>(now() at time zone 'Asia/Tehran')::date or payment_on<'1900-01-01'::date or request_id is null then raise exception 'Invalid payment details'; end if;
 payload:=jsonb_build_object('kind','payment','payer_kind',payer_kind,'payer_name',coalesce(btrim(payer_name),''),'note',coalesce(note,''),'date',payment_on);
 perform pg_advisory_xact_lock(hashtextextended(b::text||request_id::text,1));
 select * into old_pay from public.payments p where p.building_id=b and p.idempotency_key=request_id;
 if found then
  select ft.entry_details into old_details from public.financial_transactions ft where ft.building_id=b and ft.reference_type='payment' and ft.reference_id=old_pay.id;
  if old_details is distinct from payload then raise exception 'Request already used with different payment details'; end if;
  return public.record_manual_payment(b,u,a,amount,method,request_id);
 end if;
 pay:=public.record_manual_payment(b,u,a,amount,method,request_id);
 stamp:=case when payment_on=(now() at time zone 'Asia/Tehran')::date then now() else (payment_on::timestamp+interval '12 hours') at time zone 'Asia/Tehran' end;
 update public.payments set paid_at=stamp where id=pay and building_id=b;
 update public.financial_transactions ft set occurred_at=stamp,entry_details=payload where ft.building_id=b and ft.reference_type='payment' and ft.reference_id=pay;
 return pay;
end $$;
revoke all on function public.record_payment_details(uuid,uuid,uuid,bigint,text,uuid,text,text,text,date) from public,anon;
grant execute on function public.record_payment_details(uuid,uuid,uuid,bigint,text,uuid,text,text,text,date) to authenticated;

-- The base UI and the invoker RPC need only these grants; RLS remains authoritative.
grant select,insert,update on public.units,public.unit_residents to authenticated;
grant select,update on public.buildings to authenticated;
grant select on public.building_members to authenticated;
grant select,insert,update on public.profiles to authenticated;

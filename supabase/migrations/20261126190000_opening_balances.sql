-- Import a unit's existing balance once, without creating fictional cash flow.
-- Owner and resident are tracked as origins; repayment remains a shared unit ledger.
alter table public.charge_periods add column period_kind text not null default 'regular' check(period_kind in ('regular','opening'));
alter table public.payments alter column account_id drop not null;
alter table public.payments drop constraint payments_method_check;
alter table public.payments add constraint payments_method_check check(method in ('cash','bank_transfer','opening_credit'));
alter table public.payments add constraint payments_account_kind_check check((method='opening_credit' and account_id is null) or (method<>'opening_credit' and account_id is not null));
create table public.opening_balance_records (
 id uuid primary key default gen_random_uuid(), building_id uuid not null, unit_id uuid not null,
 owner_balance bigint not null check(owner_balance between -1000000000000 and 1000000000000),
 resident_balance bigint not null check(resident_balance between -1000000000000 and 1000000000000),
 balance_on date not null, request_id uuid not null, created_by uuid not null references auth.users(id),
 debt_period_id uuid, credit_payment_id uuid,
 created_at timestamptz not null default now(), unique(building_id,unit_id), unique(building_id,request_id),
 foreign key(building_id,unit_id) references public.units(building_id,id),
 foreign key(building_id,debt_period_id) references public.charge_periods(building_id,id),
 foreign key(building_id,credit_payment_id,unit_id) references public.payments(building_id,id,unit_id)
);
alter table public.opening_balance_records enable row level security;
revoke all on public.opening_balance_records from public,anon,authenticated;
grant select on public.opening_balance_records to authenticated;
create policy opening_balances_staff_read on public.opening_balance_records for select to authenticated using(public.has_building_role(building_id,array['manager','accountant']::public.building_role[]));
create function public.record_opening_balance(b uuid,u uuid,owner_balance bigint,resident_balance bigint,balance_on date,request_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare old public.opening_balance_records%rowtype; rec uuid; period uuid; payment uuid; items jsonb:='[]'::jsonb; total_debt bigint; total_credit bigint; remaining bigint; part bigint; inv record; begin
 perform public.require_finance_manager(b);
 if owner_balance is null or owner_balance not between -1000000000000 and 1000000000000 or resident_balance is null or resident_balance not between -1000000000000 and 1000000000000 or balance_on is null or balance_on not between '1900-01-01'::date and (now() at time zone 'Asia/Tehran')::date or request_id is null then raise exception 'Invalid opening balance'; end if;
 total_debt:=greatest(owner_balance,0)+greatest(resident_balance,0);
 total_credit:=greatest(-owner_balance,0)+greatest(-resident_balance,0);
 if total_debt>1000000000000 or total_credit>1000000000000 then raise exception 'Opening balance exceeds limit'; end if;
 if not exists(select 1 from public.units where building_id=b and id=u) then raise exception 'Invalid unit'; end if;
 perform pg_advisory_xact_lock(hashtextextended(b::text||request_id::text,18));
 -- Use the same unit-lock order as charge issuance. Neither a concurrent payment
 -- nor a second opening balance may slip between the existence check and import.
 perform pg_advisory_xact_lock(hashtextextended(q.id::text,0)) from public.units q where q.building_id=b order by q.id;
 select * into old from public.opening_balance_records r where r.building_id=b and r.request_id=record_opening_balance.request_id;
 if found then
  if old.unit_id<>u or old.owner_balance<>owner_balance or old.resident_balance<>resident_balance or old.balance_on<>balance_on then raise exception 'Request already used with different opening balance'; end if;
  return old.id;
 end if;
 if exists(select 1 from public.opening_balance_records r where r.building_id=b and r.unit_id=u) or exists(select 1 from public.invoices i where i.building_id=b and i.unit_id=u) or exists(select 1 from public.payments p where p.building_id=b and p.unit_id=u) then raise exception 'Opening balance is only available before other financial entries'; end if;
 -- Record receivables as ordinary invoices with explicit non-cash origins.
 if owner_balance>0 then items:=items||jsonb_build_array(jsonb_build_object('title','مانده افتتاحیه مالک','category','other','note','انتقال از حساب قبلی؛ بدون گردش صندوق','responsibility','owner','method','equal','amount',owner_balance,'units',jsonb_build_array(u))); end if;
 if resident_balance>0 then items:=items||jsonb_build_array(jsonb_build_object('title','مانده افتتاحیه ساکن','category','other','note','انتقال از حساب قبلی؛ بدون گردش صندوق','responsibility','resident','method','equal','amount',resident_balance,'units',jsonb_build_array(u))); end if;
 if total_debt>0 then
  period:=public.create_detailed_charge_period(b,'مانده افتتاحیه',balance_on,balance_on,items,gen_random_uuid());
  perform public.issue_charge_period(period);
  update public.charge_periods set period_kind='opening' where id=period and building_id=b;
 end if;
 -- A prior paid credit has no new cash account or financial transaction.
 if total_credit>0 then
  insert into public.payments(building_id,unit_id,account_id,amount,method,idempotency_key,created_by,paid_at) values(b,u,null,total_credit,'opening_credit',gen_random_uuid(),auth.uid(),(balance_on::timestamp+interval '12 hours') at time zone 'Asia/Tehran') returning id into payment;
  remaining:=total_credit;
  for inv in select * from public.invoices i where i.building_id=b and i.unit_id=u and i.status in ('issued','partially_paid','overdue') order by i.due_on,i.created_at,i.id for update loop
   exit when remaining=0;
   part:=least(remaining,inv.principal-inv.discount+inv.penalty-inv.paid_amount);
   if part>0 then
    insert into public.payment_allocations(building_id,payment_id,invoice_id,unit_id,amount) values(b,payment,inv.id,u,part);
    update public.invoices set paid_amount=paid_amount+part,status=case when paid_amount+part=principal-discount+penalty then 'paid' else 'partially_paid' end where id=inv.id;
    remaining:=remaining-part;
   end if;
  end loop;
 end if;
 insert into public.opening_balance_records(building_id,unit_id,owner_balance,resident_balance,balance_on,request_id,created_by,debt_period_id,credit_payment_id)
 values(b,u,owner_balance,resident_balance,balance_on,request_id,auth.uid(),period,payment) returning id into rec;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id) values(b,auth.uid(),'record','opening_balance',rec);
 return rec;
end $$;
revoke all on function public.record_opening_balance(uuid,uuid,bigint,bigint,date,uuid) from public,anon;
grant execute on function public.record_opening_balance(uuid,uuid,bigint,bigint,date,uuid) to authenticated;

-- Existing remotely provisioned projects may grant anon permissions by default.
revoke all on function public.create_building(text,text) from public,anon;
revoke all on function public.has_building_role(uuid,public.building_role[]) from public,anon;
revoke all on function public.is_unit_resident(uuid,uuid) from public,anon;
grant execute on function public.create_building(text,text) to authenticated;
grant execute on function public.has_building_role(uuid,public.building_role[]) to authenticated;
grant execute on function public.is_unit_resident(uuid,uuid) to authenticated;

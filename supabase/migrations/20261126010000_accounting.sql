-- All amounts are integer tomans. Financial writes are only available via RPCs.
create table public.charge_periods (
 id uuid primary key default gen_random_uuid(), building_id uuid not null references public.buildings(id),
 title text not null check(length(btrim(title)) between 1 and 120), issued_on date not null, due_on date not null,
 status text not null default 'draft' check(status in ('draft','issued')), created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(), check(due_on>=issued_on), unique(building_id,id)
);
create table public.charge_rules (
 id uuid primary key default gen_random_uuid(), building_id uuid not null, period_id uuid not null unique,
 total_amount bigint not null check(total_amount > 0 and total_amount <= 1000000000000),
 equal_weight numeric(5,2) not null default 0 check(equal_weight>=0), area_weight numeric(5,2) not null default 0 check(area_weight>=0),
 people_weight numeric(5,2) not null default 0 check(people_weight>=0), parking_weight numeric(5,2) not null default 0 check(parking_weight>=0), storage_weight numeric(5,2) not null default 0 check(storage_weight>=0),
 check(equal_weight+area_weight+people_weight+parking_weight+storage_weight=100),
 foreign key(building_id,period_id) references public.charge_periods(building_id,id)
);
create table public.unit_charges (
 id uuid primary key default gen_random_uuid(), building_id uuid not null, period_id uuid not null, unit_id uuid not null,
 amount bigint not null check(amount>=0), metrics jsonb not null, created_at timestamptz not null default now(),
 unique(building_id,period_id,unit_id), unique(building_id,id),
 foreign key(building_id,period_id) references public.charge_periods(building_id,id), foreign key(building_id,unit_id) references public.units(building_id,id)
);
create table public.invoices (
 id uuid primary key default gen_random_uuid(), building_id uuid not null, unit_id uuid not null, period_id uuid not null, charge_id uuid not null,
 invoice_number text not null, principal bigint not null check(principal>=0), discount bigint not null default 0 check(discount>=0 and discount<=principal),
 penalty bigint not null default 0 check(penalty>=0), previous_debt bigint not null default 0 check(previous_debt>=0),
 paid_amount bigint not null default 0 check(paid_amount>=0 and paid_amount<=principal-discount+penalty),
 issued_on date not null, due_on date not null, status text not null check(status in ('draft','issued','partially_paid','paid','overdue','cancelled')),
 created_at timestamptz not null default now(), unique(building_id,invoice_number), unique(building_id,id), unique(building_id,id,unit_id), unique(building_id,period_id,unit_id),
 foreign key(building_id,unit_id) references public.units(building_id,id), foreign key(building_id,period_id) references public.charge_periods(building_id,id), foreign key(building_id,charge_id) references public.unit_charges(building_id,id)
);
create table public.accounts (
 id uuid primary key default gen_random_uuid(), building_id uuid not null references public.buildings(id), name text not null check(length(btrim(name)) between 1 and 120),
 kind text not null check(kind in ('cash','bank','repair','reserve','other')), created_by uuid not null references auth.users(id), created_at timestamptz not null default now(), unique(building_id,id)
);
create table public.payments (
 id uuid primary key default gen_random_uuid(), building_id uuid not null, unit_id uuid not null, account_id uuid not null,
 amount bigint not null check(amount>0 and amount<=1000000000000), method text not null check(method in ('cash','bank_transfer')),
 idempotency_key uuid not null, created_by uuid not null references auth.users(id), paid_at timestamptz not null default now(),
 unique(building_id,id), unique(building_id,idempotency_key), unique(building_id,id,unit_id),
 foreign key(building_id,unit_id) references public.units(building_id,id), foreign key(building_id,account_id) references public.accounts(building_id,id)
);
create table public.payment_allocations (
 id uuid primary key default gen_random_uuid(), building_id uuid not null, payment_id uuid not null, invoice_id uuid not null, unit_id uuid not null,
 amount bigint not null check(amount>0), created_at timestamptz not null default now(), unique(payment_id,invoice_id),
 foreign key(building_id,payment_id,unit_id) references public.payments(building_id,id,unit_id), foreign key(building_id,invoice_id,unit_id) references public.invoices(building_id,id,unit_id), foreign key(building_id,unit_id) references public.units(building_id,id)
);
create table public.financial_transactions (
 id uuid primary key default gen_random_uuid(), building_id uuid not null, account_id uuid not null,
 transaction_type text not null check(transaction_type in ('receipt','expense','adjustment_in','adjustment_out')),
 amount bigint not null check(amount>0), occurred_at timestamptz not null default now(), document_no text not null,
 description text not null default '', created_by uuid not null references auth.users(id), reference_type text not null, reference_id uuid not null,
 reverses_id uuid references public.financial_transactions(id), created_at timestamptz not null default now(),
 unique(building_id,document_no), unique(building_id,reference_type,reference_id), unique(reverses_id), unique(building_id,id),
 foreign key(building_id,account_id) references public.accounts(building_id,id)
);
create table public.expenses (
 id uuid primary key default gen_random_uuid(), building_id uuid not null, account_id uuid not null, title text not null check(length(btrim(title)) between 1 and 200),
 amount bigint not null check(amount>0 and amount<=1000000000000), created_by uuid not null references auth.users(id), occurred_at timestamptz not null default now(),
 unique(building_id,id), foreign key(building_id,account_id) references public.accounts(building_id,id)
);
create table public.checks (
 id uuid primary key default gen_random_uuid(), building_id uuid not null references public.buildings(id), unit_id uuid, account_id uuid,
 number text not null, amount bigint not null check(amount>0), due_on date not null,
 status text not null default 'pending' check(status in ('pending','cleared','returned','cancelled')), created_by uuid not null references auth.users(id),
 foreign key(building_id,unit_id) references public.units(building_id,id), foreign key(building_id,account_id) references public.accounts(building_id,id)
);
create table public.audit_logs (
 id uuid primary key default gen_random_uuid(), building_id uuid not null references public.buildings(id), actor_id uuid not null references auth.users(id),
 action text not null, entity_type text not null, entity_id uuid not null, details jsonb not null default '{}', created_at timestamptz not null default now()
);
create index on public.charge_periods(building_id,issued_on);
create index on public.unit_charges(building_id,unit_id);
create index on public.invoices(building_id,unit_id,due_on);
create index on public.payments(building_id,unit_id,paid_at);
create index on public.payment_allocations(building_id,invoice_id);
create index on public.financial_transactions(building_id,account_id,occurred_at);
create index on public.expenses(building_id,occurred_at);
create index on public.checks(building_id,due_on);
create index on public.audit_logs(building_id,created_at);

-- Fail closed: no direct mutations, even for managers. All writes go through checked RPCs.
do $$ declare t text; begin foreach t in array array['charge_periods','charge_rules','unit_charges','invoices','payments','payment_allocations','accounts','financial_transactions','expenses','checks','audit_logs'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from anon, authenticated',t);
 execute format('grant select on public.%I to authenticated',t);
 end loop; end $$;
create policy periods_staff_read on public.charge_periods for select to authenticated using(public.has_building_role(building_id,array['manager','accountant']::public.building_role[]));
create policy rules_staff_read on public.charge_rules for select to authenticated using(public.has_building_role(building_id,array['manager','accountant']::public.building_role[]));
create policy charges_read on public.unit_charges for select to authenticated using(public.has_building_role(building_id,array['manager','accountant']::public.building_role[]) or public.is_unit_resident(building_id,unit_id));
create policy invoices_read on public.invoices for select to authenticated using(public.has_building_role(building_id,array['manager','accountant']::public.building_role[]) or public.is_unit_resident(building_id,unit_id));
create policy payments_read on public.payments for select to authenticated using(public.has_building_role(building_id,array['manager','accountant']::public.building_role[]) or public.is_unit_resident(building_id,unit_id));
create policy allocations_read on public.payment_allocations for select to authenticated using(public.has_building_role(building_id,array['manager','accountant']::public.building_role[]) or public.is_unit_resident(building_id,unit_id));
create policy accounts_staff_read on public.accounts for select to authenticated using(public.has_building_role(building_id,array['manager','accountant']::public.building_role[]));
create policy tx_staff_read on public.financial_transactions for select to authenticated using(public.has_building_role(building_id,array['manager','accountant']::public.building_role[]));
create policy expense_staff_read on public.expenses for select to authenticated using(public.has_building_role(building_id,array['manager','accountant']::public.building_role[]));
create policy checks_staff_read on public.checks for select to authenticated using(public.has_building_role(building_id,array['manager','accountant']::public.building_role[]));
create policy audit_manager_read on public.audit_logs for select to authenticated using(public.has_building_role(building_id,array['manager']::public.building_role[]));

create function public.require_finance_manager(b uuid) returns void language plpgsql stable security definer set search_path='' as $$ begin
 if auth.uid() is null or not public.has_building_role(b,array['manager']::public.building_role[]) then raise exception 'Not authorized' using errcode='42501'; end if;
end $$;
revoke all on function public.require_finance_manager(uuid) from public,anon,authenticated;

create function public.create_charge_period(b uuid, title text, issued_on date, due_on date, total_amount bigint, equal_weight numeric, area_weight numeric, people_weight numeric, parking_weight numeric, storage_weight numeric) returns uuid
language plpgsql security definer set search_path='' as $$ declare p uuid; begin
 perform public.require_finance_manager(b);
 insert into public.charge_periods(building_id,title,issued_on,due_on,created_by) values(b,btrim(title),issued_on,due_on,auth.uid()) returning id into p;
 insert into public.charge_rules(building_id,period_id,total_amount,equal_weight,area_weight,people_weight,parking_weight,storage_weight) values(b,p,total_amount,equal_weight,area_weight,people_weight,parking_weight,storage_weight);
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id) values(b,auth.uid(),'create','charge_period',p);
 return p;
end $$;
-- Largest-remainder allocation preserves the exact total; ties are stable by unit UUID.
create function public.preview_charge_period(p uuid) returns table(unit_id uuid, amount bigint, metrics jsonb)
language plpgsql security definer set search_path='' as $$ declare b uuid; r public.charge_rules%rowtype; begin
 select cp.building_id into b from public.charge_periods cp where cp.id=p;
 if b is null then raise exception 'Period not found'; end if; perform public.require_finance_manager(b);
 if (select status from public.charge_periods where id=p)<>'draft' then raise exception 'Only draft periods can be previewed'; end if;
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
create function public.issue_charge_period(p uuid) returns integer language plpgsql security definer set search_path='' as $$
declare cp public.charge_periods%rowtype; x record; c uuid; invoice_id uuid; n integer:=0; prev bigint; credit_row record; available bigint; applied bigint; remaining bigint; begin
 select * into cp from public.charge_periods where id=p for update;
 if not found then raise exception 'Period not found'; end if; perform public.require_finance_manager(cp.building_id);
 if cp.status<>'draft' then raise exception 'Period already issued'; end if;
 -- Serialize issuance with payments for all units in UUID order.
 perform pg_advisory_xact_lock(hashtextextended(u.id::text,0)) from public.units u where u.building_id=cp.building_id order by u.id;
 perform u.id from public.units u where u.building_id=cp.building_id order by u.id for share;
 for x in select * from public.preview_charge_period(p) loop
  select coalesce(sum(i.principal-i.discount+i.penalty-i.paid_amount),0) into prev from public.invoices i where i.building_id=cp.building_id and i.unit_id=x.unit_id and i.status not in ('draft','cancelled','paid');
  insert into public.unit_charges(building_id,period_id,unit_id,amount,metrics) values(cp.building_id,p,x.unit_id,x.amount,x.metrics) returning id into c;
  insert into public.invoices(building_id,unit_id,period_id,charge_id,invoice_number,principal,previous_debt,issued_on,due_on,status)
  values(cp.building_id,x.unit_id,p,c,'INV-'||replace(c::text,'-',''),x.amount,prev,cp.issued_on,cp.due_on,case when x.amount=0 then 'paid' else 'issued' end) returning id into invoice_id;
  -- Apply previously unallocated unit credit, oldest receipt first, without creating another cash transaction.
  remaining:=x.amount;
  for credit_row in select pay.id,pay.amount-coalesce((select sum(pa.amount) from public.payment_allocations pa where pa.payment_id=pay.id),0) as credit from public.payments pay where pay.building_id=cp.building_id and pay.unit_id=x.unit_id order by pay.paid_at,pay.id loop
   exit when remaining=0;
   available:=credit_row.credit; applied:=least(available,remaining);
   if applied>0 then
    insert into public.payment_allocations(building_id,payment_id,invoice_id,unit_id,amount) values(cp.building_id,credit_row.id,invoice_id,x.unit_id,applied);
    update public.invoices set paid_amount=paid_amount+applied,status=case when paid_amount+applied=principal-discount+penalty then 'paid' else 'partially_paid' end where id=invoice_id;
    remaining:=remaining-applied;
   end if;
  end loop;
  n:=n+1;
 end loop;
 update public.charge_periods set status='issued' where id=p;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id,details) values(cp.building_id,auth.uid(),'issue','charge_period',p,jsonb_build_object('units',n));
 return n;
end $$;
create function public.create_account(b uuid, account_name text, account_kind text) returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid; begin perform public.require_finance_manager(b);
 insert into public.accounts(building_id,name,kind,created_by) values(b,btrim(account_name),account_kind,auth.uid()) returning id into a;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id) values(b,auth.uid(),'create','account',a); return a;
end $$;
-- Oldest invoice first; any unallocated amount is unit credit. Unit advisory locks protect concurrent payments/issuance.
create function public.record_manual_payment(b uuid, u uuid, a uuid, amount bigint, method text, request_id uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare pay public.payments%rowtype; remaining bigint; part bigint; inv record; begin
 perform public.require_finance_manager(b);
 if request_id is null or amount is null or amount<=0 or amount>1000000000000 or method not in ('cash','bank_transfer') or method is null then raise exception 'Invalid payment'; end if;
 if not exists(select 1 from public.units where building_id=b and id=u) or not exists(select 1 from public.accounts where building_id=b and id=a) then raise exception 'Invalid unit or account'; end if;
 perform pg_advisory_xact_lock(hashtextextended(b::text||request_id::text,1));
 select * into pay from public.payments where building_id=b and idempotency_key=request_id;
 if found then
  if pay.unit_id<>u or pay.account_id<>a or pay.amount<>amount or pay.method<>method then raise exception 'Idempotency key already used for another payment'; end if; return pay.id;
 end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 insert into public.payments(building_id,unit_id,account_id,amount,method,idempotency_key,created_by) values(b,u,a,amount,method,request_id,auth.uid()) returning * into pay;
 remaining:=amount;
 for inv in select * from public.invoices i where i.building_id=b and i.unit_id=u and i.status in ('issued','partially_paid','overdue') order by i.due_on,i.created_at,i.id for update loop
  exit when remaining=0; part:=least(remaining,inv.principal-inv.discount+inv.penalty-inv.paid_amount);
  if part>0 then
   insert into public.payment_allocations(building_id,payment_id,invoice_id,unit_id,amount) values(b,pay.id,inv.id,u,part);
   update public.invoices set paid_amount=paid_amount+part,status=case when paid_amount+part=principal-discount+penalty then 'paid' else 'partially_paid' end where id=inv.id;
   remaining:=remaining-part;
  end if;
 end loop;
 insert into public.financial_transactions(building_id,account_id,transaction_type,amount,document_no,description,created_by,reference_type,reference_id)
 values(b,a,'receipt',amount,'PAY-'||replace(pay.id::text,'-',''),'دریافت دستی',auth.uid(),'payment',pay.id);
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id,details) values(b,auth.uid(),'record','payment',pay.id,jsonb_build_object('amount',amount,'unallocated_credit',remaining));
 return pay.id;
end $$;
create function public.record_expense(b uuid, a uuid, title text, amount bigint, request_id uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare e uuid; existing public.financial_transactions%rowtype; begin
 perform public.require_finance_manager(b);
 if request_id is null or amount is null or amount<=0 or amount>1000000000000 or length(btrim(coalesce(title,''))) not between 1 and 200 then raise exception 'Invalid expense'; end if;
 if not exists(select 1 from public.accounts where building_id=b and id=a) then raise exception 'Invalid account'; end if;
 perform pg_advisory_xact_lock(hashtextextended(b::text||request_id::text,2));
 select * into existing from public.financial_transactions where building_id=b and reference_type='expense_request' and reference_id=request_id;
 if found then
  if existing.account_id<>a or existing.amount<>amount or existing.description<>btrim(title) then raise exception 'Idempotency key already used for another expense'; end if;
  return (select x.id from public.expenses x where x.id=existing.id);
 end if;
 e:=gen_random_uuid();
 insert into public.expenses(id,building_id,account_id,title,amount,created_by) values(e,b,a,btrim(title),amount,auth.uid());
 insert into public.financial_transactions(id,building_id,account_id,transaction_type,amount,document_no,description,created_by,reference_type,reference_id)
 values(e,b,a,'expense',amount,'EXP-'||replace(e::text,'-',''),btrim(title),auth.uid(),'expense_request',request_id);
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id,details) values(b,auth.uid(),'record','expense',e,jsonb_build_object('amount',amount)); return e;
end $$;
-- Expense reversal is an append-only compensating document; payments require a separate refund workflow (not implemented).
create function public.reverse_expense(b uuid, transaction_id uuid, reason text) returns uuid language plpgsql security definer set search_path='' as $$
declare original public.financial_transactions%rowtype; correction uuid; begin
 perform public.require_finance_manager(b);
 if length(btrim(coalesce(reason,''))) not between 1 and 500 then raise exception 'A reason is required'; end if;
 select * into original from public.financial_transactions where id=transaction_id and building_id=b for update;
 if not found or original.transaction_type<>'expense' then raise exception 'Only expenses can be reversed'; end if;
 if exists(select 1 from public.financial_transactions where reverses_id=original.id) then raise exception 'Already reversed'; end if;
 correction:=gen_random_uuid();
 insert into public.financial_transactions(id,building_id,account_id,transaction_type,amount,document_no,description,created_by,reference_type,reference_id,reverses_id)
 values(correction,b,original.account_id,'adjustment_in',original.amount,'ADJ-'||replace(correction::text,'-',''),btrim(reason),auth.uid(),'expense_reversal',original.id,original.id);
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id,details) values(b,auth.uid(),'reverse','transaction',original.id,jsonb_build_object('correction_id',correction,'reason',reason)); return correction;
end $$;
-- The previous-debt snapshot is informational, never added to the new invoice's principal:
-- older invoices remain independently payable, avoiding double-counting.
create function public.unit_balance(b uuid, u uuid) returns table(debt bigint,credit bigint,net_debt bigint)
language plpgsql stable security definer set search_path='' as $$ declare d bigint; c bigint; begin
 if auth.uid() is null or not (public.has_building_role(b,array['manager','accountant']::public.building_role[]) or public.is_unit_resident(b,u)) then raise exception 'Not authorized' using errcode='42501'; end if;
 if not exists(select 1 from public.units where building_id=b and id=u) then raise exception 'Unit not found'; end if;
 select coalesce(sum(i.principal-i.discount+i.penalty-i.paid_amount),0) into d from public.invoices i where i.building_id=b and i.unit_id=u and i.status not in ('draft','cancelled','paid');
 select coalesce(sum(p.amount-coalesce((select sum(pa.amount) from public.payment_allocations pa where pa.payment_id=p.id),0)),0) into c from public.payments p where p.building_id=b and p.unit_id=u;
 return query select d,c,d-c;
end $$;
revoke all on function public.create_charge_period(uuid,text,date,date,bigint,numeric,numeric,numeric,numeric,numeric) from public,anon;
revoke all on function public.preview_charge_period(uuid) from public,anon;
revoke all on function public.issue_charge_period(uuid) from public,anon;
revoke all on function public.create_account(uuid,text,text) from public,anon;
revoke all on function public.record_manual_payment(uuid,uuid,uuid,bigint,text,uuid) from public,anon;
revoke all on function public.record_expense(uuid,uuid,text,bigint,uuid) from public,anon;
revoke all on function public.reverse_expense(uuid,uuid,text) from public,anon;
revoke all on function public.unit_balance(uuid,uuid) from public,anon;
grant execute on function public.create_charge_period(uuid,text,date,date,bigint,numeric,numeric,numeric,numeric,numeric) to authenticated;
grant execute on function public.preview_charge_period(uuid) to authenticated;
grant execute on function public.issue_charge_period(uuid) to authenticated;
grant execute on function public.create_account(uuid,text,text) to authenticated;
grant execute on function public.record_manual_payment(uuid,uuid,uuid,bigint,text,uuid) to authenticated;
grant execute on function public.record_expense(uuid,uuid,text,bigint,uuid) to authenticated;
grant execute on function public.reverse_expense(uuid,uuid,text) to authenticated;
grant execute on function public.unit_balance(uuid,uuid) to authenticated;

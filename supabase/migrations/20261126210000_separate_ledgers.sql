-- Do not reinterpret historically shared balances automatically.
do $$ begin
 if exists(select 1 from public.invoices) or exists(select 1 from public.payments) then raise exception 'Existing shared financial records require a reviewed conversion'; end if;
end $$;
alter table public.invoices add column responsibility text not null default 'resident' check(responsibility in ('owner','resident'));
alter table public.payments add column responsibility text not null default 'resident' check(responsibility in ('owner','resident'));
alter table public.invoices drop constraint invoices_building_id_period_id_unit_id_key;
alter table public.invoices add unique(building_id,period_id,unit_id,responsibility);
alter table public.unit_charges add column responsibility text not null default 'resident' check(responsibility in ('owner','resident'));
alter table public.unit_charges drop constraint unit_charges_building_id_period_id_unit_id_key;
alter table public.unit_charges add unique(building_id,period_id,unit_id,responsibility);
create or replace function public.issue_charge_period(p uuid) returns integer language plpgsql security definer set search_path='' as $$
declare cp public.charge_periods%rowtype; x record; c uuid; invoice_id uuid; n integer:=0; prev bigint; credit_row record; available bigint; applied bigint; remaining bigint; begin
 select * into cp from public.charge_periods where id=p for update;
 if not found then raise exception 'Period not found'; end if; perform public.require_finance_manager(cp.building_id);
 if cp.status<>'draft' then raise exception 'Period already issued'; end if;
 -- Serialize issuance with payments for all units in UUID order.
 perform pg_advisory_xact_lock(hashtextextended(u.id::text,0)) from public.units u where u.building_id=cp.building_id order by u.id;
 perform u.id from public.units u where u.building_id=cp.building_id order by u.id for share;
 for x in select v.unit_id, coalesce(z.amount,v.amount) amount, case when z.role is null then v.metrics else jsonb_set(v.metrics,'{lines}',z.lines) end metrics,coalesce(z.role,'resident') responsibility
 from public.preview_charge_period(p) v left join lateral (select l->>'responsibility' role,sum((l->>'amount')::bigint)::bigint amount,jsonb_agg(l) lines from jsonb_array_elements(coalesce(v.metrics->'lines','[]'::jsonb)) l group by l->>'responsibility') z on true loop
  select coalesce(sum(i.principal-i.discount+i.penalty-i.paid_amount),0) into prev from public.invoices i where i.building_id=cp.building_id and i.unit_id=x.unit_id and i.responsibility=x.responsibility and i.status not in ('draft','cancelled','paid');
  insert into public.unit_charges(building_id,period_id,unit_id,amount,metrics,responsibility) values(cp.building_id,p,x.unit_id,x.amount,x.metrics,x.responsibility) returning id into c;
  insert into public.invoices(building_id,unit_id,period_id,charge_id,invoice_number,principal,previous_debt,issued_on,due_on,status,responsibility)
  values(cp.building_id,x.unit_id,p,c,'INV-'||replace(c::text,'-',''),x.amount,prev,cp.issued_on,cp.due_on,case when x.amount=0 then 'paid' else 'issued' end,x.responsibility) returning id into invoice_id;
  -- Apply previously unallocated unit credit, oldest receipt first, without creating another cash transaction.
  remaining:=x.amount;
  for credit_row in select pay.id,pay.amount-coalesce((select sum(pa.amount) from public.payment_allocations pa where pa.payment_id=pay.id),0) as credit from public.payments pay where pay.building_id=cp.building_id and pay.unit_id=x.unit_id and pay.responsibility=x.responsibility order by pay.paid_at,pay.id loop
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
create function public.record_role_payment(b uuid, u uuid, a uuid, amount bigint, method text, request_id uuid, target_role text) returns uuid language plpgsql security definer set search_path='' as $$
declare pay public.payments%rowtype; remaining bigint; part bigint; inv record; begin
 perform public.require_finance_manager(b);
 if target_role is null or target_role not in ('owner','resident') then raise exception 'Invalid account role'; end if;
 if request_id is null or amount is null or amount<=0 or amount>1000000000000 or method not in ('cash','bank_transfer') or method is null then raise exception 'Invalid payment'; end if;
 if not exists(select 1 from public.units where building_id=b and id=u) or not exists(select 1 from public.accounts where building_id=b and id=a) then raise exception 'Invalid unit or account'; end if;
 perform pg_advisory_xact_lock(hashtextextended(b::text||request_id::text,1));
 select * into pay from public.payments where building_id=b and idempotency_key=request_id;
 if found then
  if pay.unit_id<>u or pay.account_id<>a or pay.amount<>amount or pay.method<>method or pay.responsibility<>target_role then raise exception 'Idempotency key already used for another payment'; end if; return pay.id;
 end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 insert into public.payments(building_id,unit_id,account_id,amount,method,idempotency_key,created_by,responsibility) values(b,u,a,amount,method,request_id,auth.uid(),target_role) returning * into pay;
 remaining:=amount;
 for inv in select * from public.invoices i where i.building_id=b and i.unit_id=u and i.responsibility=target_role and i.status in ('issued','partially_paid','overdue') order by i.due_on,i.created_at,i.id for update loop
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

revoke all on function public.record_role_payment(uuid,uuid,uuid,bigint,text,uuid,text) from public,anon,authenticated;
create or replace function public.record_manual_payment(b uuid,u uuid,a uuid,amount bigint,method text,request_id uuid) returns uuid language sql security definer set search_path='' as $$ select public.record_role_payment(b,u,a,amount,method,request_id,'resident') $$;
create or replace function public.record_payment_details(b uuid,u uuid,a uuid,amount bigint,method text,request_id uuid,payer_kind text,payer_name text,note text,payment_on date)
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
  return public.record_role_payment(b,u,a,amount,method,request_id,case when payer_kind='owner' then 'owner' else 'resident' end);
 end if;
 pay:=public.record_role_payment(b,u,a,amount,method,request_id,case when payer_kind='owner' then 'owner' else 'resident' end);
 stamp:=case when payment_on=(now() at time zone 'Asia/Tehran')::date then now() else (payment_on::timestamp+interval '12 hours') at time zone 'Asia/Tehran' end;
 update public.payments set paid_at=stamp where id=pay and building_id=b;
 update public.financial_transactions ft set occurred_at=stamp,entry_details=payload where ft.building_id=b and ft.reference_type='payment' and ft.reference_id=pay;
 return pay;
end $$;
create or replace function public.record_opening_balance(b uuid,u uuid,owner_balance bigint,resident_balance bigint,balance_on date,request_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare old public.opening_balance_records%rowtype; rec uuid; period uuid; payment uuid; owner_credit uuid; resident_credit uuid; items jsonb:='[]'::jsonb; total_debt bigint; total_credit bigint; remaining bigint; part bigint; inv record; credit_row record; begin
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
 for credit_row in select * from (values ('owner',owner_balance),('resident',resident_balance)) v(role,balance) where balance<0 loop
 insert into public.payments(building_id,unit_id,account_id,amount,method,idempotency_key,created_by,paid_at,responsibility) values(b,u,null,-credit_row.balance,'opening_credit',gen_random_uuid(),auth.uid(),(balance_on::timestamp+interval '12 hours') at time zone 'Asia/Tehran',credit_row.role) returning id into payment;
 if credit_row.role='owner' then owner_credit:=payment; else resident_credit:=payment; end if;
 end loop;
 insert into public.opening_balance_records(building_id,unit_id,owner_balance,resident_balance,balance_on,request_id,created_by,debt_period_id,credit_payment_id,owner_credit_payment_id,resident_credit_payment_id)
 values(b,u,owner_balance,resident_balance,balance_on,request_id,auth.uid(),period,coalesce(resident_credit,owner_credit),owner_credit,resident_credit) returning id into rec;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id) values(b,auth.uid(),'record','opening_balance',rec);
 return rec;
end $$;

create function public.report_role_balances(b uuid)
returns table(unit_id uuid,unit_number text,responsibility text,debt bigint,credit bigint,net_debt bigint)
language plpgsql stable security definer set search_path='' as $$ begin
 if auth.uid() is null or not public.has_building_role(b,array['manager','accountant']::public.building_role[]) then raise exception 'Not authorized' using errcode='42501'; end if;
 return query select u.id,u.number,r.role,d.amount,c.amount,d.amount-c.amount from public.units u cross join (values ('owner'),('resident')) r(role)
 cross join lateral (select coalesce(sum(i.principal-i.discount+i.penalty-i.paid_amount),0)::bigint amount from public.invoices i where i.building_id=b and i.unit_id=u.id and i.responsibility=r.role and i.status not in ('draft','cancelled')) d
 cross join lateral (select coalesce(sum(p.amount-coalesce((select sum(a.amount) from public.payment_allocations a where a.payment_id=p.id),0)),0)::bigint amount from public.payments p where p.building_id=b and p.unit_id=u.id and p.responsibility=r.role) c
 where u.building_id=b order by u.number,r.role;
end $$;
revoke all on function public.report_role_balances(uuid) from public,anon;
grant execute on function public.report_role_balances(uuid) to authenticated;

-- Each resident can see only the financial ledger for their active owner/tenant link.
create function public.has_unit_finance_role(b uuid,u uuid,target_role text)
returns boolean language sql stable security definer set search_path='' as $$
 select target_role in ('owner','resident') and exists(
  select 1 from public.unit_residents r join public.building_members m
   on m.building_id=r.building_id and m.user_id=r.user_id
   and ((target_role='owner' and r.kind='owner' and m.role='owner') or (target_role='resident' and r.kind='tenant' and m.role='resident'))
  where r.building_id=b and r.unit_id=u and r.user_id=auth.uid()
   and (r.starts_on is null or r.starts_on<=current_date) and (r.ends_on is null or r.ends_on>=current_date));
$$;
revoke all on function public.has_unit_finance_role(uuid,uuid,text) from public,anon;
grant execute on function public.has_unit_finance_role(uuid,uuid,text) to authenticated;

drop policy charges_read on public.unit_charges;
create policy charges_read on public.unit_charges for select to authenticated using(
 public.has_building_role(building_id,array['manager','accountant']::public.building_role[]) or public.has_unit_finance_role(building_id,unit_id,responsibility));
drop policy invoices_read on public.invoices;
create policy invoices_read on public.invoices for select to authenticated using(
 public.has_building_role(building_id,array['manager','accountant']::public.building_role[]) or
 (status not in ('draft','cancelled') and public.has_unit_finance_role(building_id,unit_id,responsibility)));
drop policy payments_read on public.payments;
create policy payments_read on public.payments for select to authenticated using(
 public.has_building_role(building_id,array['manager','accountant']::public.building_role[]) or public.has_unit_finance_role(building_id,unit_id,responsibility));
drop policy allocations_read on public.payment_allocations;
create policy allocations_read on public.payment_allocations for select to authenticated using(
 public.has_building_role(building_id,array['manager','accountant']::public.building_role[]) or exists(
  select 1 from public.payments p where p.building_id=payment_allocations.building_id and p.id=payment_allocations.payment_id
   and public.has_unit_finance_role(p.building_id,p.unit_id,p.responsibility)));

drop function public.resident_invoices(uuid,uuid);
create function public.resident_invoices(b uuid,u uuid) returns table(id uuid,invoice_number text,period_title text,principal bigint,discount bigint,penalty bigint,previous_debt bigint,paid_amount bigint,issued_on date,due_on date,status text,responsibility text)
language plpgsql stable security definer set search_path='' as $$ begin
 if auth.uid() is null or not (public.has_unit_finance_role(b,u,'owner') or public.has_unit_finance_role(b,u,'resident')) then raise exception 'Not authorized' using errcode='42501'; end if;
 return query select i.id,i.invoice_number,p.title,i.principal,i.discount,i.penalty,i.previous_debt,i.paid_amount,i.issued_on,i.due_on,i.status,i.responsibility
 from public.invoices i join public.charge_periods p on p.building_id=i.building_id and p.id=i.period_id
 where i.building_id=b and i.unit_id=u and public.has_unit_finance_role(b,u,i.responsibility) and i.status not in ('draft','cancelled') order by i.issued_on desc,i.created_at desc,i.id;
end $$;
revoke all on function public.resident_invoices(uuid,uuid) from public,anon;
grant execute on function public.resident_invoices(uuid,uuid) to authenticated;

create or replace function public.unit_balance(b uuid,u uuid) returns table(debt bigint,credit bigint,net_debt bigint)
language plpgsql stable security definer set search_path='' as $$ declare d bigint; c bigint; staff boolean; begin
 staff:=auth.uid() is not null and public.has_building_role(b,array['manager','accountant']::public.building_role[]);
 if auth.uid() is null or not (staff or public.has_unit_finance_role(b,u,'owner') or public.has_unit_finance_role(b,u,'resident')) then raise exception 'Not authorized' using errcode='42501'; end if;
 if not exists(select 1 from public.units where building_id=b and id=u) then raise exception 'Unit not found'; end if;
 select coalesce(sum(i.principal-i.discount+i.penalty-i.paid_amount),0) into d from public.invoices i where i.building_id=b and i.unit_id=u and i.status not in ('draft','cancelled','paid') and (staff or public.has_unit_finance_role(b,u,i.responsibility));
 select coalesce(sum(p.amount-coalesce((select sum(pa.amount) from public.payment_allocations pa where pa.payment_id=p.id),0)),0) into c from public.payments p where p.building_id=b and p.unit_id=u and (staff or public.has_unit_finance_role(b,u,p.responsibility));
 return query select d,c,d-c;
end $$;

create or replace function public.invoice_charge_lines(b uuid, invoice uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare i public.invoices%rowtype; c public.unit_charges%rowtype; r public.charge_rules%rowtype; begin
 select * into i from public.invoices where building_id=b and id=invoice and status not in ('draft','cancelled');
 if not found or auth.uid() is null or not (public.has_building_role(b,array['manager','accountant']::public.building_role[]) or public.has_unit_finance_role(b,i.unit_id,i.responsibility)) then raise exception 'Not authorized' using errcode='42501'; end if;
 select * into strict c from public.unit_charges where building_id=b and id=i.charge_id;
 if c.metrics ? 'lines' then return c.metrics->'lines'; end if;
 select * into strict r from public.charge_rules where building_id=b and period_id=i.period_id;
 return jsonb_build_array(jsonb_build_object('title','شارژ دوره','category','monthly','note','','responsibility',i.responsibility,'method','mixed','total',r.total_amount,'amount',i.principal,
 'weights',jsonb_build_object('equal',r.equal_weight,'area',r.area_weight,'people',r.people_weight,'parking',r.parking_weight,'storage',r.storage_weight)));
end $$;

-- Keep a durable reference to each role's transferred opening credit.
alter table public.opening_balance_records add column owner_credit_payment_id uuid references public.payments(id), add column resident_credit_payment_id uuid references public.payments(id);

-- A receipt carries its ledger role all the way through bank reconciliation.
alter table public.payment_receipts add column responsibility text not null default 'resident' check(responsibility in ('owner','resident'));
drop policy receipts_read on public.payment_receipts;
create policy receipts_read on public.payment_receipts for select to authenticated using(
 (status<>'uploading' and public.has_building_role(building_id,array['manager']::public.building_role[])) or
 (submitted_by=auth.uid() and public.has_unit_finance_role(building_id,unit_id,responsibility)));
drop policy apartment_receipt_upload on storage.objects;
create policy apartment_receipt_upload on storage.objects for insert to authenticated with check(
 bucket_id='apartment-yar-receipts' and exists(select 1 from public.payment_receipts r where r.object_path=name and r.status='uploading' and r.submitted_by=auth.uid() and public.has_unit_finance_role(r.building_id,r.unit_id,r.responsibility)));
drop policy apartment_receipt_download on storage.objects;
create policy apartment_receipt_download on storage.objects for select to authenticated using(
 bucket_id='apartment-yar-receipts' and exists(select 1 from public.payment_receipts r where r.object_path=name and
 ((r.submitted_by=auth.uid() and public.has_unit_finance_role(r.building_id,r.unit_id,r.responsibility)) or (r.status<>'uploading' and public.has_building_role(r.building_id,array['manager']::public.building_role[])))));
drop function public.create_receipt_upload(uuid,uuid,bigint,text,text,text);
create function public.create_receipt_upload(b uuid,u uuid,target_role text,amount bigint,reference text,note text,mime_type text) returns table(receipt_id uuid,object_path text)
language plpgsql security definer set search_path='' as $$
declare rid uuid:=gen_random_uuid(); path text; begin
 if auth.uid() is null or not public.has_unit_finance_role(b,u,target_role) then raise exception 'Not authorized' using errcode='42501'; end if;
 if amount is null or amount not between 1 and 1000000000000 or length(btrim(coalesce(reference,''))) not between 1 and 120 or length(coalesce(note,''))>1000 or mime_type not in ('image/jpeg','image/png','image/webp') or mime_type is null then raise exception 'Invalid receipt'; end if;
 path:=b::text||'/'||rid::text;
 insert into public.payment_receipts(id,building_id,unit_id,submitted_by,responsibility,amount,reference,note,mime_type,object_path) values(rid,b,u,auth.uid(),target_role,amount,btrim(reference),coalesce(note,''),mime_type,path);
 return query select rid,path;
end $$;
revoke all on function public.create_receipt_upload(uuid,uuid,text,bigint,text,text,text) from public,anon;
grant execute on function public.create_receipt_upload(uuid,uuid,text,bigint,text,text,text) to authenticated;
create or replace function public.post_receipt_payment(b uuid,rid uuid,a uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare r public.payment_receipts%rowtype; p public.payments%rowtype; pid uuid; begin
 perform public.require_finance_manager(b);
 select * into r from public.payment_receipts where id=rid and building_id=b for update;
 if not found then raise exception 'Receipt not found'; end if;
 if r.payment_id is not null then select * into p from public.payments where id=r.payment_id and building_id=b; if not found or p.account_id<>a then raise exception 'Receipt already recorded in a different account'; end if; return r.payment_id; end if;
 if r.status not in ('submitted','reviewed') then raise exception 'Receipt is not eligible for recording'; end if;
 pid:=public.record_role_payment(b,r.unit_id,a,r.amount,'bank_transfer',r.id,r.responsibility);
 update public.payment_receipts set payment_id=pid,status='reviewed',reviewed_at=coalesce(reviewed_at,now()) where id=r.id;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id,details) values(b,auth.uid(),'record_payment','payment_receipt',r.id,jsonb_build_object('payment_id',pid,'responsibility',r.responsibility));
 return pid;
end $$;
revoke all on function public.post_receipt_payment(uuid,uuid,uuid) from public,anon;
grant execute on function public.post_receipt_payment(uuid,uuid,uuid) to authenticated;

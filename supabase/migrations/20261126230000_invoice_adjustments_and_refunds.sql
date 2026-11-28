-- Audited invoice corrections and append-only payment refunds.
create table public.invoice_adjustments (
 id uuid primary key default gen_random_uuid(), building_id uuid not null, invoice_id uuid not null, unit_id uuid not null,
 before_discount bigint not null, after_discount bigint not null, before_penalty bigint not null, after_penalty bigint not null,
 reason text not null check(length(btrim(reason)) between 1 and 500), request_id uuid not null, created_by uuid not null references auth.users(id), created_at timestamptz not null default now(),
 unique(building_id,request_id), foreign key(building_id,invoice_id,unit_id) references public.invoices(building_id,id,unit_id)
);
create index on public.invoice_adjustments(building_id,invoice_id,created_at desc);
alter table public.invoice_adjustments enable row level security;
revoke all on public.invoice_adjustments from public,anon,authenticated;
grant select on public.invoice_adjustments to authenticated;
create policy invoice_adjustments_staff_read on public.invoice_adjustments for select to authenticated using(public.has_building_role(building_id,array['manager','accountant']::public.building_role[]));

create table public.payment_refunds (
 id uuid primary key default gen_random_uuid(), building_id uuid not null, payment_id uuid not null, account_id uuid not null,
 amount bigint not null check(amount between 1 and 1000000000000), reason text not null check(length(btrim(reason)) between 1 and 500),
 request_id uuid not null, created_by uuid not null references auth.users(id), created_at timestamptz not null default now(),
 unique(building_id,request_id), unique(building_id,id), foreign key(building_id,payment_id) references public.payments(building_id,id), foreign key(building_id,account_id) references public.accounts(building_id,id)
);
create index on public.payment_refunds(building_id,payment_id,created_at);
alter table public.payment_refunds enable row level security;
revoke all on public.payment_refunds from public,anon,authenticated;
grant select on public.payment_refunds to authenticated;
create policy payment_refunds_staff_read on public.payment_refunds for select to authenticated using(public.has_building_role(building_id,array['manager','accountant']::public.building_role[]));
create policy payment_refunds_role_read on public.payment_refunds for select to authenticated using(exists(
 select 1 from public.payments p where p.building_id=payment_refunds.building_id and p.id=payment_refunds.payment_id
 and public.has_unit_finance_role(p.building_id,p.unit_id,p.responsibility)));

create table public.payment_allocation_reversals (
 id uuid primary key default gen_random_uuid(), building_id uuid not null, payment_id uuid not null, invoice_id uuid not null, unit_id uuid not null,
 payment_refund_id uuid not null references public.payment_refunds(id), amount bigint not null check(amount>0), created_at timestamptz not null default now(),
 foreign key(building_id,payment_id,unit_id) references public.payments(building_id,id,unit_id),
 foreign key(building_id,invoice_id,unit_id) references public.invoices(building_id,id,unit_id)
);
create index on public.payment_allocation_reversals(payment_refund_id);
create index on public.payment_allocation_reversals(payment_id,invoice_id);
alter table public.payment_allocation_reversals enable row level security;
revoke all on public.payment_allocation_reversals from public,anon,authenticated;
grant select on public.payment_allocation_reversals to authenticated;
create policy payment_allocation_reversals_staff_read on public.payment_allocation_reversals for select to authenticated using(public.has_building_role(building_id,array['manager','accountant']::public.building_role[]));

create function public.adjust_invoice(b uuid, invoice_id uuid, new_discount bigint, new_penalty bigint, reason text, request_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare i public.invoices%rowtype; old public.invoice_adjustments%rowtype; adjustment uuid; total bigint; new_status text; begin
 perform public.require_finance_manager(b);
 if new_discount is null or new_discount<0 or new_penalty is null or new_penalty<0 or length(btrim(coalesce(reason,''))) not between 1 and 500 or request_id is null then raise exception 'Invalid invoice adjustment'; end if;
 perform pg_advisory_xact_lock(hashtextextended(b::text||request_id::text,37));
 select * into old from public.invoice_adjustments x where x.building_id=b and x.request_id=adjust_invoice.request_id;
 if found then
  if old.invoice_id<>adjust_invoice.invoice_id or old.after_discount<>new_discount or old.after_penalty<>new_penalty or old.reason<>btrim(reason) then raise exception 'Request already used for a different invoice adjustment'; end if;
  return old.id;
 end if;
 select * into i from public.invoices x where x.building_id=b and x.id=adjust_invoice.invoice_id for update;
 if not found or i.status in ('draft','cancelled') then raise exception 'Invoice cannot be adjusted'; end if;
 total:=i.principal-new_discount+new_penalty;
 if new_discount>i.principal or total>1000000000000 or total<i.paid_amount then raise exception 'Adjustment cannot reduce amount below payments already allocated'; end if;
 if i.discount=new_discount and i.penalty=new_penalty then raise exception 'Adjustment does not change the invoice'; end if;
 new_status:=case when total=i.paid_amount then 'paid' when i.paid_amount>0 then 'partially_paid' when i.due_on<current_date then 'overdue' else 'issued' end;
 adjustment:=gen_random_uuid();
 update public.invoices set discount=new_discount,penalty=new_penalty,status=new_status where id=i.id and building_id=b;
 insert into public.invoice_adjustments(id,building_id,invoice_id,unit_id,before_discount,after_discount,before_penalty,after_penalty,reason,request_id,created_by)
 values(adjustment,b,i.id,i.unit_id,i.discount,new_discount,i.penalty,new_penalty,btrim(reason),request_id,auth.uid());
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id,details) values(b,auth.uid(),'adjust','invoice',i.id,jsonb_build_object('adjustment_id',adjustment,'before_discount',i.discount,'after_discount',new_discount,'before_penalty',i.penalty,'after_penalty',new_penalty,'reason',btrim(reason)));
 return adjustment;
end $$;
revoke all on function public.adjust_invoice(uuid,uuid,bigint,bigint,text,uuid) from public,anon;
grant execute on function public.adjust_invoice(uuid,uuid,bigint,bigint,text,uuid) to authenticated;

create function public.payment_unallocated_credit(payment_key uuid) returns bigint
language sql stable security definer set search_path='' as $$
 select coalesce(greatest(p.amount
  -coalesce((select sum(r.amount) from public.payment_refunds r where r.payment_id=p.id),0)
  -coalesce((select sum(a.amount) from public.payment_allocations a where a.payment_id=p.id),0)
  +coalesce((select sum(v.amount) from public.payment_allocation_reversals v where v.payment_id=p.id),0),0),0)::bigint
 from public.payments p where p.id=payment_key;
$$;
revoke all on function public.payment_unallocated_credit(uuid) from public,anon,authenticated;

create function public.refund_payment(b uuid,payment_id uuid,amount bigint,reason text,request_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare pay public.payments%rowtype; old public.payment_refunds%rowtype; original public.financial_transactions%rowtype; refund_id uuid; remaining bigint; credit bigint; part bigint; item record; available bigint; new_paid bigint; new_total bigint; begin
 perform public.require_finance_manager(b);
 if amount is null or amount not between 1 and 1000000000000 or length(btrim(coalesce(reason,''))) not between 1 and 500 or request_id is null then raise exception 'Invalid payment refund'; end if;
 perform pg_advisory_xact_lock(hashtextextended(b::text||request_id::text,38));
 select * into old from public.payment_refunds r where r.building_id=b and r.request_id=refund_payment.request_id;
 if found then
  if old.payment_id<>refund_payment.payment_id or old.amount<>refund_payment.amount or old.reason<>btrim(reason) then raise exception 'Request already used for a different refund'; end if;
  return old.id;
 end if;
 select * into pay from public.payments p where p.building_id=b and p.id=refund_payment.payment_id for update;
 if not found or pay.account_id is null or pay.method='opening_credit' then raise exception 'Payment is not refundable through a cash account'; end if;
 if not exists(select 1 from public.accounts a where a.building_id=b and a.id=pay.account_id) then raise exception 'Payment account not found'; end if;
 select * into original from public.financial_transactions t where t.building_id=b and t.reference_type='payment' and t.reference_id=pay.id and t.transaction_type='receipt';
 if not found then raise exception 'Original receipt transaction not found'; end if;
 if amount>pay.amount-coalesce((select sum(r.amount) from public.payment_refunds r where r.payment_id=pay.id),0) then raise exception 'Refund exceeds remaining payment amount'; end if;
 credit:=public.payment_unallocated_credit(pay.id);
 refund_id:=gen_random_uuid();
 insert into public.payment_refunds(id,building_id,payment_id,account_id,amount,reason,request_id,created_by) values(refund_id,b,pay.id,pay.account_id,amount,btrim(reason),request_id,auth.uid());
 remaining:=greatest(amount-credit,0);
 for item in select a.id,a.invoice_id,a.amount-coalesce((select sum(v.amount) from public.payment_allocation_reversals v where v.payment_id=pay.id and v.invoice_id=a.invoice_id),0) available,
  i.paid_amount,i.principal,i.discount,i.penalty,i.due_on,i.unit_id
  from public.payment_allocations a join public.invoices i on i.building_id=a.building_id and i.id=a.invoice_id
  where a.building_id=b and a.payment_id=pay.id order by i.due_on desc,i.issued_on desc,i.created_at desc,a.created_at desc,i.id desc,a.id desc for update of i loop
  exit when remaining=0;
  available:=item.available; part:=least(available,remaining);
  if part>0 then
   if part>item.paid_amount then raise exception 'Payment allocation ledger is inconsistent'; end if;
   insert into public.payment_allocation_reversals(building_id,payment_id,invoice_id,unit_id,payment_refund_id,amount) values(b,pay.id,item.invoice_id,item.unit_id,refund_id,part);
   new_paid:=item.paid_amount-part; new_total:=item.principal-item.discount+item.penalty;
   update public.invoices set paid_amount=new_paid,status=case when new_paid=new_total then 'paid' when new_paid>0 then 'partially_paid' when item.due_on<current_date then 'overdue' else 'issued' end where id=item.invoice_id and building_id=b;
   remaining:=remaining-part;
  end if;
 end loop;
 if remaining>0 then raise exception 'Refund could not be fully matched to the payment ledger'; end if;
 insert into public.financial_transactions(id,building_id,account_id,transaction_type,amount,document_no,description,created_by,reference_type,reference_id)
 values(refund_id,b,pay.account_id,'adjustment_out',amount,'REF-'||replace(refund_id::text,'-',''),'برگشت دریافت: '||btrim(reason),auth.uid(),'payment_refund',refund_id);
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id,details) values(b,auth.uid(),'refund','payment',pay.id,jsonb_build_object('refund_id',refund_id,'amount',amount,'reason',btrim(reason)));
 return refund_id;
end $$;
revoke all on function public.refund_payment(uuid,uuid,bigint,text,uuid) from public,anon;
grant execute on function public.refund_payment(uuid,uuid,bigint,text,uuid) to authenticated;

-- Keep credit reports and future charge allocation aligned with partial refunds.
create or replace function public.issue_charge_period(p uuid) returns integer language plpgsql security definer set search_path='' as $$
declare cp public.charge_periods%rowtype; x record; c uuid; invoice_id uuid; n integer:=0; prev bigint; credit_row record; available bigint; applied bigint; remaining bigint; begin
 select * into cp from public.charge_periods where id=p for update;
 if not found then raise exception 'Period not found'; end if; perform public.require_finance_manager(cp.building_id);
 if cp.status<>'draft' then raise exception 'Period already issued'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u.id::text,0)) from public.units u where u.building_id=cp.building_id order by u.id;
 perform u.id from public.units u where u.building_id=cp.building_id order by u.id for share;
 for x in select v.unit_id,coalesce(z.amount,v.amount) amount,case when z.role is null then v.metrics else jsonb_set(v.metrics,'{lines}',z.lines) end metrics,coalesce(z.role,'resident') responsibility
 from public.preview_charge_period(p) v left join lateral (select l->>'responsibility' role,sum((l->>'amount')::bigint)::bigint amount,jsonb_agg(l) lines from jsonb_array_elements(coalesce(v.metrics->'lines','[]'::jsonb)) l group by l->>'responsibility') z on true loop
  select coalesce(sum(i.principal-i.discount+i.penalty-i.paid_amount),0) into prev from public.invoices i where i.building_id=cp.building_id and i.unit_id=x.unit_id and i.responsibility=x.responsibility and i.status not in ('draft','cancelled','paid');
  insert into public.unit_charges(building_id,period_id,unit_id,amount,metrics,responsibility) values(cp.building_id,p,x.unit_id,x.amount,x.metrics,x.responsibility) returning id into c;
  insert into public.invoices(building_id,unit_id,period_id,charge_id,invoice_number,principal,previous_debt,issued_on,due_on,status,responsibility)
  values(cp.building_id,x.unit_id,p,c,'INV-'||replace(c::text,'-',''),x.amount,prev,cp.issued_on,cp.due_on,case when x.amount=0 then 'paid' else 'issued' end,x.responsibility) returning id into invoice_id;
  remaining:=x.amount;
  for credit_row in select pay.id,public.payment_unallocated_credit(pay.id) credit from public.payments pay where pay.building_id=cp.building_id and pay.unit_id=x.unit_id and pay.responsibility=x.responsibility order by pay.paid_at,pay.id loop
   exit when remaining=0; available:=credit_row.credit; applied:=least(available,remaining);
   if applied>0 then insert into public.payment_allocations(building_id,payment_id,invoice_id,unit_id,amount) values(cp.building_id,credit_row.id,invoice_id,x.unit_id,applied);
    update public.invoices set paid_amount=paid_amount+applied,status=case when paid_amount+applied=principal-discount+penalty then 'paid' else 'partially_paid' end where id=invoice_id; remaining:=remaining-applied; end if;
  end loop;
  n:=n+1;
 end loop;
 update public.charge_periods set status='issued' where id=p;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id,details) values(cp.building_id,auth.uid(),'issue','charge_period',p,jsonb_build_object('units',n)); return n;
end $$;

create or replace function public.unit_balance(b uuid,u uuid) returns table(debt bigint,credit bigint,net_debt bigint)
language plpgsql stable security definer set search_path='' as $$ declare d bigint; c bigint; staff boolean; begin
 staff:=auth.uid() is not null and public.has_building_role(b,array['manager','accountant']::public.building_role[]);
 if auth.uid() is null or not (staff or public.has_unit_finance_role(b,u,'owner') or public.has_unit_finance_role(b,u,'resident')) then raise exception 'Not authorized' using errcode='42501'; end if;
 if not exists(select 1 from public.units where building_id=b and id=u) then raise exception 'Unit not found'; end if;
 select coalesce(sum(i.principal-i.discount+i.penalty-i.paid_amount),0) into d from public.invoices i where i.building_id=b and i.unit_id=u and i.status not in ('draft','cancelled','paid') and (staff or public.has_unit_finance_role(b,u,i.responsibility));
 select coalesce(sum(public.payment_unallocated_credit(p.id)),0) into c from public.payments p where p.building_id=b and p.unit_id=u and (staff or public.has_unit_finance_role(b,u,p.responsibility));
 return query select d,c,d-c;
end $$;

create or replace function public.report_role_balances(b uuid)
returns table(unit_id uuid,unit_number text,responsibility text,debt bigint,credit bigint,net_debt bigint)
language plpgsql stable security definer set search_path='' as $$ begin
 if auth.uid() is null or not public.has_building_role(b,array['manager','accountant']::public.building_role[]) then raise exception 'Not authorized' using errcode='42501'; end if;
 return query select u.id,u.number,r.role,d.amount,c.amount,d.amount-c.amount from public.units u cross join (values ('owner'),('resident')) r(role)
 cross join lateral (select coalesce(sum(i.principal-i.discount+i.penalty-i.paid_amount),0)::bigint amount from public.invoices i where i.building_id=b and i.unit_id=u.id and i.responsibility=r.role and i.status not in ('draft','cancelled')) d
 cross join lateral (select coalesce(sum(public.payment_unallocated_credit(p.id)),0)::bigint amount from public.payments p where p.building_id=b and p.unit_id=u.id and p.responsibility=r.role) c
 where u.building_id=b order by u.number,r.role;
end $$;
revoke all on function public.report_role_balances(uuid) from public,anon;
grant execute on function public.report_role_balances(uuid) to authenticated;

create or replace function public.report_unit_balances(b uuid,p uuid default null)
returns table(unit_id uuid,unit_number text,issued bigint,paid bigint,debt bigint,credit bigint,net_debt bigint)
language plpgsql stable security definer set search_path='' as $$ begin
 if auth.uid() is null or not public.has_building_role(b,array['manager','accountant']::public.building_role[]) then raise exception 'Not authorized' using errcode='42501'; end if;
 if p is not null and not exists(select 1 from public.charge_periods where id=p and building_id=b) then raise exception 'Period not found'; end if;
 return query with invoice_totals as (
  select i.unit_id,sum(i.principal-i.discount+i.penalty)::bigint issued,sum(i.paid_amount)::bigint paid from public.invoices i where i.building_id=b and i.status not in ('draft','cancelled') and (p is null or i.period_id=p) group by i.unit_id
 ), credits as (select pay.unit_id,sum(public.payment_unallocated_credit(pay.id))::bigint credit from public.payments pay where pay.building_id=b group by pay.unit_id)
 select u.id,u.number,coalesce(i.issued,0)::bigint,coalesce(i.paid,0)::bigint,(coalesce(i.issued,0)-coalesce(i.paid,0))::bigint,coalesce(c.credit,0)::bigint,(coalesce(i.issued,0)-coalesce(i.paid,0)-coalesce(c.credit,0))::bigint
 from public.units u left join invoice_totals i on i.unit_id=u.id left join credits c on c.unit_id=u.id where u.building_id=b order by u.number,u.id;
end $$;
revoke all on function public.report_unit_balances(uuid,uuid) from public,anon;
grant execute on function public.report_unit_balances(uuid,uuid) to authenticated;

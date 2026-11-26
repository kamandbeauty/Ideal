-- Recording an independently verified bank transfer against its receipt is atomic and repeat-safe.
alter table public.payment_receipts add column payment_id uuid;
alter table public.payment_receipts add constraint payment_receipts_payment_fkey foreign key(building_id,payment_id) references public.payments(building_id,id);
create unique index payment_receipts_payment_unique on public.payment_receipts(payment_id) where payment_id is not null;
create function public.post_receipt_payment(b uuid,rid uuid,a uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare r public.payment_receipts%rowtype; p public.payments%rowtype; pid uuid; begin
 perform public.require_finance_manager(b);
 select * into r from public.payment_receipts where id=rid and building_id=b for update;
 if not found then raise exception 'Receipt not found'; end if;
 if r.payment_id is not null then
  select * into p from public.payments where id=r.payment_id and building_id=b;
  if not found or p.account_id<>a then raise exception 'Receipt already recorded in a different account'; end if;
  return r.payment_id;
 end if;
 if r.status not in ('submitted','reviewed') then raise exception 'Receipt is not eligible for recording'; end if;
 -- receipt UUID is the operation key, so retries and concurrent submissions cannot create a second payment.
 pid:=public.record_manual_payment(b,r.unit_id,a,r.amount,'bank_transfer',r.id);
 update public.payment_receipts set payment_id=pid,status='reviewed',reviewed_at=coalesce(reviewed_at,now()) where id=r.id;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id,details) values(b,auth.uid(),'record_payment','payment_receipt',r.id,jsonb_build_object('payment_id',pid));
 return pid;
end $$;
revoke all on function public.post_receipt_payment(uuid,uuid,uuid) from public,anon;
grant execute on function public.post_receipt_payment(uuid,uuid,uuid) to authenticated;

-- Snapshot-based reports; no financial mutation is performed by these RPCs.
create function public.report_unit_balances(b uuid,p uuid default null)
returns table(unit_id uuid,unit_number text,issued bigint,paid bigint,debt bigint,credit bigint,net_debt bigint)
language plpgsql stable security definer set search_path='' as $$ begin
 if auth.uid() is null or not public.has_building_role(b,array['manager','accountant']::public.building_role[]) then raise exception 'Not authorized' using errcode='42501'; end if;
 if p is not null and not exists(select 1 from public.charge_periods where id=p and building_id=b) then raise exception 'Period not found'; end if;
 return query with invoice_totals as (
  select i.unit_id,sum(i.principal-i.discount+i.penalty)::bigint as issued,sum(i.paid_amount)::bigint as paid
  from public.invoices i where i.building_id=b and i.status not in ('draft','cancelled') and (p is null or i.period_id=p) group by i.unit_id
 ), credits as (
  select pay.unit_id,sum(pay.amount-coalesce((select sum(a.amount) from public.payment_allocations a where a.building_id=b and a.payment_id=pay.id),0))::bigint as credit
  from public.payments pay where pay.building_id=b group by pay.unit_id
 )
 select u.id,u.number,coalesce(i.issued,0)::bigint,coalesce(i.paid,0)::bigint,(coalesce(i.issued,0)-coalesce(i.paid,0))::bigint,coalesce(c.credit,0)::bigint,
 (coalesce(i.issued,0)-coalesce(i.paid,0)-coalesce(c.credit,0))::bigint
 from public.units u left join invoice_totals i on i.unit_id=u.id left join credits c on c.unit_id=u.id where u.building_id=b order by u.number,u.id;
end $$;
revoke all on function public.report_unit_balances(uuid,uuid) from public,anon;
grant execute on function public.report_unit_balances(uuid,uuid) to authenticated;

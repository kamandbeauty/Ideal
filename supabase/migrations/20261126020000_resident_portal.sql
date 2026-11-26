-- A unit's owner/tenant role must match the active association, not merely a
-- different role held by the same user in the building.
create or replace function public.is_unit_resident(b uuid, u uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.unit_residents r join public.building_members m
 on m.building_id=r.building_id and m.user_id=r.user_id
 and ((r.kind='owner' and m.role='owner') or (r.kind='tenant' and m.role='resident'))
 where r.building_id=b and r.unit_id=u and r.user_id=auth.uid()
 and (r.starts_on is null or r.starts_on<=current_date) and (r.ends_on is null or r.ends_on>=current_date));
$$;
-- Link only a verified existing phone account. Creating a contact never grants access.
create function public.link_unit_resident(resident_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare r public.unit_residents%rowtype; target uuid; matches integer; normalized text; role_value public.building_role; begin
 select * into r from public.unit_residents where id=resident_id for update;
 if not found then raise exception 'Contact not found'; end if;
 perform public.require_finance_manager(r.building_id);
 if r.user_id is not null then raise exception 'Contact is already linked'; end if;
 normalized:=regexp_replace(translate(r.phone,'۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩','01234567890123456789'),'[[:space:]-]','','g');
 if normalized ~ '^0[0-9]{10}$' then normalized:='+98'||substr(normalized,2); end if;
 if normalized !~ '^\+[1-9][0-9]{7,14}$' then raise exception 'Invalid phone number'; end if;
 select count(*), min(id::text)::uuid into matches,target from auth.users where ltrim(phone,'+')=ltrim(normalized,'+') and phone_confirmed_at is not null;
 if matches<>1 then raise exception 'No unique verified account for this phone'; end if;
 role_value:=case r.kind when 'owner' then 'owner'::public.building_role else 'resident'::public.building_role end;
 insert into public.building_members(building_id,user_id,role) values(r.building_id,target,role_value) on conflict(building_id,user_id,role) do nothing;
 update public.unit_residents set user_id=target where id=r.id;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id) values(r.building_id,auth.uid(),'link','unit_resident',r.id);
end $$;
revoke all on function public.link_unit_resident(uuid) from public,anon;
grant execute on function public.link_unit_resident(uuid) to authenticated;

create function public.my_resident_units() returns table(building_id uuid,building_name text,unit_id uuid,unit_number text,kind text)
language sql stable security definer set search_path='' as $$
 select distinct r.building_id,b.name,r.unit_id,u.number,r.kind from public.unit_residents r
 join public.buildings b on b.id=r.building_id join public.units u on u.building_id=r.building_id and u.id=r.unit_id
 join public.building_members m on m.building_id=r.building_id and m.user_id=r.user_id and ((r.kind='owner' and m.role='owner') or (r.kind='tenant' and m.role='resident'))
 where auth.uid() is not null and r.user_id=auth.uid()
 and (r.starts_on is null or r.starts_on<=current_date) and (r.ends_on is null or r.ends_on>=current_date)
 order by b.name,u.number,r.kind;
$$;
revoke all on function public.my_resident_units() from public,anon;
grant execute on function public.my_resident_units() to authenticated;

-- Return only the caller's authorized unit invoices; no broad period table access.
create function public.resident_invoices(b uuid,u uuid) returns table(id uuid,invoice_number text,period_title text,principal bigint,discount bigint,penalty bigint,previous_debt bigint,paid_amount bigint,issued_on date,due_on date,status text)
language plpgsql stable security definer set search_path='' as $$ begin
 if auth.uid() is null or not public.is_unit_resident(b,u) then raise exception 'Not authorized' using errcode='42501'; end if;
 return query select i.id,i.invoice_number,p.title,i.principal,i.discount,i.penalty,i.previous_debt,i.paid_amount,i.issued_on,i.due_on,i.status
 from public.invoices i join public.charge_periods p on p.building_id=i.building_id and p.id=i.period_id
 where i.building_id=b and i.unit_id=u and i.status not in ('draft','cancelled') order by i.issued_on desc,i.created_at desc,i.id;
end $$;
revoke all on function public.resident_invoices(uuid,uuid) from public,anon;
grant execute on function public.resident_invoices(uuid,uuid) to authenticated;
-- Residents see only issued invoices. Staff retain their existing access.
drop policy invoices_read on public.invoices;
create policy invoices_read on public.invoices for select to authenticated using (
 public.has_building_role(building_id,array['manager','accountant']::public.building_role[])
 or (status not in ('draft','cancelled') and public.is_unit_resident(building_id,unit_id))
);

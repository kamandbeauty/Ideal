-- Management of already verified accounts; this does not send invitations or SMS.
create function public.verified_phone_account(raw_phone text) returns uuid
language plpgsql stable security definer set search_path='' as $$
declare normalized text; matches integer; target uuid; begin
 normalized:=regexp_replace(translate(coalesce(raw_phone,''),'۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩','01234567890123456789'),'[[:space:]-]','','g');
 if normalized ~ '^0[0-9]{10}$' then normalized:='+98'||substr(normalized,2); end if;
 if normalized !~ '^\+[1-9][0-9]{7,14}$' then raise exception 'Invalid phone number'; end if;
 select count(*),min(id::text)::uuid into matches,target from auth.users where ltrim(phone,'+')=ltrim(normalized,'+') and phone_confirmed_at is not null;
 if matches<>1 then raise exception 'No unique verified account for this phone'; end if; return target;
end $$;
revoke all on function public.verified_phone_account(text) from public,anon,authenticated;

-- Lock per building/user to serialize removal of shared roles across unit links.
create or replace function public.link_unit_resident(resident_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare r public.unit_residents%rowtype; target uuid; role_value public.building_role; begin
 select * into r from public.unit_residents where id=resident_id for update;
 if not found then raise exception 'Contact not found'; end if; perform public.require_finance_manager(r.building_id);
 if r.user_id is not null then raise exception 'Contact is already linked'; end if;
 target:=public.verified_phone_account(r.phone);
 perform pg_advisory_xact_lock(hashtextextended(r.building_id::text||target::text,7));
 role_value:=case r.kind when 'owner' then 'owner'::public.building_role else 'resident'::public.building_role end;
 insert into public.building_members(building_id,user_id,role) values(r.building_id,target,role_value) on conflict(building_id,user_id,role) do nothing;
 update public.unit_residents set user_id=target where id=r.id;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id) values(r.building_id,auth.uid(),'link','unit_resident',r.id);
end $$;
create function public.unlink_unit_resident(resident_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare r public.unit_residents%rowtype; role_value public.building_role; begin
 select * into r from public.unit_residents where id=resident_id for update;
 if not found then raise exception 'Contact not found'; end if; perform public.require_finance_manager(r.building_id);
 if r.user_id is null then raise exception 'Contact is not linked'; end if;
 perform pg_advisory_xact_lock(hashtextextended(r.building_id::text||r.user_id::text,7));
 role_value:=case r.kind when 'owner' then 'owner'::public.building_role else 'resident'::public.building_role end;
 update public.unit_residents set user_id=null where id=r.id;
 if not exists(select 1 from public.unit_residents x where x.building_id=r.building_id and x.user_id=r.user_id and x.kind=r.kind) then
  delete from public.building_members where building_id=r.building_id and user_id=r.user_id and role=role_value;
 end if;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id) values(r.building_id,auth.uid(),'unlink','unit_resident',r.id);
end $$;
create function public.assign_staff(b uuid,phone text,staff_role text) returns uuid language plpgsql security definer set search_path='' as $$
declare target uuid; membership uuid; role_value public.building_role; begin
 perform public.require_finance_manager(b);
 if staff_role is null or staff_role not in ('accountant','maintenance') then raise exception 'Invalid staff role'; end if;
 target:=public.verified_phone_account(phone);role_value:=staff_role::public.building_role;
 perform pg_advisory_xact_lock(hashtextextended(b::text||target::text,7));
 insert into public.building_members(building_id,user_id,role) values(b,target,role_value) on conflict(building_id,user_id,role) do nothing returning id into membership;
 if membership is null then raise exception 'Role already assigned'; end if;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id,details) values(b,auth.uid(),'assign','building_member',membership,jsonb_build_object('role',staff_role));
 return membership;
end $$;
create function public.remove_staff(b uuid,member_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare m public.building_members%rowtype; begin
 perform public.require_finance_manager(b);
 select * into m from public.building_members where id=member_id and building_id=b for update;
 if not found or m.role not in ('accountant','maintenance') then raise exception 'Staff role not found'; end if;
 perform pg_advisory_xact_lock(hashtextextended(b::text||m.user_id::text,7));
 delete from public.building_members where id=m.id;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id,details) values(b,auth.uid(),'remove','building_member',m.id,jsonb_build_object('role',m.role));
end $$;
create function public.list_staff(b uuid) returns table(member_id uuid,role public.building_role,phone text)
language plpgsql stable security definer set search_path='' as $$ begin
 perform public.require_finance_manager(b);
 return query select m.id,m.role,u.phone from public.building_members m join auth.users u on u.id=m.user_id where m.building_id=b and m.role in ('accountant','maintenance') order by m.created_at;
end $$;
revoke all on function public.unlink_unit_resident(uuid) from public,anon;
revoke all on function public.assign_staff(uuid,text,text) from public,anon;
revoke all on function public.remove_staff(uuid,uuid) from public,anon;
revoke all on function public.list_staff(uuid) from public,anon;
grant execute on function public.unlink_unit_resident(uuid) to authenticated;
grant execute on function public.assign_staff(uuid,text,text) to authenticated;
grant execute on function public.remove_staff(uuid,uuid) to authenticated;
grant execute on function public.list_staff(uuid) to authenticated;

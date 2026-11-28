-- Minimal, app-owner-only operational inventory. Never expose auth.users directly.
drop function public.app_admin_overview();
create function public.app_admin_overview()
returns table(buildings bigint,units bigint,active_plans bigint,users bigint,active_users_30d bigint)
language plpgsql stable security definer set search_path='' as $$
begin
 if not public.is_app_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 return query
 select
  (select count(*) from public.buildings),
  (select count(*) from public.units),
  (select count(*) from public.subscription_plans where active),
  (select count(*) from auth.users),
  (select count(*) from auth.users where last_sign_in_at >= now()-interval '30 days');
end $$;

create or replace function public.app_admin_users(search_text text,page_offset integer)
returns table(id uuid,full_name text,phone_masked text,created_at timestamptz,last_sign_in_at timestamptz,building_count bigint)
language plpgsql stable security definer set search_path='' as $$
begin
 if not public.is_app_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 if search_text is null or length(search_text)>100 or page_offset is null or page_offset<0 or page_offset>100000 then
  raise exception 'Invalid search or offset';
 end if;
 return query
 select u.id,coalesce(nullif(p.full_name,''),'بدون نام'),
  case when coalesce(u.phone,'')='' then '—'
       when length(u.phone)<=4 then repeat('•',length(u.phone))
       else left(u.phone,3)||repeat('•',greatest(length(u.phone)-5,1))||right(u.phone,2) end,
  u.created_at,u.last_sign_in_at,
  (select count(distinct m.building_id) from public.building_members m where m.user_id=u.id)
 from auth.users u left join public.profiles p on p.id=u.id
 where search_text='' or strpos(lower(coalesce(p.full_name,'')||' '||coalesce(u.phone,'')),lower(btrim(search_text)))>0
 order by u.created_at desc,u.id desc limit 21 offset page_offset;
end $$;

-- All non-deleted records are currently active; buildings do not yet have a
-- pause/archive lifecycle in the product schema.
create or replace function public.app_admin_active_buildings(search_text text,page_offset integer)
returns table(id uuid,name text,created_at timestamptz,unit_count bigint,manager_count bigint)
language plpgsql stable security definer set search_path='' as $$
begin
 if not public.is_app_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 if search_text is null or length(search_text)>100 or page_offset is null or page_offset<0 or page_offset>100000 then
  raise exception 'Invalid search or offset';
 end if;
 return query select b.id,b.name,b.created_at,
  (select count(*) from public.units u where u.building_id=b.id),
  (select count(*) from public.building_members m where m.building_id=b.id and m.role='manager')
 from public.buildings b where strpos(lower(b.name),lower(btrim(search_text)))>0
 order by b.created_at desc,b.id desc limit 21 offset page_offset;
end $$;

-- A private Storage bucket holds encrypted multipart archives. Return names and
-- aggregate sizes only; never issue signed URLs through the public API.
create or replace function public.app_admin_backup_inventory()
returns table(archive_name text,part_count bigint,total_bytes bigint,last_part_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not public.is_app_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 return query
 select regexp_replace(o.name,'\.part[0-9]{4}$',''),count(*),
  coalesce(sum(case when (o.metadata->>'size') ~ '^[0-9]+$' then (o.metadata->>'size')::bigint else 0 end),0),
  max(o.created_at)
 from storage.objects o
 where o.bucket_id='apartment-yar-db-backups' and o.name ~ '\.tar\.gz\.gpg\.part[0-9]{4}$'
 group by regexp_replace(o.name,'\.part[0-9]{4}$','')
 order by max(o.created_at) desc limit 20;
end $$;

revoke all on function public.app_admin_overview(),public.app_admin_users(text,integer),public.app_admin_active_buildings(text,integer),public.app_admin_backup_inventory() from public,anon;
grant execute on function public.app_admin_overview(),public.app_admin_users(text,integer),public.app_admin_active_buildings(text,integer),public.app_admin_backup_inventory() to authenticated;

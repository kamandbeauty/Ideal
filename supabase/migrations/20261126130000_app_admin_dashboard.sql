-- App administrators may inspect limited operational metadata, not building finances or resident data.
create function public.app_admin_overview() returns table(buildings bigint,units bigint,active_plans bigint)
language plpgsql stable security definer set search_path='' as $$ begin
 if not public.is_app_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 return query select (select count(*) from public.buildings), (select count(*) from public.units), (select count(*) from public.subscription_plans where active);
end $$;
create function public.app_admin_buildings(search_text text,page_offset integer) returns table(id uuid,name text,created_at timestamptz,unit_count bigint,manager_count bigint)
language plpgsql stable security definer set search_path='' as $$ begin
 if not public.is_app_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 if search_text is null or length(search_text)>100 or page_offset is null or page_offset<0 or page_offset>100000 then raise exception 'Invalid search or offset'; end if;
 return query select b.id,b.name,b.created_at,(select count(*) from public.units u where u.building_id=b.id),(select count(*) from public.building_members m where m.building_id=b.id and m.role='manager')
 from public.buildings b where strpos(lower(b.name),lower(btrim(search_text)))>0 order by b.created_at desc,b.id desc limit 21 offset page_offset;
end $$;
create function public.app_admin_plan_history(page_offset integer) returns table(id uuid,plan_id uuid,actor_id uuid,old_values jsonb,new_values jsonb,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$ begin
 if not public.is_app_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 if page_offset is null or page_offset<0 or page_offset>100000 then raise exception 'Invalid offset'; end if;
 return query select a.id,a.plan_id,a.actor_id,a.old_values,a.new_values,a.created_at from public.subscription_plan_audit a order by a.created_at desc,a.id desc limit 21 offset page_offset;
end $$;
revoke all on function public.app_admin_overview(),public.app_admin_buildings(text,integer),public.app_admin_plan_history(integer) from public,anon;
grant execute on function public.app_admin_overview(),public.app_admin_buildings(text,integer),public.app_admin_plan_history(integer) to authenticated;

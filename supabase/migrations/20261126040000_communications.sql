-- Private resident-to-manager messages and building/unit announcements.
create table public.announcements (
 id uuid primary key default gen_random_uuid(),building_id uuid not null references public.buildings(id),unit_id uuid,
 title text not null check(length(btrim(title)) between 1 and 160),body text not null check(length(btrim(body)) between 1 and 5000),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),
 foreign key(building_id,unit_id) references public.units(building_id,id)
);
create table public.conversations (
 id uuid primary key default gen_random_uuid(),building_id uuid not null,unit_id uuid not null,resident_id uuid not null references auth.users(id),
 created_at timestamptz not null default now(),unique(building_id,id),unique(building_id,unit_id,resident_id),
 foreign key(building_id,unit_id) references public.units(building_id,id)
);
create table public.messages (
 id uuid primary key default gen_random_uuid(),building_id uuid not null,conversation_id uuid not null,
 sender_id uuid not null references auth.users(id),body text not null check(length(btrim(body)) between 1 and 4000),
 created_at timestamptz not null default now(),foreign key(building_id,conversation_id) references public.conversations(building_id,id)
);
create index on public.announcements(building_id,created_at desc);
create index on public.conversations(building_id,unit_id,resident_id);
create index on public.messages(building_id,conversation_id,created_at);
alter table public.announcements enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
revoke all on public.announcements,public.conversations,public.messages from public,anon,authenticated;
grant select on public.announcements,public.conversations,public.messages to authenticated;
create policy announcements_select on public.announcements for select to authenticated using (
 public.has_building_role(building_id,array['manager']::public.building_role[]) or
 (unit_id is null and public.has_active_unit(building_id)) or (unit_id is not null and public.is_unit_resident(building_id,unit_id))
);
create function public.can_read_conversation(b uuid,c uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.conversations x where x.building_id=b and x.id=c and
 (public.has_building_role(b,array['manager']::public.building_role[]) or (x.resident_id=auth.uid() and public.is_unit_resident(b,x.unit_id))));
$$;
revoke all on function public.can_read_conversation(uuid,uuid) from public,anon;
grant execute on function public.can_read_conversation(uuid,uuid) to authenticated;
create policy conversations_select on public.conversations for select to authenticated using (public.can_read_conversation(building_id,id));
create policy messages_select on public.messages for select to authenticated using (public.can_read_conversation(building_id,conversation_id));
create function public.publish_announcement(b uuid,u uuid,title text,body text) returns uuid language plpgsql security definer set search_path='' as $$
declare id uuid; begin
 perform public.require_finance_manager(b);
 if u is not null and not exists(select 1 from public.units where building_id=b and units.id=u) then raise exception 'Invalid unit'; end if;
 insert into public.announcements(building_id,unit_id,title,body,created_by) values(b,u,btrim(title),btrim(body),auth.uid()) returning announcements.id into id;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id) values(b,auth.uid(),'publish','announcement',id); return id;
end $$;
create function public.open_resident_conversation(b uuid,u uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare cid uuid; begin
 if auth.uid() is null or not public.is_unit_resident(b,u) then raise exception 'Not authorized' using errcode='42501'; end if;
 insert into public.conversations(building_id,unit_id,resident_id) values(b,u,auth.uid()) on conflict(building_id,unit_id,resident_id) do update set resident_id=excluded.resident_id returning id into cid;
 return cid;
end $$;
create function public.send_conversation_message(b uuid,c uuid,body text) returns uuid language plpgsql security definer set search_path='' as $$
declare mid uuid; begin
 if auth.uid() is null or not public.can_read_conversation(b,c) then raise exception 'Not authorized' using errcode='42501'; end if;
 if length(btrim(coalesce(body,''))) not between 1 and 4000 then raise exception 'Invalid message'; end if;
 insert into public.messages(building_id,conversation_id,sender_id,body) values(b,c,auth.uid(),btrim(body)) returning id into mid;
 return mid;
end $$;
revoke all on function public.publish_announcement(uuid,uuid,text,text) from public,anon;
revoke all on function public.open_resident_conversation(uuid,uuid) from public,anon;
revoke all on function public.send_conversation_message(uuid,uuid,text) from public,anon;
grant execute on function public.publish_announcement(uuid,uuid,text,text) to authenticated;
grant execute on function public.open_resident_conversation(uuid,uuid) to authenticated;
grant execute on function public.send_conversation_message(uuid,uuid,text) to authenticated;

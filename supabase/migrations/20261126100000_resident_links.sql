-- A link is a navigation aid bound to an existing authenticated resident, not a login credential.
create table public.resident_links (
 id uuid primary key default gen_random_uuid(),
 resident_id uuid not null references public.unit_residents(id) on delete cascade,
 user_id uuid not null references auth.users(id),
 token_hash text not null unique,
 expires_at timestamptz not null,
 revoked_at timestamptz,
 created_at timestamptz not null default now()
);
alter table public.resident_links enable row level security;
revoke all on public.resident_links from public, anon, authenticated;

create function public.issue_resident_link(resident_id uuid) returns text
language plpgsql security definer set search_path='' as $$
declare r public.unit_residents%rowtype; token text; begin
 select * into r from public.unit_residents where id=resident_id for update;
 if not found then raise exception 'Contact not found'; end if;
 if not public.has_building_role(r.building_id,array['manager']::public.building_role[]) then raise exception 'Not authorized' using errcode='42501'; end if;
 if r.user_id is null or (r.starts_on is not null and r.starts_on>current_date) or (r.ends_on is not null and r.ends_on<current_date) or not exists (
  select 1 from public.building_members m where m.building_id=r.building_id and m.user_id=r.user_id and ((r.kind='owner' and m.role='owner') or (r.kind='tenant' and m.role='resident'))
 ) then raise exception 'Resident account is not active'; end if;
 update public.resident_links set revoked_at=now() where resident_links.resident_id=r.id and revoked_at is null;
 token:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
 insert into public.resident_links(resident_id,user_id,token_hash,expires_at) values(r.id,r.user_id,encode(sha256(convert_to(token,'UTF8')),'hex'),now()+interval '7 days');
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id) values(r.building_id,auth.uid(),'issue_link','unit_resident',r.id);
 return token;
end $$;
create function public.revoke_resident_links(resident_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare r public.unit_residents%rowtype; begin
 select * into r from public.unit_residents where id=resident_id for update;
 if not found then raise exception 'Contact not found'; end if;
 if not public.has_building_role(r.building_id,array['manager']::public.building_role[]) then raise exception 'Not authorized' using errcode='42501'; end if;
 update public.resident_links set revoked_at=now() where resident_links.resident_id=r.id and revoked_at is null;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id) values(r.building_id,auth.uid(),'revoke_links','unit_resident',r.id);
end $$;
create function public.resolve_resident_link(token text) returns table(building_id uuid,unit_id uuid)
language plpgsql stable security definer set search_path='' as $$ begin
 if auth.uid() is null or token is null or token !~ '^[0-9a-f]{64}$' then raise exception 'Invalid or expired link' using errcode='42501'; end if;
 return query select r.building_id,r.unit_id from public.resident_links l join public.unit_residents r on r.id=l.resident_id
 where l.token_hash=encode(sha256(convert_to(token,'UTF8')),'hex') and l.user_id=auth.uid() and r.user_id=l.user_id
 and l.revoked_at is null and l.expires_at>now() and public.is_unit_resident(r.building_id,r.unit_id);
 if not found then raise exception 'Invalid or expired link' using errcode='42501'; end if;
end $$;
revoke all on function public.issue_resident_link(uuid),public.revoke_resident_links(uuid),public.resolve_resident_link(text) from public,anon;
grant execute on function public.issue_resident_link(uuid),public.revoke_resident_links(uuid),public.resolve_resident_link(text) to authenticated;
-- A detached or changed association must never revive an old link on reconnection.
create function public.invalidate_changed_resident_links() returns trigger language plpgsql security definer set search_path='' as $$ begin
 if new.user_id is distinct from old.user_id or new.unit_id is distinct from old.unit_id or new.building_id is distinct from old.building_id or new.kind is distinct from old.kind or new.starts_on is distinct from old.starts_on or new.ends_on is distinct from old.ends_on then
  update public.resident_links set revoked_at=now() where resident_id=old.id and revoked_at is null;
 end if;
 return new;
end $$;
revoke all on function public.invalidate_changed_resident_links() from public,anon,authenticated;
create trigger invalidate_resident_links after update on public.unit_residents for each row execute function public.invalidate_changed_resident_links();

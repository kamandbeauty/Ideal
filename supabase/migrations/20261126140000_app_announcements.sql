-- Global announcements contain public-to-signed-in-users text only, never building financial data.
create table public.app_announcements (
 id uuid primary key default gen_random_uuid(), title text not null check (length(btrim(title)) between 1 and 120),
 body text not null check (length(btrim(body)) between 1 and 2000),
 published_at timestamptz not null default now(), archived_at timestamptz,
 created_by uuid not null references auth.users(id)
);
create table public.app_announcement_audit (
 id uuid primary key default gen_random_uuid(), announcement_id uuid not null references public.app_announcements(id),
 actor_id uuid not null references auth.users(id), action text not null check (action in ('publish','archive')),
 created_at timestamptz not null default now()
);
alter table public.app_announcements enable row level security;
alter table public.app_announcement_audit enable row level security;
revoke all on public.app_announcements,public.app_announcement_audit from public,anon,authenticated;

create function public.publish_app_announcement(p_title text,p_body text) returns uuid
language plpgsql security definer set search_path='' as $$ declare aid uuid; begin
 if not public.is_app_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 if p_title is null or length(btrim(p_title)) not between 1 and 120 or p_body is null or length(btrim(p_body)) not between 1 and 2000 then raise exception 'Invalid announcement'; end if;
 insert into public.app_announcements(title,body,created_by) values(btrim(p_title),btrim(p_body),auth.uid()) returning id into aid;
 insert into public.app_announcement_audit(announcement_id,actor_id,action) values(aid,auth.uid(),'publish');
 return aid;
end $$;
create function public.archive_app_announcement(p_id uuid) returns void
language plpgsql security definer set search_path='' as $$ begin
 if not public.is_app_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 update public.app_announcements set archived_at=now() where id=p_id and archived_at is null;
 if not found then raise exception 'Announcement not found or already archived'; end if;
 insert into public.app_announcement_audit(announcement_id,actor_id,action) values(p_id,auth.uid(),'archive');
end $$;
create function public.app_admin_announcements(page_offset integer) returns table(id uuid,title text,body text,published_at timestamptz,archived_at timestamptz)
language plpgsql stable security definer set search_path='' as $$ begin
 if not public.is_app_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 if page_offset is null or page_offset<0 or page_offset>100000 then raise exception 'Invalid offset'; end if;
 return query select a.id,a.title,a.body,a.published_at,a.archived_at from public.app_announcements a order by a.published_at desc,a.id desc limit 21 offset page_offset;
end $$;
create function public.current_app_announcements() returns table(id uuid,title text,body text,published_at timestamptz)
language plpgsql stable security definer set search_path='' as $$ begin
 if auth.uid() is null then raise exception 'Not authorized' using errcode='42501'; end if;
 return query select a.id,a.title,a.body,a.published_at from public.app_announcements a where a.archived_at is null order by a.published_at desc,a.id desc limit 20;
end $$;
revoke all on function public.publish_app_announcement(text,text),public.archive_app_announcement(uuid),public.app_admin_announcements(integer),public.current_app_announcements() from public,anon;
grant execute on function public.publish_app_announcement(text,text),public.archive_app_announcement(uuid),public.app_admin_announcements(integer),public.current_app_announcements() to authenticated;

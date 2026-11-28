create table public.building_polls(
 id uuid primary key default gen_random_uuid(),building_id uuid not null references public.buildings(id),
 title text not null check(length(btrim(title)) between 1 and 160),description text not null default '' check(length(description)<=2000),
 status text not null default 'open' check(status in ('open','closed','published')),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),closed_at timestamptz,published_at timestamptz,
 unique(building_id,id)
);
create table public.building_poll_options(
 id uuid primary key default gen_random_uuid(),building_id uuid not null,poll_id uuid not null,label text not null check(length(btrim(label)) between 1 and 120),position smallint not null,
 unique(building_id,poll_id,id),unique(building_id,poll_id,position),
 foreign key(building_id,poll_id) references public.building_polls(building_id,id) on delete cascade
);
create table public.building_poll_votes(
 building_id uuid not null,poll_id uuid not null,option_id uuid not null,voter_id uuid not null references auth.users(id),created_at timestamptz not null default now(),
 primary key(poll_id,voter_id),
 foreign key(building_id,poll_id) references public.building_polls(building_id,id) on delete cascade,
 foreign key(building_id,poll_id,option_id) references public.building_poll_options(building_id,poll_id,id)
);
create index building_polls_building_created on public.building_polls(building_id,created_at desc);
create index building_poll_votes_poll_option on public.building_poll_votes(poll_id,option_id);
alter table public.building_polls enable row level security;
alter table public.building_poll_options enable row level security;
alter table public.building_poll_votes enable row level security;
revoke all on public.building_polls,public.building_poll_options,public.building_poll_votes from public,anon,authenticated;
grant select on public.building_polls,public.building_poll_options,public.building_poll_votes to authenticated;
create policy building_polls_read on public.building_polls for select to authenticated using(
 public.has_building_role(building_id,array['manager']::public.building_role[]) or public.has_active_unit(building_id));
create policy building_poll_options_read on public.building_poll_options for select to authenticated using(
 public.has_building_role(building_id,array['manager']::public.building_role[]) or public.has_active_unit(building_id));
create policy building_poll_votes_self_read on public.building_poll_votes for select to authenticated using(voter_id=auth.uid());

create function public.create_building_poll(b uuid,p_title text,p_description text,p_options jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare pid uuid; option_count integer;
begin
 perform public.require_finance_manager(b);
 if length(btrim(coalesce(p_title,''))) not between 1 and 160 or length(coalesce(p_description,''))>2000 or jsonb_typeof(p_options) is distinct from 'array' then raise exception 'Invalid poll'; end if;
 option_count:=jsonb_array_length(p_options);
 if option_count not between 2 and 10 or exists(select 1 from jsonb_array_elements_text(p_options) as x(value) where length(btrim(x.value)) not between 1 and 120) or
  (select count(distinct lower(btrim(x.value))) from jsonb_array_elements_text(p_options) as x(value))<>option_count then raise exception 'Invalid poll options'; end if;
 insert into public.building_polls(building_id,title,description,created_by) values(b,btrim(p_title),btrim(coalesce(p_description,'')),auth.uid()) returning id into pid;
 insert into public.building_poll_options(building_id,poll_id,label,position)
 select b,pid,btrim(x.value),x.ordinality::smallint from jsonb_array_elements_text(p_options) with ordinality x(value,ordinality);
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id,details)
 values(b,auth.uid(),'create','building_poll',pid,jsonb_build_object('options',option_count));
 return pid;
end $$;

create function public.vote_building_poll(poll uuid,selected_option uuid) returns void
language plpgsql security definer set search_path='' as $$
declare p public.building_polls%rowtype;
begin
 if auth.uid() is null then raise exception 'Not authorized' using errcode='42501'; end if;
 select * into p from public.building_polls where id=poll for update;
 if not found or not public.has_active_unit(p.building_id) then raise exception 'Not authorized' using errcode='42501'; end if;
 if p.status<>'open' then raise exception 'Voting is closed'; end if;
 if not exists(select 1 from public.building_poll_options where building_id=p.building_id and poll_id=p.id and id=selected_option) then raise exception 'Invalid option'; end if;
 insert into public.building_poll_votes(building_id,poll_id,option_id,voter_id) values(p.building_id,p.id,selected_option,auth.uid())
 on conflict(poll_id,voter_id) do update set option_id=excluded.option_id,created_at=now();
end $$;

create function public.review_building_poll(b uuid,poll uuid,decision text) returns void
language plpgsql security definer set search_path='' as $$
declare p public.building_polls%rowtype;
begin
 perform public.require_finance_manager(b);
 select * into p from public.building_polls where building_id=b and id=poll for update;
 if not found then raise exception 'Poll not found'; end if;
 if decision='close' and p.status='open' then update public.building_polls set status='closed',closed_at=now() where id=p.id;
 elsif decision='publish' and p.status='closed' then update public.building_polls set status='published',published_at=now() where id=p.id;
 else raise exception 'Invalid poll review'; end if;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id,details)
 values(b,auth.uid(),case when decision='close' then 'close_poll' else 'publish_poll_results' end,'building_poll',p.id,jsonb_build_object('status',case when decision='close' then 'closed' else 'published' end));
end $$;

create function public.building_poll_results(poll uuid) returns table(option_id uuid,label text,vote_count bigint)
language plpgsql stable security definer set search_path='' as $$
declare p public.building_polls%rowtype;
begin
 select * into p from public.building_polls where id=poll;
 if not found then raise exception 'Poll not found'; end if;
 if not public.has_building_role(p.building_id,array['manager']::public.building_role[]) and
  (not public.has_active_unit(p.building_id) or p.status<>'published') then raise exception 'Results are not available' using errcode='42501'; end if;
 return query select o.id,o.label,count(v.voter_id)::bigint from public.building_poll_options o left join public.building_poll_votes v
  on v.building_id=o.building_id and v.poll_id=o.poll_id and v.option_id=o.id
  where o.building_id=p.building_id and o.poll_id=p.id group by o.id,o.label,o.position order by o.position;
end $$;

revoke all on function public.create_building_poll(uuid,text,text,jsonb),public.vote_building_poll(uuid,uuid),public.review_building_poll(uuid,uuid,text),public.building_poll_results(uuid) from public,anon;
grant execute on function public.create_building_poll(uuid,text,text,jsonb),public.vote_building_poll(uuid,uuid),public.review_building_poll(uuid,uuid,text),public.building_poll_results(uuid) to authenticated;

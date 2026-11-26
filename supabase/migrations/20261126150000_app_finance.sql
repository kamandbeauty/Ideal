-- Owner-maintained operating ledger: separate from building accounts and not evidence of a Bazaar purchase.
create table public.app_finance_entries (
 id uuid primary key default gen_random_uuid(), request_id uuid not null unique,
 kind text not null check(kind in ('income','expense')),
 title text not null check(length(btrim(title)) between 1 and 200),
 amount_toman bigint not null check(amount_toman between 1 and 1000000000000),
 entry_date date not null, note text not null default '' check(length(note)<=1000),
 created_by uuid not null references auth.users(id), created_at timestamptz not null default now(),
 voided_at timestamptz, voided_by uuid references auth.users(id), void_reason text,
 check ((voided_at is null and voided_by is null and void_reason is null) or (voided_at is not null and voided_by is not null and void_reason is not null and length(btrim(void_reason)) between 1 and 500))
);
create index on public.app_finance_entries(entry_date desc,id desc);
alter table public.app_finance_entries enable row level security;
revoke all on public.app_finance_entries from public,anon,authenticated;
create function public.record_app_finance(p_request uuid,p_kind text,p_title text,p_amount bigint,p_date date,p_note text) returns uuid
language plpgsql security definer set search_path='' as $$
declare existing public.app_finance_entries%rowtype; result uuid; begin
 if not public.is_app_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 if p_request is null or p_kind is null or p_kind not in ('income','expense') or p_title is null or length(btrim(p_title)) not between 1 and 200 or p_amount is null or p_amount not between 1 and 1000000000000 or p_date is null or p_note is null or length(p_note)>1000 then raise exception 'Invalid entry'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_request::text,9));
 select * into existing from public.app_finance_entries where request_id=p_request;
 if found then
  if existing.kind is distinct from p_kind or existing.title is distinct from btrim(p_title) or existing.amount_toman is distinct from p_amount or existing.entry_date is distinct from p_date or existing.note is distinct from btrim(p_note) or existing.created_by is distinct from auth.uid() then raise exception 'Request already used with different data'; end if;
  return existing.id;
 end if;
 insert into public.app_finance_entries(request_id,kind,title,amount_toman,entry_date,note,created_by) values(p_request,p_kind,btrim(p_title),p_amount,p_date,btrim(p_note),auth.uid()) returning id into result;
 return result;
end $$;
create function public.void_app_finance(p_id uuid,p_reason text) returns void
language plpgsql security definer set search_path='' as $$ begin
 if not public.is_app_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 if p_reason is null or length(btrim(p_reason)) not between 1 and 500 then raise exception 'Reason required'; end if;
 update public.app_finance_entries set voided_at=now(),voided_by=auth.uid(),void_reason=btrim(p_reason) where id=p_id and voided_at is null;
 if not found then raise exception 'Entry not found or already voided'; end if;
end $$;
create function public.app_finance_report(p_from date,p_to date) returns table(income_toman text,expense_toman text,net_toman text,entries bigint)
language plpgsql stable security definer set search_path='' as $$ begin
 if not public.is_app_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 if p_from is null or p_to is null or p_from>p_to then raise exception 'Invalid dates'; end if;
 return query select coalesce(sum(amount_toman) filter(where kind='income'),0)::text,coalesce(sum(amount_toman) filter(where kind='expense'),0)::text,(coalesce(sum(amount_toman) filter(where kind='income'),0)-coalesce(sum(amount_toman) filter(where kind='expense'),0))::text,count(*) from public.app_finance_entries e where e.entry_date between p_from and p_to and e.voided_at is null;
end $$;
create function public.app_finance_list(p_from date,p_to date,p_offset integer) returns table(id uuid,kind text,title text,amount_toman bigint,entry_date date,note text,created_by uuid,created_at timestamptz,voided_at timestamptz,voided_by uuid,void_reason text)
language plpgsql stable security definer set search_path='' as $$ begin
 if not public.is_app_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 if p_from is null or p_to is null or p_from>p_to or p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Invalid dates or offset'; end if;
 return query select e.id,e.kind,e.title,e.amount_toman,e.entry_date,e.note,e.created_by,e.created_at,e.voided_at,e.voided_by,e.void_reason from public.app_finance_entries e where e.entry_date between p_from and p_to order by e.entry_date desc,e.created_at desc,e.id desc limit 21 offset p_offset;
end $$;
revoke all on function public.record_app_finance(uuid,text,text,bigint,date,text),public.void_app_finance(uuid,text),public.app_finance_report(date,date),public.app_finance_list(date,date,integer) from public,anon;
grant execute on function public.record_app_finance(uuid,text,text,bigint,date,text),public.void_app_finance(uuid,text),public.app_finance_report(date,date),public.app_finance_list(date,date,integer) to authenticated;

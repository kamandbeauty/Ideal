-- One JSON value avoids PostgREST row limits silently truncating a financial export.
create function public.app_finance_export(p_from date,p_to date) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb; begin
 if not public.is_app_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 if p_from is null or p_to is null or p_from>p_to then raise exception 'Invalid dates'; end if;
 if (select count(*) from public.app_finance_entries e where e.entry_date between p_from and p_to)>1000 then raise exception 'Export exceeds 1000 records; use a shorter date range'; end if;
 select coalesce(jsonb_agg(to_jsonb(items) order by items.entry_date desc,items.created_at desc,items.id desc),'[]'::jsonb) into result
 from (select e.id,e.kind,e.title,e.amount_toman,e.entry_date,e.note,e.created_by,e.created_at,e.voided_at,e.voided_by,e.void_reason from public.app_finance_entries e where e.entry_date between p_from and p_to) items;
 return result;
end $$;
revoke all on function public.app_finance_export(date,date) from public,anon;
grant execute on function public.app_finance_export(date,date) to authenticated;

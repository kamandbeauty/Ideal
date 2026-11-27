-- Server-clock trial starts when the building is created. Paid entitlement records
-- are provisioned only by a trusted server after independent purchase verification.
create table public.building_entitlements (
 building_id uuid primary key references public.buildings(id),
 paid_until timestamptz not null,
 updated_at timestamptz not null default now()
);
alter table public.building_entitlements enable row level security;
revoke all on public.building_entitlements from public,anon,authenticated;
create function public.building_subscription_status(b uuid)
returns table(state text,trial_ends_at timestamptz,paid_until timestamptz,access_until timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare trial_end timestamptz; paid_end timestamptz;
begin
 if auth.uid() is null or not public.has_building_role(b,array['manager','accountant','owner','resident','maintenance']::public.building_role[]) then raise exception 'Not authorized' using errcode='42501'; end if;
 select x.created_at+interval '168 hours' into strict trial_end from public.buildings x where x.id=b;
 select e.paid_until into paid_end from public.building_entitlements e where e.building_id=b;
 return query select case when paid_end>now() then 'active' when trial_end>now() then 'trial' else 'expired' end,trial_end,paid_end,greatest(trial_end,paid_end);
end $$;
revoke all on function public.building_subscription_status(uuid) from public,anon;
grant execute on function public.building_subscription_status(uuid) to authenticated;

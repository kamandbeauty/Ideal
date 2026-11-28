-- This event-trigger helper is not attached to a DDL trigger and must not be
-- callable as an RPC by API roles.
revoke execute on function public.rls_auto_enable() from public, anon, authenticated, service_role;

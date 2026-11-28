-- CREATE OR REPLACE resets the function's default PUBLIC execute privilege.
revoke all on function public.app_admin_overview() from public,anon;
grant execute on function public.app_admin_overview() to authenticated;

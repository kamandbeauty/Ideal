-- Backup objects contain private building and resident information.
-- Only the Supabase service role may access this private bucket.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('apartment-yar-db-backups','apartment-yar-db-backups',false,52428800,array['application/octet-stream'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;


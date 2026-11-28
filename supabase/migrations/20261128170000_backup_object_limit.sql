-- Supabase Free limits each upload to 50 MB; archives are split into 40 MB parts.
update storage.buckets set file_size_limit=52428800 where id='apartment-yar-db-backups';

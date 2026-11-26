-- Deposit declarations require a message and receipt image; they are not verified payments.
alter table public.payment_receipts drop constraint payment_receipts_reference_check;
alter table public.payment_receipts add constraint receipt_reference_length check(length(reference)<=120);

create or replace function public.create_receipt_upload(b uuid,u uuid,amount bigint,reference text,note text,mime_type text) returns table(receipt_id uuid,object_path text)
language plpgsql security definer set search_path='' as $$
declare rid uuid:=gen_random_uuid(); path text; begin
 if auth.uid() is null or not public.is_unit_resident(b,u) then raise exception 'Not authorized' using errcode='42501'; end if;
 if amount is null or amount not between 1 and 1000000000000 or length(coalesce(reference,''))>120 or length(btrim(coalesce(note,''))) not between 1 and 1000 or mime_type not in ('image/jpeg','image/png','image/webp') or mime_type is null then raise exception 'Invalid receipt'; end if;
 path:=b::text||'/'||rid::text;
 insert into public.payment_receipts(id,building_id,unit_id,submitted_by,amount,reference,note,mime_type,object_path) values(rid,b,u,auth.uid(),amount,btrim(coalesce(reference,'')),btrim(note),mime_type,path);
 return query select rid,path;
end $$;

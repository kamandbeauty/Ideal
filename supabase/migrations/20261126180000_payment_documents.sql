-- Optional supporting image of an already-recorded payment. Never creates a cash entry.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('apartment-yar-payment-documents','apartment-yar-payment-documents',false,5242880,array['image/jpeg','image/png','image/webp']);
create table public.payment_documents (
 id uuid primary key default gen_random_uuid(), building_id uuid not null, payment_id uuid not null,
 created_by uuid not null references auth.users(id), mime_type text not null check(mime_type in ('image/jpeg','image/png','image/webp')),
 object_path text not null unique, status text not null default 'uploading' check(status in ('uploading','ready')),
 created_at timestamptz not null default now(), ready_at timestamptz, unique(building_id,payment_id),
 foreign key(building_id,payment_id) references public.payments(building_id,id)
);
alter table public.payment_documents enable row level security;
revoke all on public.payment_documents from public,anon,authenticated;
grant select on public.payment_documents to authenticated;
create policy payment_documents_manager_read on public.payment_documents for select to authenticated using(public.has_building_role(building_id,array['manager']::public.building_role[]));
create policy payment_documents_upload on storage.objects for insert to authenticated with check (
 bucket_id='apartment-yar-payment-documents' and exists(select 1 from public.payment_documents d where d.object_path=name and d.status='uploading' and public.has_building_role(d.building_id,array['manager']::public.building_role[]))
);
create policy payment_documents_download on storage.objects for select to authenticated using (
 bucket_id='apartment-yar-payment-documents' and exists(select 1 from public.payment_documents d where d.object_path=name and d.status='ready' and public.has_building_role(d.building_id,array['manager']::public.building_role[]))
);
create function public.create_payment_document(b uuid,p uuid,mime text) returns table(document_id uuid,object_path text,status text)
language plpgsql security definer set search_path='' as $$
declare d public.payment_documents%rowtype; ident uuid; begin
 perform public.require_finance_manager(b);
 if mime is null or mime not in ('image/jpeg','image/png','image/webp') then raise exception 'Invalid document type'; end if;
 if not exists(select 1 from public.payments q where q.building_id=b and q.id=p) then raise exception 'Payment not found'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p::text,15));
 select * into d from public.payment_documents pd where pd.building_id=b and pd.payment_id=p;
 if not found then
  ident:=gen_random_uuid();
  insert into public.payment_documents(id,building_id,payment_id,created_by,mime_type,object_path) values(ident,b,p,auth.uid(),mime,b::text||'/'||ident::text) returning * into d;
 elsif d.status='uploading' and d.mime_type<>mime then raise exception 'Retry with the original image type'; end if;
 return query select d.id,d.object_path,d.status;
end $$;
create function public.confirm_payment_document(b uuid,document_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare d public.payment_documents%rowtype; begin
 perform public.require_finance_manager(b);
 select * into d from public.payment_documents where id=document_id and building_id=b for update;
 if not found then raise exception 'Document not found'; end if;
 if d.status='ready' then return; end if;
 if not exists(select 1 from storage.objects o where o.bucket_id='apartment-yar-payment-documents' and o.name=d.object_path) then raise exception 'Image not found'; end if;
 update public.payment_documents set status='ready',ready_at=now() where id=d.id;
 insert into public.audit_logs(building_id,actor_id,action,entity_type,entity_id) values(b,auth.uid(),'attach','payment_document',d.id);
end $$;
revoke all on function public.create_payment_document(uuid,uuid,text) from public,anon;
revoke all on function public.confirm_payment_document(uuid,uuid) from public,anon;
grant execute on function public.create_payment_document(uuid,uuid,text) to authenticated;
grant execute on function public.confirm_payment_document(uuid,uuid) to authenticated;

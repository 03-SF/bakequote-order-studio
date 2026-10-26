begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('profile-images','profile-images',false,5242880,array['image/jpeg','image/png','image/webp']),
 ('business-images','business-images',true,5242880,array['image/jpeg','image/png','image/webp']),
 ('product-images','product-images',true,5242880,array['image/jpeg','image/png','image/webp']),
 ('order-references','order-references',false,5242880,array['image/jpeg','image/png','image/webp']),
 ('conversation-attachments','conversation-attachments',false,5242880,array['image/jpeg','image/png','image/webp']);

-- Immutable uploads (no UPDATE policy). New filenames are used on replacement.
create policy profile_images_read on storage.objects for select to authenticated
using(bucket_id='profile-images' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy profile_images_insert on storage.objects for insert to authenticated
with check(bucket_id='profile-images' and name ~ '^[0-9a-f-]+/[0-9a-f-]+\.(jpg|png|webp)$'
 and (storage.foldername(name))[1]=(select auth.uid())::text
 and exists(select 1 from public.profiles p where p.id=(select auth.uid())));
create policy profile_images_delete on storage.objects for delete to authenticated
using(bucket_id='profile-images' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy business_images_read_owner on storage.objects for select to authenticated
using(bucket_id='business-images' and exists(select 1 from public.businesses b
 where b.id::text=(storage.foldername(name))[1] and b.owner_id=(select auth.uid())));
create policy business_images_insert on storage.objects for insert to authenticated
with check(bucket_id='business-images' and name ~ '^[0-9a-f-]+/profile/[0-9a-f-]+\.(jpg|png|webp)$'
 and exists(select 1 from public.businesses b where b.id::text=(storage.foldername(name))[1] and b.owner_id=(select auth.uid())));
create policy business_images_delete on storage.objects for delete to authenticated
using(bucket_id='business-images' and exists(select 1 from public.businesses b
 where b.id::text=(storage.foldername(name))[1] and b.owner_id=(select auth.uid())));
-- Public buckets serve object bytes publicly; metadata listing stays owner-only.
-- Products and order/conversation membership do not exist yet. Explicit restrictive
-- denial also prevents accidental permissive policies from opening these buckets.
create policy future_buckets_closed on storage.objects as restrictive for all to anon,authenticated
using(bucket_id not in ('product-images','order-references','conversation-attachments'))
with check(bucket_id not in ('product-images','order-references','conversation-attachments'));
commit;

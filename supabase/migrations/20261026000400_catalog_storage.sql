BEGIN;
DROP POLICY future_buckets_closed ON storage.objects;
CREATE POLICY private_membership_closed ON storage.objects AS RESTRICTIVE FOR ALL TO anon,authenticated
 USING(bucket_id NOT IN ('order-references','conversation-attachments')) WITH CHECK(bucket_id NOT IN ('order-references','conversation-attachments'));
DROP POLICY business_images_insert ON storage.objects;
DROP POLICY business_images_read_owner ON storage.objects;
DROP POLICY business_images_delete ON storage.objects;
CREATE POLICY business_images_read_owner ON storage.objects FOR SELECT TO authenticated USING(bucket_id='business-images' AND EXISTS(SELECT 1 FROM public.businesses b WHERE b.id::text=(storage.foldername(storage.objects.name))[1] AND b.owner_id=(SELECT auth.uid())));
CREATE POLICY business_images_delete ON storage.objects FOR DELETE TO authenticated USING(bucket_id='business-images' AND EXISTS(SELECT 1 FROM public.businesses b WHERE b.id::text=(storage.foldername(storage.objects.name))[1] AND b.owner_id=(SELECT auth.uid())));
CREATE POLICY business_images_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(
 bucket_id='business-images' AND name ~ '^[0-9a-f-]{36}/(profile|cover)/[0-9a-f-]{36}\.(jpg|png|webp)$' AND EXISTS(SELECT 1 FROM public.businesses b WHERE b.id::text=(storage.foldername(storage.objects.name))[1] AND b.owner_id=(SELECT auth.uid())));
CREATE POLICY product_images_read ON storage.objects FOR SELECT TO authenticated USING(bucket_id='product-images' AND EXISTS(SELECT 1 FROM public.products p JOIN public.businesses b ON b.id=p.business_id WHERE p.business_id::text=(storage.foldername(storage.objects.name))[1] AND p.id::text=(storage.foldername(storage.objects.name))[2] AND b.owner_id=(SELECT auth.uid())));
CREATE POLICY product_images_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='product-images' AND name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$' AND EXISTS(SELECT 1 FROM public.products p JOIN public.businesses b ON b.id=p.business_id WHERE p.business_id::text=(storage.foldername(storage.objects.name))[1] AND p.id::text=(storage.foldername(storage.objects.name))[2] AND b.owner_id=(SELECT auth.uid())));
CREATE POLICY product_images_delete ON storage.objects FOR DELETE TO authenticated USING(bucket_id='product-images' AND EXISTS(SELECT 1 FROM public.products p JOIN public.businesses b ON b.id=p.business_id WHERE p.business_id::text=(storage.foldername(storage.objects.name))[1] AND p.id::text=(storage.foldername(storage.objects.name))[2] AND b.owner_id=(SELECT auth.uid())));
CREATE FUNCTION public.set_baker_image(p_business_id uuid,p_revision bigint,p_slot text,p_product_id uuid DEFAULT NULL,p_path text DEFAULT NULL) RETURNS bigint
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE b public.businesses; bucket text;
BEGIN
 SELECT * INTO b FROM public.businesses WHERE id=p_business_id AND owner_id=auth.uid() FOR UPDATE;
 IF b.id IS NULL THEN RAISE EXCEPTION 'Business access denied' USING ERRCODE='42501'; END IF;
 IF p_revision IS NULL OR b.revision<>p_revision THEN RAISE EXCEPTION 'Reload before changing image' USING ERRCODE='40001'; END IF;
 IF p_slot IS NULL OR p_slot NOT IN ('profile','cover','product') THEN RAISE EXCEPTION 'Invalid image slot' USING ERRCODE='22023'; END IF;
 bucket:=CASE WHEN p_slot='product' THEN 'product-images' ELSE 'business-images' END;
 IF p_slot='product' AND NOT EXISTS(SELECT 1 FROM public.products WHERE id=p_product_id AND business_id=b.id) THEN RAISE EXCEPTION 'Product access denied' USING ERRCODE='42501'; END IF;
 IF p_path IS NOT NULL AND (p_path !~ ('^'||b.id::text||'/'||CASE WHEN p_slot='product' THEN p_product_id::text ELSE p_slot END||'/[0-9a-f-]{36}\.(jpg|png|webp)$') OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id=bucket AND name=p_path)) THEN RAISE EXCEPTION 'Upload an owned image first' USING ERRCODE='22023'; END IF;
 IF p_slot='product' THEN UPDATE public.products SET image_path=p_path WHERE id=p_product_id AND business_id=b.id;
 ELSIF p_slot='profile' THEN UPDATE public.businesses SET image_path=p_path WHERE id=b.id;
 ELSE UPDATE public.businesses SET cover_path=p_path WHERE id=b.id; END IF;
 UPDATE public.businesses SET revision=revision+1 WHERE id=b.id;
 RETURN b.revision+1;
END $$;
REVOKE ALL ON FUNCTION public.set_baker_image(uuid,bigint,text,uuid,text) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.set_baker_image(uuid,bigint,text,uuid,text) TO authenticated;
-- Never delete an image still referenced by an owned business/product, even
-- after a crash between pointer commit and local cleanup-queue acknowledgement.
CREATE POLICY referenced_public_images_retained ON storage.objects AS RESTRICTIVE FOR DELETE TO authenticated USING(
 bucket_id NOT IN ('business-images','product-images') OR
 (NOT EXISTS(SELECT 1 FROM public.businesses WHERE image_path=storage.objects.name OR cover_path=storage.objects.name)
  AND NOT EXISTS(SELECT 1 FROM public.products WHERE image_path=storage.objects.name)));
COMMIT;

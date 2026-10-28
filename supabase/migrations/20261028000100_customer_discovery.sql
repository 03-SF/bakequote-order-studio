BEGIN;
-- Public customer reads remain explicit projections; raw owner tables stay private.
CREATE INDEX products_public_page_idx ON public.products(business_id,id) WHERE active;
CREATE OR REPLACE FUNCTION public.public_business(p_code text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('id',id,'code',code,'name',name,'description',description,
 'location',location,'image_path',image_path,'cover_path',cover_path,
 'pickup_enabled',pickup_enabled,'delivery_enabled',delivery_enabled,'minimum_paisa',minimum_paisa)
 FROM public.businesses WHERE code=upper(trim(p_code)) AND onboarding_complete
$$;

CREATE FUNCTION public.public_menu(p_code text,p_after uuid DEFAULT NULL,p_limit integer DEFAULT 20)
RETURNS SETOF jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 30 THEN
  RAISE EXCEPTION 'Invalid page size' USING ERRCODE='22023'; END IF;
 RETURN QUERY SELECT jsonb_build_object('id',p.id,'name',p.name,'description',p.description,
  'kind',p.kind,'image_path',p.image_path,'minimum_quantity',p.minimum_quantity,
  'variants',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',v->>'id','label',v->>'label',
    'units',v->'units','price_paisa',v->'price_paisa') ORDER BY ord),'[]'::jsonb)
    FROM jsonb_array_elements(p.variants) WITH ORDINALITY AS a(v,ord) WHERE (v->>'active')::boolean),
  'options',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',v->>'id','label',v->>'label',
    'kind',v->>'kind','price_paisa',v->'price_paisa') ORDER BY ord),'[]'::jsonb)
    FROM jsonb_array_elements(p.options) WITH ORDINALITY AS a(v,ord) WHERE (v->>'active')::boolean))
 FROM public.products p JOIN public.businesses b ON b.id=p.business_id
 WHERE b.code=upper(trim(p_code)) AND b.onboarding_complete AND p.active
 AND (p_after IS NULL OR p.id>p_after)
 AND EXISTS(SELECT 1 FROM jsonb_array_elements(p.variants) v WHERE (v->>'active')::boolean)
 ORDER BY p.id LIMIT p_limit;
END $$;

CREATE TABLE public.saved_businesses(
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
 PRIMARY KEY(user_id,business_id)
);
ALTER TABLE public.saved_businesses ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.saved_businesses FROM public,anon,authenticated;
GRANT SELECT ON public.saved_businesses TO authenticated;
CREATE POLICY saved_businesses_self ON public.saved_businesses FOR SELECT TO authenticated
 USING(user_id=(SELECT auth.uid()));

CREATE FUNCTION public.set_saved_business(p_business_id uuid,p_saved boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
 IF p_saved IS NULL THEN RAISE EXCEPTION 'Choose saved state' USING ERRCODE='22023'; END IF;
 IF p_saved THEN
  -- Lock against concurrent publication changes; retrying the same state is idempotent.
  PERFORM 1 FROM public.businesses WHERE id=p_business_id AND onboarding_complete FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bakery unavailable' USING ERRCODE='22023'; END IF;
  INSERT INTO public.saved_businesses VALUES(auth.uid(),p_business_id) ON CONFLICT DO NOTHING;
 ELSE
  DELETE FROM public.saved_businesses WHERE user_id=auth.uid() AND business_id=p_business_id;
 END IF;
END $$;

CREATE FUNCTION public.saved_bakeries(p_after uuid DEFAULT NULL,p_limit integer DEFAULT 20)
RETURNS TABLE(business_id uuid,profile jsonb) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 30 THEN RAISE EXCEPTION 'Invalid page size' USING ERRCODE='22023'; END IF;
 RETURN QUERY SELECT s.business_id,public.public_business(b.code)
 FROM public.saved_businesses s JOIN public.businesses b ON b.id=s.business_id
 WHERE s.user_id=auth.uid() AND (p_after IS NULL OR s.business_id>p_after)
 ORDER BY s.business_id LIMIT p_limit;
END $$;

CREATE FUNCTION public.set_business_publication(p_business_id uuid,p_revision bigint,p_published boolean)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE b public.businesses;
BEGIN
 SELECT * INTO b FROM public.businesses WHERE id=p_business_id AND owner_id=auth.uid() FOR UPDATE;
 IF b.id IS NULL THEN RAISE EXCEPTION 'Business access denied' USING ERRCODE='42501'; END IF;
 IF p_revision IS NULL OR b.revision<>p_revision THEN RAISE EXCEPTION 'Reload workspace' USING ERRCODE='40001'; END IF;
 IF p_published IS NULL THEN RAISE EXCEPTION 'Choose publication state' USING ERRCODE='22023'; END IF;
 IF p_published THEN PERFORM public.check_business_setup(b.id); END IF;
 UPDATE public.businesses SET onboarding_complete=p_published,revision=revision+1 WHERE id=b.id;
 RETURN b.revision+1;
END $$;

REVOKE ALL ON FUNCTION public.public_menu(text,uuid,integer),public.set_saved_business(uuid,boolean),
 public.saved_bakeries(uuid,integer),public.set_business_publication(uuid,bigint,boolean) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.public_menu(text,uuid,integer) TO anon,authenticated;
GRANT EXECUTE ON FUNCTION public.set_saved_business(uuid,boolean),public.saved_bakeries(uuid,integer),
 public.set_business_publication(uuid,bigint,boolean) TO authenticated;
COMMIT;

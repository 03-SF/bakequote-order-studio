BEGIN;
CREATE TABLE public.request_drafts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), customer_id uuid NOT NULL REFERENCES auth.users(id),
 business_id uuid NOT NULL REFERENCES public.businesses(id), input jsonb NOT NULL DEFAULT '{}',
 revision bigint NOT NULL DEFAULT 0, review jsonb, review_token uuid,
 submitted_order_id uuid, updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX one_open_request_draft ON public.request_drafts(customer_id,business_id) WHERE submitted_order_id IS NULL;
CREATE TABLE public.order_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), reference text NOT NULL UNIQUE DEFAULT ('BQ-'||upper(replace(gen_random_uuid()::text,'-',''))),
 source_draft_id uuid NOT NULL UNIQUE REFERENCES public.request_drafts(id), submission_token uuid NOT NULL,
 customer_id uuid NOT NULL REFERENCES auth.users(id), business_id uuid NOT NULL REFERENCES public.businesses(id),
 status text NOT NULL DEFAULT 'pending' CHECK(status='pending'),
 snapshot jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), current_quote_version integer NOT NULL DEFAULT 1
);
ALTER TABLE public.request_drafts ADD FOREIGN KEY(submitted_order_id) REFERENCES public.order_requests(id);
CREATE INDEX requests_customer_page ON public.order_requests(customer_id,id);
CREATE INDEX requests_business_page ON public.order_requests(business_id,id);
CREATE TABLE public.request_quotes (
 order_id uuid NOT NULL REFERENCES public.order_requests(id), version integer NOT NULL CHECK(version>0),
 estimate jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(order_id,version)
);
CREATE TABLE public.request_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid NOT NULL REFERENCES public.order_requests(id),
 kind text NOT NULL CHECK(kind='requested'), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX request_events_order ON public.request_events(order_id);
CREATE TABLE public.request_uploads (
 path text PRIMARY KEY, draft_id uuid NOT NULL REFERENCES public.request_drafts(id), retired boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX request_uploads_draft ON public.request_uploads(draft_id);
CREATE TABLE public.request_attachments (
 path text PRIMARY KEY REFERENCES public.request_uploads(path), order_id uuid NOT NULL REFERENCES public.order_requests(id)
);
CREATE INDEX request_attachments_order ON public.request_attachments(order_id);

ALTER TABLE public.request_drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_quotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_attachments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.request_drafts,public.order_requests,public.request_quotes,public.request_events,public.request_uploads,public.request_attachments FROM public,anon,authenticated;
GRANT SELECT ON public.request_drafts,public.order_requests,public.request_quotes,public.request_events,public.request_uploads,public.request_attachments TO authenticated;
CREATE FUNCTION public.request_participant(p_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.order_requests r JOIN public.businesses b ON b.id=r.business_id
 WHERE r.id=p_id AND (r.customer_id=auth.uid() OR b.owner_id=auth.uid()))
$$;
CREATE POLICY request_draft_self ON public.request_drafts FOR SELECT TO authenticated USING(customer_id=(SELECT auth.uid()));
CREATE POLICY requests_participants ON public.order_requests FOR SELECT TO authenticated USING(public.request_participant(id));
CREATE POLICY quotes_participants ON public.request_quotes FOR SELECT TO authenticated USING(public.request_participant(order_id));
CREATE POLICY events_participants ON public.request_events FOR SELECT TO authenticated USING(public.request_participant(order_id));
CREATE POLICY attachments_participants ON public.request_attachments FOR SELECT TO authenticated USING(public.request_participant(order_id));
CREATE POLICY uploads_self ON public.request_uploads FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.request_drafts d WHERE d.id=draft_id AND d.customer_id=auth.uid()));

CREATE FUNCTION public.open_request_draft(p_business_id uuid) RETURNS public.request_drafts
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d public.request_drafts;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM auth.users WHERE id=auth.uid() AND email_confirmed_at IS NOT NULL) THEN RAISE EXCEPTION 'Verified sign in required' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.profiles WHERE id=auth.uid() FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM public.businesses WHERE id=p_business_id AND onboarding_complete) THEN RAISE EXCEPTION 'Bakery unavailable' USING ERRCODE='22023'; END IF;
 SELECT * INTO d FROM public.request_drafts WHERE customer_id=auth.uid() AND business_id=p_business_id AND submitted_order_id IS NULL;
 IF d.id IS NULL THEN INSERT INTO public.request_drafts(customer_id,business_id) VALUES(auth.uid(),p_business_id) RETURNING * INTO d; END IF;
 RETURN d;
END $$;

CREATE FUNCTION public.save_request_draft(p_id uuid,p_revision bigint,p_input jsonb) RETURNS public.request_drafts
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d public.request_drafts;
BEGIN
 SELECT * INTO d FROM public.request_drafts WHERE id=p_id AND customer_id=auth.uid() FOR UPDATE;
 IF d.id IS NULL THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
 IF d.submitted_order_id IS NOT NULL THEN RAISE EXCEPTION 'Already submitted; reopen request' USING ERRCODE='23514'; END IF;
 IF p_revision IS NULL OR p_revision<>d.revision THEN RAISE EXCEPTION 'Draft changed; reload' USING ERRCODE='40001'; END IF;
 IF jsonb_typeof(p_input) IS DISTINCT FROM 'object' OR octet_length(p_input::text)>16000 THEN RAISE EXCEPTION 'Invalid draft' USING ERRCODE='22023'; END IF;
 UPDATE public.request_drafts SET input=p_input, revision=revision+1,review=NULL,review_token=NULL,updated_at=now() WHERE id=d.id RETURNING * INTO d;
 RETURN d;
END $$;

CREATE FUNCTION public.request_choice(p jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT jsonb_strip_nulls(jsonb_build_object('id',p->'id','label',p->'label','units',p->'units','kind',p->'kind','price_paisa',p->'price_paisa'))
$$;
CREATE FUNCTION public.request_catalog(p_business_id uuid,p_product_id uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('business_name',b.name,'code',b.code,'product',jsonb_build_object('id',p.id,'name',p.name,'kind',p.kind,'minimum_quantity',p.minimum_quantity,
 'variants',(SELECT coalesce(jsonb_agg(public.request_choice(v)),'[]') FROM jsonb_array_elements(p.variants) v WHERE (v->>'active')::boolean),
 'options',(SELECT coalesce(jsonb_agg(public.request_choice(v)),'[]') FROM jsonb_array_elements(p.options) v WHERE (v->>'active')::boolean)),
 'pickup',b.pickup_enabled,'delivery',b.delivery_enabled,'zones',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',z.id,'name',z.name,'fee_paisa',z.fee_paisa)),'[]') FROM public.delivery_zones z WHERE z.business_id=b.id AND z.active AND b.delivery_enabled))
 FROM public.businesses b JOIN public.products p ON p.business_id=b.id WHERE b.id=p_business_id AND p.id=p_product_id AND b.onboarding_complete AND p.active
$$;

-- Private internal validator. Caller holds the business lock, also used by catalog/settings changes.
CREATE FUNCTION public.request_snapshot(p_draft_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d public.request_drafts; b public.businesses; p public.products; x jsonb; v jsonb; opts jsonb; estimate jsonb; cal jsonb;
 variant uuid; zone uuid; option_ids uuid[]; quantity integer; service_date date; lines jsonb; attachment text;
BEGIN
 SELECT * INTO STRICT d FROM public.request_drafts WHERE id=p_draft_id;
 SELECT * INTO b FROM public.businesses WHERE id=d.business_id;
 x:=d.input;
 IF NOT b.onboarding_complete THEN RAISE EXCEPTION 'Bakery unavailable' USING ERRCODE='22023'; END IF;
 SELECT * INTO p FROM public.products WHERE id=(x->>'product_id')::uuid AND business_id=b.id AND active;
 IF p.id IS NULL THEN RAISE EXCEPTION 'Product unavailable' USING ERRCODE='22023'; END IF;
 IF length(trim(coalesce(x->>'contact_name',''))) NOT BETWEEN 1 AND 100 OR length(trim(coalesce(x->>'phone',''))) NOT BETWEEN 3 AND 40
 OR length(coalesce(x->>'instructions',''))>2000 OR length(coalesce(x->>'cake_message',''))>200
 OR (p.kind<>'cake' AND length(coalesce(x->>'cake_message',''))>0)
 OR coalesce(x->>'fulfilment','') NOT IN ('pickup','delivery') THEN RAISE EXCEPTION 'Complete contact and design fields' USING ERRCODE='22023'; END IF;
 IF x->>'fulfilment'='delivery' THEN
  zone:=(x->>'zone_id')::uuid;
  IF zone IS NULL OR length(trim(coalesce(x->>'address',''))) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Delivery zone and address required' USING ERRCODE='22023'; END IF;
 ELSE
  IF nullif(x->>'zone_id','') IS NOT NULL THEN RAISE EXCEPTION 'Pickup cannot select delivery zone' USING ERRCODE='22023'; END IF;
 END IF;
 IF coalesce(x->>'service_date','') !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'Invalid date' USING ERRCODE='22023'; END IF;
 service_date:=(x->>'service_date')::date;
 cal:=public.bakery_availability(b.code,service_date,1);
 IF (cal->>'configured')::boolean IS DISTINCT FROM true OR cal->'days'->0->>'state' IS DISTINCT FROM 'available' THEN RAISE EXCEPTION 'Date unavailable' USING ERRCODE='23514'; END IF;
 IF jsonb_typeof(x->'option_ids') IS DISTINCT FROM 'array' OR jsonb_array_length(x->'option_ids')>200 OR jsonb_typeof(x->'attachments') IS DISTINCT FROM 'array' OR jsonb_array_length(x->'attachments')>3 THEN RAISE EXCEPTION 'Invalid selections' USING ERRCODE='22023'; END IF;
 SELECT coalesce(array_agg(value::uuid),'{}') INTO option_ids FROM jsonb_array_elements_text(x->'option_ids');
 variant:=(x->>'variant_id')::uuid; quantity:=(x->>'quantity')::integer;
 estimate:=public.catalog_estimate(p.id,variant,option_ids,quantity,zone);
 SELECT value INTO v FROM jsonb_array_elements(p.variants) WHERE value->>'id'=variant::text;
 SELECT coalesce(jsonb_agg(public.request_choice(value) ORDER BY value->>'id'),'[]') INTO opts FROM jsonb_array_elements(p.options) WHERE (value->>'id')::uuid=ANY(option_ids);
 IF (SELECT count(*)<>count(DISTINCT value) FROM jsonb_array_elements_text(x->'attachments')) THEN RAISE EXCEPTION 'Duplicate attachment' USING ERRCODE='22023'; END IF;
 FOR attachment IN SELECT jsonb_array_elements_text(x->'attachments') LOOP
  IF NOT EXISTS(SELECT 1 FROM public.request_uploads u JOIN storage.objects o ON o.name=u.path AND o.bucket_id='order-references'
   WHERE u.path=attachment AND u.draft_id=d.id AND NOT u.retired) THEN RAISE EXCEPTION 'Attachment unavailable or not owned' USING ERRCODE='42501'; END IF;
 END LOOP;
 lines:=jsonb_build_array(jsonb_build_object('label',v->>'label','unit_paisa',v->'price_paisa','quantity',quantity,'amount_paisa',(v->>'price_paisa')::bigint*quantity));
 FOR v IN SELECT value FROM jsonb_array_elements(opts) LOOP
  lines:=lines||jsonb_build_array(jsonb_build_object('label',v->>'label','unit_paisa',v->'price_paisa','quantity',quantity,'amount_paisa',(v->>'price_paisa')::bigint*quantity));
 END LOOP;
 RETURN jsonb_build_object('business_name',b.name,'business_code',b.code,'product_id',p.id,'variant_id',variant,'option_ids',to_jsonb(option_ids),'zone_id',zone,'product_name',p.name,'product_kind',p.kind,
 'variant', (SELECT public.request_choice(value) FROM jsonb_array_elements(p.variants) WHERE value->>'id'=variant::text),'options',opts,
 'quantity',quantity,'service_date',service_date,'timezone',cal->>'timezone','fulfilment',x->>'fulfilment',
 'zone',CASE WHEN zone IS NULL THEN NULL ELSE (SELECT name FROM public.delivery_zones WHERE id=zone) END,
 'address',CASE WHEN zone IS NULL THEN '' ELSE x->>'address' END,
 'pickup_address',CASE WHEN zone IS NULL THEN b.pickup_address ELSE '' END,
 'contact_name',trim(x->>'contact_name'),'phone',trim(x->>'phone'),'cake_message',coalesce(x->>'cake_message',''),
 'instructions',coalesce(x->>'instructions',''),'attachments',x->'attachments','estimate',estimate||jsonb_build_object('lines',lines));
END $$;

CREATE FUNCTION public.review_request(p_id uuid,p_revision bigint) RETURNS public.request_drafts
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d public.request_drafts; snapshot jsonb;
BEGIN
 SELECT * INTO d FROM public.request_drafts WHERE id=p_id AND customer_id=auth.uid() FOR UPDATE;
 IF d.id IS NULL THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
 IF p_revision IS NULL OR d.revision<>p_revision OR d.submitted_order_id IS NOT NULL THEN RAISE EXCEPTION 'Reload draft' USING ERRCODE='40001'; END IF;
 PERFORM 1 FROM public.businesses WHERE id=d.business_id FOR UPDATE;
 snapshot:=public.request_snapshot(d.id);
 UPDATE public.request_drafts SET review=snapshot,review_token=gen_random_uuid() WHERE id=d.id RETURNING * INTO d;
 RETURN d;
END $$;

CREATE FUNCTION public.submit_request(p_id uuid,p_review_token uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d public.request_drafts; snapshot jsonb; oid uuid;
BEGIN
 SELECT * INTO d FROM public.request_drafts WHERE id=p_id AND customer_id=auth.uid() FOR UPDATE;
 IF d.id IS NULL THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
 IF p_review_token IS NULL OR d.review_token IS DISTINCT FROM p_review_token THEN RAISE EXCEPTION 'Review changed; review again' USING ERRCODE='40001'; END IF;
 IF d.submitted_order_id IS NOT NULL THEN RETURN d.submitted_order_id; END IF;
 PERFORM 1 FROM public.businesses WHERE id=d.business_id FOR UPDATE;
 snapshot:=public.request_snapshot(d.id);
 IF snapshot IS DISTINCT FROM d.review THEN RAISE EXCEPTION 'Catalog or estimate changed; review again' USING ERRCODE='40001'; END IF;
 INSERT INTO public.order_requests(source_draft_id,submission_token,customer_id,business_id,snapshot)
 VALUES(d.id,p_review_token,d.customer_id,d.business_id,snapshot) RETURNING id INTO oid;
 INSERT INTO public.request_quotes(order_id,version,estimate) VALUES(oid,1,snapshot->'estimate');
 INSERT INTO public.request_events(order_id,kind) VALUES(oid,'requested');
 INSERT INTO public.request_attachments(path,order_id) SELECT value,oid FROM jsonb_array_elements_text(snapshot->'attachments');
 UPDATE public.request_drafts SET submitted_order_id=oid WHERE id=d.id;
 -- Deliberately no capacity allocation, confirmation, agreement or conversation.
 RETURN oid;
END $$;

CREATE FUNCTION public.register_request_upload(p_draft_id uuid,p_path text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM 1 FROM public.request_drafts WHERE id=p_draft_id AND customer_id=auth.uid() AND submitted_order_id IS NULL FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Draft access denied' USING ERRCODE='42501'; END IF;
 IF p_path IS NULL OR p_path !~ ('^'||auth.uid()::text||'/'||p_draft_id::text||'/[0-9a-f-]{36}\.(jpg|png|webp)$') THEN RAISE EXCEPTION 'Invalid path' USING ERRCODE='22023'; END IF;
 IF EXISTS(SELECT 1 FROM public.request_uploads WHERE path=p_path AND NOT retired) THEN RETURN; END IF;
 IF (SELECT count(*) FROM public.request_uploads WHERE draft_id=p_draft_id AND NOT retired)>=3 THEN RAISE EXCEPTION 'Maximum three images' USING ERRCODE='22023'; END IF;
 INSERT INTO public.request_uploads(path,draft_id) VALUES(p_path,p_draft_id);
END $$;
CREATE FUNCTION public.retire_request_upload(p_path text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d public.request_drafts;
BEGIN
 IF p_path IS NULL OR p_path !~ ('^'||auth.uid()::text||'/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$') THEN RAISE EXCEPTION 'Invalid path' USING ERRCODE='22023'; END IF;
 SELECT * INTO d FROM public.request_drafts WHERE id=split_part(p_path,'/',2)::uuid AND customer_id=auth.uid() FOR UPDATE;
 IF d.id IS NULL OR EXISTS(SELECT 1 FROM public.request_attachments WHERE path=p_path) THEN RAISE EXCEPTION 'Attachment protected' USING ERRCODE='42501'; END IF;
 -- Tombstone even an uncertain registration: a delayed retry cannot revive it.
 INSERT INTO public.request_uploads(path,draft_id,retired) VALUES(p_path,d.id,true)
 ON CONFLICT(path) DO UPDATE SET retired=true;
END $$;
CREATE FUNCTION public.request_object_access(p_path text,p_action text) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d public.request_drafts; retired boolean;
BEGIN
 IF p_action='read' THEN RETURN EXISTS(SELECT 1 FROM public.request_uploads u JOIN public.request_drafts rd ON rd.id=u.draft_id WHERE u.path=p_path AND rd.customer_id=auth.uid())
 OR EXISTS(SELECT 1 FROM public.request_attachments a WHERE a.path=p_path AND public.request_participant(a.order_id)); END IF;
 -- Same draft lock as submission prevents cleanup racing successful attachment.
 SELECT d0.* INTO d FROM public.request_drafts d0 JOIN public.request_uploads u ON u.draft_id=d0.id
 WHERE u.path=p_path AND d0.customer_id=auth.uid() FOR UPDATE OF d0;
 IF d.id IS NULL THEN RETURN false; END IF;
 SELECT u.retired INTO retired FROM public.request_uploads u WHERE u.path=p_path;
 IF p_action='insert' THEN RETURN d.submitted_order_id IS NULL AND NOT retired; END IF;
 IF p_action='delete' THEN RETURN NOT EXISTS(SELECT 1 FROM public.request_attachments WHERE path=p_path); END IF;
 RETURN false;
END $$;
-- Replace only the restrictive gate; conversation attachments remain closed.
DROP POLICY private_membership_closed ON storage.objects;
CREATE POLICY private_membership_closed ON storage.objects AS RESTRICTIVE FOR ALL TO anon,authenticated
 USING(bucket_id<>'conversation-attachments') WITH CHECK(bucket_id<>'conversation-attachments');
CREATE POLICY request_images_read ON storage.objects FOR SELECT TO authenticated USING(bucket_id='order-references' AND public.request_object_access(name,'read'));
CREATE POLICY request_images_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='order-references' AND public.request_object_access(name,'insert'));
CREATE POLICY request_images_delete ON storage.objects FOR DELETE TO authenticated USING(bucket_id='order-references' AND public.request_object_access(name,'delete'));
-- No UPDATE policy: immutable filenames, replacement via new registered object.
REVOKE ALL ON FUNCTION public.request_participant(uuid),public.open_request_draft(uuid),public.save_request_draft(uuid,bigint,jsonb),
 public.request_catalog(uuid,uuid),public.request_choice(jsonb),public.request_snapshot(uuid),public.review_request(uuid,bigint),public.submit_request(uuid,uuid),
 public.register_request_upload(uuid,text),public.retire_request_upload(text),public.request_object_access(text,text) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.request_participant(uuid),public.open_request_draft(uuid),public.save_request_draft(uuid,bigint,jsonb),
 public.request_catalog(uuid,uuid),public.review_request(uuid,bigint),public.submit_request(uuid,uuid),public.register_request_upload(uuid,text),
 public.retire_request_upload(text),public.request_object_access(text,text) TO authenticated;
COMMIT;

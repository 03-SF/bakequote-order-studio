BEGIN;
-- English-only migration tolerates existing Urdu preferences.
UPDATE public.profiles SET locale = 'en' WHERE locale <> 'en';
ALTER TABLE public.profiles DROP CONSTRAINT profiles_locale_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_locale_check CHECK (locale = 'en');

ALTER TABLE public.businesses
 ADD COLUMN description text NOT NULL DEFAULT '' CHECK(length(description)<=2000),
 ADD COLUMN owner_name text NOT NULL DEFAULT '' CHECK(length(owner_name)<=100),
 ADD COLUMN contact_phone text NOT NULL DEFAULT '' CHECK(length(contact_phone)<=40),
 ADD COLUMN location text NOT NULL DEFAULT '' CHECK(length(location)<=200),
 ADD COLUMN pickup_address text NOT NULL DEFAULT '' CHECK(length(pickup_address)<=500),
 ADD COLUMN cover_path text,
 ADD COLUMN code text NOT NULL DEFAULT upper(replace(gen_random_uuid()::text,'-','')) UNIQUE,
 ADD COLUMN pickup_enabled boolean NOT NULL DEFAULT true,
 ADD COLUMN delivery_enabled boolean NOT NULL DEFAULT false,
 ADD COLUMN minimum_paisa bigint NOT NULL DEFAULT 0 CHECK(minimum_paisa BETWEEN 0 AND 100000000000),
 ADD COLUMN revision bigint NOT NULL DEFAULT 0;
ALTER TABLE public.businesses ADD CONSTRAINT cover_owned CHECK(cover_path IS NULL OR cover_path ~ ('^'||id::text||'/cover/[0-9a-f-]{36}\.(jpg|png|webp)$'));

CREATE TABLE public.products (
 id uuid PRIMARY KEY,
 business_id uuid NOT NULL REFERENCES public.businesses(id),
 name text NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 100),
 description text NOT NULL DEFAULT '' CHECK(length(description)<=2000),
 kind text NOT NULL CHECK(kind IN ('cake','cupcakes')),
 active boolean NOT NULL DEFAULT false,
 minimum_quantity integer NOT NULL DEFAULT 1 CHECK(minimum_quantity BETWEEN 1 AND 10000),
 image_path text,
 variants jsonb NOT NULL DEFAULT '[]'::jsonb,
 options jsonb NOT NULL DEFAULT '[]'::jsonb,
 CHECK(image_path IS NULL OR image_path ~ ('^'||business_id::text||'/'||id::text||'/[0-9a-f-]{36}\.(jpg|png|webp)$')),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX products_business_idx ON public.products(business_id);
CREATE TABLE public.delivery_zones (
 id uuid PRIMARY KEY,
 business_id uuid NOT NULL REFERENCES public.businesses(id),
 name text NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 100),
 fee_paisa bigint NOT NULL CHECK(fee_paisa BETWEEN 0 AND 100000000000),
 active boolean NOT NULL DEFAULT true
);
CREATE INDEX zones_business_idx ON public.delivery_zones(business_id);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_zones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.products,public.delivery_zones FROM public,anon,authenticated;
GRANT SELECT ON public.products,public.delivery_zones TO authenticated;
CREATE POLICY products_owner_read ON public.products FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.businesses b WHERE b.id=business_id AND b.owner_id=(SELECT auth.uid())));
CREATE POLICY zones_owner_read ON public.delivery_zones FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.businesses b WHERE b.id=business_id AND b.owner_id=(SELECT auth.uid())));
-- All catalog mutations go through locked, revision-checked RPCs. No deletes:
-- future orders must store immutable snapshots, never resolve historical prices here.
CREATE FUNCTION public.validate_catalog(p_variants jsonb,p_options jsonb,p_active boolean) RETURNS void
 LANGUAGE plpgsql SET search_path='' AS $$
DECLARE x jsonb; seen text[] := '{}';
BEGIN
 IF jsonb_typeof(p_variants) IS DISTINCT FROM 'array' OR jsonb_typeof(p_options) IS DISTINCT FROM 'array' OR jsonb_array_length(p_variants)>200 OR jsonb_array_length(p_options)>200 THEN RAISE EXCEPTION 'Invalid catalog arrays' USING ERRCODE='22023'; END IF;
 FOR x IN SELECT value FROM jsonb_array_elements(p_variants) UNION ALL SELECT value FROM jsonb_array_elements(p_options) LOOP
  IF jsonb_typeof(x->'price_paisa') IS DISTINCT FROM 'number' OR jsonb_typeof(x->'label') IS DISTINCT FROM 'string' OR coalesce(x->>'id','') !~ '^[0-9a-f-]{36}$' OR (x->>'id')=ANY(seen) OR length(trim(coalesce(x->>'label',''))) NOT BETWEEN 1 AND 100 OR coalesce(x->>'price_paisa','') !~ '^[0-9]{1,12}$' OR (x->>'price_paisa')::bigint>100000000000 OR jsonb_typeof(x->'active') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Invalid catalog option' USING ERRCODE='22023'; END IF;
  seen:=array_append(seen,x->>'id');
 END LOOP;
 FOR x IN SELECT value FROM jsonb_array_elements(p_variants) LOOP
  IF jsonb_typeof(x->'units') IS DISTINCT FROM 'number' OR coalesce(x->>'units','') !~ '^[1-9][0-9]{0,5}$' THEN RAISE EXCEPTION 'Invalid size or pack quantity' USING ERRCODE='22023'; END IF;
 END LOOP;
 FOR x IN SELECT value FROM jsonb_array_elements(p_options) LOOP
  IF coalesce(x->>'kind','') NOT IN ('flavour','finish','extra') THEN RAISE EXCEPTION 'Invalid option kind' USING ERRCODE='22023'; END IF;
 END LOOP;
 IF p_active AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_variants) v WHERE (v->>'active')::boolean) THEN RAISE EXCEPTION 'Active product requires an active size or pack' USING ERRCODE='22023'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.validate_catalog(jsonb,jsonb,boolean) FROM public,anon,authenticated;

CREATE FUNCTION public.save_baker_workspace(p_business_id uuid,p_revision bigint,p_business jsonb,p_products jsonb,p_zones jsonb) RETURNS bigint
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE b public.businesses; x jsonb; n bigint; ids uuid[] := '{}'; zids uuid[] := '{}';
BEGIN
 SELECT * INTO b FROM public.businesses WHERE id=p_business_id AND owner_id=auth.uid() FOR UPDATE;
 IF b.id IS NULL THEN RAISE EXCEPTION 'Business access denied' USING ERRCODE='42501'; END IF;
 IF p_revision IS NULL OR b.revision<>p_revision THEN RAISE EXCEPTION 'Workspace changed; reload before saving' USING ERRCODE='40001'; END IF;
 IF jsonb_typeof(p_products) IS DISTINCT FROM 'array' OR jsonb_typeof(p_zones) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Invalid workspace' USING ERRCODE='22023'; END IF;
 UPDATE public.businesses SET name=p_business->>'name',description=p_business->>'description',owner_name=p_business->>'owner_name',contact_phone=p_business->>'contact_phone',location=p_business->>'location',pickup_address=p_business->>'pickup_address',pickup_enabled=(p_business->>'pickup_enabled')::boolean,delivery_enabled=(p_business->>'delivery_enabled')::boolean,minimum_paisa=(p_business->>'minimum_paisa')::bigint,revision=revision+1 WHERE id=b.id RETURNING revision INTO n;
 FOR x IN SELECT value FROM jsonb_array_elements(p_products) LOOP
  IF (x->>'id')::uuid=ANY(ids) THEN RAISE EXCEPTION 'Duplicate product'; END IF;
  ids:=array_append(ids,(x->>'id')::uuid);
  IF EXISTS(SELECT 1 FROM public.products WHERE id=(x->>'id')::uuid AND business_id<>b.id) THEN RAISE EXCEPTION 'Product access denied' USING ERRCODE='42501'; END IF;
  PERFORM public.validate_catalog(x->'variants',x->'options',(x->>'active')::boolean);
  INSERT INTO public.products(id,business_id,name,description,kind,active,minimum_quantity,variants,options)
  VALUES((x->>'id')::uuid,b.id,x->>'name',x->>'description',x->>'kind',(x->>'active')::boolean,(x->>'minimum_quantity')::integer,x->'variants',x->'options')
  ON CONFLICT(id) DO UPDATE SET name=excluded.name,description=excluded.description,kind=excluded.kind,active=excluded.active,minimum_quantity=excluded.minimum_quantity,variants=excluded.variants,options=excluded.options;
 END LOOP;
 UPDATE public.products SET active=false WHERE business_id=b.id AND NOT(id=ANY(ids));
 FOR x IN SELECT value FROM jsonb_array_elements(p_zones) LOOP
  IF (x->>'id')::uuid=ANY(zids) THEN RAISE EXCEPTION 'Duplicate zone'; END IF;
  zids:=array_append(zids,(x->>'id')::uuid);
  IF EXISTS(SELECT 1 FROM public.delivery_zones WHERE id=(x->>'id')::uuid AND business_id<>b.id) THEN RAISE EXCEPTION 'Zone access denied' USING ERRCODE='42501'; END IF;
  INSERT INTO public.delivery_zones(id,business_id,name,fee_paisa,active) VALUES((x->>'id')::uuid,b.id,x->>'name',(x->>'fee_paisa')::bigint,(x->>'active')::boolean)
  ON CONFLICT(id) DO UPDATE SET name=excluded.name,fee_paisa=excluded.fee_paisa,active=excluded.active;
 END LOOP;
 UPDATE public.delivery_zones SET active=false WHERE business_id=b.id AND NOT(id=ANY(zids));
 -- Active businesses must remain complete after edits.
 IF b.onboarding_complete THEN PERFORM public.check_business_setup(b.id); END IF;
 RETURN n;
END $$;
-- Required public fields exclude personal owner name, phone and exact pickup address.
CREATE FUNCTION public.check_business_setup(p_id uuid) RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE b public.businesses;
BEGIN
 SELECT * INTO STRICT b FROM public.businesses WHERE id=p_id;
 IF length(trim(b.name))=0 OR length(trim(b.description))=0 OR length(trim(b.owner_name))=0 OR length(trim(b.contact_phone))=0 OR length(trim(b.location))=0 OR (NOT b.pickup_enabled AND NOT b.delivery_enabled) OR (b.pickup_enabled AND length(trim(b.pickup_address))=0) OR (b.delivery_enabled AND NOT EXISTS(SELECT 1 FROM public.delivery_zones WHERE business_id=b.id AND active)) THEN RAISE EXCEPTION 'Complete business, contact and fulfilment details before activation' USING ERRCODE='22023'; END IF;
END $$;
CREATE FUNCTION public.activate_business(p_business_id uuid,p_revision bigint) RETURNS bigint
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE b public.businesses;
BEGIN
 SELECT * INTO b FROM public.businesses WHERE id=p_business_id AND owner_id=auth.uid() FOR UPDATE;
 IF b.id IS NULL THEN RAISE EXCEPTION 'Business access denied' USING ERRCODE='42501'; END IF;
 IF p_revision IS NULL OR b.revision<>p_revision THEN RAISE EXCEPTION 'Reload workspace' USING ERRCODE='40001'; END IF;
 PERFORM public.check_business_setup(b.id);
 UPDATE public.businesses SET onboarding_complete=true,revision=revision+1 WHERE id=b.id;
 RETURN b.revision+1;
END $$;
-- Deliberate safe projection: no owner ID, owner/contact, exact address or drafts.
CREATE FUNCTION public.public_business(p_code text) RETURNS jsonb
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('id',id,'code',code,'name',name,'description',description,'location',location,'image_path',image_path,'cover_path',cover_path,'pickup_enabled',pickup_enabled,'delivery_enabled',delivery_enabled,'minimum_paisa',minimum_paisa) FROM public.businesses WHERE code=p_code AND onboarding_complete
$$;
CREATE FUNCTION public.catalog_estimate(p_product_id uuid,p_variant_id uuid,p_option_ids uuid[] DEFAULT '{}',p_quantity integer DEFAULT 1,p_zone_id uuid DEFAULT NULL) RETURNS jsonb
 LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.products; b public.businesses; v jsonb; o jsonb; subtotal bigint; fee bigint:=0; flavour integer:=0; finish integer:=0; seen uuid[]:='{}'; oid uuid;
BEGIN
 SELECT * INTO p FROM public.products WHERE id=p_product_id;
 SELECT * INTO b FROM public.businesses WHERE id=p.business_id;
 IF b.id IS NULL OR (b.owner_id=auth.uid() OR b.onboarding_complete) IS NOT TRUE THEN RAISE EXCEPTION 'Catalog access denied' USING ERRCODE='42501'; END IF;
 IF p_quantity IS NULL OR NOT p.active OR p_quantity NOT BETWEEN p.minimum_quantity AND 10000 THEN RAISE EXCEPTION 'Product unavailable or minimum quantity not met' USING ERRCODE='22023'; END IF;
 SELECT value INTO v FROM jsonb_array_elements(p.variants) WHERE value->>'id'=p_variant_id::text AND (value->>'active')::boolean;
 IF v IS NULL THEN RAISE EXCEPTION 'Size or pack unavailable' USING ERRCODE='22023'; END IF;
 subtotal:=(v->>'price_paisa')::bigint;
 FOREACH oid IN ARRAY p_option_ids LOOP
  IF oid=ANY(seen) THEN RAISE EXCEPTION 'Duplicate selection' USING ERRCODE='22023'; END IF;
  seen:=array_append(seen,oid);
  SELECT value INTO o FROM jsonb_array_elements(p.options) WHERE value->>'id'=oid::text AND (value->>'active')::boolean;
  IF o IS NULL THEN RAISE EXCEPTION 'Option unavailable for product' USING ERRCODE='22023'; END IF;
  IF o->>'kind'='flavour' THEN flavour:=flavour+1; END IF;
  IF o->>'kind'='finish' THEN finish:=finish+1; END IF;
  subtotal:=subtotal+(o->>'price_paisa')::bigint;
 END LOOP;
 IF flavour>1 OR finish>1 THEN RAISE EXCEPTION 'Choose at most one flavour and finish' USING ERRCODE='22023'; END IF;
 subtotal:=subtotal*p_quantity;
 IF subtotal<b.minimum_paisa THEN RAISE EXCEPTION 'Minimum order value not met' USING ERRCODE='22023'; END IF;
 IF p_zone_id IS NULL THEN
  IF NOT b.pickup_enabled THEN RAISE EXCEPTION 'Pickup unavailable' USING ERRCODE='22023'; END IF;
 ELSE
  SELECT fee_paisa INTO fee FROM public.delivery_zones WHERE id=p_zone_id AND business_id=b.id AND active;
  IF NOT b.delivery_enabled OR fee IS NULL THEN RAISE EXCEPTION 'Delivery zone unavailable' USING ERRCODE='22023'; END IF;
 END IF;
 IF subtotal+fee>9007199254740991 THEN RAISE EXCEPTION 'Estimate exceeds exact client representation' USING ERRCODE='22023'; END IF;
 RETURN jsonb_build_object('subtotal_paisa',subtotal,'delivery_paisa',fee,'total_paisa',subtotal+fee,'currency','PKR','business_revision',b.revision);
END $$;
REVOKE ALL ON FUNCTION public.save_baker_workspace(uuid,bigint,jsonb,jsonb,jsonb),public.check_business_setup(uuid),public.activate_business(uuid,bigint),public.public_business(text),public.catalog_estimate(uuid,uuid,uuid[],integer,uuid) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.save_baker_workspace(uuid,bigint,jsonb,jsonb,jsonb),public.activate_business(uuid,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.public_business(text),public.catalog_estimate(uuid,uuid,uuid[],integer,uuid) TO anon,authenticated;
COMMIT;

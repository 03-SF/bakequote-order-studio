BEGIN;
CREATE OR REPLACE FUNCTION public.public_business(p_code text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('id',b.id,'code',b.code,'name',b.name,'description',b.description,
 'location',b.location,'image_path',b.image_path,'cover_path',b.cover_path,
 'pickup_enabled',b.pickup_enabled,'delivery_enabled',b.delivery_enabled,'minimum_paisa',b.minimum_paisa,
 'delivery_zones',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',z.name,'fee_paisa',z.fee_paisa) ORDER BY z.id),'[]'::jsonb)
 FROM public.delivery_zones z WHERE z.business_id=b.id AND z.active AND b.delivery_enabled))
 FROM public.businesses b WHERE b.code=upper(trim(p_code)) AND b.onboarding_complete
$$;
CREATE TABLE public.availability_settings (
 business_id uuid PRIMARY KEY REFERENCES public.businesses(id) ON DELETE CASCADE,
 timezone text NOT NULL,
 lead_days integer NOT NULL CHECK(lead_days BETWEEN 0 AND 365),
 daily_capacity integer NOT NULL CHECK(daily_capacity BETWEEN 1 AND 10000),
 revision bigint NOT NULL DEFAULT 1
);
CREATE TABLE public.blocked_dates (
 business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
 service_date date NOT NULL,
 PRIMARY KEY(business_id,service_date)
);
-- Integration contract only. Phase 5/6 must attach real orders and write this ledger
-- in the SAME transaction after locking the business. No client writes or fake live bookings.
CREATE TABLE public.capacity_allocations (
 business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
 order_id uuid NOT NULL,
 service_date date NOT NULL,
 status text NOT NULL CHECK(status IN ('pending','confirmed','baking','ready','delivered','declined','withdrawn','cancelled')),
 PRIMARY KEY(business_id,order_id)
);
CREATE INDEX capacity_by_date ON public.capacity_allocations(business_id,service_date,status);
ALTER TABLE public.availability_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_dates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.capacity_allocations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.availability_settings,public.blocked_dates,public.capacity_allocations FROM public,anon,authenticated;

CREATE FUNCTION public.capacity_used(p_business_id uuid,p_date date) RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT count(*)::integer FROM public.capacity_allocations WHERE business_id=p_business_id
 AND service_date=p_date AND status IN ('confirmed','baking','ready','delivered')
$$;
CREATE FUNCTION public.availability_state(p_date date,p_today date,p_lead integer,p_capacity integer,p_used integer,p_blocked boolean)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN p_date<p_today THEN 'past' WHEN p_blocked THEN 'blocked'
 WHEN p_date<p_today+p_lead THEN 'lead-time-restricted' WHEN p_used>=p_capacity THEN 'full' ELSE 'available' END
$$;

CREATE FUNCTION public.owner_availability(p_business_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.availability_settings;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.businesses WHERE id=p_business_id AND owner_id=auth.uid()) THEN
 RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
 SELECT * INTO s FROM public.availability_settings WHERE business_id=p_business_id;
 RETURN jsonb_build_object('timezone',s.timezone,'lead_days',s.lead_days,'daily_capacity',s.daily_capacity,
 'revision',coalesce(s.revision,0),'today',(now() AT TIME ZONE coalesce(s.timezone,'UTC'))::date);
END $$;

CREATE FUNCTION public.save_availability(p_business_id uuid,p_revision bigint,p_timezone text,p_lead_days integer,p_capacity integer)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.availability_settings;
BEGIN
 PERFORM 1 FROM public.businesses WHERE id=p_business_id AND owner_id=auth.uid() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
 SELECT * INTO s FROM public.availability_settings WHERE business_id=p_business_id;
 IF p_revision IS NULL OR p_revision<>coalesce(s.revision,0) THEN RAISE EXCEPTION 'Reload availability' USING ERRCODE='40001'; END IF;
 IF p_timezone IS NULL OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name=p_timezone)
 OR p_lead_days IS NULL OR p_lead_days NOT BETWEEN 0 AND 365 OR p_capacity IS NULL OR p_capacity NOT BETWEEN 1 AND 10000 THEN
 RAISE EXCEPTION 'Invalid availability settings' USING ERRCODE='22023'; END IF;
 IF EXISTS(SELECT 1 FROM public.capacity_allocations WHERE business_id=p_business_id AND status IN ('confirmed','baking','ready','delivered')
 AND service_date>=(now() AT TIME ZONE p_timezone)::date GROUP BY service_date HAVING count(*)>p_capacity)
 OR (s.timezone IS DISTINCT FROM p_timezone AND EXISTS(SELECT 1 FROM public.capacity_allocations WHERE business_id=p_business_id)) THEN
 RAISE EXCEPTION 'Existing bookings conflict with settings' USING ERRCODE='23514'; END IF;
 INSERT INTO public.availability_settings VALUES(p_business_id,p_timezone,p_lead_days,p_capacity,1)
 ON CONFLICT(business_id) DO UPDATE SET timezone=excluded.timezone,lead_days=excluded.lead_days,
 daily_capacity=excluded.daily_capacity,revision=public.availability_settings.revision+1;
 RETURN coalesce(s.revision,0)+1;
END $$;

CREATE FUNCTION public.set_blocked_date(p_business_id uuid,p_revision bigint,p_date date,p_blocked boolean)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.availability_settings; today date;
BEGIN
 PERFORM 1 FROM public.businesses WHERE id=p_business_id AND owner_id=auth.uid() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
 SELECT * INTO s FROM public.availability_settings WHERE business_id=p_business_id;
 IF s.business_id IS NULL THEN RAISE EXCEPTION 'Configure availability first' USING ERRCODE='22023'; END IF;
 IF p_revision IS NULL OR p_revision<>s.revision THEN RAISE EXCEPTION 'Reload availability' USING ERRCODE='40001'; END IF;
 today:=(now() AT TIME ZONE s.timezone)::date;
 IF p_date IS NULL OR p_date<today OR p_date>today+730 OR p_blocked IS NULL THEN RAISE EXCEPTION 'Invalid service date' USING ERRCODE='22023'; END IF;
 IF p_blocked AND public.capacity_used(p_business_id,p_date)>0 THEN RAISE EXCEPTION 'Existing bookings: resolve conflict first' USING ERRCODE='23514'; END IF;
 IF p_blocked THEN INSERT INTO public.blocked_dates VALUES(p_business_id,p_date) ON CONFLICT DO NOTHING;
 ELSE DELETE FROM public.blocked_dates WHERE business_id=p_business_id AND service_date=p_date; END IF;
 UPDATE public.availability_settings SET revision=revision+1 WHERE business_id=p_business_id;
 RETURN s.revision+1;
END $$;

CREATE FUNCTION public.bakery_availability(p_code text,p_start date DEFAULT NULL,p_days integer DEFAULT 31)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE b public.businesses; s public.availability_settings; today date; first_day date; days jsonb;
BEGIN
 IF p_days IS NULL OR p_days NOT BETWEEN 1 AND 62 THEN RAISE EXCEPTION 'Invalid range' USING ERRCODE='22023'; END IF;
 SELECT * INTO b FROM public.businesses WHERE code=upper(trim(p_code)) AND (onboarding_complete OR owner_id=auth.uid());
 IF b.id IS NULL THEN RETURN NULL; END IF;
 SELECT * INTO s FROM public.availability_settings WHERE business_id=b.id;
 IF s.business_id IS NULL THEN RETURN jsonb_build_object('configured',false); END IF;
 today:=(now() AT TIME ZONE s.timezone)::date;
 first_day:=coalesce(p_start,date_trunc('month',today)::date);
 IF first_day<today-366 OR first_day+p_days>today+731 THEN RAISE EXCEPTION 'Range outside calendar window' USING ERRCODE='22023'; END IF;
 SELECT jsonb_agg(jsonb_build_object('date',d,'state',public.availability_state(d,today,s.lead_days,s.daily_capacity,
 public.capacity_used(b.id,d),EXISTS(SELECT 1 FROM public.blocked_dates WHERE business_id=b.id AND service_date=d))) ORDER BY d)
 INTO days FROM (SELECT first_day+i AS d FROM generate_series(0,p_days-1) i
 WHERE p_start IS NOT NULL OR first_day+i<(first_day+interval '1 month')::date) q;
 RETURN jsonb_build_object('configured',true,'timezone',s.timezone,'lead_days',s.lead_days,'today',today,'days',days);
END $$;

CREATE TABLE public.recent_businesses (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
 opened_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(user_id,business_id)
);
CREATE INDEX recent_by_user ON public.recent_businesses(user_id,opened_at DESC,business_id);
ALTER TABLE public.recent_businesses ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.recent_businesses FROM public,anon,authenticated;
GRANT SELECT ON public.recent_businesses TO authenticated;
CREATE POLICY recent_self ON public.recent_businesses FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
CREATE FUNCTION public.record_bakery_open(p_business_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.profiles WHERE id=auth.uid() FOR UPDATE;
 PERFORM 1 FROM public.businesses WHERE id=p_business_id AND onboarding_complete FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Bakery unavailable' USING ERRCODE='22023'; END IF;
 INSERT INTO public.recent_businesses VALUES(auth.uid(),p_business_id,clock_timestamp())
 ON CONFLICT(user_id,business_id) DO UPDATE SET opened_at=excluded.opened_at;
 DELETE FROM public.recent_businesses WHERE user_id=auth.uid() AND business_id IN
 (SELECT business_id FROM public.recent_businesses WHERE user_id=auth.uid() ORDER BY opened_at DESC,business_id OFFSET 20);
END $$;
CREATE FUNCTION public.recent_bakeries() RETURNS TABLE(business_id uuid,profile jsonb)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT r.business_id,public.public_business(b.code) FROM public.recent_businesses r
 JOIN public.businesses b ON b.id=r.business_id WHERE r.user_id=auth.uid() ORDER BY r.opened_at DESC,r.business_id LIMIT 20;
END $$;
REVOKE ALL ON FUNCTION public.capacity_used(uuid,date),public.availability_state(date,date,integer,integer,integer,boolean),
 public.owner_availability(uuid),public.save_availability(uuid,bigint,text,integer,integer),public.set_blocked_date(uuid,bigint,date,boolean),
 public.bakery_availability(text,date,integer),public.record_bakery_open(uuid),public.recent_bakeries() FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.owner_availability(uuid),public.save_availability(uuid,bigint,text,integer,integer),
 public.set_blocked_date(uuid,bigint,date,boolean),public.record_bakery_open(uuid),public.recent_bakeries() TO authenticated;
GRANT EXECUTE ON FUNCTION public.bakery_availability(text,date,integer) TO anon,authenticated;
COMMIT;

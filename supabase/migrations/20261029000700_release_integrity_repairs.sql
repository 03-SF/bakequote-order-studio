BEGIN;
-- The communication migration recreated an obsolete restrictive policy that
-- denied legitimate product and order-reference operations. Keep conversation
-- attachments closed until their complete upload/membership lifecycle is tested.
DROP POLICY IF EXISTS future_buckets_closed ON storage.objects;

ALTER TABLE public.capacity_allocations DROP CONSTRAINT capacity_allocations_status_check;
ALTER TABLE public.capacity_allocations ADD CONSTRAINT capacity_allocations_status_check
 CHECK(status IN ('pending','confirmed','baking','decorating','ready','delivered','declined','withdrawn','cancelled'));
CREATE OR REPLACE FUNCTION public.capacity_used(p_business_id uuid,p_date date) RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT count(*)::integer FROM public.capacity_allocations WHERE business_id=p_business_id
 AND service_date=p_date AND status IN ('confirmed','baking','decorating','ready','delivered')
$$;

-- Do not invent a commercial plan limit for newly created usage rows. Existing
-- configured limits are preserved. Owner approval and provider reconciliation
-- are required before commercial entitlements are enabled.
ALTER TABLE public.business_usage_months ALTER COLUMN free_limit DROP NOT NULL;
ALTER TABLE public.business_usage_months ALTER COLUMN free_limit DROP DEFAULT;
ALTER TABLE public.order_operations ADD COLUMN actor_id uuid REFERENCES auth.users(id);
ALTER TABLE public.order_operations ADD COLUMN operation_input jsonb;

CREATE OR REPLACE FUNCTION public.confirm_order(p_order_id uuid,p_expected_version bigint,
 p_quote_version integer,p_due_at timestamptz,p_operation_id uuid)
RETURNS public.order_requests LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.order_requests; b public.businesses; s public.availability_settings;
 u public.business_usage_months; existing public.order_operations; v_service_date date; usage_month date;
 input jsonb:=jsonb_build_object('expected_version',p_expected_version,'quote_version',p_quote_version,'due_at',p_due_at);
BEGIN
 SELECT * INTO r FROM public.order_requests WHERE id=p_order_id FOR UPDATE;
 IF r.id IS NULL THEN RAISE EXCEPTION 'Order unavailable' USING ERRCODE='42501'; END IF;
 SELECT * INTO b FROM public.businesses WHERE id=r.business_id AND owner_id=auth.uid() FOR UPDATE;
 IF b.id IS NULL THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
 IF p_operation_id IS NULL THEN RAISE EXCEPTION 'Operation ID required' USING ERRCODE='22023'; END IF;
 SELECT * INTO existing FROM public.order_operations WHERE operation_id=p_operation_id;
 IF FOUND THEN
  IF existing.order_id IS DISTINCT FROM r.id OR existing.actor_id IS DISTINCT FROM auth.uid()
   OR existing.command IS DISTINCT FROM 'confirm' OR existing.operation_input IS DISTINCT FROM input
   THEN RAISE EXCEPTION 'Operation ID already used for another action' USING ERRCODE='40001'; END IF;
  RETURN r;
 END IF;
 IF r.status IS DISTINCT FROM 'pending' THEN RAISE EXCEPTION 'Invalid current status' USING ERRCODE='23514'; END IF;
 IF p_expected_version IS NULL OR p_expected_version<>r.version THEN RAISE EXCEPTION 'Version conflict' USING ERRCODE='40001'; END IF;
 IF p_quote_version IS NULL OR p_quote_version<>r.current_quote_version
  OR r.agreed_quote_version IS DISTINCT FROM r.current_quote_version
  OR NOT EXISTS(SELECT 1 FROM public.order_agreements a WHERE a.order_id=r.id
   AND a.quote_version=r.current_quote_version AND a.recorded_by=r.customer_id)
  THEN RAISE EXCEPTION 'Current quote agreement required' USING ERRCODE='40001'; END IF;
 IF p_due_at IS NULL OR p_due_at<=now() THEN RAISE EXCEPTION 'Due time must be in the future' USING ERRCODE='22023'; END IF;
 v_service_date:=(r.snapshot->>'service_date')::date;
 SELECT * INTO s FROM public.availability_settings WHERE business_id=b.id;
 IF s.business_id IS NULL OR v_service_date<(now() AT TIME ZONE s.timezone)::date
  OR (p_due_at AT TIME ZONE s.timezone)::date<>v_service_date
  OR EXISTS(SELECT 1 FROM public.blocked_dates d WHERE d.business_id=b.id AND d.service_date=v_service_date)
  OR public.capacity_used(b.id,v_service_date)>=s.daily_capacity
  THEN RAISE EXCEPTION 'Date unavailable' USING ERRCODE='23514'; END IF;
 usage_month:=date_trunc('month',now() AT TIME ZONE s.timezone)::date;
 INSERT INTO public.business_usage_months(business_id,month_start) VALUES(b.id,usage_month)
  ON CONFLICT DO NOTHING;
 SELECT * INTO u FROM public.business_usage_months WHERE business_id=b.id AND month_start=usage_month FOR UPDATE;
 IF u.free_limit IS NOT NULL AND u.confirmed_count>=u.free_limit
  THEN RAISE EXCEPTION 'Free confirmation limit reached' USING ERRCODE='P0001'; END IF;
 UPDATE public.business_usage_months SET confirmed_count=confirmed_count+1 WHERE business_id=b.id AND month_start=usage_month;
 UPDATE public.order_requests SET status='confirmed',due_at=p_due_at,confirmed_at=now(),version=version+1 WHERE id=r.id RETURNING * INTO r;
 INSERT INTO public.capacity_allocations(business_id,order_id,service_date,status) VALUES(b.id,r.id,v_service_date,'confirmed');
 INSERT INTO public.order_events(order_id,kind,actor_id) VALUES(r.id,'confirmed',auth.uid());
 INSERT INTO public.order_operations(operation_id,order_id,command,result_status,actor_id,operation_input)
  VALUES(p_operation_id,r.id,'confirm','confirmed',auth.uid(),input);
 RETURN r;
END $$;

CREATE OR REPLACE FUNCTION public.transition_order(p_order_id uuid,p_expected_version bigint,p_next_status text,p_operation_id uuid)
RETURNS public.order_requests LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.order_requests; owner_id uuid; existing public.order_operations; allowed boolean;
 input jsonb:=jsonb_build_object('expected_version',p_expected_version,'next_status',p_next_status);
BEGIN
 SELECT * INTO r FROM public.order_requests WHERE id=p_order_id FOR UPDATE;
 IF r.id IS NULL THEN RAISE EXCEPTION 'Order unavailable' USING ERRCODE='42501'; END IF;
 SELECT b.owner_id INTO owner_id FROM public.businesses b WHERE b.id=r.business_id;
 IF auth.uid() IS NULL OR (auth.uid() IS DISTINCT FROM owner_id AND auth.uid() IS DISTINCT FROM r.customer_id)
  THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
 IF p_operation_id IS NULL THEN RAISE EXCEPTION 'Operation ID required' USING ERRCODE='22023'; END IF;
 SELECT * INTO existing FROM public.order_operations WHERE operation_id=p_operation_id;
 IF FOUND THEN
  IF existing.order_id IS DISTINCT FROM r.id OR existing.actor_id IS DISTINCT FROM auth.uid()
   OR existing.command IS DISTINCT FROM 'transition' OR existing.operation_input IS DISTINCT FROM input
   THEN RAISE EXCEPTION 'Operation ID already used for another action' USING ERRCODE='40001'; END IF;
  RETURN r;
 END IF;
 IF p_expected_version IS NULL OR p_expected_version<>r.version THEN RAISE EXCEPTION 'Version conflict' USING ERRCODE='40001'; END IF;
 IF auth.uid()=owner_id THEN
  allowed:=(r.status='pending' AND p_next_status='declined') OR (r.status='confirmed' AND p_next_status='baking')
   OR (r.status='baking' AND p_next_status='decorating') OR (r.status='decorating' AND p_next_status='ready')
   OR (r.status='ready' AND p_next_status='delivered');
 ELSE allowed:=r.status='pending' AND p_next_status='withdrawn'; END IF;
 IF allowed IS DISTINCT FROM true THEN RAISE EXCEPTION 'Invalid status transition' USING ERRCODE='23514'; END IF;
 UPDATE public.order_requests SET status=p_next_status,version=version+1 WHERE id=r.id RETURNING * INTO r;
 IF p_next_status IN ('baking','decorating','ready','delivered') THEN
  UPDATE public.capacity_allocations SET status=p_next_status WHERE order_id=r.id;
 END IF;
 INSERT INTO public.order_events(order_id,kind,actor_id) VALUES(r.id,'status_'||p_next_status,auth.uid());
 INSERT INTO public.order_operations(operation_id,order_id,command,result_status,actor_id,operation_input)
  VALUES(p_operation_id,r.id,'transition',p_next_status,auth.uid(),input);
 RETURN r;
END $$;
-- Interpret the selected wall time in the bakery's configured timezone,
-- independent of the customer's or baker's device timezone.
CREATE FUNCTION public.confirm_order_local(p_order_id uuid,p_expected_version bigint,p_quote_version integer,
 p_local_time text,p_operation_id uuid) RETURNS public.order_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_date date; v_timezone text; v_due timestamptz;
BEGIN
 SELECT (r.snapshot->>'service_date')::date,s.timezone INTO v_date,v_timezone
 FROM public.order_requests r JOIN public.businesses b ON b.id=r.business_id
 JOIN public.availability_settings s ON s.business_id=b.id
 WHERE r.id=p_order_id AND b.owner_id=auth.uid();
 IF v_timezone IS NULL THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
 IF p_local_time IS NULL OR p_local_time !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
  THEN RAISE EXCEPTION 'Invalid local time' USING ERRCODE='22023'; END IF;
 v_due:=(v_date+p_local_time::time) AT TIME ZONE v_timezone;
 IF (v_due AT TIME ZONE v_timezone) IS DISTINCT FROM (v_date+p_local_time::time)
  THEN RAISE EXCEPTION 'Local time does not exist in bakery timezone' USING ERRCODE='22023'; END IF;
 RETURN public.confirm_order(p_order_id,p_expected_version,p_quote_version,v_due,p_operation_id);
END $$;
REVOKE ALL ON FUNCTION public.confirm_order_local(uuid,bigint,integer,text,uuid) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_order_local(uuid,bigint,integer,text,uuid) TO authenticated;
-- Manual-create retries must not return another bakery's order. Bind every
-- operation key to the actor and complete input under the owned business lock.
CREATE OR REPLACE FUNCTION public.add_manual_order(p_business_id uuid,p_name text,p_phone text,p_snapshot jsonb,
 p_total_paisa bigint,p_service_date date,p_operation_id uuid,p_acknowledge_lead_time boolean DEFAULT false)
RETURNS public.order_requests LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE b public.businesses; s public.availability_settings; r public.order_requests;
 u public.business_usage_months; old public.order_operations; v_month date;
 input jsonb:=jsonb_build_object('business_id',p_business_id,'name',p_name,'phone',p_phone,'snapshot',p_snapshot,
  'total_paisa',p_total_paisa,'service_date',p_service_date,'acknowledge_lead_time',p_acknowledge_lead_time);
BEGIN
 SELECT * INTO b FROM public.businesses WHERE id=p_business_id AND owner_id=auth.uid() FOR UPDATE;
 IF b.id IS NULL THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
 IF p_operation_id IS NULL THEN RAISE EXCEPTION 'Operation ID required' USING ERRCODE='22023'; END IF;
 SELECT * INTO old FROM public.order_operations WHERE operation_id=p_operation_id;
 IF FOUND THEN
  IF old.actor_id IS DISTINCT FROM auth.uid() OR old.command IS DISTINCT FROM 'manual_create'
   OR old.operation_input IS DISTINCT FROM input THEN RAISE EXCEPTION 'Operation ID already used' USING ERRCODE='40001'; END IF;
  SELECT * INTO r FROM public.order_requests WHERE id=old.order_id AND business_id=b.id;
  IF r.id IS NULL THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
  RETURN r;
 END IF;
 SELECT * INTO s FROM public.availability_settings WHERE business_id=b.id;
 IF s.business_id IS NULL OR p_service_date IS NULL OR p_service_date<(now() AT TIME ZONE s.timezone)::date
  OR (p_service_date<(now() AT TIME ZONE s.timezone)::date+s.lead_days AND p_acknowledge_lead_time IS DISTINCT FROM true)
  OR EXISTS(SELECT 1 FROM public.blocked_dates d WHERE d.business_id=b.id AND d.service_date=p_service_date)
  OR public.capacity_used(b.id,p_service_date)>=s.daily_capacity THEN RAISE EXCEPTION 'Date unavailable' USING ERRCODE='23514'; END IF;
 IF p_total_paisa IS NULL OR p_total_paisa NOT BETWEEN 1 AND 9007199254740991
  OR p_name IS NULL OR char_length(btrim(p_name)) NOT BETWEEN 1 AND 100
  OR char_length(coalesce(p_phone,''))>40 OR jsonb_typeof(p_snapshot) IS DISTINCT FROM 'object'
  OR octet_length(p_snapshot::text)>16000 THEN RAISE EXCEPTION 'Invalid manual order' USING ERRCODE='22023'; END IF;
 v_month:=date_trunc('month',now() AT TIME ZONE s.timezone)::date;
 INSERT INTO public.business_usage_months(business_id,month_start) VALUES(b.id,v_month) ON CONFLICT DO NOTHING;
 SELECT * INTO u FROM public.business_usage_months WHERE business_id=b.id AND month_start=v_month FOR UPDATE;
 IF u.free_limit IS NOT NULL AND u.confirmed_count>=u.free_limit THEN RAISE EXCEPTION 'Free confirmation limit reached' USING ERRCODE='P0001'; END IF;
 UPDATE public.business_usage_months SET confirmed_count=confirmed_count+1 WHERE business_id=b.id AND month_start=v_month;
 INSERT INTO public.order_requests(source,submission_token,customer_id,business_id,status,snapshot,current_quote_version,agreed_quote_version,agreement_basis,due_at,confirmed_at)
 VALUES('manual',p_operation_id,NULL,b.id,'confirmed',p_snapshot||jsonb_build_object('contact_name',btrim(p_name),'phone',coalesce(p_phone,''),
  'service_date',p_service_date,'estimate',jsonb_build_object('subtotal_paisa',p_total_paisa,'delivery_paisa',0,'total_paisa',p_total_paisa,'lines','[]'::jsonb)),
  1,1,'Manual order acknowledgement',NULL,now()) RETURNING * INTO r;
 INSERT INTO public.capacity_allocations(business_id,order_id,service_date,status) VALUES(b.id,r.id,p_service_date,'confirmed');
 INSERT INTO public.order_events(order_id,kind,actor_id) VALUES(r.id,'manual_created',auth.uid());
 INSERT INTO public.order_operations(operation_id,order_id,command,result_status,actor_id,operation_input)
  VALUES(p_operation_id,r.id,'manual_create','confirmed',auth.uid(),input);
 RETURN r;
END $$;

-- No worker exists and the legacy recent-login check does not prove this
-- session was reauthenticated. Prevent misleading deletion requests until a
-- real verified reauthentication and end-to-end cleanup workflow exists.
REVOKE EXECUTE ON FUNCTION public.request_account_deletion(text) FROM authenticated;
COMMIT;

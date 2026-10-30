BEGIN;
ALTER TABLE public.order_events ADD COLUMN IF NOT EXISTS details jsonb;

-- The old endpoint cannot accept an explicitly confirmed due time or retry key.
REVOKE EXECUTE ON FUNCTION public.reschedule_order(uuid,bigint,date) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.reschedule_order_local(p_order_id uuid,p_expected_version bigint,
 p_service_date date,p_local_time text,p_operation_id uuid)
RETURNS public.order_requests LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.order_requests; b public.businesses; s public.availability_settings;
 old_allocation public.capacity_allocations; previous public.order_operations;
 local_due timestamp; new_due timestamptz; old_due timestamptz; n integer;
 input jsonb:=jsonb_build_object('expected_version',p_expected_version,'service_date',p_service_date,'local_time',p_local_time);
BEGIN
 SELECT * INTO r FROM public.order_requests WHERE id=p_order_id FOR UPDATE;
 SELECT * INTO b FROM public.businesses WHERE id=r.business_id AND owner_id=auth.uid() FOR UPDATE;
 IF r.id IS NULL OR b.id IS NULL THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
 IF p_operation_id IS NULL THEN RAISE EXCEPTION 'Operation ID required' USING ERRCODE='22023'; END IF;
 SELECT * INTO previous FROM public.order_operations WHERE operation_id=p_operation_id;
 IF FOUND THEN
  IF previous.order_id IS DISTINCT FROM r.id OR previous.actor_id IS DISTINCT FROM auth.uid()
   OR previous.command IS DISTINCT FROM 'reschedule' OR previous.operation_input IS DISTINCT FROM input
   THEN RAISE EXCEPTION 'Operation ID conflict' USING ERRCODE='40001'; END IF;
  RETURN r;
 END IF;
 IF p_expected_version IS NULL OR p_expected_version<>r.version THEN RAISE EXCEPTION 'Version conflict' USING ERRCODE='40001'; END IF;
 IF r.status NOT IN ('confirmed','baking','decorating','ready') OR p_service_date IS NULL
  OR p_local_time IS NULL OR p_local_time !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
  THEN RAISE EXCEPTION 'Invalid schedule' USING ERRCODE='22023'; END IF;
 IF EXISTS(SELECT 1 FROM public.order_cancellation_requests WHERE order_id=r.id AND status='open')
  THEN RAISE EXCEPTION 'Resolve cancellation first' USING ERRCODE='23514'; END IF;
 SELECT * INTO s FROM public.availability_settings WHERE business_id=b.id;
 SELECT * INTO old_allocation FROM public.capacity_allocations WHERE order_id=r.id FOR UPDATE;
 IF s.business_id IS NULL OR old_allocation.order_id IS NULL OR old_allocation.business_id<>b.id
  OR old_allocation.status<>r.status THEN RAISE EXCEPTION 'Allocation unavailable' USING ERRCODE='23514'; END IF;
 local_due:=p_service_date+p_local_time::time;
 new_due:=local_due AT TIME ZONE s.timezone;
 IF (new_due AT TIME ZONE s.timezone) IS DISTINCT FROM local_due OR new_due<=now()
  THEN RAISE EXCEPTION 'Invalid local due time' USING ERRCODE='22023'; END IF;
 IF p_service_date < (now() AT TIME ZONE s.timezone)::date+s.lead_days
  OR EXISTS(SELECT 1 FROM public.blocked_dates WHERE business_id=b.id AND service_date=p_service_date)
  OR (p_service_date<>old_allocation.service_date AND public.capacity_used(b.id,p_service_date)>=s.daily_capacity)
  THEN RAISE EXCEPTION 'Date unavailable' USING ERRCODE='23514'; END IF;
 old_due:=r.due_at;
 UPDATE public.order_requests SET snapshot=jsonb_set(snapshot,'{service_date}',to_jsonb(p_service_date::text)),
  due_at=new_due,version=version+1 WHERE id=r.id RETURNING * INTO r;
 UPDATE public.capacity_allocations SET service_date=p_service_date WHERE order_id=r.id;
 GET DIAGNOSTICS n = ROW_COUNT;
 IF n<>1 THEN RAISE EXCEPTION 'Allocation mismatch' USING ERRCODE='23514'; END IF;
 INSERT INTO public.order_events(order_id,kind,actor_id,details)
 VALUES(r.id,'rescheduled',auth.uid(),jsonb_build_object('old_date',old_allocation.service_date,'old_due_at',old_due,
  'new_date',p_service_date,'new_due_at',new_due,'timezone',s.timezone));
 INSERT INTO public.order_operations(operation_id,order_id,command,result_status,actor_id,operation_input)
 VALUES(p_operation_id,r.id,'reschedule',r.status,auth.uid(),input);
 RETURN r;
END $$;
REVOKE ALL ON FUNCTION public.reschedule_order_local(uuid,bigint,date,text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.reschedule_order_local(uuid,bigint,date,text,uuid) TO authenticated;
COMMIT;

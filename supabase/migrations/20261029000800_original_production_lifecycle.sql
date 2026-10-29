BEGIN;
-- Existing Decorating values and history remain intact. They may advance to
-- Ready; new transitions into Decorating are no longer permitted.
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
   OR (r.status IN ('baking','decorating') AND p_next_status='ready')
   OR (r.status='ready' AND p_next_status='delivered');
 ELSE allowed:=r.status='pending' AND p_next_status='withdrawn'; END IF;
 IF allowed IS DISTINCT FROM true THEN RAISE EXCEPTION 'Invalid status transition' USING ERRCODE='23514'; END IF;
 UPDATE public.order_requests SET status=p_next_status,version=version+1 WHERE id=r.id RETURNING * INTO r;
 IF p_next_status IN ('baking','ready','delivered') THEN
  UPDATE public.capacity_allocations SET status=p_next_status WHERE order_id=r.id;
 END IF;
 INSERT INTO public.order_events(order_id,kind,actor_id) VALUES(r.id,'status_'||p_next_status,auth.uid());
 INSERT INTO public.order_operations(operation_id,order_id,command,result_status,actor_id,operation_input)
  VALUES(p_operation_id,r.id,'transition',p_next_status,auth.uid(),input);
 RETURN r;
END $$;
COMMIT;

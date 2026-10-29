BEGIN;

-- Phase 5 extends the immutable request snapshot; it never rewrites the
-- Phase 4 request or its initial estimate.
ALTER TABLE public.order_requests
  DROP CONSTRAINT IF EXISTS order_requests_status_check;
ALTER TABLE public.order_requests
  ADD CONSTRAINT order_requests_status_check
  CHECK (status IN ('pending','confirmed','baking','decorating','ready',
                    'delivered','declined','withdrawn','cancelled'));
ALTER TABLE public.order_requests
  ADD COLUMN IF NOT EXISTS due_at timestamptz,
  ADD COLUMN IF NOT EXISTS agreed_quote_version integer,
  ADD COLUMN IF NOT EXISTS agreement_basis text,
  ADD COLUMN IF NOT EXISTS agreement_message_id uuid,
  ADD COLUMN IF NOT EXISTS confirmed_at timestamptz,
  ADD COLUMN IF NOT EXISTS version bigint NOT NULL DEFAULT 1;

ALTER TABLE public.request_quotes
  ADD COLUMN IF NOT EXISTS reason text,
  ADD COLUMN IF NOT EXISTS actor_id uuid REFERENCES auth.users(id);
ALTER TABLE public.request_quotes
  ADD CONSTRAINT request_quotes_reason_length
  CHECK (reason IS NULL OR char_length(reason) BETWEEN 1 AND 1000);

CREATE TABLE public.order_agreements (
  order_id uuid PRIMARY KEY REFERENCES public.order_requests(id) ON DELETE CASCADE,
  quote_version integer NOT NULL,
  basis text NOT NULL CHECK (char_length(btrim(basis)) BETWEEN 1 AND 1000),
  referenced_message_id uuid,
  recorded_by uuid NOT NULL REFERENCES auth.users(id),
  recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.business_usage_months (
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  month_start date NOT NULL,
  confirmed_count integer NOT NULL DEFAULT 0 CHECK (confirmed_count >= 0),
  free_limit integer NOT NULL DEFAULT 20 CHECK (free_limit >= 0),
  PRIMARY KEY (business_id, month_start)
);

CREATE TABLE public.order_operations (
  operation_id uuid PRIMARY KEY,
  order_id uuid NOT NULL REFERENCES public.order_requests(id) ON DELETE CASCADE,
  command text NOT NULL,
  result_status text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.order_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.order_requests(id) ON DELETE CASCADE,
  kind text NOT NULL,
  actor_id uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX order_events_order ON public.order_events(order_id, created_at);

ALTER TABLE public.order_agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_usage_months ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_operations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.order_agreements, public.business_usage_months,
  public.order_operations FROM public, anon, authenticated;
REVOKE ALL ON public.order_events FROM public, anon, authenticated;
GRANT SELECT ON public.order_agreements TO authenticated;
GRANT SELECT ON public.order_events TO authenticated;

CREATE POLICY order_agreements_participants ON public.order_agreements
FOR SELECT TO authenticated USING (public.request_participant(order_id));
CREATE POLICY order_events_participants ON public.order_events
FOR SELECT TO authenticated USING (public.request_participant(order_id));

CREATE OR REPLACE FUNCTION public.order_participant(p_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT public.request_participant(p_id)
$$;

CREATE OR REPLACE FUNCTION public.revise_order_quote(
  p_order_id uuid,
  p_expected_version integer,
  p_estimate jsonb,
  p_reason text
) RETURNS public.request_quotes
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.order_requests; q public.request_quotes;
  next_version integer;
BEGIN
  SELECT * INTO r FROM public.order_requests
    WHERE id=p_order_id
      AND EXISTS (SELECT 1 FROM public.businesses b
                  WHERE b.id=business_id AND b.owner_id=auth.uid())
    FOR UPDATE;
  IF r.id IS NULL THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
  IF r.status <> 'pending' THEN RAISE EXCEPTION 'Order is no longer pending' USING ERRCODE='23514'; END IF;
  IF p_expected_version IS NULL OR p_expected_version <> r.current_quote_version
    THEN RAISE EXCEPTION 'Quote changed' USING ERRCODE='40001'; END IF;
  IF jsonb_typeof(p_estimate) IS DISTINCT FROM 'object'
    OR (p_estimate->>'total_paisa')::bigint IS NULL
    OR (p_estimate->>'total_paisa')::bigint <= 0
    OR p_reason IS NULL OR char_length(btrim(p_reason)) NOT BETWEEN 1 AND 1000
    THEN RAISE EXCEPTION 'Invalid quote' USING ERRCODE='22023'; END IF;
  next_version := r.current_quote_version + 1;
  INSERT INTO public.request_quotes(order_id,version,estimate,reason,actor_id)
    VALUES (r.id,next_version,p_estimate,btrim(p_reason),auth.uid())
    RETURNING * INTO q;
  UPDATE public.order_requests
    SET current_quote_version=next_version, agreed_quote_version=NULL,
        agreement_basis=NULL, agreement_message_id=NULL, version=version+1
    WHERE id=r.id;
  INSERT INTO public.order_events(order_id,kind,actor_id)
    VALUES (r.id,'quote_revised',auth.uid());
  RETURN q;
END $$;

CREATE OR REPLACE FUNCTION public.record_order_agreement(
  p_order_id uuid,
  p_quote_version integer,
  p_basis text,
  p_message_id uuid DEFAULT NULL
) RETURNS public.order_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.order_requests; q public.request_quotes;
  agreement public.order_agreements;
BEGIN
  SELECT * INTO r FROM public.order_requests
    WHERE id=p_order_id AND customer_id=auth.uid() FOR UPDATE;
  IF r.id IS NULL THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
  IF r.status <> 'pending' THEN RAISE EXCEPTION 'Order is no longer pending' USING ERRCODE='23514'; END IF;
  SELECT * INTO q FROM public.request_quotes
    WHERE order_id=r.id AND version=p_quote_version;
  IF q.order_id IS NULL OR p_quote_version <> r.current_quote_version
    THEN RAISE EXCEPTION 'Quote changed' USING ERRCODE='40001'; END IF;
  IF p_basis IS NULL OR char_length(btrim(p_basis)) NOT BETWEEN 1 AND 1000
    THEN RAISE EXCEPTION 'Agreement basis required' USING ERRCODE='22023'; END IF;
  IF p_message_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.request_events e
    WHERE e.id=p_message_id AND e.order_id=r.id
  ) THEN RAISE EXCEPTION 'Message does not belong to order' USING ERRCODE='42501'; END IF;
  INSERT INTO public.order_agreements
    (order_id,quote_version,basis,referenced_message_id,recorded_by)
    VALUES (r.id,p_quote_version,btrim(p_basis),p_message_id,auth.uid())
    ON CONFLICT (order_id) DO UPDATE SET quote_version=excluded.quote_version,
      basis=excluded.basis, referenced_message_id=excluded.referenced_message_id,
      recorded_by=excluded.recorded_by, recorded_at=now();
  UPDATE public.order_requests
    SET agreed_quote_version=p_quote_version, agreement_basis=btrim(p_basis),
        agreement_message_id=p_message_id, version=version+1
    WHERE id=r.id RETURNING * INTO r;
  INSERT INTO public.order_events(order_id,kind,actor_id)
    VALUES (r.id,'quote_agreed',auth.uid());
  RETURN r;
END $$;

CREATE OR REPLACE FUNCTION public.confirm_order(
  p_order_id uuid,
  p_expected_version bigint,
  p_quote_version integer,
  p_due_at timestamptz,
  p_operation_id uuid
) RETURNS public.order_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.order_requests; b public.businesses; s public.availability_settings;
  usage_row public.business_usage_months; service_date date; month_start date;
  used integer; limit_count integer;
BEGIN
  SELECT * INTO r FROM public.order_requests WHERE id=p_order_id FOR UPDATE;
  IF r.id IS NULL THEN RAISE EXCEPTION 'Order unavailable' USING ERRCODE='42501'; END IF;
  SELECT * INTO b FROM public.businesses WHERE id=r.business_id AND owner_id=auth.uid() FOR UPDATE;
  IF b.id IS NULL THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
  IF p_operation_id IS NOT NULL THEN
    SELECT result_status INTO r.status FROM public.order_operations
      WHERE operation_id=p_operation_id AND order_id=r.id;
    IF FOUND THEN RETURN r; END IF;
  END IF;
  IF r.status <> 'pending' THEN RAISE EXCEPTION 'Invalid current status' USING ERRCODE='23514'; END IF;
  IF p_expected_version IS NULL OR p_expected_version<>r.version
    THEN RAISE EXCEPTION 'Version conflict' USING ERRCODE='40001'; END IF;
  IF p_quote_version IS NULL OR p_quote_version<>r.current_quote_version
    OR r.agreed_quote_version<>r.current_quote_version
    THEN RAISE EXCEPTION 'Quote changed' USING ERRCODE='40001'; END IF;
  IF p_due_at IS NULL OR p_due_at <= now()
    THEN RAISE EXCEPTION 'Due time must be in the future' USING ERRCODE='22023'; END IF;
  service_date := (r.snapshot->>'service_date')::date;
  SELECT * INTO s FROM public.availability_settings WHERE business_id=b.id;
  IF s.business_id IS NULL OR service_date < (now() AT TIME ZONE s.timezone)::date
    OR (p_due_at AT TIME ZONE s.timezone)::date <> service_date
    OR EXISTS (SELECT 1 FROM public.blocked_dates d
               WHERE d.business_id=b.id AND d.service_date=service_date)
    OR public.capacity_used(b.id,service_date) >= s.daily_capacity
    THEN RAISE EXCEPTION 'Date unavailable' USING ERRCODE='23514'; END IF;
  month_start := date_trunc('month', now() AT TIME ZONE s.timezone)::date;
  SELECT * INTO usage_row FROM public.business_usage_months
    WHERE business_id=b.id AND month_start=confirm_order.month_start FOR UPDATE;
  IF usage_row.business_id IS NULL THEN
    INSERT INTO public.business_usage_months(business_id,month_start)
      VALUES(b.id,month_start) RETURNING * INTO usage_row;
  END IF;
  IF usage_row.confirmed_count >= usage_row.free_limit
    THEN RAISE EXCEPTION 'Free confirmation limit reached' USING ERRCODE='quota_reached'; END IF;
  UPDATE public.business_usage_months SET confirmed_count=confirmed_count+1
    WHERE business_id=b.id AND month_start=confirm_order.month_start;
  UPDATE public.order_requests
    SET status='confirmed', due_at=p_due_at, confirmed_at=now(), version=version+1
    WHERE id=r.id RETURNING * INTO r;
  INSERT INTO public.capacity_allocations(business_id,order_id,service_date,status)
    VALUES(b.id,r.id,service_date,'confirmed');
  INSERT INTO public.order_events(order_id,kind,actor_id) VALUES(r.id,'confirmed',auth.uid());
  IF p_operation_id IS NOT NULL THEN
    INSERT INTO public.order_operations(operation_id,order_id,command,result_status)
      VALUES(p_operation_id,r.id,'confirm','confirmed');
  END IF;
  RETURN r;
END $$;

CREATE OR REPLACE FUNCTION public.transition_order(
  p_order_id uuid,
  p_expected_version bigint,
  p_next_status text,
  p_operation_id uuid
) RETURNS public.order_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.order_requests; b public.businesses;
  actor_is_owner boolean; allowed boolean := false;
BEGIN
  SELECT * INTO r FROM public.order_requests WHERE id=p_order_id FOR UPDATE;
  IF r.id IS NULL THEN RAISE EXCEPTION 'Order unavailable' USING ERRCODE='42501'; END IF;
  IF p_operation_id IS NOT NULL THEN
    SELECT result_status INTO r.status FROM public.order_operations
      WHERE operation_id=p_operation_id AND order_id=r.id;
    IF FOUND THEN RETURN r; END IF;
  END IF;
  SELECT * INTO b FROM public.businesses
    WHERE id=r.business_id AND owner_id=auth.uid();
  actor_is_owner := b.id IS NOT NULL;
  IF p_expected_version IS NULL OR p_expected_version<>r.version
    THEN RAISE EXCEPTION 'Version conflict' USING ERRCODE='40001'; END IF;
  IF actor_is_owner THEN
    allowed := (r.status='pending' AND p_next_status='declined')
      OR (r.status='confirmed' AND p_next_status='baking')
      OR (r.status='baking' AND p_next_status='decorating')
      OR (r.status='decorating' AND p_next_status='ready')
      OR (r.status='ready' AND p_next_status='delivered');
  ELSE
    IF r.customer_id<>auth.uid() THEN
      RAISE EXCEPTION 'Access denied' USING ERRCODE='42501';
    END IF;
    allowed := r.status='pending' AND p_next_status='withdrawn';
  END IF;
  IF NOT allowed THEN RAISE EXCEPTION 'Invalid status transition' USING ERRCODE='23514'; END IF;
  UPDATE public.order_requests SET status=p_next_status, version=version+1
    WHERE id=r.id RETURNING * INTO r;
  IF p_next_status IN ('baking','decorating','ready','delivered','cancelled') THEN
    UPDATE public.capacity_allocations SET status=p_next_status
      WHERE order_id=r.id;
  END IF;
  INSERT INTO public.order_events(order_id,kind,actor_id)
    VALUES(r.id,'status_'||p_next_status,auth.uid());
  IF p_operation_id IS NOT NULL THEN
    INSERT INTO public.order_operations(operation_id,order_id,command,result_status)
      VALUES(p_operation_id,r.id,'transition',p_next_status);
  END IF;
  RETURN r;
END $$;

CREATE OR REPLACE FUNCTION public.request_order_cancellation(
  p_order_id uuid,
  p_expected_version bigint
) RETURNS public.order_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.order_requests;
BEGIN
  SELECT * INTO r FROM public.order_requests
    WHERE id=p_order_id AND customer_id=auth.uid() FOR UPDATE;
  IF r.id IS NULL THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
  IF p_expected_version IS NULL OR p_expected_version<>r.version
    THEN RAISE EXCEPTION 'Version conflict' USING ERRCODE='40001'; END IF;
  IF r.status NOT IN ('confirmed','baking')
    THEN RAISE EXCEPTION 'Cancellation unavailable' USING ERRCODE='23514'; END IF;
  UPDATE public.order_requests SET version=version+1 WHERE id=r.id RETURNING * INTO r;
  INSERT INTO public.order_events(order_id,kind,actor_id)
    VALUES(r.id,'cancellation_requested',auth.uid());
  RETURN r;
END $$;

REVOKE ALL ON FUNCTION public.revise_order_quote(uuid,integer,jsonb,text)
  FROM public, anon;
REVOKE ALL ON FUNCTION public.record_order_agreement(uuid,integer,text,uuid)
  FROM public, anon;
REVOKE ALL ON FUNCTION public.confirm_order(uuid,bigint,integer,timestamptz,uuid)
  FROM public, anon;
REVOKE ALL ON FUNCTION public.transition_order(uuid,bigint,text,uuid)
  FROM public, anon;
REVOKE ALL ON FUNCTION public.request_order_cancellation(uuid,bigint)
  FROM public, anon;
GRANT EXECUTE ON FUNCTION public.revise_order_quote(uuid,integer,jsonb,text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_order_agreement(uuid,integer,text,uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_order(uuid,bigint,integer,timestamptz,uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.transition_order(uuid,bigint,text,uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_order_cancellation(uuid,bigint)
  TO authenticated;

COMMIT;

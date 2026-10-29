BEGIN;

ALTER TABLE public.order_requests
  ALTER COLUMN source_draft_id DROP NOT NULL,
  ALTER COLUMN customer_id DROP NOT NULL,
  ALTER COLUMN submission_token DROP NOT NULL;
ALTER TABLE public.order_requests
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'app'
    CHECK (source IN ('app','manual'));

CREATE TABLE public.baker_contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  phone_normalized text NOT NULL CHECK (char_length(phone_normalized) BETWEEN 3 AND 40),
  display_name text NOT NULL CHECK (char_length(btrim(display_name)) BETWEEN 1 AND 100),
  notes text NOT NULL DEFAULT '' CHECK (char_length(notes) <= 2000),
  linked_customer_id uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, phone_normalized)
);
CREATE INDEX baker_contacts_search ON public.baker_contacts(business_id, phone_normalized, display_name);

CREATE TABLE public.order_private_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.order_requests(id) ON DELETE CASCADE,
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  body text NOT NULL CHECK (char_length(btrim(body)) BETWEEN 1 AND 2000),
  actor_id uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX order_private_notes_order ON public.order_private_notes(order_id, created_at);

CREATE TABLE public.order_advances (
  order_id uuid PRIMARY KEY REFERENCES public.order_requests(id) ON DELETE CASCADE,
  amount_paisa bigint NOT NULL CHECK (amount_paisa >= 0),
  recorded_by uuid NOT NULL REFERENCES auth.users(id),
  recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.order_cancellation_requests (
  order_id uuid PRIMARY KEY REFERENCES public.order_requests(id) ON DELETE CASCADE,
  reason text NOT NULL CHECK (char_length(btrim(reason)) BETWEEN 1 AND 1000),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','accepted','rejected','resolved')),
  requested_by uuid NOT NULL REFERENCES auth.users(id),
  resolved_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

ALTER TABLE public.baker_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_private_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_advances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_cancellation_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.baker_contacts, public.order_private_notes,
  public.order_advances, public.order_cancellation_requests
  FROM public, anon, authenticated;
GRANT SELECT ON public.baker_contacts, public.order_private_notes,
  public.order_advances, public.order_cancellation_requests TO authenticated;

CREATE POLICY baker_contacts_owner ON public.baker_contacts
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.businesses b WHERE b.id=business_id AND b.owner_id=auth.uid())
);
CREATE POLICY order_private_notes_owner ON public.order_private_notes
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.businesses b WHERE b.id=business_id AND b.owner_id=auth.uid())
);
CREATE POLICY order_advances_participant ON public.order_advances
FOR SELECT TO authenticated USING (public.request_participant(order_id));
CREATE POLICY order_cancellations_participant ON public.order_cancellation_requests
FOR SELECT TO authenticated USING (public.request_participant(order_id));

CREATE OR REPLACE FUNCTION public.baker_today(
  p_business_id uuid,
  p_date date DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE b public.businesses; s public.availability_settings; day date;
  due jsonb; pending_count integer;
BEGIN
  SELECT * INTO b FROM public.businesses
    WHERE id=p_business_id AND owner_id=auth.uid();
  IF b.id IS NULL THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
  SELECT * INTO s FROM public.availability_settings WHERE business_id=b.id;
  IF s.business_id IS NULL THEN
    RETURN jsonb_build_object('configured',false,'orders','[]'::jsonb,'pending',0);
  END IF;
  day := coalesce(p_date,(now() AT TIME ZONE s.timezone)::date);
  SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.due_at NULLS LAST, r.id),'[]'::jsonb)
    INTO due
    FROM public.order_requests r
    WHERE r.business_id=b.id AND (r.snapshot->>'service_date')::date=day;
  SELECT count(*)::integer INTO pending_count FROM public.order_requests r
    WHERE r.business_id=b.id AND r.status='pending';
  RETURN jsonb_build_object(
    'configured',true,'timezone',s.timezone,'date',day,
    'orders',due,'pending',pending_count
  );
END $$;

CREATE OR REPLACE FUNCTION public.upsert_baker_contact(
  p_business_id uuid,
  p_phone text,
  p_name text,
  p_notes text DEFAULT ''
) RETURNS public.baker_contacts
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.baker_contacts; normalized text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.businesses WHERE id=p_business_id AND owner_id=auth.uid())
    THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
  normalized := regexp_replace(coalesce(p_phone,''), '[^0-9+]', '', 'g');
  IF char_length(normalized) NOT BETWEEN 3 AND 40
    OR p_name IS NULL OR char_length(btrim(p_name)) NOT BETWEEN 1 AND 100
    OR char_length(coalesce(p_notes,''))>2000
    THEN RAISE EXCEPTION 'Invalid contact' USING ERRCODE='22023'; END IF;
  INSERT INTO public.baker_contacts(business_id,phone_normalized,display_name,notes)
    VALUES(p_business_id,normalized,btrim(p_name),coalesce(p_notes,''))
  ON CONFLICT (business_id,phone_normalized) DO UPDATE SET
    display_name=excluded.display_name, notes=excluded.notes, updated_at=now()
  RETURNING * INTO c;
  RETURN c;
END $$;

CREATE OR REPLACE FUNCTION public.add_manual_order(
  p_business_id uuid,
  p_name text,
  p_phone text,
  p_snapshot jsonb,
  p_total_paisa bigint,
  p_service_date date,
  p_operation_id uuid,
  p_acknowledge_lead_time boolean DEFAULT false
) RETURNS public.order_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE b public.businesses; s public.availability_settings; r public.order_requests;
  month_start date; u public.business_usage_months;
BEGIN
  SELECT * INTO b FROM public.businesses WHERE id=p_business_id AND owner_id=auth.uid() FOR UPDATE;
  IF b.id IS NULL THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
  IF p_operation_id IS NOT NULL AND EXISTS(
    SELECT 1 FROM public.order_operations WHERE operation_id=p_operation_id
  ) THEN SELECT r.* INTO r FROM public.order_requests r
    JOIN public.order_operations o ON o.order_id=r.id
    WHERE o.operation_id=p_operation_id; RETURN r; END IF;
  SELECT * INTO s FROM public.availability_settings WHERE business_id=b.id;
  IF s.business_id IS NULL OR p_service_date IS NULL
    OR (p_service_date < (now() AT TIME ZONE s.timezone)::date + s.lead_days
        AND NOT p_acknowledge_lead_time)
    OR EXISTS (SELECT 1 FROM public.blocked_dates d WHERE d.business_id=b.id AND d.service_date=p_service_date)
    OR public.capacity_used(b.id,p_service_date) >= s.daily_capacity
    THEN RAISE EXCEPTION 'Date unavailable or lead time acknowledgement required' USING ERRCODE='23514'; END IF;
  IF p_total_paisa IS NULL OR p_total_paisa<=0
    OR p_name IS NULL OR char_length(btrim(p_name)) NOT BETWEEN 1 AND 100
    THEN RAISE EXCEPTION 'Invalid manual order' USING ERRCODE='22023'; END IF;
  month_start := date_trunc('month',now() AT TIME ZONE s.timezone)::date;
  SELECT * INTO u FROM public.business_usage_months
    WHERE business_id=b.id AND month_start=add_manual_order.month_start FOR UPDATE;
  IF u.business_id IS NULL THEN
    INSERT INTO public.business_usage_months(business_id,month_start)
      VALUES(b.id,month_start) RETURNING * INTO u;
  END IF;
  IF u.confirmed_count>=u.free_limit
    THEN RAISE EXCEPTION 'Free confirmation limit reached' USING ERRCODE='quota_reached'; END IF;
  UPDATE public.business_usage_months SET confirmed_count=confirmed_count+1
    WHERE business_id=b.id AND month_start=add_manual_order.month_start;
  INSERT INTO public.order_requests(
    source,submission_token,customer_id,business_id,status,snapshot,
    current_quote_version,agreed_quote_version,agreement_basis,
    due_at,confirmed_at
  ) VALUES(
    'manual',p_operation_id,NULL,b.id,'confirmed',
    p_snapshot || jsonb_build_object(
      'contact_name',btrim(p_name),'phone',coalesce(p_phone,''),
      'service_date',p_service_date,'estimate',
        jsonb_build_object('subtotal_paisa',p_total_paisa,
          'delivery_paisa',0,'total_paisa',p_total_paisa,'lines','[]'::jsonb)
    ),1,1,'Manual order acknowledgement',NULL,now()
  ) RETURNING * INTO r;
  INSERT INTO public.capacity_allocations(business_id,order_id,service_date,status)
    VALUES(b.id,r.id,p_service_date,'confirmed');
  INSERT INTO public.order_events(order_id,kind,actor_id)
    VALUES(r.id,'manual_created',auth.uid());
  IF p_operation_id IS NOT NULL THEN
    INSERT INTO public.order_operations(operation_id,order_id,command,result_status)
      VALUES(p_operation_id,r.id,'manual_create','confirmed');
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
    OR r.status NOT IN ('confirmed','baking')
    THEN RAISE EXCEPTION 'Cancellation unavailable' USING ERRCODE='23514'; END IF;
  INSERT INTO public.order_cancellation_requests(order_id,reason,requested_by)
    VALUES(r.id,'Customer requested cancellation',auth.uid())
    ON CONFLICT (order_id) DO UPDATE SET status='open',reason=excluded.reason,
      requested_by=excluded.requested_by,created_at=now(),resolved_by=NULL,resolved_at=NULL;
  UPDATE public.order_requests SET version=version+1 WHERE id=r.id RETURNING * INTO r;
  INSERT INTO public.order_events(order_id,kind,actor_id)
    VALUES(r.id,'cancellation_requested',auth.uid());
  RETURN r;
END $$;

CREATE OR REPLACE FUNCTION public.add_order_private_note(
  p_order_id uuid,
  p_body text
) RETURNS public.order_private_notes
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE n public.order_private_notes; r public.order_requests;
BEGIN
  SELECT * INTO r FROM public.order_requests WHERE id=p_order_id;
  IF r.id IS NULL OR NOT EXISTS(
    SELECT 1 FROM public.businesses WHERE id=r.business_id AND owner_id=auth.uid()
  ) THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
  IF p_body IS NULL OR char_length(btrim(p_body)) NOT BETWEEN 1 AND 2000
    THEN RAISE EXCEPTION 'Invalid note' USING ERRCODE='22023'; END IF;
  INSERT INTO public.order_private_notes(order_id,business_id,body,actor_id)
    VALUES(r.id,r.business_id,btrim(p_body),auth.uid()) RETURNING * INTO n;
  RETURN n;
END $$;

CREATE OR REPLACE FUNCTION public.record_order_advance(
  p_order_id uuid,
  p_amount_paisa bigint
) RETURNS public.order_advances
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE a public.order_advances; r public.order_requests; total bigint;
BEGIN
  SELECT * INTO r FROM public.order_requests WHERE id=p_order_id
    AND EXISTS (SELECT 1 FROM public.businesses b WHERE b.id=business_id AND b.owner_id=auth.uid())
    FOR UPDATE;
  IF r.id IS NULL THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
  total := (r.snapshot->'estimate'->>'total_paisa')::bigint;
  IF p_amount_paisa IS NULL OR p_amount_paisa<0 OR p_amount_paisa>total
    THEN RAISE EXCEPTION 'Advance cannot exceed final price' USING ERRCODE='22023'; END IF;
  INSERT INTO public.order_advances(order_id,amount_paisa,recorded_by)
    VALUES(r.id,p_amount_paisa,auth.uid())
  ON CONFLICT(order_id) DO UPDATE SET amount_paisa=excluded.amount_paisa,
    recorded_by=excluded.recorded_by, recorded_at=now()
  RETURNING * INTO a;
  RETURN a;
END $$;

CREATE OR REPLACE FUNCTION public.reschedule_order(
  p_order_id uuid,
  p_expected_version bigint,
  p_service_date date
) RETURNS public.order_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.order_requests; b public.businesses; s public.availability_settings;
BEGIN
  SELECT * INTO r FROM public.order_requests WHERE id=p_order_id FOR UPDATE;
  SELECT * INTO b FROM public.businesses WHERE id=r.business_id AND owner_id=auth.uid() FOR UPDATE;
  IF r.id IS NULL OR b.id IS NULL THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
  SELECT * INTO s FROM public.availability_settings WHERE business_id=b.id;
  IF r.status NOT IN ('confirmed','baking','decorating','ready')
    OR p_expected_version<>r.version OR p_service_date IS NULL
    OR p_service_date < (now() AT TIME ZONE s.timezone)::date + s.lead_days
    OR EXISTS (SELECT 1 FROM public.blocked_dates d WHERE d.business_id=b.id AND d.service_date=p_service_date)
    OR public.capacity_used(b.id,p_service_date) >= s.daily_capacity
    THEN RAISE EXCEPTION 'Reschedule rejected' USING ERRCODE='23514'; END IF;
  UPDATE public.order_requests SET snapshot=jsonb_set(snapshot,'{service_date}',to_jsonb(p_service_date::text)),
    version=version+1 WHERE id=r.id RETURNING * INTO r;
  UPDATE public.capacity_allocations SET service_date=p_service_date WHERE order_id=r.id;
  INSERT INTO public.order_events(order_id,kind,actor_id) VALUES(r.id,'rescheduled',auth.uid());
  RETURN r;
END $$;

CREATE OR REPLACE FUNCTION public.resolve_order_cancellation(
  p_order_id uuid,
  p_expected_version bigint,
  p_accept boolean
) RETURNS public.order_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.order_requests; c public.order_cancellation_requests;
BEGIN
  SELECT * INTO r FROM public.order_requests WHERE id=p_order_id
    AND EXISTS (SELECT 1 FROM public.businesses b WHERE b.id=business_id AND b.owner_id=auth.uid())
    FOR UPDATE;
  SELECT * INTO c FROM public.order_cancellation_requests WHERE order_id=p_order_id AND status='open' FOR UPDATE;
  IF r.id IS NULL OR c.order_id IS NULL OR p_expected_version<>r.version
    THEN RAISE EXCEPTION 'Cancellation decision is stale' USING ERRCODE='40001'; END IF;
  UPDATE public.order_cancellation_requests SET status=CASE WHEN p_accept THEN 'accepted' ELSE 'rejected' END,
    resolved_by=auth.uid(),resolved_at=now() WHERE order_id=r.id;
  IF p_accept THEN
    UPDATE public.order_requests SET status='cancelled',version=version+1 WHERE id=r.id RETURNING * INTO r;
    UPDATE public.capacity_allocations SET status='cancelled' WHERE order_id=r.id;
  ELSE
    UPDATE public.order_requests SET version=version+1 WHERE id=r.id RETURNING * INTO r;
  END IF;
  INSERT INTO public.order_events(order_id,kind,actor_id)
    VALUES(r.id,CASE WHEN p_accept THEN 'cancelled' ELSE 'cancellation_rejected' END,auth.uid());
  RETURN r;
END $$;

REVOKE ALL ON FUNCTION public.baker_today(uuid,date),
  public.upsert_baker_contact(uuid,text,text,text),
  public.add_manual_order(uuid,text,text,jsonb,bigint,date,uuid,boolean),
  public.add_order_private_note(uuid,text),
  public.record_order_advance(uuid,bigint),
  public.reschedule_order(uuid,bigint,date),
  public.resolve_order_cancellation(uuid,bigint,boolean),
  public.request_order_cancellation(uuid,bigint)
  FROM public, anon;
GRANT EXECUTE ON FUNCTION public.baker_today(uuid,date),
  public.upsert_baker_contact(uuid,text,text,text),
  public.add_manual_order(uuid,text,text,jsonb,bigint,date,uuid,boolean),
  public.add_order_private_note(uuid,text),
  public.record_order_advance(uuid,bigint),
  public.reschedule_order(uuid,bigint,date),
  public.resolve_order_cancellation(uuid,bigint,boolean),
  public.request_order_cancellation(uuid,bigint)
  TO authenticated;

COMMIT;

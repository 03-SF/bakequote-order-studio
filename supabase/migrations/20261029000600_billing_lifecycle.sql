BEGIN;

CREATE TABLE public.store_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL CHECK(provider IN ('apple','google')),
  environment text NOT NULL CHECK(environment IN ('sandbox','production')),
  transaction_id text NOT NULL,
  product_id text NOT NULL,
  account_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  verified_payload_digest text NOT NULL,
  state text NOT NULL CHECK(state IN ('verified','expired','revoked','grace')),
  purchased_at timestamptz,
  expires_at timestamptz,
  verified_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(provider, transaction_id)
);

CREATE TABLE public.account_entitlements (
  account_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id text NOT NULL,
  provider text NOT NULL CHECK(provider IN ('apple','google')),
  environment text NOT NULL CHECK(environment IN ('sandbox','production')),
  state text NOT NULL CHECK(state IN ('active','grace','expired','revoked')),
  source_transaction_id uuid NOT NULL REFERENCES public.store_transactions(id),
  expires_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(account_id, product_id)
);

CREATE TABLE public.deletion_requests (
  account_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'requested'
    CHECK(status IN ('requested','blocked_active_orders','processing','completed','failed')),
  requested_at timestamptz NOT NULL DEFAULT now(),
  last_error text,
  completed_at timestamptz
);
CREATE TABLE public.deletion_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK(kind IN ('media','account')),
  status text NOT NULL DEFAULT 'pending'
    CHECK(status IN ('pending','processing','completed','failed')),
  attempts integer NOT NULL DEFAULT 0 CHECK(attempts >= 0),
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);
CREATE UNIQUE INDEX one_open_deletion_job
  ON public.deletion_jobs(account_id,kind)
  WHERE status IN ('pending','processing');

ALTER TABLE public.store_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deletion_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deletion_jobs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.store_transactions,public.account_entitlements,
  public.deletion_requests,public.deletion_jobs FROM public,anon,authenticated;
GRANT SELECT ON public.account_entitlements,public.deletion_requests TO authenticated;

CREATE POLICY own_entitlements ON public.account_entitlements
FOR SELECT TO authenticated USING(account_id=auth.uid());
CREATE POLICY own_deletion_request ON public.deletion_requests
FOR SELECT TO authenticated USING(account_id=auth.uid());

CREATE FUNCTION public.current_entitlement(p_product_id text)
RETURNS public.account_entitlements
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT e FROM public.account_entitlements e
  WHERE e.account_id=auth.uid() AND e.product_id=p_product_id
    AND e.state IN ('active','grace')
    AND (e.expires_at IS NULL OR e.expires_at > now())
$$;

CREATE FUNCTION public.account_export_snapshot()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid := auth.uid(); snapshot jsonb;
BEGIN
  IF actor IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  SELECT jsonb_build_object(
    'format','bakequote-account-export-v1',
    'created_at',now(),
    'account_id',actor,
    'profile',(SELECT to_jsonb(p) FROM public.profiles p WHERE p.id=actor),
    'customer_profile',(SELECT to_jsonb(p) FROM public.customer_profiles p WHERE p.id=actor),
    'baker_profile',(SELECT to_jsonb(p) FROM public.baker_profiles p WHERE p.id=actor),
    'business',(SELECT to_jsonb(b) FROM public.businesses b WHERE b.owner_id=actor),
    'orders',(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.created_at),'[]'::jsonb)
              FROM public.order_requests r
              LEFT JOIN public.businesses b ON b.id=r.business_id
              WHERE r.customer_id=actor OR b.owner_id=actor)
  ) INTO snapshot;
  RETURN snapshot;
END $$;

CREATE FUNCTION public.request_account_deletion(p_confirmation text)
RETURNS public.deletion_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid := auth.uid(); result public.deletion_requests;
  active_count integer;
BEGIN
  IF actor IS NULL OR p_confirmation <> 'DELETE'
    THEN RAISE EXCEPTION 'Type DELETE to confirm account deletion' USING ERRCODE='22023'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM auth.users
    WHERE id=actor AND last_sign_in_at > now() - interval '15 minutes'
  ) THEN
    RAISE EXCEPTION 'Reauthenticate before requesting deletion' USING ERRCODE='42501';
  END IF;
  SELECT count(*) INTO active_count
  FROM public.order_requests r
  LEFT JOIN public.businesses b ON b.id=r.business_id
  WHERE (r.customer_id=actor OR b.owner_id=actor)
    AND r.status IN ('pending','confirmed','baking','decorating','ready');
  INSERT INTO public.deletion_requests(account_id,status)
    VALUES(actor,CASE WHEN active_count>0 THEN 'blocked_active_orders' ELSE 'requested' END)
    ON CONFLICT(account_id) DO UPDATE SET
      status=CASE WHEN active_count>0 THEN 'blocked_active_orders' ELSE 'requested' END,
      requested_at=now(),last_error=NULL
    RETURNING * INTO result;
  IF active_count=0 THEN
    INSERT INTO public.deletion_jobs(account_id,kind)
      VALUES(actor,'media'),(actor,'account')
      ON CONFLICT DO NOTHING;
  END IF;
  RETURN result;
END $$;

REVOKE ALL ON FUNCTION public.current_entitlement(text),
  public.account_export_snapshot(),public.request_account_deletion(text)
  FROM public,anon;
GRANT EXECUTE ON FUNCTION public.current_entitlement(text),
  public.account_export_snapshot(),public.request_account_deletion(text)
  TO authenticated;

-- Store callbacks must be performed by a trusted server integration after
-- provider verification; clients cannot grant or edit entitlements.
CREATE FUNCTION public.apply_verified_store_event(
  p_provider text,p_environment text,p_transaction_id text,
  p_product_id text,p_account_id uuid,p_payload_digest text,
  p_state text,p_purchased_at timestamptz,p_expires_at timestamptz
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE transaction_row public.store_transactions;
BEGIN
  IF p_provider NOT IN ('apple','google')
    OR p_environment NOT IN ('sandbox','production')
    OR p_state NOT IN ('verified','expired','revoked','grace')
    OR p_transaction_id IS NULL OR p_product_id IS NULL
    OR p_payload_digest IS NULL THEN
    RAISE EXCEPTION 'Invalid verified store event' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.store_transactions(
    provider,environment,transaction_id,product_id,account_id,
    verified_payload_digest,state,purchased_at,expires_at)
    VALUES(p_provider,p_environment,p_transaction_id,p_product_id,p_account_id,
      p_payload_digest,p_state,p_purchased_at,p_expires_at)
    ON CONFLICT(provider,transaction_id) DO UPDATE SET
      state=excluded.state,expires_at=excluded.expires_at,
      verified_at=now()
    RETURNING * INTO transaction_row;
  INSERT INTO public.account_entitlements(
    account_id,product_id,provider,environment,state,source_transaction_id,expires_at)
    VALUES(p_account_id,p_product_id,p_provider,p_environment,
      CASE WHEN p_state='verified' THEN 'active' ELSE p_state END,
      transaction_row.id,p_expires_at)
    ON CONFLICT(account_id,product_id) DO UPDATE SET
      state=excluded.state,source_transaction_id=excluded.source_transaction_id,
      expires_at=excluded.expires_at,updated_at=now();
END $$;
REVOKE ALL ON FUNCTION public.apply_verified_store_event(
  text,text,text,text,uuid,text,text,timestamptz,timestamptz)
  FROM public,anon,authenticated;

COMMIT;

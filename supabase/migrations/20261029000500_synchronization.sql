BEGIN;

ALTER TABLE public.order_events
  ADD COLUMN IF NOT EXISTS feed_sequence bigint GENERATED ALWAYS AS IDENTITY;
CREATE UNIQUE INDEX IF NOT EXISTS order_events_feed_sequence
  ON public.order_events(feed_sequence);

CREATE OR REPLACE FUNCTION public.sync_order_changes(
  p_after_sequence bigint DEFAULT 0,
  p_limit integer DEFAULT 100
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  start_sequence bigint := greatest(coalesce(p_after_sequence, 0), 0);
  page_limit integer := least(greatest(coalesce(p_limit, 1), 1), 100);
  next_sequence bigint;
  changes jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;

  SELECT coalesce(max(e.feed_sequence), start_sequence)
    INTO next_sequence
  FROM public.order_events e
  WHERE e.feed_sequence > start_sequence
    AND public.request_participant(e.order_id);

  SELECT coalesce(jsonb_agg(to_jsonb(row) ORDER BY row.feed_sequence), '[]'::jsonb)
    INTO changes
  FROM (
    SELECT e.feed_sequence, e.id AS event_id, e.order_id, e.kind,
           e.actor_id, e.created_at, r.status, r.version,
           r.current_quote_version, r.due_at
    FROM public.order_events e
    JOIN public.order_requests r ON r.id=e.order_id
    WHERE e.feed_sequence > start_sequence
      AND public.request_participant(e.order_id)
    ORDER BY e.feed_sequence
    LIMIT page_limit
  ) row;

  IF jsonb_array_length(changes) > 0 THEN
    next_sequence := (changes -> -1 ->> 'feed_sequence')::bigint;
  END IF;
  RETURN jsonb_build_object(
    'cursor', next_sequence,
    'changes', changes
  );
END $$;

REVOKE ALL ON FUNCTION public.sync_order_changes(bigint,integer) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.sync_order_changes(bigint,integer) TO authenticated;

COMMIT;

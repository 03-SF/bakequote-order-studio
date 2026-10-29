BEGIN;

CREATE TABLE public.order_conversations (
  order_id uuid PRIMARY KEY REFERENCES public.order_requests(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.order_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.order_requests(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES auth.users(id),
  client_message_id uuid NOT NULL,
  body text NOT NULL CHECK (char_length(btrim(body)) BETWEEN 1 AND 4000),
  attachment_paths text[] NOT NULL DEFAULT '{}',
  sequence bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(order_id, client_message_id)
);
CREATE INDEX order_messages_page ON public.order_messages(order_id, sequence);

CREATE TABLE public.order_message_cursors (
  order_id uuid NOT NULL REFERENCES public.order_conversations(order_id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  last_sequence bigint NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(order_id,user_id)
);

CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  order_id uuid REFERENCES public.order_requests(id) ON DELETE CASCADE,
  message_id uuid REFERENCES public.order_messages(id) ON DELETE CASCADE,
  kind text NOT NULL,
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 500),
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notifications_recipient ON public.notifications(recipient_id, created_at DESC);
CREATE UNIQUE INDEX one_message_notification
  ON public.notifications(message_id) WHERE message_id IS NOT NULL;

CREATE TABLE public.order_reviews (
  order_id uuid PRIMARY KEY REFERENCES public.order_requests(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES auth.users(id),
  rating integer NOT NULL CHECK(rating BETWEEN 1 AND 5),
  body text NOT NULL DEFAULT '' CHECK(char_length(body)<=2000),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.order_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.order_requests(id) ON DELETE CASCADE,
  reporter_id uuid NOT NULL REFERENCES auth.users(id),
  category text NOT NULL CHECK(category IN ('spam','harassment','safety','other')),
  body text NOT NULL CHECK(char_length(btrim(body)) BETWEEN 1 AND 2000),
  status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','reviewing','resolved')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.user_blocks (
  blocker_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(blocker_id,blocked_id),
  CHECK(blocker_id<>blocked_id)
);

ALTER TABLE public.order_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_message_cursors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.order_conversations,public.order_messages,
  public.order_message_cursors,public.notifications,public.order_reviews,
  public.order_reports,public.user_blocks FROM public,anon,authenticated;
GRANT SELECT ON public.order_conversations,public.order_messages,
  public.order_message_cursors,public.notifications,public.order_reviews,
  public.order_reports,public.user_blocks TO authenticated;

CREATE FUNCTION public.communication_participant(p_order_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.order_requests r
    JOIN public.businesses b ON b.id=r.business_id
    WHERE r.id=p_order_id AND r.source='app'
      AND (r.customer_id=auth.uid() OR b.owner_id=auth.uid())
      AND NOT EXISTS (
        SELECT 1 FROM public.user_blocks ub
        WHERE (ub.blocker_id=auth.uid() AND ub.blocked_id=CASE
          WHEN r.customer_id=auth.uid() THEN b.owner_id ELSE r.customer_id END)
           OR (ub.blocked_id=auth.uid() AND ub.blocker_id=CASE
          WHEN r.customer_id=auth.uid() THEN b.owner_id ELSE r.customer_id END)
      )
  )
$$;
CREATE POLICY conversations_participant ON public.order_conversations
FOR SELECT TO authenticated USING(public.communication_participant(order_id));
CREATE POLICY messages_participant ON public.order_messages
FOR SELECT TO authenticated USING(public.communication_participant(order_id));
CREATE POLICY cursors_self ON public.order_message_cursors
FOR SELECT TO authenticated USING(user_id=auth.uid());
CREATE POLICY notifications_self ON public.notifications
FOR SELECT TO authenticated USING(recipient_id=auth.uid());
CREATE POLICY reviews_participant ON public.order_reviews
FOR SELECT TO authenticated USING(public.request_participant(order_id));
CREATE POLICY reports_reporter ON public.order_reports
FOR SELECT TO authenticated USING(reporter_id=auth.uid());
CREATE POLICY blocks_self ON public.user_blocks
FOR SELECT TO authenticated USING(blocker_id=auth.uid());

CREATE OR REPLACE FUNCTION public.send_order_message(
  p_order_id uuid,
  p_client_message_id uuid,
  p_body text,
  p_attachment_paths text[] DEFAULT '{}'
) RETURNS public.order_messages
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.order_requests; m public.order_messages; recipient uuid;
BEGIN
  SELECT * INTO r FROM public.order_requests WHERE id=p_order_id
    AND public.communication_participant(id) FOR UPDATE;
  IF r.id IS NULL THEN RAISE EXCEPTION 'Conversation unavailable' USING ERRCODE='42501'; END IF;
  IF EXISTS(SELECT 1 FROM public.user_blocks WHERE blocker_id=auth.uid()
    AND blocked_id=CASE WHEN r.customer_id=auth.uid()
      THEN (SELECT owner_id FROM public.businesses WHERE id=r.business_id)
      ELSE r.customer_id END)
    OR EXISTS(SELECT 1 FROM public.user_blocks WHERE blocked_id=auth.uid()
      AND blocker_id=CASE WHEN r.customer_id=auth.uid()
        THEN (SELECT owner_id FROM public.businesses WHERE id=r.business_id)
        ELSE r.customer_id END)
    THEN RAISE EXCEPTION 'Messaging is blocked' USING ERRCODE='42501'; END IF;
  IF r.status IN ('declined','withdrawn','cancelled') THEN
    RAISE EXCEPTION 'Messaging window is closed' USING ERRCODE='23514'; END IF;
  IF p_client_message_id IS NULL OR p_body IS NULL
    OR char_length(btrim(p_body)) NOT BETWEEN 1 AND 4000
    OR coalesce(array_length(p_attachment_paths,1),0)>3
    OR EXISTS (
      SELECT 1
      FROM unnest(coalesce(p_attachment_paths,'{}')) AS requested(path)
      WHERE requested.path IS NULL
        OR requested.path NOT LIKE r.id::text || '/%'
        OR NOT EXISTS (
          SELECT 1 FROM storage.objects object
          WHERE object.bucket_id='conversation-attachments'
            AND object.name=requested.path
        )
    )
    THEN RAISE EXCEPTION 'Invalid message' USING ERRCODE='22023'; END IF;
  INSERT INTO public.order_conversations(order_id) VALUES(r.id) ON CONFLICT DO NOTHING;
  INSERT INTO public.order_messages(order_id,sender_id,client_message_id,body,attachment_paths)
    VALUES(r.id,auth.uid(),p_client_message_id,btrim(p_body),coalesce(p_attachment_paths,'{}'))
    ON CONFLICT(order_id,client_message_id) DO UPDATE SET body=order_messages.body
    RETURNING * INTO m;
  IF m.sender_id <> auth.uid() OR m.body <> btrim(p_body) THEN
    RAISE EXCEPTION 'Message retry does not match the original' USING ERRCODE='23505';
  END IF;
  recipient := CASE WHEN r.customer_id=auth.uid()
    THEN (SELECT owner_id FROM public.businesses WHERE id=r.business_id)
    ELSE r.customer_id END;
  INSERT INTO public.notifications(recipient_id,order_id,message_id,kind,body)
    VALUES(recipient,r.id,m.id,'message','New order message')
    ON CONFLICT DO NOTHING;
  RETURN m;
END $$;

CREATE OR REPLACE FUNCTION public.mark_order_messages_read(
  p_order_id uuid,
  p_sequence bigint
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF NOT public.communication_participant(p_order_id)
    THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
  INSERT INTO public.order_message_cursors(order_id,user_id,last_sequence)
    VALUES(p_order_id,auth.uid(),greatest(0,p_sequence))
  ON CONFLICT(order_id,user_id) DO UPDATE SET
    last_sequence=greatest(order_message_cursors.last_sequence,excluded.last_sequence),
    updated_at=now();
END $$;

CREATE OR REPLACE FUNCTION public.submit_order_review(
  p_order_id uuid,
  p_rating integer,
  p_body text DEFAULT ''
) RETURNS public.order_reviews
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.order_requests; v public.order_reviews;
BEGIN
  SELECT * INTO r FROM public.order_requests WHERE id=p_order_id AND customer_id=auth.uid();
  IF r.id IS NULL OR r.source<>'app' OR r.status<>'delivered'
    THEN RAISE EXCEPTION 'Review unavailable' USING ERRCODE='23514'; END IF;
  INSERT INTO public.order_reviews(order_id,customer_id,rating,body)
    VALUES(r.id,auth.uid(),p_rating,coalesce(p_body,''))
    ON CONFLICT(order_id) DO NOTHING RETURNING * INTO v;
  IF v.order_id IS NULL THEN RAISE EXCEPTION 'Review already submitted' USING ERRCODE='23514'; END IF;
  RETURN v;
END $$;

CREATE OR REPLACE FUNCTION public.report_order(
  p_order_id uuid,
  p_category text,
  p_body text
) RETURNS public.order_reports
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v public.order_reports;
BEGIN
  IF NOT public.communication_participant(p_order_id)
    THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
  INSERT INTO public.order_reports(order_id,reporter_id,category,body)
    VALUES(p_order_id,auth.uid(),p_category,btrim(p_body)) RETURNING * INTO v;
  RETURN v;
END $$;

CREATE OR REPLACE FUNCTION public.block_order_participant(p_order_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.order_requests; other_id uuid;
BEGIN
  SELECT * INTO r FROM public.order_requests WHERE id=p_order_id
    AND public.communication_participant(id);
  IF r.id IS NULL THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
  other_id := CASE WHEN r.customer_id=auth.uid()
    THEN (SELECT owner_id FROM public.businesses WHERE id=r.business_id)
    ELSE r.customer_id END;
  IF other_id IS NULL THEN RAISE EXCEPTION 'Manual orders have no conversation' USING ERRCODE='23514'; END IF;
  INSERT INTO public.user_blocks(blocker_id,blocked_id) VALUES(auth.uid(),other_id)
    ON CONFLICT DO NOTHING;
END $$;

REVOKE ALL ON FUNCTION public.send_order_message(uuid,uuid,text,text[]) FROM public,anon;
REVOKE ALL ON FUNCTION public.mark_order_messages_read(uuid,bigint) FROM public,anon;
REVOKE ALL ON FUNCTION public.submit_order_review(uuid,integer,text) FROM public,anon;
REVOKE ALL ON FUNCTION public.report_order(uuid,text,text) FROM public,anon;
REVOKE ALL ON FUNCTION public.block_order_participant(uuid) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.send_order_message(uuid,uuid,text,text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_order_messages_read(uuid,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_order_review(uuid,integer,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.report_order(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.block_order_participant(uuid) TO authenticated;

-- Conversation media remains private and membership-gated. Objects must use
-- generated order-scoped names; no client metadata listing is granted.
DROP POLICY IF EXISTS future_buckets_closed ON storage.objects;
CREATE POLICY future_buckets_closed ON storage.objects AS RESTRICTIVE
FOR ALL TO anon,authenticated
USING(bucket_id NOT IN ('product-images','order-references'))
WITH CHECK(bucket_id NOT IN ('product-images','order-references'));
CREATE POLICY conversation_media_participant_read ON storage.objects
FOR SELECT TO authenticated USING (
  bucket_id='conversation-attachments'
  AND EXISTS (
    SELECT 1 FROM public.order_messages m
    WHERE m.order_id=(storage.foldername(name))[1]::uuid
      AND public.communication_participant(m.order_id)
      AND name=ANY(m.attachment_paths)
  )
);
CREATE POLICY conversation_media_participant_insert ON storage.objects
FOR INSERT TO authenticated WITH CHECK (
  bucket_id='conversation-attachments'
  AND name ~ '^[0-9a-f-]+/[0-9a-f-]+\.(jpg|png|webp)$'
  AND public.communication_participant((storage.foldername(name))[1]::uuid)
);

COMMIT;

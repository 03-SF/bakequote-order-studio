-- Authorized operator only. Read-only counts; does not expose customer data or
-- alter historical records. Review each affected order privately before repair.
SELECT
  count(*) AS allocated_orders,
  count(*) FILTER (WHERE r.due_at IS NULL OR s.timezone IS NULL
    OR r.snapshot->>'service_date' IS NULL) AS missing_information,
  count(*) FILTER (WHERE r.due_at IS NOT NULL AND s.timezone IS NOT NULL
    AND r.snapshot->>'service_date' IS NOT NULL
    AND to_char(r.due_at AT TIME ZONE s.timezone, 'YYYY-MM-DD')
        <> r.snapshot->>'service_date') AS due_date_mismatch,
  count(*) FILTER (WHERE r.snapshot->>'service_date' IS NOT NULL
    AND a.service_date::text <> r.snapshot->>'service_date') AS allocation_date_mismatch
FROM public.order_requests r
JOIN public.capacity_allocations a ON a.order_id = r.id
LEFT JOIN public.availability_settings s ON s.business_id = r.business_id;

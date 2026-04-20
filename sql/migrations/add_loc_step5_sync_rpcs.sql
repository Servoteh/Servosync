-- ============================================================================
-- LOKACIJE DELOVA — RPC-ji za Node worker (claim / mark_synced / mark_failed)
-- ============================================================================
-- Worker (workers/loc-sync-mssql) poziva ove funkcije preko PostgREST-a sa
-- service role JWT-om (ne anon i ne korisnik). Koristi `FOR UPDATE SKIP LOCKED`
-- da više radnika može raditi paralelno bez konflikta.
--
-- Napomena: koriste se LABELOVANI dollar-quotes ($fn_*$) umesto $$ zbog
-- Supabase SQL Editor parsera koji ponekad pogrešno identifikuje granice
-- kad u istom fajlu postoji više $$-blokova.
--
-- DOWN:
--   DROP FUNCTION IF EXISTS public.loc_claim_sync_events(text, int);
--   DROP FUNCTION IF EXISTS public.loc_mark_sync_synced(uuid);
--   DROP FUNCTION IF EXISTS public.loc_mark_sync_failed(uuid, text);
-- ============================================================================

-- ── Claim: marše N event-a kao IN_PROGRESS i vraća ih workeru ────────────
CREATE OR REPLACE FUNCTION public.loc_claim_sync_events(
  p_worker_id text,
  p_batch_size integer DEFAULT 10
)
RETURNS SETOF public.loc_sync_outbound_events
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn_claim$
DECLARE
  v_batch integer := GREATEST(1, LEAST(COALESCE(p_batch_size, 10), 100));
BEGIN
  IF p_worker_id IS NULL OR length(p_worker_id) = 0 THEN
    RAISE EXCEPTION 'worker_id is required';
  END IF;

  RETURN QUERY
  WITH candidate AS (
    SELECT id
      FROM public.loc_sync_outbound_events
     WHERE status IN ('PENDING', 'FAILED')
       AND (next_retry_at IS NULL OR next_retry_at <= now())
     ORDER BY created_at ASC
     LIMIT v_batch
     FOR UPDATE SKIP LOCKED
  ),
  claimed AS (
    UPDATE public.loc_sync_outbound_events e
       SET status           = 'IN_PROGRESS',
           locked_by_worker = p_worker_id,
           locked_at        = now(),
           attempts         = e.attempts + 1
      FROM candidate c
     WHERE e.id = c.id
     RETURNING e.*
  )
  SELECT * FROM claimed;
END;
$fn_claim$;

REVOKE ALL ON FUNCTION public.loc_claim_sync_events(text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.loc_claim_sync_events(text, integer) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.loc_claim_sync_events(text, integer) TO service_role;

COMMENT ON FUNCTION public.loc_claim_sync_events(text, integer) IS
  'Worker claim: atomski marse do p_batch_size event-a kao IN_PROGRESS i vraca ih. Koristi FOR UPDATE SKIP LOCKED.';

-- ── Success — event je primenjen u MSSQL-u ───────────────────────────────
CREATE OR REPLACE FUNCTION public.loc_mark_sync_synced(p_event_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn_synced$
DECLARE
  v_count integer;
BEGIN
  UPDATE public.loc_sync_outbound_events
     SET status        = 'SYNCED',
         synced_at     = now(),
         last_error    = NULL,
         next_retry_at = NULL
   WHERE id = p_event_id
     AND status = 'IN_PROGRESS';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count > 0;
END;
$fn_synced$;

REVOKE ALL ON FUNCTION public.loc_mark_sync_synced(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.loc_mark_sync_synced(uuid) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.loc_mark_sync_synced(uuid) TO service_role;

-- ── Failure — sa exponential backoff (2^attempts minuta, cap 6h) ─────────
CREATE OR REPLACE FUNCTION public.loc_mark_sync_failed(
  p_event_id uuid,
  p_error text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn_failed$
DECLARE
  v_attempts integer;
  v_delay_min integer;
  v_final boolean;
  v_count integer;
BEGIN
  /* Napomena: umesto `SELECT ... INTO v_attempts` koristimo skalarni
   * subquery sa dodelom da izbegnemo SQL Editor parsere koji pogrešno
   * prepoznaju SELECT INTO kao DDL (u tom slučaju Postgres pokušava da
   * tretira v_attempts kao novu tabelu, što baca 42P01). */
  v_attempts := (
    SELECT attempts
      FROM public.loc_sync_outbound_events
     WHERE id = p_event_id
     LIMIT 1
  );

  IF v_attempts IS NULL THEN
    RETURN FALSE;
  END IF;

  /* Exponential backoff: 2, 4, 8, 16, 32, 64, 128, ... min (cap 360 = 6h).
   * Posle 10 pokusaja ide u DEAD_LETTER (rucna inspekcija). */
  v_delay_min := LEAST(360, POWER(2, LEAST(v_attempts, 8))::int);
  v_final := v_attempts >= 10;

  UPDATE public.loc_sync_outbound_events
     SET status           = CASE WHEN v_final THEN 'DEAD_LETTER' ELSE 'FAILED' END,
         last_error       = LEFT(COALESCE(p_error, ''), 4000),
         next_retry_at    = CASE WHEN v_final THEN NULL ELSE now() + make_interval(mins => v_delay_min) END,
         locked_by_worker = NULL,
         locked_at        = NULL
   WHERE id = p_event_id;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count > 0;
END;
$fn_failed$;

REVOKE ALL ON FUNCTION public.loc_mark_sync_failed(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.loc_mark_sync_failed(uuid, text) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.loc_mark_sync_failed(uuid, text) TO service_role;

COMMENT ON FUNCTION public.loc_mark_sync_failed(uuid, text) IS
  'Worker mark failed: exponential backoff (2^attempts min, cap 6h). Posle 10 pokusaja -> DEAD_LETTER.';

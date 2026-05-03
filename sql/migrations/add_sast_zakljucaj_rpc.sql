-- ============================================================================
-- SASTANCI — atomski RPC za zakljucavanje sastanka (Sprint 2 — H3)
-- ============================================================================
-- Zamenjuje frontend multi-step tokove:
--   * src/services/sastanakArhiva.js::arhivirajSastanak
--   * src/services/sastanciDetalj.js::zakljucajSaSapisanikom
--
-- Napomena o stvarnoj šemi:
--   * snapshot_ucesnici  -> sastanak_arhiva.snapshot JSONB
--   * pdf_url/path       -> sastanak_arhiva.zapisnik_storage_path
--   * pdf_saved_at       -> sastanak_arhiva.zapisnik_generated_at
--   * created_by_email   -> sastanak_arhiva.arhivirao_email
--   * snapshot_at        -> sastanak_arhiva.arhivirano_at
-- ============================================================================

CREATE OR REPLACE FUNCTION public.sast_zakljucaj_sastanak(
  p_sastanak_id      UUID,
  p_pdf_url          TEXT DEFAULT NULL,
  p_pdf_storage_path TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email      TEXT := lower(COALESCE(auth.jwt() ->> 'email', ''));
  v_status     TEXT;
  v_now        TIMESTAMPTZ := now();
  v_pdf_path   TEXT := COALESCE(NULLIF(p_pdf_storage_path, ''), NULLIF(p_pdf_url, ''));
  v_authorized BOOLEAN;
  v_snapshot   JSONB;
  v_sastanak   JSONB;
BEGIN
  IF v_email = '' THEN
    RAISE EXCEPTION 'Nemate pravo da zaključite ovaj sastanak.'
      USING ERRCODE = '42501';
  END IF;

  SELECT s.status,
         (
           public.current_user_is_management()
           OR LOWER(COALESCE(s.vodio_email, '')) = v_email
           OR LOWER(COALESCE(s.zapisnicar_email, '')) = v_email
           OR LOWER(COALESCE(s.created_by_email, '')) = v_email
         )
    INTO v_status, v_authorized
  FROM public.sastanci s
  WHERE s.id = p_sastanak_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sastanak nije pronađen.'
      USING ERRCODE = 'P0002';
  END IF;

  IF NOT v_authorized THEN
    RAISE EXCEPTION 'Nemate pravo da zaključite ovaj sastanak.'
      USING ERRCODE = '42501';
  END IF;

  SELECT to_jsonb(s)
    INTO v_sastanak
  FROM public.sastanci s
  WHERE s.id = p_sastanak_id;

  SELECT jsonb_build_object(
           'schemaVersion', 2,
           'snapshotAt', v_now,
           'sastanak', v_sastanak,
           'ucesnici', COALESCE(
             jsonb_agg(
               jsonb_build_object(
                 'email', email,
                 'label', label,
                 'prisutan', prisutan,
                 'pozvan', pozvan,
                 'napomena', napomena
               )
               ORDER BY label NULLS LAST, email
             ),
             '[]'::jsonb
           ),
           'pmTeme', '[]'::jsonb,
           'akcije', '[]'::jsonb,
           'aktivnosti', '[]'::jsonb,
           'slike', '[]'::jsonb
         )
    INTO v_snapshot
  FROM public.sastanak_ucesnici
  WHERE sastanak_id = p_sastanak_id;

  IF v_status = 'zakljucan' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'reason', 'already_locked',
      'sastanak_id', p_sastanak_id
    );
  END IF;

  INSERT INTO public.sastanak_arhiva (
    sastanak_id,
    snapshot,
    zapisnik_storage_path,
    zapisnik_generated_at,
    arhivirao_email,
    arhivirao_label,
    arhivirano_at
  ) VALUES (
    p_sastanak_id,
    v_snapshot,
    v_pdf_path,
    CASE WHEN v_pdf_path IS NOT NULL THEN v_now ELSE NULL END,
    v_email,
    v_email,
    v_now
  )
  ON CONFLICT (sastanak_id) DO UPDATE
    SET snapshot = EXCLUDED.snapshot,
        zapisnik_storage_path = COALESCE(EXCLUDED.zapisnik_storage_path, public.sastanak_arhiva.zapisnik_storage_path),
        zapisnik_generated_at = COALESCE(EXCLUDED.zapisnik_generated_at, public.sastanak_arhiva.zapisnik_generated_at),
        arhivirao_email = EXCLUDED.arhivirao_email,
        arhivirao_label = EXCLUDED.arhivirao_label,
        arhivirano_at = EXCLUDED.arhivirano_at;

  UPDATE public.sastanci
     SET status = 'zakljucan',
         zakljucan_at = v_now,
         zakljucan_by_email = v_email,
         updated_at = v_now
   WHERE id = p_sastanak_id;

  RETURN jsonb_build_object(
    'ok', true,
    'sastanak_id', p_sastanak_id,
    'zakljucan_at', v_now
  );
END;
$$;

COMMENT ON FUNCTION public.sast_zakljucaj_sastanak(UUID, TEXT, TEXT) IS
  'Atomski zakljucava sastanak: proverava scope, kreira/upisuje arhiva snapshot i menja status u zakljucan.';

REVOKE ALL ON FUNCTION public.sast_zakljucaj_sastanak(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sast_zakljucaj_sastanak(UUID, TEXT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';

-- Zamenjuje multi-step logiku iz: sastanakArhiva.js i sastanciDetalj.js
-- Vidi: docs/audit/sastanci-audit-2026-05-03.md H3

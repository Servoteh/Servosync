-- ============================================================================
-- LOKACIJE × MAŠINE — Faza 1: BigTehn operativni status za TP
-- ============================================================================
-- Pokreni JEDNOM u Supabase SQL Editoru (idempotentno).
--
-- Šta radi:
--   1. Kreira VIEW `v_loc_tp_operation_slots` — jedna red po (work_order_id,
--      operacija). Reshape `bigtehn_work_order_lines_cache` + agregati iz
--      `bigtehn_tech_routing_cache` (prijave operatera).
--      Kolone:
--        - qty_finished  = SUM(komada) WHERE is_completed = TRUE
--        - qty_in_process = SUM(komada) WHERE started_at NOT NULL AND is_completed = FALSE
--        - real_seconds  = SUM(prn_timer_seconds) (stvarni vreme rada za operaciju)
--        - status         = NOT_STARTED | IN_PROGRESS | DONE
--        - machine_code, machine_name (uračunato overlay → assigned_machine_code)
--        - last_started_at, last_finished_at, operators (CSV)
--      Bez `total_qty` po operaciji (komada se računaju za ceo RN — vidi
--      bigtehn_work_orders_cache.komada).
--
--      ŠEMA VIEW-a je dizajnirana DA BUDE ISTA kao buduća fizička tabela
--      `loc_tp_operation_slots` (Faza 2). Kad worker stigne, view → tabela,
--      RPC i UI ne menjaju kontrakt.
--
--   2. Kreira RPC `loc_get_bigtehn_op_status(p_work_order_id bigint)` —
--      vraća `{ ok, work_order: { id, ident_broj, broj_crteza, naziv_dela,
--      komada_total }, operations: [...] }`. RLS check kroz `loc_auth_roles()`.
--
-- VAŽNO za multi-operation TP (npr. 1500 kom kroz 3 operacije):
--   - Svaka operacija ima SVOJ qty_finished i qty_in_process (ograničen na
--     komada_total RN-a kao prirodni cap — ako operater javi 1700/1500 to je
--     domenska greška u BigTehn-u, ne računamo na nivou view-a).
--   - UI prikazuje OPERATION LIST, ne TP-level „X done / Y in_process"
--     headline, da izbegnemo duplo brojanje istih komada koja prelaze kroz
--     više operacija u nizu.
--
-- DOWN:
--   DROP FUNCTION IF EXISTS public.loc_get_bigtehn_op_status(bigint);
--   DROP VIEW IF EXISTS public.v_loc_tp_operation_slots;
-- ============================================================================

-- ── 1. VIEW: v_loc_tp_operation_slots ───────────────────────────────────────
CREATE OR REPLACE VIEW public.v_loc_tp_operation_slots AS
SELECT
  l.work_order_id,
  l.id                                                 AS line_id,
  l.operacija                                          AS operation_code,
  l.opis_rada                                          AS operation_name,
  l.alat_pribor                                        AS alat_pribor,
  l.machine_code                                       AS original_machine_code,
  COALESCE(o.assigned_machine_code, l.machine_code)    AS machine_code,
  m.name                                               AS machine_name,
  COALESCE(m.no_procedure, FALSE)                      AS is_non_machining,
  l.tpz                                                AS tpz_min,
  l.tk                                                 AS tk_min,
  /* Agregati iz prijava. NULL prijava → 0 (CO­ALESCE u SUM ne radi
   * pre FILTER; trik sa COALESCE oko ukupne sume). */
  COALESCE(SUM(tr.komada) FILTER (WHERE tr.is_completed = TRUE), 0)::numeric AS qty_finished,
  COALESCE(SUM(tr.komada) FILTER (
    WHERE tr.started_at IS NOT NULL AND COALESCE(tr.is_completed, FALSE) = FALSE
  ), 0)::numeric                                      AS qty_in_process,
  COALESCE(SUM(tr.prn_timer_seconds), 0)::bigint     AS real_seconds,
  MIN(tr.started_at)                                   AS first_started_at,
  MAX(tr.started_at)                                   AS last_started_at,
  MAX(tr.finished_at)                                  AS last_finished_at,
  BOOL_OR(tr.is_completed)                             AS any_completed,
  COUNT(tr.id) FILTER (WHERE tr.started_at IS NOT NULL) AS prijava_count,
  /* Operateri koji su radili na ovoj operaciji — comma-separated, dedup-ovano. */
  NULLIF(string_agg(DISTINCT NULLIF(trim(tr.potpis), ''), ', ' ORDER BY NULLIF(trim(tr.potpis), '')), '')
                                                       AS operators,
  /* Derivacija statusa: same kao u UI panelu, ali isračunata na server-u
   * da klijent ne mora da je pravi sam. */
  CASE
    WHEN BOOL_OR(tr.is_completed) THEN 'DONE'
    WHEN COUNT(tr.id) FILTER (WHERE tr.started_at IS NOT NULL) > 0 THEN 'IN_PROGRESS'
    ELSE 'NOT_STARTED'
  END                                                  AS status,
  'bigtehn'::TEXT                                      AS source
FROM public.bigtehn_work_order_lines_cache l
LEFT JOIN public.production_overlays o
  ON o.work_order_id = l.work_order_id AND o.line_id = l.id
LEFT JOIN public.bigtehn_machines_cache m
  ON m.rj_code = COALESCE(o.assigned_machine_code, l.machine_code)
LEFT JOIN public.bigtehn_tech_routing_cache tr
  ON tr.work_order_id = l.work_order_id
 AND tr.operacija = l.operacija
GROUP BY
  l.work_order_id,
  l.id,
  l.operacija,
  l.opis_rada,
  l.alat_pribor,
  l.machine_code,
  o.assigned_machine_code,
  m.name,
  m.no_procedure,
  l.tpz,
  l.tk;

COMMENT ON VIEW public.v_loc_tp_operation_slots IS
  'Faza 1: jedan red po (work_order_id, operacija). Reshape BigTehn cache-a u '
  'shape buduće `loc_tp_operation_slots` tabele (Faza 2). Status: '
  'NOT_STARTED / IN_PROGRESS / DONE. UI panel u Lokacije / Pregled predmeta čita ovo.';

GRANT SELECT ON public.v_loc_tp_operation_slots TO authenticated;
/* Anon NEMA pristup — TP komada / klijent podaci nisu javni. */

-- ── 2. RPC: loc_get_bigtehn_op_status(work_order_id) ───────────────────────
DROP FUNCTION IF EXISTS public.loc_get_bigtehn_op_status(bigint);

CREATE OR REPLACE FUNCTION public.loc_get_bigtehn_op_status(p_work_order_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $fn$
DECLARE
  v_wo jsonb;
  v_ops jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;
  /* Isti role-check kao u ostalim Lokacije RPC-ima (loc_auth_roles vraća
   * lower-case array uloga; cardinality=0 znači da korisnik nema nijednu). */
  IF cardinality(public.loc_auth_roles()) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_role');
  END IF;
  IF p_work_order_id IS NULL OR p_work_order_id <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_work_order_id');
  END IF;

  /* Header iz bigtehn_work_orders_cache — koristi se za prikaz „TP 755, crtež
   * 1091063, 1500 kom" u modal headeru. */
  SELECT to_jsonb(wo) INTO v_wo
  FROM (
    SELECT
      id, ident_broj, broj_crteza, naziv_dela,
      materijal, dimenzija_materijala,
      komada AS komada_total, rok_izrade, status_rn
    FROM public.bigtehn_work_orders_cache
    WHERE id = p_work_order_id
  ) wo;

  IF v_wo IS NULL THEN
    /* RN ne postoji u keš-u (možda obrisan u BigTehn-u između sync-eva). */
    RETURN jsonb_build_object('ok', false, 'error', 'work_order_not_found');
  END IF;

  /* Lista operacija — sortirano po operacija (TEXT comparison, ali kako
   * BigTehn šalje cifre kao stringove tipa „010", „020", lex sort radi
   * očekivano u 95% slučajeva. Ako se kasnije ispostavi da neki klijent
   * koristi „10" / „2" / „100" → razmotri natural sort na klijentu). */
  SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.operation_code), '[]'::jsonb)
    INTO v_ops
  FROM (
    SELECT
      operation_code, operation_name, alat_pribor,
      original_machine_code, machine_code, machine_name, is_non_machining,
      tpz_min, tk_min,
      qty_finished, qty_in_process,
      real_seconds,
      first_started_at, last_started_at, last_finished_at,
      any_completed, prijava_count, operators, status
    FROM public.v_loc_tp_operation_slots
    WHERE work_order_id = p_work_order_id
  ) t;

  RETURN jsonb_build_object(
    'ok', true,
    'work_order', v_wo,
    'operations', COALESCE(v_ops, '[]'::jsonb)
  );
EXCEPTION
  WHEN others THEN
    RETURN jsonb_build_object('ok', false, 'error', 'exception', 'detail', SQLERRM);
END;
$fn$;

COMMENT ON FUNCTION public.loc_get_bigtehn_op_status(bigint) IS
  'Faza 1: vraća listu operacija (sa mašinama, komada i statusima) za jedan RN. '
  'Panel u Lokacije / Pregled predmeta čita ovo da bi prikazao stvarni operativni '
  'status uz placement (koji je čisto fizički). SECURITY INVOKER + loc_auth_roles().';

REVOKE ALL ON FUNCTION public.loc_get_bigtehn_op_status(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.loc_get_bigtehn_op_status(bigint) FROM anon;
GRANT EXECUTE ON FUNCTION public.loc_get_bigtehn_op_status(bigint) TO authenticated;

-- ── Sanity ──────────────────────────────────────────────────────────────────
DO $sanity$
DECLARE
  v_has_view BOOLEAN;
  v_has_fn   BOOLEAN;
BEGIN
  v_has_view := EXISTS (
    SELECT 1 FROM pg_views
     WHERE schemaname='public' AND viewname='v_loc_tp_operation_slots'
  );
  v_has_fn := EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname='loc_get_bigtehn_op_status'
  );
  IF NOT (v_has_view AND v_has_fn) THEN
    RAISE EXCEPTION 'add_loc_bigtehn_op_status_rpc failed: view=%, fn=%', v_has_view, v_has_fn;
  END IF;
  RAISE NOTICE 'add_loc_bigtehn_op_status_rpc OK.';
END $sanity$;

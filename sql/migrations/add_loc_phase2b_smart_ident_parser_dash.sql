-- ============================================================================
-- LOKACIJE × MAŠINE — Faza 2B: parser dopuna za dash (revizija/sub-batch)
-- ============================================================================
-- Pokreni JEDNOM u Supabase SQL Editoru (idempotentno, CREATE OR REPLACE).
--
-- DOPUNA U ODNOSU NA `add_loc_phase2b_smart_ident_parser.sql`:
--   BigTehn konvencija: dash u predmet poziciji označava REVIZIJU/SUB-BATCH,
--   ne deo predmet koda. Primer:
--     - „9400-1/430" znači: predmet=„9400", TP=„1/430"
--       (NE predmet=„9400-1" kao naivni fallback)
--     - „9400-2/405" znači: predmet=„9400", TP=„2/405"
--
--   Prvobitni parser (longest-match protiv aktivnih predmeta) ne prepoznaje
--   ovaj slučaj jer „9400-1" nije u `bigtehn_items_cache` — pada na fallback
--   sa pogrešnim predmet kodom.
--
--   Dodajemo **Pass 2** logiku: ako prvi segment sadrži dash, probaj
--   bazu (pre dash) kao predmet kandidat; suffix posle dash + ostatak path-a
--   = TP. Aktivira se SAMO ako baza postoji kao aktivan predmet u kešu.
--
-- TEST CASES (po user input-u):
--   „9400/1/165"   → predmet=„9400/1", tp=„165"   (Pass 1, hier match)
--   „9400/399"     → predmet=„9400",   tp=„399"   (Pass 1, simple)
--   „9400-1/430"   → predmet=„9400",   tp=„1/430" (Pass 2, dash)
--   „9400-2/405"   → predmet=„9400",   tp=„2/405" (Pass 2, dash)
--   „0000.0"       → null / null                  (jedan segment)
--
-- ZAVISI OD: `add_loc_phase2b_smart_ident_parser.sql` (postojeća parser funkcija).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.loc_bigtehn_parse_ident(p_ident TEXT)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $fn_parse$
DECLARE
  v_ident        TEXT;
  v_parts        TEXT[];
  v_count        INT;
  v_idx          INT;
  v_predmet      TEXT;
  v_tp           TEXT;
  /* Pass 2 helpers */
  v_dash_pos     INT;
  v_base         TEXT;
  v_dash_suffix  TEXT;
  v_rest         TEXT;
BEGIN
  v_ident := NULLIF(trim(COALESCE(p_ident, '')), '');
  IF v_ident IS NULL THEN
    RETURN jsonb_build_object('predmet', NULL, 'tp', NULL);
  END IF;

  v_parts := string_to_array(v_ident, '/');
  v_count := COALESCE(array_length(v_parts, 1), 0);

  /* Single-segment ident (npr. „0000.0") — bad. */
  IF v_count < 2 THEN
    RETURN jsonb_build_object('predmet', NULL, 'tp', NULL);
  END IF;

  /* ── Pass 1: longest direct prefix match (hijerarhija „9400/1/165" itd.) */
  FOR v_idx IN REVERSE (v_count - 1)..1 LOOP
    v_predmet := array_to_string(v_parts[1:v_idx], '/');

    IF EXISTS (
      SELECT 1 FROM public.bigtehn_items_cache b
       WHERE b.broj_predmeta = v_predmet
         AND b.status = 'U TOKU'
         AND b.datum_zakljucenja IS NULL
       LIMIT 1
    ) THEN
      v_tp := array_to_string(v_parts[(v_idx + 1):v_count], '/');
      v_tp := NULLIF(trim(v_tp), '');
      IF v_tp IS NULL THEN
        CONTINUE;
      END IF;
      RETURN jsonb_build_object('predmet', v_predmet, 'tp', v_tp);
    END IF;
  END LOOP;

  /* ── Pass 2: dash u prvom segmentu (BigTehn revizija/sub-batch konvencija)
   * „9400-1/430" → base=„9400" (predmet ako aktivan), dash_suffix=„1",
   *                rest=„430" → tp=„1/430". */
  IF position('-' IN v_parts[1]) > 0 THEN
    v_dash_pos := position('-' IN v_parts[1]);
    v_base := substring(v_parts[1], 1, v_dash_pos - 1);
    v_dash_suffix := substring(v_parts[1], v_dash_pos + 1);

    IF length(trim(v_base)) > 0
       AND length(trim(v_dash_suffix)) > 0
       AND EXISTS (
         SELECT 1 FROM public.bigtehn_items_cache b
          WHERE b.broj_predmeta = v_base
            AND b.status = 'U TOKU'
            AND b.datum_zakljucenja IS NULL
          LIMIT 1
       )
    THEN
      /* Spoji dash_suffix sa ostatkom kao kosa-crta path. */
      v_rest := array_to_string(v_parts[2:v_count], '/');
      IF length(COALESCE(v_rest, '')) > 0 THEN
        v_tp := v_dash_suffix || '/' || v_rest;
      ELSE
        v_tp := v_dash_suffix;
      END IF;
      RETURN jsonb_build_object('predmet', v_base, 'tp', v_tp);
    END IF;
  END IF;

  /* ── Fallback: predmet = parts[1], tp = parts[2]. Ne čak ni „active" check
   * — to znači da je ident u sistemu ali predmet nije u kešu. Naša UI još
   * uvek može da matchuje placement na ovaj ključ. */
  v_predmet := v_parts[1];
  v_tp := NULLIF(trim(v_parts[2]), '');
  IF v_predmet IS NULL OR length(trim(v_predmet)) = 0 OR v_tp IS NULL THEN
    RETURN jsonb_build_object('predmet', NULL, 'tp', NULL);
  END IF;
  RETURN jsonb_build_object('predmet', v_predmet, 'tp', v_tp, 'fallback', TRUE);
END;
$fn_parse$;

COMMENT ON FUNCTION public.loc_bigtehn_parse_ident(TEXT) IS
  'BigTehn ident_broj → {predmet, tp}. Pass 1: longest „/" prefix match protiv '
  'aktivnih predmeta. Pass 2: ako prvi segment ima „-", probaj bazu pre dash '
  'kao predmet, dash suffix + ostatak path-a = tp. Fallback: split 1 / split 2 '
  '(sa fallback:true flag-om). Vidi add_loc_phase2b_smart_ident_parser_dash.sql.';

-- ── Sanity ──────────────────────────────────────────────────────────────────
DO $sanity$
DECLARE
  v_t1 jsonb;
  v_t2 jsonb;
  v_t3 jsonb;
BEGIN
  v_t1 := public.loc_bigtehn_parse_ident('TEST-NONEXIST-99/123');  /* Pass 1 + Pass 2 oba fail → fallback */
  v_t2 := public.loc_bigtehn_parse_ident('SOMETHING/X');           /* Pass 1 fail (osim ako ima predmet „SOMETHING") → fallback */
  v_t3 := public.loc_bigtehn_parse_ident('NULL_SEGMENT');           /* Single segment → null */
  RAISE NOTICE 'loc_bigtehn_parse_ident dash smoke: t1=%, t2=%, t3=%', v_t1, v_t2, v_t3;
  RAISE NOTICE 'add_loc_phase2b_smart_ident_parser_dash OK. Pokreni testove: SELECT loc_bigtehn_parse_ident(...) na realnim ident-ima sa dash.';
END
$sanity$;

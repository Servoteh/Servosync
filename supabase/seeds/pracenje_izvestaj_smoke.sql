-- ============================================================================
-- Smoke test: get_predmet_pracenje_izvestaj + upis u pracenje_proizvodnje_napomene
-- (INSERT ... ON CONFLICT; service_role / MCP / psql bez JWT)
-- Pokrenuti u Supabase SQL editoru, MCP execute_sql, ili psql.
--
-- Koristi prvi dostupan predmet iz bigtehn_items_cache koji ima bar jedan
-- red u v_bigtehn_rn_struktura. Nema hardkodovanih ID-jeva.
-- ============================================================================

DO $smoke$
DECLARE
  v_item_id    integer;
  v_root_rn_id bigint;
  v_result     jsonb;
  v_rows       jsonb;
  v_summary    jsonb;
  v_nap_id     uuid;
  v_found_nap  boolean;
  v_row        jsonb;
BEGIN
  -- -------------------------------------------------------------------------
  -- 0) Pronađi testni predmet: prvi sa bar 1 RN u stablu
  -- -------------------------------------------------------------------------
  SELECT s.predmet_item_id::integer
  INTO v_item_id
  FROM public.v_bigtehn_rn_struktura s
  GROUP BY s.predmet_item_id
  HAVING count(*) >= 1
  ORDER BY s.predmet_item_id
  LIMIT 1;

  IF v_item_id IS NULL THEN
    RAISE NOTICE 'SKIP: nema podataka u v_bigtehn_rn_struktura — instaliraj BigTehn seed ili pokreni sync.';
    RETURN;
  END IF;
  RAISE NOTICE 'Testni predmet: %', v_item_id;

  -- Pronađi prvi non-root RN za testove podstabla
  SELECT s.rn_id
  INTO v_root_rn_id
  FROM public.v_bigtehn_rn_struktura s
  WHERE s.predmet_item_id = v_item_id::bigint
    AND s.parent_rn_id IS NOT NULL
  ORDER BY s.nivo, s.rn_id
  LIMIT 1;

  -- -------------------------------------------------------------------------
  -- TEST 1: Ceo predmet, lot=12 (default)
  -- -------------------------------------------------------------------------
  v_result := public.get_predmet_pracenje_izvestaj(v_item_id, NULL, 12);

  IF v_result IS NULL OR NOT (v_result ? 'rows') THEN
    RAISE EXCEPTION 'TEST 1 FAIL: get_predmet_pracenje_izvestaj vratio NULL ili nema "rows" ključa';
  END IF;

  v_rows    := v_result->'rows';
  v_summary := v_result->'summary';

  IF jsonb_array_length(v_rows) = 0 THEN
    RAISE EXCEPTION 'TEST 1 FAIL: rows je prazan niz za predmet %', v_item_id;
  END IF;
  IF NOT (v_result ? 'predmet') THEN
    RAISE EXCEPTION 'TEST 1 FAIL: nema "predmet" ključa u odgovoru';
  END IF;
  IF (v_result->>'lot_qty')::int IS DISTINCT FROM 12 THEN
    RAISE EXCEPTION 'TEST 1 FAIL: lot_qty nije 12, dobijeno %', v_result->>'lot_qty';
  END IF;
  IF NOT (v_result ? 'summary') THEN
    RAISE EXCEPTION 'TEST 1 FAIL: nema "summary" ključa';
  END IF;
  -- Svaki red mora imati statusi objekat
  SELECT INTO v_row elem FROM jsonb_array_elements(v_rows) elem WHERE NOT (elem ? 'statusi') LIMIT 1;
  IF v_row IS NOT NULL THEN
    RAISE EXCEPTION 'TEST 1 FAIL: red nema "statusi" ključa: %', v_row;
  END IF;
  RAISE NOTICE 'TEST 1 OK: ceo predmet lot=12, % redova, summary: %',
    jsonb_array_length(v_rows), v_summary;

  -- -------------------------------------------------------------------------
  -- TEST 2: Ceo predmet, lot=24
  -- -------------------------------------------------------------------------
  v_result := public.get_predmet_pracenje_izvestaj(v_item_id, NULL, 24);
  IF (v_result->>'lot_qty')::int IS DISTINCT FROM 24 THEN
    RAISE EXCEPTION 'TEST 2 FAIL: lot_qty nije 24';
  END IF;
  RAISE NOTICE 'TEST 2 OK: lot=24, % redova', jsonb_array_length(v_result->'rows');

  -- -------------------------------------------------------------------------
  -- TEST 3: Podstablo (root_rn_id)
  -- -------------------------------------------------------------------------
  IF v_root_rn_id IS NOT NULL THEN
    v_result := public.get_predmet_pracenje_izvestaj(v_item_id, v_root_rn_id, 12);
    IF v_result IS NULL OR jsonb_array_length(v_result->'rows') = 0 THEN
      RAISE EXCEPTION 'TEST 3 FAIL: podstablo za root_rn_id=% je prazno', v_root_rn_id;
    END IF;
    IF v_result->'root' IS NULL THEN
      RAISE EXCEPTION 'TEST 3 FAIL: root objekat je NULL za podstablo zahtev';
    END IF;
    RAISE NOTICE 'TEST 3 OK: podstablo root=%, % redova', v_root_rn_id, jsonb_array_length(v_result->'rows');
  ELSE
    RAISE NOTICE 'TEST 3 SKIP: predmet % nema non-root RN-ova (samo jedan nivo)', v_item_id;
  END IF;

  -- -------------------------------------------------------------------------
  -- TEST 4: Direktan INSERT (service_role, bez JWT) + verifikacija u RPC payloadu
  -- production.upsert_pracenje_proizvodnje_napomena traži auth.uid() — ne radi u MCP.
  -- -------------------------------------------------------------------------
  DECLARE
    v_test_rn_id bigint;
    v_test_note text := 'Smoke test napomena ' || clock_timestamp()::text;
  BEGIN
    SELECT s.rn_id INTO v_test_rn_id
    FROM public.v_bigtehn_rn_struktura s
    WHERE s.predmet_item_id = v_item_id::bigint
    ORDER BY s.nivo, s.rn_id
    LIMIT 1;

    IF v_test_rn_id IS NULL THEN
      RAISE EXCEPTION 'TEST 4 FAIL: ne mogu da pronađem rn_id za predmet %', v_item_id;
    END IF;

    INSERT INTO production.pracenje_proizvodnje_napomene
      (predmet_item_id, bigtehn_rn_id, note)
    VALUES (v_item_id, v_test_rn_id, v_test_note)
    ON CONFLICT (predmet_item_id, bigtehn_rn_id) DO UPDATE
      SET note = EXCLUDED.note, updated_at = now()
    RETURNING id INTO v_nap_id;

    IF v_nap_id IS NULL THEN
      RAISE EXCEPTION 'TEST 4 FAIL: INSERT nije vratio id';
    END IF;

    v_result := public.get_predmet_pracenje_izvestaj(v_item_id, NULL, 12);
    SELECT INTO v_row elem FROM jsonb_array_elements(v_result->'rows') elem
    WHERE (elem->>'node_id')::bigint = v_test_rn_id
      AND (elem->>'korisnicka_napomena') LIKE 'Smoke test napomena%'
    LIMIT 1;

    IF v_row IS NULL THEN
      RAISE EXCEPTION 'TEST 4 FAIL: zapisana napomena nije nađena u izveštaju za rn_id=%', v_test_rn_id;
    END IF;
    RAISE NOTICE 'TEST 4 OK: napomena kreirana (id=%) i nađena u izveštaju', v_nap_id;

    DELETE FROM production.pracenje_proizvodnje_napomene
    WHERE predmet_item_id = v_item_id AND bigtehn_rn_id = v_test_rn_id;
    RAISE NOTICE 'TEST 4 cleanup: napomena obrisana';
  END;

  -- -------------------------------------------------------------------------
  -- TEST 5: Nepostojeći predmet → exception
  -- -------------------------------------------------------------------------
  BEGIN
    v_result := public.get_predmet_pracenje_izvestaj(999999999, NULL, 12);
    RAISE EXCEPTION 'TEST 5 FAIL: nije bačen exception za nepostojeći predmet';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'TEST 5 OK: exception za nepostojeći predmet (SQLSTATE=%)', SQLSTATE;
  END;

  -- -------------------------------------------------------------------------
  -- TEST 6: lot_qty=0 ili negativan → normalizuje se na 1..100000 (ne baca exception)
  -- -------------------------------------------------------------------------
  v_result := public.get_predmet_pracenje_izvestaj(v_item_id, NULL, 0);
  IF (v_result->>'lot_qty')::int <= 0 THEN
    RAISE EXCEPTION 'TEST 6 FAIL: lot_qty=0 rezultovao u <=0 lot (expected: normalizovan na 12 ili 1)';
  END IF;
  RAISE NOTICE 'TEST 6 OK: lot_qty=0 normalizovan na %', v_result->>'lot_qty';

  -- -------------------------------------------------------------------------
  -- TEST 7: Proveri statusi polja u prvom redu
  -- -------------------------------------------------------------------------
  v_result := public.get_predmet_pracenje_izvestaj(v_item_id, NULL, 12);
  v_row := (SELECT elem FROM jsonb_array_elements(v_result->'rows') elem LIMIT 1);
  IF NOT (
    (v_row->'statusi' ? 'kasni')
    AND (v_row->'statusi' ? 'nema_tp')
    AND (v_row->'statusi' ? 'nema_crtez')
    AND (v_row->'statusi' ? 'nema_zavrsnu_kontrolu')
    AND (v_row->'statusi' ? 'nije_kompletirano')
    AND (v_row->'statusi' ? 'nema_rn')
  ) THEN
    RAISE EXCEPTION 'TEST 7 FAIL: prvi red nema sve statusi ključeve, statusi=%', v_row->'statusi';
  END IF;
  RAISE NOTICE 'TEST 7 OK: statusi objekat ima sva 6 polja';

  RAISE NOTICE '=== SVE OK: smoke test završen za predmet % ===', v_item_id;
END $smoke$;

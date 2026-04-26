-- ============================================================================
-- Smoke test (nije seed podataka) — pokrenuti kao admin / service_role posle
-- migracije 20260426203000__pracenje_aktivni_predmeti_init.sql
-- Preduslov: bigtehn_rn_components_test.sql (Predmet A=810100, B=810101, C=810102)
-- ============================================================================

-- 1) get_aktivni_predmeti
-- expected: jsonb niz sa 3 objekta (A,B,C ako su svi u v_active), polja:
--   item_id, broj_predmeta, naziv_predmeta, customer_name, sort_priority|null,
--   broj_root_rn (A:1, B:1, C:1), redni_broj 1..3
SELECT public.get_aktivni_predmeti() AS aktivni_predmeti;

-- 2) get_podsklopovi_predmeta(810102) — Predmet C
-- expected: jsonb niz dužine 5; nivo 0 jedan root; dva n1; dva n2 pod istim parent_rn_id
SELECT public.get_podsklopovi_predmeta(810102) AS podsklopovi_c;

-- 3) get_podsklopovi_predmeta(810100) — Predmet A (samo root, nivo 0)
-- expected: jsonb niz dužine 1; nivo 0; parent_rn_id null
SELECT public.get_podsklopovi_predmeta(810100) AS podsklopovi_a;

-- 4–5) Admin RPC (JWT mora biti admin — u SQL editoru bez korisnika obično preskače)
-- expected set: void + red 810102 sort_priority = 0
-- expected shift: void + renumeracija 0..N-1
DO $$
BEGIN
  IF public.current_user_is_admin() THEN
    PERFORM public.set_predmet_prioritet(810102, 0);
    PERFORM public.shift_predmet_prioritet(810102, 'down');
    RAISE NOTICE 'admin smoke: set + shift izvršeni';
  ELSE
    RAISE NOTICE 'admin smoke preskočen (nema admin JWT) — ručno kao admin u aplikaciji';
  END IF;
END $$;

-- 6) Stanje tabele prioriteta
SELECT count(*) AS predmet_prioritet_row_count FROM production.predmet_prioritet;

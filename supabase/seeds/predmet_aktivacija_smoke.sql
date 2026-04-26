-- predmet_aktivacija smoke (admin/menadžment ili service role u SQL editoru)
--
-- 1) list: broj elemenata = broj redova u bigtehn_items_cache
-- 2) set_predmet_aktivacija: deaktivacija + napomena, ponovo list, get_aktivni_predmeti
-- 3) set vraćanje na true, null napomena (ne menja postojeću)
--
-- Ažuriraj @test_id na jedan stvaran id (ili u psql: \set test_id 123 pa zameni ispod)

DO $smoke$
DECLARE
  tid          integer;
  n_cache      integer;
  n_list       integer;
  j            boolean;
  n_in_aktivni int;
BEGIN
  SELECT id INTO tid FROM public.bigtehn_items_cache ORDER BY id LIMIT 1;
  IF tid IS NULL THEN
    RAISE NOTICE 'SKIP: prazan bigtehn_items_cache';
    RETURN;
  END IF;

  n_list := jsonb_array_length(COALESCE(public.list_predmet_aktivacija_admin(), '[]'::jsonb));
  SELECT count(*)::int INTO n_cache FROM public.bigtehn_items_cache;
  -- expected: n_list = n_cache
  IF n_list IS DISTINCT FROM n_cache THEN
    RAISE EXCEPTION 'list_predmet: očekivano % redova, dobijeno %', n_cache, n_list;
  END IF;
  RAISE NOTICE 'OK 1) list: % = cache %', n_list, n_cache;

  PERFORM public.set_predmet_aktivacija(tid, false, 'test napomena');
  -- expected: taj item ima je_aktivan = false, napomena = test
  SELECT (e->>'je_aktivan')::boolean INTO j
  FROM jsonb_array_elements(COALESCE(public.list_predmet_aktivacija_admin(), '[]'::jsonb)) e
  WHERE (e->>'item_id')::int = tid;
  IF j IS NOT FALSE THEN
    RAISE EXCEPTION 'Očekivano je_aktivan=false nakon set, dobijeno %', j;
  END IF;
  IF (SELECT (e->>'napomena') FROM jsonb_array_elements(COALESCE(public.list_predmet_aktivacija_admin(), '[]'::jsonb)) e WHERE (e->>'item_id')::int = tid)
     IS DISTINCT FROM 'test napomena' THEN
    RAISE EXCEPTION 'Napomena nije očekivana nakon set';
  END IF;
  RAISE NOTICE 'OK 2) set false + napomena';

  n_in_aktivni := (
    SELECT count(*)::int
    FROM jsonb_array_elements(public.get_aktivni_predmeti()) e
    WHERE (e->>'item_id')::int = tid
  );
  -- expected: 0 jer je je_aktivan = false
  IF n_in_aktivni <> 0 THEN
    RAISE EXCEPTION 'get_aktivni_predmeti: očekivano 0 redova za deaktiviran item %, ima %', tid, n_in_aktivni;
  END IF;
  RAISE NOTICE 'OK 3) get_aktivni ne sadrži deaktiviran predmet (bez obzira na MES)';

  PERFORM public.set_predmet_aktivacija(tid, true, null);
  RAISE NOTICE 'OK 4) vraćeno true, p_napomena null';
  -- expected: napomena i dalje 'test napomena'
  IF (SELECT (e->>'napomena') FROM jsonb_array_elements(COALESCE(public.list_predmet_aktivacija_admin(), '[]'::jsonb)) e WHERE (e->>'item_id')::int = tid)
     IS DISTINCT FROM 'test napomena' THEN
    RAISE EXCEPTION 'p_napomena NULL je trebalo da zadrži staru napomenu';
  END IF;
  RAISE NOTICE 'OK 5) napomena očuvana nakon set(..., true, null)';

  n_in_aktivni := (
    SELECT count(*)::int
    FROM jsonb_array_elements(public.get_aktivni_predmeti()) e
    WHERE (e->>'item_id')::int = tid
  );
  IF n_in_aktivni <> 1 THEN
    RAISE EXCEPTION 'nakon reaktivacije očekivan tačno 1 red u get_aktivni za item %, ima %', tid, n_in_aktivni;
  END IF;
  RAISE NOTICE 'OK 6) get_aktivni ponovo sadrži predmet nakon je_aktivan=true';

  RAISE NOTICE 'smoke uspeh za predmet_id=%', tid;
END
$smoke$;

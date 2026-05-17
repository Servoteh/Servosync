-- =====================================================================
-- PP Sprint 1M-a — plan_cache_mode = force_custom_plan + drop 1K idle indeks
-- =====================================================================
-- Cilj: spustiti `plan_pp_open_ops_for_machine('8.4', 100, 0)` ispod ~10 s
-- (baseline ~29 s pošto je 1K partial indeks idle).
--
-- Sprint 1L dijagnoza (vidi docs/migration/pp-sprint1l-status.md):
--   - Direct view `count(*) ... WHERE effective_machine_code='8.4'` = 6.5 s
--   - Funkcija `plan_pp_open_ops_for_machine('8.4',100,0)`           = 29 s
--   - 1K partial indeks (`bigtehn_tr_cache_incomplete_wo_op_idx`) ima
--     `idx_scan = 0` — planner ga nikad ne bira (promašena meta:
--     hot path filtuje `is_completed IS TRUE`, ne `false`).
--   - `DISCARD PLANS` ne pomaže — to čisti prepared-stmt cache, ali
--     plpgsql funkcije imaju svoj per-function plan cache koji koristi
--     `plan_cache_mode = auto` po defaultu (zna da bira generic plan
--     i kad bi custom bio drastično bolji).
--
-- Postavljanje `plan_cache_mode = force_custom_plan` na nivou funkcije
-- prisiljava planner da za svaki poziv pravi novi plan koji koristi
-- konkretnu vrednost `p_machine_code`. Time se izbegava generic plan
-- koji ne zna selektivnost različitih mašina.
--
-- DRAFT — NE izvršavati automatski; ručno aplicirati u Supabase Studio.
-- =====================================================================


-- ─────────────────────────────────────────────────────────────────────
-- 1. DROP 1K partial indeksa (idle, idx_scan=0)
-- ─────────────────────────────────────────────────────────────────────
-- Indeks je promašen: `is_completed = FALSE` (Sprint 1K) targetira
-- `_ready_chain` LATERAL, ali planner u praksi koristi `wo_idx` sa
-- runtime filter-om. Veličina 16 kB, ali ostavlja DML overhead na svaki
-- INSERT/UPDATE nad `bigtehn_tech_routing_cache` (cache se osvežava
-- preko bridge sync-a svakih 15 min). Nema koristi → drop.
--
-- Indeks je prazan (~9 indeksiranih redova, 16 kB), DROP bez CONCURRENTLY
-- završava se za milisekunde. Drži ACCESS EXCLUSIVE na tabeli, ali
-- praktično bez rizika. CONCURRENTLY izbegnut jer Supabase SQL Editor /
-- MCP wrap-uje multi-statement u transakciju (CONCURRENTLY tu pada sa
-- "DROP INDEX CONCURRENTLY cannot run inside a transaction block").

DROP INDEX IF EXISTS public.bigtehn_tr_cache_incomplete_wo_op_idx;


-- ─────────────────────────────────────────────────────────────────────
-- 2. ALTER FUNCTION plan_cache_mode = force_custom_plan
-- ─────────────────────────────────────────────────────────────────────
-- Ovaj setting važi samo za pozive ove konkretne funkcije; ne diramo
-- globalni server setting. Reverzibilno preko `RESET plan_cache_mode`.

ALTER FUNCTION public.plan_pp_open_ops_for_machine(text, integer, integer)
  SET plan_cache_mode = force_custom_plan;


-- =====================================================================
-- VERIFIKACIJA POSLE APPLY-A
-- =====================================================================
--
-- 1. Indeks 1K nestao:
/*
SELECT EXISTS (
  SELECT 1
  FROM pg_indexes
  WHERE schemaname = 'public'
    AND indexname = 'bigtehn_tr_cache_incomplete_wo_op_idx'
) AS still_exists;
-- Očekivano: false
*/
--
-- 2. Funkcija ima plan_cache_mode setting:
/*
SELECT proname, proconfig
FROM pg_proc
WHERE proname = 'plan_pp_open_ops_for_machine'
  AND pronamespace = 'public'::regnamespace;
-- Očekivano: proconfig sadrži '{plan_cache_mode=force_custom_plan, search_path=public, statement_timeout=180s}'
*/
--
-- 3. Merenje (Sprint 1L baseline = 29 s):
/*
DISCARD ALL;
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM public.plan_pp_open_ops_for_machine('8.4'::text, 100, 0);
-- Cilj: Execution Time < 10 000 ms
-- Posebno proveriti: shared hits (sada ~8.6M = 67 GB) — treba pasti
-- ka direct-view nivou (~1.07M = 8.4 GB).
*/
--
-- 4. Sanity check sa drugom mašinom (proveriti da li je popravak
--    generalan, ne samo za 8.4):
/*
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM public.plan_pp_open_ops_for_machine('TS3', 100, 0);
*/


-- =====================================================================
-- ROLLBACK
-- =====================================================================
/*
-- Vraćanje plan_cache_mode na default:
ALTER FUNCTION public.plan_pp_open_ops_for_machine(text, integer, integer)
  RESET plan_cache_mode;

-- Vraćanje 1K indeksa (ako se ipak pokaže potrebnim):
-- (Pokrenuti kao samostalan statement van transakcije ako koristiš CONCURRENTLY;
--  inače bez CONCURRENTLY je OK pošto je indeks vrlo mali.)
CREATE INDEX IF NOT EXISTS bigtehn_tr_cache_incomplete_wo_op_idx
  ON public.bigtehn_tech_routing_cache (work_order_id, operacija)
  WHERE is_completed = false;
*/


DO $$ BEGIN
  RAISE NOTICE 'PP 1M-a: 1K idle index dropped, plan_pp_open_ops_for_machine SET plan_cache_mode=force_custom_plan. Pokreni verifikaciju #2 i #3 u SQL Editor-u i izmeri Execution Time.';
END $$;

NOTIFY pgrst, 'reload schema';

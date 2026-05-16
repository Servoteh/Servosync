-- =====================================================================
-- PP Sprint 1K — perf optimizacija PP-A NOT EXISTS provere
-- =====================================================================
-- Cilj: spustiti plan_pp_open_ops_for_machine('8.4', 100, 0) execution
-- time sa ~25 s na < 1 s.
--
-- Sprint 1D merenje pokazalo:
--   - bigtehn_tech_routing_cache ima ~72 118 redova
--   - is_completed = FALSE: samo 9 redova (~0.012%)
--   - Postojeći indeks (work_order_id, operacija) ne uključuje is_completed
--   - PP-A NOT EXISTS radi heap lookup po kandidat-redu × 4543 ops na top mašini
--
-- Partial indeks na (work_order_id, operacija) WHERE is_completed = false
-- gađa samo ~9 redova → PP-A NOT EXISTS postaje O(1) lookup.
--
-- DRAFT — NE izvršavati automatski; ručno aplicirati u Supabase Studio.
-- CONCURRENTLY = bridge sync radi tokom create-a, nema lock-a na tabeli.
-- =====================================================================


-- ─────────────────────────────────────────────────────────────────────
-- 1. Partial indeks za PP-A NOT EXISTS
-- ─────────────────────────────────────────────────────────────────────
-- WHERE is_completed = false znači da indeks indeksira SAMO nezavršene
-- redove. Pošto je incomplete fraction ~0.012%, indeks je trivijalno
-- mali. Postgres planner će prepoznati paritet u EXISTS upitu i koristiti
-- partial indeks bez heap lookup-a.

CREATE INDEX CONCURRENTLY IF NOT EXISTS bigtehn_tr_cache_incomplete_wo_op_idx
  ON public.bigtehn_tech_routing_cache (work_order_id, operacija)
  WHERE is_completed = false;

COMMENT ON INDEX public.bigtehn_tr_cache_incomplete_wo_op_idx IS
  'Sprint 1K perf: partial indeks za PP-A NOT EXISTS provere (is_ready_for_machine u v_production_operations_pre_g4). Indeksira samo nezavršene operacije (~0.01% tabele).';


-- =====================================================================
-- VERIFIKACIJA POSLE APPLY-A
-- =====================================================================
--
-- 1. Indeks postoji i ima očekivanu veličinu:
/*
SELECT indexname, indexdef, pg_size_pretty(pg_relation_size(indexname::regclass)) AS size
FROM pg_indexes
WHERE tablename = 'bigtehn_tech_routing_cache'
  AND indexname = 'bigtehn_tr_cache_incomplete_wo_op_idx';
-- Očekivano: 1 red, size < 100 kB
*/
--
-- 2. Ponovi merenje (Sprint 1D SQL #1):
/*
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM public.plan_pp_open_ops_for_machine('8.4'::text, 100, 0);
-- Očekivano: Execution Time < 1 s
-- Look at plan: trazi "Index Only Scan using bigtehn_tr_cache_incomplete_wo_op_idx"
-- ili "Bitmap Index Scan ... incomplete_wo_op" u _ready_chain LATERAL-u.
*/
--
-- 3. Statistika korišćenja posle nekoliko realnih query-ja:
/*
SELECT s.indexrelname, s.idx_scan, s.idx_tup_read,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS size
FROM pg_stat_user_indexes s
WHERE s.indexrelname = 'bigtehn_tr_cache_incomplete_wo_op_idx';
-- Očekivano: idx_scan raste sa svakim PP modul load-om
*/


-- =====================================================================
-- ROLLBACK (ako bude potrebno)
-- =====================================================================
/*
DROP INDEX CONCURRENTLY IF EXISTS public.bigtehn_tr_cache_incomplete_wo_op_idx;
*/
-- =====================================================================


-- =====================================================================
-- DALJI KORACI AKO PARTIAL INDEKS NIJE DOVOLJAN
-- =====================================================================
--
-- Ako execution time ostaje > 1 s posle apply-a ovog indeksa, sledeći
-- kandidat je `bigtehn_work_order_lines_cache` indeks za prev_any/prev_block
-- LATERAL-e u view-u. Najpre proveri postojeće indekse:
/*
SELECT indexname, indexdef FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'bigtehn_work_order_lines_cache';
*/
-- Ako nema (work_order_id, prioritet), dodati:
/*
CREATE INDEX CONCURRENTLY IF NOT EXISTS bigtehn_wo_lines_wo_prioritet_idx
  ON public.bigtehn_work_order_lines_cache (work_order_id, prioritet);
*/
-- Ovo bi išlo u poseban Sprint 1K+1.

NOTIFY pgrst, 'reload schema';

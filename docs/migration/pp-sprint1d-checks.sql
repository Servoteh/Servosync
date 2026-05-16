-- =====================================================================
-- PP Sprint 1D — EXPLAIN ANALYZE alat za M21 perf merenje
-- =====================================================================
-- Cilj: izmeriti realan plan i execution time plan_pp_open_ops_for_machine
-- RPC-a na top mašinama iz produkcije.
--
-- IZVRŠAVANJE: Jara ručno u Supabase SQL Editor-u, redom upita 1–7.
-- Rezultate prepisati u docs/migration/pp-sprint1d-status.md.
--
-- VAŽNO: svi upiti su READ-ONLY. EXPLAIN ANALYZE pokreće stvarni upit
-- (ne samo plan) — ali za SELECT/RPC pozive bez side-effecta to je
-- bezbedno. Statement timeout 180s je u rpc-u.
-- =====================================================================


-- --- 1. Najveća mašina (8.4, 4543 otvorenih operacija) ---
-- Očekivano: ako > 5s → potreban cover/partial indeks (Sprint 1E).
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT, VERBOSE, SETTINGS)
SELECT * FROM public.plan_pp_open_ops_for_machine('8.4'::text, 100, 0);


-- --- 2. Druga mašina (8.3, 3263 operacija) za poređenje ---
-- Pomaže da identifikujemo skaliranje (linearno N, sub-linearno, eksplozivno).
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT, VERBOSE)
SELECT * FROM public.plan_pp_open_ops_for_machine('8.3'::text, 100, 0);


-- --- 3. Direktan view query (bez RPC wrapper-a) — vidi LATERAL plan ---
-- Ovo je low-level pogled na sam view, bez paginacije po RN.
-- count(*) je dovoljan da pokrene sve LATERAL subselect-e.
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT count(*) FROM public.v_production_operations_effective
WHERE effective_machine_code = '8.4';


-- --- 4. Helper: top 3 RN-a na mašini 8.4 (za izolovani PP-A NOT EXISTS test) ---
-- Trebaće work_order_id u upitu #5 — kopirati prvi rezultat odavde.
SELECT work_order_id, count(*) as ops_count
FROM public.v_production_operations_effective
WHERE effective_machine_code = '8.4'
GROUP BY work_order_id
ORDER BY ops_count DESC, work_order_id
LIMIT 3;


-- --- 5. PP-A NOT EXISTS izolovan test ---
-- ZAMENI :WO_ID konkretnim work_order_id iz upita #4.
-- ZAMENI :OPERACIJA sa nekom srednjom vrednošću (npr. 5 ili 10) — to je
-- redni broj TP operacije za koju proveravamo "spremnost".
-- Ovo je tačan upit koji se izvršava unutar LATERAL u view-u, izolovan.
/*
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT NOT EXISTS (
  SELECT 1 FROM public.bigtehn_tech_routing_cache tr_rb
  WHERE tr_rb.work_order_id = :WO_ID
    AND tr_rb.operacija < :OPERACIJA
    AND tr_rb.is_completed IS FALSE
) AS is_ready_rb;
*/


-- --- 6. Indeks usage stats — koliki je hit rate na postojeće indekse? ---
-- Ako idx_scan = 0 za neki indeks → mrtav, kandidat za DROP.
-- Ako idx_scan visok ali idx_tup_fetch >> idx_tup_read → heap lookup overhead.
SELECT
  i.indexname,
  i.indexdef,
  s.idx_scan,
  s.idx_tup_read,
  s.idx_tup_fetch,
  pg_size_pretty(pg_relation_size(i.indexname::regclass)) AS index_size
FROM pg_indexes i
LEFT JOIN pg_stat_user_indexes s
  ON s.indexrelname = i.indexname AND s.schemaname = i.schemaname
WHERE i.schemaname = 'public'
  AND i.tablename = 'bigtehn_tech_routing_cache'
ORDER BY s.idx_scan DESC NULLS LAST;


-- --- 7. Tabela size + row count + bloat estimate ---
-- Daje kontekst za interpretaciju execution time-a.
-- Ako je tabela > 10 GB ili row count > 50M, optimizacije postaju kritičnije.
SELECT
  pg_size_pretty(pg_total_relation_size('public.bigtehn_tech_routing_cache')) AS total_size_with_indexes,
  pg_size_pretty(pg_relation_size('public.bigtehn_tech_routing_cache')) AS table_size,
  pg_size_pretty(pg_indexes_size('public.bigtehn_tech_routing_cache')) AS indexes_size,
  (SELECT count(*) FROM public.bigtehn_tech_routing_cache) AS row_count;


-- --- 8. Helper: koliko `is_completed = false` redova ima (relevantno za partial indeks) ---
-- Ako je incomplete < 30% od ukupnog, partial indeks daje veliki gain.
SELECT
  count(*) AS total_rows,
  count(*) FILTER (WHERE is_completed IS FALSE) AS incomplete_rows,
  count(*) FILTER (WHERE is_completed IS TRUE)  AS completed_rows,
  ROUND(100.0 * count(*) FILTER (WHERE is_completed IS FALSE) / NULLIF(count(*), 0), 1) AS incomplete_pct
FROM public.bigtehn_tech_routing_cache;


-- =====================================================================
-- TUMAČENJE REZULTATA
-- =====================================================================
--
-- Šta gledati u EXPLAIN ANALYZE output-u:
--   • "Planning Time"   — vreme za pravljenje plana (obično < 5 ms)
--   • "Execution Time"  — stvarno vreme izvršavanja (KLJUČNI metrik)
--   • "Buffers: shared hit=X read=Y" — hit = u shared_buffers, read = disk I/O
--     Ako read >> hit → tabela ne staje u memoriju, povećaj shared_buffers ili indeks.
--   • Node sa najvećim "actual time=X..Y" — bottleneck
--   • "Rows Removed by Filter" — koliko je redova proverno a odbačeno
--     Visoka vrednost → indeks ne pokriva filter dobro.
--
-- Pragovi za odluku (vidi pp-sprint1d-analysis.md):
--   < 1s   → status quo OK
--   1-5s   → kandidat za optimizaciju, ne hitno
--   > 5s   → Sprint 1E prioritet
--   > 60s  → kritičan fix, hitno
--
-- Ako su rezultati u zelenoj zoni: ZATVORI Sprint 1D bez daljih izmena.
-- Ako > 5s: Sprint 1E krećemo sa cover ili partial indeksom (vidi analizu).
--
-- Predlog migracije (NE izvršavati pre odluke):
/*
-- Opcija A: cover indeks
CREATE INDEX CONCURRENTLY IF NOT EXISTS bigtehn_tr_cache_wo_op_completed_idx
  ON public.bigtehn_tech_routing_cache (work_order_id, operacija)
  INCLUDE (is_completed);

-- Opcija B: partial indeks (samo nezavršeni)
CREATE INDEX CONCURRENTLY IF NOT EXISTS bigtehn_tr_cache_incomplete_wo_op_idx
  ON public.bigtehn_tech_routing_cache (work_order_id, operacija)
  WHERE is_completed = false;
*/

-- =====================================================================
-- Rezultati za zapis (template za pp-sprint1d-status.md)
-- =====================================================================
--
-- SQL #1 (RPC 8.4):
--   Planning Time: ___ ms
--   Execution Time: ___ ms
--   Top bottleneck node: ___
--   Buffers shared: hit=___ read=___
--
-- SQL #2 (RPC 8.3): Execution Time: ___ ms
--
-- SQL #3 (direct view 8.4): Execution Time: ___ ms
--
-- SQL #6 (indeks stats): bigtehn_tr_cache_wo_op_idx scan count = ___
--
-- SQL #7 (table size): total = ___ GB, rows = ___
--
-- SQL #8 (incomplete pct): incomplete = ___% (uticaj na partial indeks odluku)
--
-- ODLUKA: Sprint 1E [YES/NO/DELAYED]
--   Razlog: ___
-- =====================================================================

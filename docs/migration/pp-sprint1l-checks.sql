-- =====================================================================
-- PP Sprint 1L — perf dijagnoza posle 1K fail-a
-- =====================================================================
-- Cilj: identifikovati pravi bottleneck (LATERAL nested / plan cache /
-- susedni indeksi) pošto 1K partial indeks nije dao očekivani rezultat.
--
-- IZVRŠAVANJE: Jara ručno u Supabase SQL Editor-u (ili MCP execute_sql).
-- Rezultati u docs/migration/pp-sprint1l-status.md.
--
-- Svi upiti su READ-ONLY (EXPLAIN ANALYZE pokreće SELECT, ne menja state).
-- =====================================================================


-- --- 1. Direct view EXPLAIN (Sprint 1D SQL #3 koji nije izvršen) ---
-- Cilj: vidimo PRAVI plan, bez Function Scan obavijanja. Sve LATERAL-e
-- razvučene, svaki node ima actual time + buffers po sopstvenom skenu.
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT, VERBOSE)
SELECT count(*)
FROM public.v_production_operations_effective
WHERE effective_machine_code = '8.4';


-- --- 2. Indeksi na susednim tabelama ---
-- Tražimo (work_order_id, prioritet) ili sl. na lines cache.
-- Ako fali → prev_any/prev_block LATERAL radi seq scan po RN-u.
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('bigtehn_work_order_lines_cache', 'bigtehn_work_orders_cache')
ORDER BY tablename, indexname;


-- --- 3. Da li 1K partial indeks uopšte radi? ---
-- Ako idx_scan = 0 → planner ga ne koristi → plan cache problem (Hipoteza B)
-- ili partial filter ne matchuje EXISTS sintaksu.
SELECT
  indexrelname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch,
  pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE indexrelname = 'bigtehn_tr_cache_incomplete_wo_op_idx';


-- --- 4. Plan cache test (DISCARD PLANS pa ponovi RPC) ---
-- Ako se Execution Time drastično spušta → Hipoteza B (plan cache)
-- potvrđena. Onda treba ALTER FUNCTION sa plan_cache_mode.
DISCARD PLANS;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM public.plan_pp_open_ops_for_machine('8.4'::text, 100, 0);


-- --- 5. production.predmet_aktivacija indeks audit (Hipoteza C) ---
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'production'
  AND tablename = 'predmet_aktivacija'
ORDER BY indexname;


-- --- 6. (BONUS) Sa BUFFERS=true vidi se shared/temp split ---
-- Pomaže da znamo gde tačno se troši I/O.
-- Pokrenuti samo ako #1 nije dovoljno informativan.
/*
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON, VERBOSE)
SELECT * FROM public.v_production_operations_effective
WHERE effective_machine_code = '8.4'
LIMIT 100;
*/


-- =====================================================================
-- TUMAČENJE
-- =====================================================================
--
-- Od #1 (direct view EXPLAIN):
--   - Tražimo "Nested Loop" sa visokim "actual rows × loops" — to je
--     LATERAL koji se izvršava po-redu.
--   - Tražimo "Seq Scan on bigtehn_work_order_lines_cache" — to znači
--     indeks ne pokriva filter.
--   - "Bitmap Heap Scan" sa mnogo "Heap Blocks: exact=X" → I/O cost.
--
-- Od #2 (indeksi na lines cache):
--   - Ako nema indeksa koji počinje sa (work_order_id), prev_any/block
--     radi punu skanu lines cache-a po-redu. Tačno sa veličinom view-a.
--
-- Od #3 (1K indeks usage):
--   - idx_scan = 0 nakon nekoliko realnih pokušaja → plan cache (Hipoteza B)
--     ili planner nije prihvatio partial.
--   - idx_scan > 0 ali execution još uvek 24s → indeks radi, ali nije
--     bottleneck.
--
-- Od #4 (DISCARD PLANS test):
--   - Ako prelazi < 1s → Hipoteza B (sesija reset rešava). Trajna popravka:
--       ALTER FUNCTION public.plan_pp_open_ops_for_machine(text,integer,integer)
--         SET plan_cache_mode = force_custom_plan;
--   - Ako i dalje ~24s → Hipoteza A ili C.
--
-- Od #5 (predmet_aktivacija):
--   - Bez indeksa na (predmet_item_id), EXISTS pravi seq scan.
--   - Trivijalan fix:
--       CREATE INDEX ON production.predmet_aktivacija (predmet_item_id)
--         WHERE je_aktivan = true;
--
-- =====================================================================
-- Format za zapis u pp-sprint1l-status.md
-- =====================================================================
--
-- #1 plan (skraćen): _______
-- #2 lines cache indeksi: _______
-- #3 1K indeks idx_scan: _______ (broj)
-- #4 posle DISCARD PLANS, execution: _______ ms
-- #5 predmet_aktivacija indeksi: _______
--
-- ODLUKA Sprint 1M:
--   A. Indeks na lines cache (work_order_id, prioritet)
--   B. ALTER FUNCTION plan_cache_mode = force_custom_plan
--   C. Indeks na predmet_aktivacija (predmet_item_id)
--   D. Refaktor view-a (kombinuj prev_any+prev_block)
--   E. Materijalizovan view sa REFRESH na bridge sync
-- =====================================================================

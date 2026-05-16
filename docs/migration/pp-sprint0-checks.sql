-- =====================================================================
-- PP Sprint 0 — read-only DB checks
-- =====================================================================
-- Cilj: pre Sprint 1 izmena potvrditi da je trenutno stanje baze
-- onakvo kako audit dokument pretpostavlja (PP-A applied, indeksi
-- postoje, cross-module funkcije postoje, RLS policies konzistentne).
--
-- IZVRŠAVANJE: Jara ručno u Supabase SQL Editor-u, redom upita 1–10.
-- Rezultate prepisati u docs/migration/pp-sprint0-status.md.
--
-- NE PRAVI MIGRACIJU. SVI UPITI SU SELECT-ONLY.
-- =====================================================================


-- --- 1. PP-A: da li v_production_operations ima is_ready_for_machine? ---
-- Očekivano: oba reda prisutna (is_ready_for_machine + is_ready_for_processing back-compat).
-- Ako fali is_ready_for_machine → PP-A SQL nije izvršen.
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'v_production_operations'
  AND column_name IN ('is_ready_for_machine', 'is_ready_for_processing')
ORDER BY column_name;


-- --- 2. PP-A: da li v_production_operations_pre_g4 view postoji? ---
SELECT viewname,
       (definition LIKE '%is_ready_for_machine%') AS has_ready_for_machine_col
FROM pg_views
WHERE schemaname = 'public'
  AND viewname = 'v_production_operations_pre_g4';


-- --- 3. PP-A: definicija plan_pp_open_ops_for_machine — sadrži li novu kolonu? ---
-- Očekivano: pg_get_functiondef vraća telo koje filtrira po effective_machine_code
-- i koristi v_production_operations_effective (ne stari is_ready_for_processing direktno).
SELECT pg_get_functiondef(p.oid) AS func_def
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'plan_pp_open_ops_for_machine';


-- --- 4. Cross-module dependencies: postoje li funkcije iz drugih modula? ---
-- Očekivano: 4 reda (sve su prisutne). Ako bilo koja fali → migration order problem.
SELECT n.nspname || '.' || p.proname AS fullname,
       p.prosecdef AS is_definer,
       p.proconfig AS config_settings
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE (n.nspname = 'production' AND p.proname = '_pracenje_line_is_final_control')
   OR (n.nspname = 'public'     AND p.proname = 'current_user_is_admin')
   OR (n.nspname = 'public'     AND p.proname = 'can_edit_plan_proizvodnje')
   OR (n.nspname = 'public'     AND p.proname = 'can_force_plan_reassign')
ORDER BY fullname;


-- --- 5. SECURITY DEFINER PP funkcije: imaju li SET search_path? ---
-- Očekivano: proconfig sadrži 'search_path=public, auth, pg_temp' (ili sličnu vrednost).
-- Ako proconfig IS NULL na bilo kojoj DEFINER funkciji → pg_temp trojanac mogućnost.
SELECT p.proname,
       p.prosecdef AS is_definer,
       p.proconfig AS config_settings
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.proname IN (
    'reassign_production_line',
    'bulk_reassign_production_lines',
    'mark_in_progress_from_tech_routing',
    'can_edit_plan_proizvodnje',
    'can_force_plan_reassign'
  )
ORDER BY p.proname;


-- --- 6. Indeks na bigtehn_tech_routing_cache (kritičan za PP-A NOT EXISTS) ---
-- Očekivano: indeks koji počinje sa (work_order_id, operacija) i opciono uključuje is_completed.
-- Ako nema → PP-A NOT EXISTS može da postane O(N²) na velikim cache-evima.
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'bigtehn_tech_routing_cache'
ORDER BY indexname;


-- --- 7. GRANT-ovi na production_reassign_audit ---
-- Očekivano (cilj): write privilegije SAMO za service_role; authenticated samo SELECT (kroz RLS).
-- Trenutno (audit pretpostavlja): authenticated ima INSERT/UPDATE/DELETE jer RLS gleda write,
-- a nije explicit REVOKE — proveri.
SELECT grantee, privilege_type
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND table_name = 'production_reassign_audit'
ORDER BY grantee, privilege_type;


-- --- 8. archived_at flow — ima li bilo koji red sa archived_at IS NOT NULL? ---
-- Očekivano: ako 0 → kolona je mrtva (nijedan code path ne postavlja).
-- Ako > 0 → neko (verovatno ručno ili stara skripta) postavlja, treba istražiti ko.
SELECT count(*)                                       AS total_rows,
       count(*) FILTER (WHERE archived_at IS NOT NULL) AS archived_total,
       count(*) FILTER (WHERE archived_at IS NULL)     AS active_total
FROM public.production_overlays;


-- --- 9. Orphan assigned_machine_code (H8) ---
-- Očekivano: 0 — sve assigned mašine i dalje postoje u cache-u.
-- Ako > 0 → bridge je izbacio mašinu a overlay je ostao; izveštaji su pogrešni.
SELECT count(*) AS orphan_count
FROM public.production_overlays po
WHERE po.assigned_machine_code IS NOT NULL
  AND po.archived_at IS NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.bigtehn_machines_cache m
    WHERE m.rj_code = po.assigned_machine_code
  );


-- --- 10. RLS politike na production_reassign_audit ---
-- Očekivano: 1 SELECT policy (can_force_plan_reassign). Ako nema EXPLICITNE write policy →
-- pisanje iz DEFINER RPC-a radi, ali default deny je jedini čuvar. Treba ili explicit
-- WITH CHECK(false) policy ili REVOKE.
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'production_reassign_audit'
ORDER BY cmd, policyname;


-- --- 11. (BONUS) Veličina v_production_operations — bazni broj operacija ---
-- Korisno za procenu performansi PP-A NOT EXISTS pre Sprint 1.
SELECT count(*) AS total_open_ops
FROM public.v_production_operations_effective;


-- --- 12. (BONUS) Broj distinct mašina sa otvorenim operacijama ---
SELECT count(DISTINCT effective_machine_code) AS distinct_machines
FROM public.v_production_operations_effective
WHERE effective_machine_code IS NOT NULL;


-- --- 13. (BONUS) Distribucija operacija po mašini — top 10 ---
-- Pomaže za H21/M21 (performance plan_pp_open_ops_for_machine sa 5K+ ops).
SELECT effective_machine_code,
       count(*) AS open_ops_count
FROM public.v_production_operations_effective
WHERE effective_machine_code IS NOT NULL
GROUP BY effective_machine_code
ORDER BY open_ops_count DESC
LIMIT 10;

-- =====================================================================
-- Posle izvršavanja: rezultati idu u docs/migration/pp-sprint0-status.md
-- =====================================================================

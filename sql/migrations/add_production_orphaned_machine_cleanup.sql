-- =====================================================================
-- PP Sprint 1H (H8): Cleanup orphan assigned_machine_code u overlay-u
-- =====================================================================
-- Noćni pg_cron job koji vraća production_overlays.assigned_machine_code
-- na NULL (= koristi originalnu mašinu) za sve redove gde assigned mašina
-- više ne postoji u bigtehn_machines_cache.
--
-- Insurance policy: Sprint 0 SQL #9 pokazao 0 orphan-a, ali bridge sync
-- može u budućnosti da ukloni mašinu iz BigTehn-a. Overlay tada postaje
-- "orphan" i izveštaji su pogrešni — cleanup vraća na originalnu mašinu,
-- šef može da ručno ponovi REASSIGN ako želi.
--
-- DRAFT — NE izvršavati automatski; ručno aplicirati u Supabase Studio.
-- Preduslov: Supabase PAID tier (pg_cron extension).
-- Zavisnost: Sprint 1G (M11 history) treba da bude apliciran pre, da
-- bi cleanup promene išle u history tabelu sa odgovarajućim changed_by.
-- =====================================================================


-- ─────────────────────────────────────────────────────────────────────
-- 1. pg_cron extension (verovatno već apliciran iz Lokacije migracija)
-- ─────────────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;


-- ─────────────────────────────────────────────────────────────────────
-- 2. Cron-only cleanup funkcija
-- ─────────────────────────────────────────────────────────────────────
-- SECURITY DEFINER + REVOKE od authenticated — zove se SAMO iz cron-a
-- pod Postgres superuser identitetom. Pattern preuzet iz Lokacije
-- (add_loc_step4_pgcron.sql).

CREATE OR REPLACE FUNCTION public._po_cleanup_orphaned_machines_cron()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cleaned integer;
BEGIN
  UPDATE public.production_overlays po
     SET assigned_machine_code = NULL,
         updated_by            = 'system:cleanup:orphaned-machines'
   WHERE po.assigned_machine_code IS NOT NULL
     AND po.archived_at IS NULL
     AND NOT EXISTS (
       SELECT 1 FROM public.bigtehn_machines_cache m
       WHERE m.rj_code = po.assigned_machine_code
     );
  GET DIAGNOSTICS v_cleaned = ROW_COUNT;

  /* Audit ide kroz production_overlays_history trigger (Sprint 1G).
     Cron metrika ostaje u cron.job_run_details. */
  RETURN v_cleaned;
END;
$$;

REVOKE ALL ON FUNCTION public._po_cleanup_orphaned_machines_cron() FROM PUBLIC;
REVOKE ALL ON FUNCTION public._po_cleanup_orphaned_machines_cron() FROM anon, authenticated;

COMMENT ON FUNCTION public._po_cleanup_orphaned_machines_cron() IS
  'H8 internal cron-only helper. Vraća assigned_machine_code na NULL ako mašina više ne postoji u bigtehn_machines_cache. NE zovi direktno — koristi se iz pg_cron job-a "po_cleanup_orphaned_machines".';


-- ─────────────────────────────────────────────────────────────────────
-- 3. Scheduled job: 02:30 UTC svaki dan
-- ─────────────────────────────────────────────────────────────────────
-- Različito od Lokacije retention job-a (03:15) da se ne pretrpa baza.
-- Idempotent unschedule pre re-apply-a.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'po_cleanup_orphaned_machines') THEN
    PERFORM cron.unschedule('po_cleanup_orphaned_machines');
  END IF;
EXCEPTION
  WHEN undefined_table THEN
    /* cron.job nije vidljiv (npr. pg_cron nije instaliran / nema privilegija).
       SELECT cron.schedule(...) ispod će svejedno pokušati i dati jasnu grešku. */
    NULL;
  WHEN insufficient_privilege THEN
    NULL;
END $$;

SELECT cron.schedule(
  'po_cleanup_orphaned_machines',
  '30 2 * * *',
  $cron$SELECT public._po_cleanup_orphaned_machines_cron()$cron$
);


-- =====================================================================
-- VERIFIKACIJA (posle apply-a)
-- =====================================================================
--
-- Schedule postoji:
/*
SELECT jobid, jobname, schedule, active
FROM cron.job
WHERE jobname = 'po_cleanup_orphaned_machines';
-- Očekivano: 1 red, active = TRUE, schedule = '30 2 * * *'
*/
--
-- Manual trigger (van schedule-a, za smoke test):
/*
SELECT public._po_cleanup_orphaned_machines_cron();
-- Očekivano: 0 (Sprint 0 SQL #9 = 0 orphan-a)
*/
--
-- Funkcija je REVOKE-ovana od authenticated:
/*
SELECT grantee, privilege_type
FROM information_schema.routine_privileges
WHERE routine_name = '_po_cleanup_orphaned_machines_cron';
-- Očekivano: nema reda za authenticated/anon
*/
--
-- Posle prvog cron run-a, vidi rezultat:
/*
SELECT start_time, end_time, status, return_message
FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'po_cleanup_orphaned_machines')
ORDER BY start_time DESC LIMIT 5;
*/
--
-- Test M11 audit integracije (posle prvog real orphan-a):
/*
SELECT changed_at, work_order_id, line_id, old_value, new_value, changed_by
FROM production_overlays_history
WHERE field_name = 'assigned_machine_code'
  AND changed_by = 'system:cleanup:orphaned-machines'
ORDER BY changed_at DESC LIMIT 20;
*/
--
-- =====================================================================
-- ROLLBACK (ako bude potrebno)
-- =====================================================================
/*
SELECT cron.unschedule('po_cleanup_orphaned_machines');
DROP FUNCTION IF EXISTS public._po_cleanup_orphaned_machines_cron();
*/
-- =====================================================================

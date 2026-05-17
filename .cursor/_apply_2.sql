-- =====================================================================
-- PP Sprint 1E — Security hardening (L5 + H5 + H9)
-- =====================================================================
-- Tri SQL-only hardening izmene u jednoj migraciji:
--
-- L5: pg_temp u search_path-u SECURITY DEFINER gate funkcija
--     (can_edit_plan_proizvodnje, can_force_plan_reassign)
-- H5: explicit REVOKE INSERT/UPDATE/DELETE od authenticated/anon
--     na production_reassign_audit (defense-in-depth)
-- H9: CHECK constraint na production_drawings.storage_path
--     (path traversal — '..', '//')
--
-- DRAFT — NE izvršavati automatski; ručno aplicirati u Supabase Studio.
--
-- VAŽNO: pre H9 ALTER-a, izvršiti pre-flight SELECT (komentar pre
-- ADD CONSTRAINT bloka) da se potvrdi da svi postojeći redovi
-- match-uju regex. Ako postoje mismatch redovi, ALTER će failovati.
-- =====================================================================


-- ─────────────────────────────────────────────────────────────────────
-- L5: pg_temp u search_path-u gate funkcija
-- ─────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.can_edit_plan_proizvodnje()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles ur
    WHERE LOWER(ur.email) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
      AND ur.is_active = TRUE
      AND ur.role IN ('admin', 'pm', 'menadzment')
  );
$$;

COMMENT ON FUNCTION public.can_edit_plan_proizvodnje() IS
  'TRUE ako je trenutno autentifikovani user admin, pm (šef mašinske obrade) ili menadzment. Sprint 1E: search_path uključuje pg_temp radi konzistentnosti sa G5/G6 RPC-ima.';

GRANT EXECUTE ON FUNCTION public.can_edit_plan_proizvodnje() TO authenticated;


CREATE OR REPLACE FUNCTION public.can_force_plan_reassign()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles ur
    WHERE lower(ur.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      AND ur.is_active IS TRUE
      AND ur.role IN ('admin', 'menadzment')
  );
$$;

COMMENT ON FUNCTION public.can_force_plan_reassign() IS
  'TRUE za aktivne admin ili menadzment korisnike koji smeju da forsiraju REASSIGN preko različitih grupa mašina. Sprint 1E: search_path uključuje pg_temp.';

GRANT EXECUTE ON FUNCTION public.can_force_plan_reassign() TO authenticated;


-- ─────────────────────────────────────────────────────────────────────
-- H5: REVOKE write na production_reassign_audit
-- ─────────────────────────────────────────────────────────────────────
-- RLS politike već blokiraju (pra_no_client_write/update/delete sa
-- USING/WITH CHECK false). Ovaj REVOKE je defense-in-depth: ako neko
-- ikad DISABLE ROW LEVEL SECURITY za debug, tabela ostaje zaštićena.
-- DEFINER RPC (reassign_production_line) i dalje upisuje normalno jer
-- bypass-uje GRANT/RLS check.

REVOKE INSERT, UPDATE, DELETE, TRUNCATE
  ON public.production_reassign_audit
  FROM authenticated, anon;

-- service_role i postgres zadržavaju write (potrebno za migration jobs
-- i SECURITY DEFINER ownership). Ne diramo ih eksplicitno.


-- ─────────────────────────────────────────────────────────────────────
-- H9: CHECK constraint za storage_path (path traversal)
-- ─────────────────────────────────────────────────────────────────────
-- Realan format iz app sloja: <work_order_id>/<line_id>/<uuid12>_<safeName>
-- gde:
--   - work_order_id i line_id su numerički
--   - uuid12 je 12 hex karaktera (crypto.randomUUID bez crtica, sliced)
--   - safeName je sanitizovan u JS-u (\w + . + -) i ograničen na 80 char
-- Regex pokriva: ^[0-9]+/[0-9]+/[A-Za-z0-9._-]+$
-- Drugi uslov: !~ '\.\.' blokira ".." unutar bilo kog segmenta
-- (jer Postgres POSIX regex ne podržava negative lookahead).

-- ── PRE-FLIGHT (pokrenuti pre ADD CONSTRAINT) ────────────────────────
-- Treba da vrati 0 redova. Ako vraća > 0, ALTER će failovati i mora
-- prvo da se reše postojeći redovi.
/*
SELECT id, storage_path
FROM public.production_drawings
WHERE NOT (
  storage_path ~ '^[0-9]+/[0-9]+/[A-Za-z0-9._-]+$'
  AND storage_path !~ '\.\.'
)
LIMIT 20;
*/

ALTER TABLE public.production_drawings
  ADD CONSTRAINT pd_storage_path_safe CHECK (
    storage_path ~ '^[0-9]+/[0-9]+/[A-Za-z0-9._-]+$'
    AND storage_path !~ '\.\.'
  );

COMMENT ON CONSTRAINT pd_storage_path_safe ON public.production_drawings IS
  'H9: sprečava path traversal. Format mora biti <wo>/<line>/<safeName>; ".." je zabranjen u svim segmentima.';


-- ─────────────────────────────────────────────────────────────────────
-- PostgREST schema reload (function signatures se ne menjaju, ali za
-- svaki slučaj — proconfig promene se vide u introspection)
-- ─────────────────────────────────────────────────────────────────────

NOTIFY pgrst, 'reload schema';


-- =====================================================================
-- VERIFIKACIJA (posle apply-a)
-- =====================================================================
--
-- L5 - search_path proveri:
/*
SELECT p.proname, p.proconfig
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
WHERE n.nspname='public'
  AND p.proname IN ('can_edit_plan_proizvodnje', 'can_force_plan_reassign');
-- Očekivano: proconfig sadrži "search_path=public, pg_temp"
*/
--
-- H5 - GRANT proveri:
/*
SELECT grantee, privilege_type
FROM information_schema.table_privileges
WHERE table_schema='public' AND table_name='production_reassign_audit'
ORDER BY grantee, privilege_type;
-- Očekivano: authenticated i anon imaju samo SELECT
*/
--
-- H9 - CHECK constraint test:
/*
-- Pozitivan test: legitimna putanja prolazi
SELECT '12345/678/abc123_drawing.pdf' ~ '^[0-9]+/[0-9]+/[A-Za-z0-9._-]+$'
   AND '12345/678/abc123_drawing.pdf' !~ '\.\.'; -- treba TRUE

-- Negativan test: path traversal blokiran
SELECT '12345/678/../etc/passwd' ~ '^[0-9]+/[0-9]+/[A-Za-z0-9._-]+$'
   AND '12345/678/../etc/passwd' !~ '\.\.'; -- treba FALSE (regex fail)
SELECT '12345/678/abc..pdf' !~ '\.\.'; -- treba FALSE (blokira ".." u sredini)
*/
--
-- Funkcionalni smoke test (UI):
--   1. Login kao pm/admin
--   2. Otvori Plan proizvodnje → Po mašini → izaberi RN
--   3. Upload skicu (📎) → ide u Storage i tabelu
--   4. Force reassign sa razlogom → kreira se audit red
--   5. Sve i dalje radi kao pre.
-- =====================================================================

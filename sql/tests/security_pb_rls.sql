-- ============================================================================
-- pgTAP: pb_tasks RLS + editor krug (has_edit_role paritet preko pb_can_edit_tasks)
-- ============================================================================
-- Zahteva primenjene migracije: add_pb_module.sql posle add_menadzment_full_edit_kadrovska,
-- enable_user_roles_rls_proper, add_audit_log.
--
-- JWT simulacija: request.jwt.claims GUC (sql/ci/00_bootstrap.sql stub auth.jwt()).
-- ============================================================================

BEGIN;
SET search_path = public, extensions;

SELECT plan(5);

-- ─── Seed: user_roles (admin piše posle enable_user_roles_rls_proper) ─────
SET LOCAL row_security = off;
INSERT INTO public.user_roles (email, role, project_id, is_active) VALUES
  ('pb-viewer@test.local', 'viewer', NULL, true),
  ('pb-pm@test.local',     'pm',     NULL, true)
ON CONFLICT (email) DO NOTHING;
SET LOCAL row_security = on;

-- ─── Seed: projekat + zaposleni + jedan zadatak (kao postgres) ────────────
INSERT INTO public.projects (id, project_code, project_name, status)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'PB-TST',
  'Test projekat',
  'active'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.employees (id, full_name, department, is_active)
VALUES (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'Test Inženjer',
  'Projektovanje',
  true
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.pb_tasks (
  id, naziv, project_id, employee_id, deleted_at
) VALUES (
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'Seed zadatak',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  NULL
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.pb_tasks (
  id, naziv, project_id, deleted_at
) VALUES (
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'Soft obrisan',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  now()
) ON CONFLICT (id) DO NOTHING;

-- =========================================================================
-- 1) Anon nema GRANT na pb_tasks → SELECT mora pasti
-- =========================================================================
RESET ROLE;
SET LOCAL ROLE anon;

SELECT throws_ok(
  'SELECT count(*)::int FROM public.pb_tasks',
  '42501',
  NULL,
  'anon NE može SELECT iz pb_tasks (permission denied)'
);

RESET ROLE;

-- =========================================================================
-- 2) Authenticated viewer — SELECT vidljivih redova
-- =========================================================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('email','pb-viewer@test.local')::text,
                  true);

SELECT cmp_ok(
  (SELECT count(*)::int FROM public.pb_tasks WHERE deleted_at IS NULL),
  '>=',
  1,
  'viewer (authenticated) može SELECT nad pb_tasks (barem seed)'
);

-- =========================================================================
-- 3) Viewer NE može INSERT
-- =========================================================================
SELECT throws_ok(
  $$ INSERT INTO public.pb_tasks (naziv, project_id)
     VALUES ('x', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') $$,
  '42501',
  NULL,
  'viewer bez edit prava NE može INSERT u pb_tasks'
);

-- =========================================================================
-- 4) PM može INSERT
-- =========================================================================
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('email','pb-pm@test.local')::text,
                  true);

SELECT lives_ok(
  $$ INSERT INTO public.pb_tasks (naziv, project_id)
     VALUES ('PM unos', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') $$,
  'pm sa has_edit_role MOŽE INSERT u pb_tasks'
);

-- =========================================================================
-- 5) Soft-deleted red se ne vidi u SELECT
-- =========================================================================
SELECT is(
  (SELECT count(*)::int FROM public.pb_tasks WHERE id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'),
  0,
  'soft-deleted zadatak NE ulazi u SELECT (deleted_at IS NOT NULL)'
);

SELECT * FROM finish();
ROLLBACK;

-- ============================================================================
-- pgTAP: PB4 pb_work_reports RLS (select po ulozi, insert/update/delete)
-- ============================================================================
-- Zahteva: sql/ci bootstrap + add_menadzment_full_edit_kadrovska +
--          enable_user_roles_rls_proper + add_pb_module + add_pb_notifications +
--          add_pb4_rls_and_agg.sql
--
-- JWT: request.jwt.claims GUC (sql/ci/00_bootstrap.sql stub auth.jwt()).
-- ============================================================================

BEGIN;
SET search_path = public, extensions;

SELECT plan(8);

-- ─── Seed (postgres bypass RLS gde treba) ───────────────────────────────────
SET LOCAL row_security = off;

INSERT INTO public.user_roles (email, role, project_id, is_active) VALUES
  ('pb4-hr-a@test.local', 'hr', NULL, true),
  ('pb4-hr-b@test.local', 'hr', NULL, true),
  ('pb4-admin@test.local', 'admin', NULL, true),
  ('pb4-leadpm@test.local', 'leadpm', NULL, true),
  ('pb4-mng@test.local', 'menadzment', NULL, true)
ON CONFLICT (email) DO NOTHING;

INSERT INTO public.employees (id, full_name, department, email, is_active)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'PB4 HR A', 'X', 'pb4-hr-a@test.local', true),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'PB4 HR B', 'X', 'pb4-hr-b@test.local', true)
ON CONFLICT (id) DO NOTHING;

DELETE FROM public.pb_work_reports WHERE employee_id IN (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid
);

INSERT INTO public.pb_work_reports (employee_id, datum, sati, opis, created_by)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', CURRENT_DATE - 1, 2.0, 'r1', 'pb4-hr-a@test.local'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', CURRENT_DATE - 2, 1.5, 'r2', 'pb4-hr-a@test.local'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', CURRENT_DATE - 1, 3.0, 'r3', 'pb4-hr-b@test.local');

SET LOCAL row_security = on;

-- Test 1: HR A vidi samo svoja 2 izveštaja
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  jsonb_build_object('email', 'pb4-hr-a@test.local')::text,
  true
);

SELECT is(
  (SELECT count(*)::int FROM public.pb_work_reports),
  2,
  'HR A vidi samo svoja 2 pb_work_reports'
);

-- Test 2: Nema redova za employee B kada filtriraš po B (RLS već ograničava — probaj direktan id)
SELECT is(
  (SELECT count(*)::int FROM public.pb_work_reports WHERE employee_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid),
  0,
  'HR A ne vidi izveštaje zaposlenog B'
);

-- Test 3: Admin vidi sve 3
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  jsonb_build_object('email', 'pb4-admin@test.local')::text,
  true
);

SELECT is(
  (SELECT count(*)::int FROM public.pb_work_reports),
  3,
  'Admin vidi sve izveštaje'
);

-- Test 4: leadpm vidi sve
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  jsonb_build_object('email', 'pb4-leadpm@test.local')::text,
  true
);

SELECT is(
  (SELECT count(*)::int FROM public.pb_work_reports),
  3,
  'leadpm vidi sve izveštaje'
);

-- Test 5: menadzment vidi sve
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  jsonb_build_object('email', 'pb4-mng@test.local')::text,
  true
);

SELECT is(
  (SELECT count(*)::int FROM public.pb_work_reports),
  3,
  'menadzment vidi sve izveštaje'
);

-- Test 6: HR A može INSERT za sebe
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  jsonb_build_object('email', 'pb4-hr-a@test.local')::text,
  true
);

SELECT lives_ok(
  $$ INSERT INTO public.pb_work_reports (employee_id, datum, sati, opis)
     VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', CURRENT_DATE, 1.0, 'ins own') $$,
  'HR A može INSERT sopstvenog izveštaja'
);

-- Test 7: HR A ne može INSERT za tuđeg zaposlenog
SELECT throws_ok(
  $$ INSERT INTO public.pb_work_reports (employee_id, datum, sati, opis)
     VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', CURRENT_DATE, 1.0, 'hack') $$,
  '42501',
  NULL,
  'HR A ne može INSERT za tuđi employee_id'
);

-- Test 8: pb_current_employee_id NULL za korisnika bez employees reda
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  jsonb_build_object('email', 'no-employee-user@test.local')::text,
  true
);

SELECT is(
  public.pb_current_employee_id(),
  NULL::uuid,
  'pb_current_employee_id NULL bez employee rekorda'
);

SELECT * FROM finish();
ROLLBACK;

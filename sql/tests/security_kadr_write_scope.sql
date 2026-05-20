-- ============================================================================
-- pgTAP: Kadrovska write RLS — menadžment scope (Faza 2.2)
-- ============================================================================
-- Preduslov: extend_kadr_managed_departments_scope.sql +
--            harden_kadr_menadzment_write_scope.sql +
--            ostale Kadrovska DDL migracije.
--
-- Ručno: psql … -v ON_ERROR_STOP=1 -f sql/tests/security_kadr_write_scope.sql
-- ============================================================================

BEGIN;
SET search_path = public, extensions;

SELECT plan(18);

ALTER TABLE public.user_roles
  ADD COLUMN IF NOT EXISTS managed_departments TEXT[];

ALTER TABLE public.user_roles
  ADD COLUMN IF NOT EXISTS managed_sub_department_ids int[];

SET LOCAL row_security = off;

INSERT INTO public.sub_departments (id, department_id, name, sort_order)
VALUES
  (640001, 5, 'KWR_Prod_Sub', 0),
  (640002, 5, 'KWR_Kom_Sub', 0)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO public.user_roles (
  email, role, project_id, is_active, managed_departments, managed_sub_department_ids
)
VALUES
  ('kadr-write-admin@test.local', 'admin', NULL, true, NULL, NULL),
  ('kadr-write-hr@test.local', 'hr', NULL, true, NULL, NULL),
  ('kadr-write-mgr1@test.local', 'menadzment', NULL, true, ARRAY['Proizvodnja']::text[], ARRAY[640001]::int[]),
  ('kadr-write-mgr3@test.local', 'menadzment', NULL, true, NULL, NULL),
  ('kadr-write-pm@test.local', 'pm', NULL, true, NULL, NULL),
  ('kadr-write-viewer-self@test.local', 'viewer', NULL, true, NULL, NULL)
ON CONFLICT (email) DO UPDATE SET
  role = EXCLUDED.role,
  is_active = EXCLUDED.is_active,
  managed_departments = EXCLUDED.managed_departments,
  managed_sub_department_ids = EXCLUDED.managed_sub_department_ids;

INSERT INTO public.employees (id, full_name, department, email, is_active, sub_department_id)
VALUES
  ('eeeeeeee-1111-1111-1111-111111111101', 'Radnik Proizvodnja', 'Proizvodnja', 'emp-prod-kwr@test.local', true, 640001),
  ('eeeeeeee-2222-2222-2222-222222222202', 'Radnik Komercijala', 'Komercijala', 'emp-kom-kwr@test.local', true, 640002),
  ('eeeeeeee-3333-3333-3333-333333333303', 'Sam Viewer', 'Proizvodnja', 'kadr-write-viewer-self@test.local', true, 640001)
ON CONFLICT (id) DO UPDATE SET
  sub_department_id = EXCLUDED.sub_department_id,
  department = EXCLUDED.department,
  is_active = EXCLUDED.is_active;

INSERT INTO public.absences (id, employee_id, type, date_from, date_to, days_count, note)
VALUES
  ('aaaaaaaa-1111-1111-1111-111111111101', 'eeeeeeee-1111-1111-1111-111111111101', 'godisnji', '2026-06-01', '2026-06-03', 3, 'kwr abs prod'),
  ('aaaaaaaa-2222-2222-2222-222222222202', 'eeeeeeee-2222-2222-2222-222222222202', 'godisnji', '2026-06-01', '2026-06-02', 2, 'kwr abs kom')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.vacation_entitlements (id, employee_id, year, days_total, days_carried_over, note)
VALUES
  ('bbbbbbbb-1111-1111-1111-111111111101', 'eeeeeeee-1111-1111-1111-111111111101', 2026, 20, 0, 've prod'),
  ('bbbbbbbb-2222-2222-2222-222222222202', 'eeeeeeee-2222-2222-2222-222222222202', 2026, 20, 0, 've kom')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.employee_children (id, employee_id, first_name, birth_date)
VALUES
  ('cccccccc-1111-1111-1111-111111111101', 'eeeeeeee-1111-1111-1111-111111111101', 'Dete', '2015-01-01')
ON CONFLICT (id) DO NOTHING;

DELETE FROM public.vacation_requests
WHERE id = 'dddddddd-9999-9999-9999-999999999999';

SET LOCAL row_security = on;

CREATE OR REPLACE FUNCTION test_set_jwt_email(p_email text)
RETURNS void LANGUAGE sql AS $$
  SELECT set_config(
    'request.jwt.claims',
    jsonb_build_object('email', p_email)::text,
    true
  );
$$;

CREATE OR REPLACE FUNCTION test_clear_jwt()
RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims', '', true);
$$;

-- 1–2) menadzment-1 (scope Proizvodnja)
SELECT test_set_jwt_email('kadr-write-mgr1@test.local');
SELECT is(
  (WITH _u AS (
    UPDATE public.absences SET note = 'kwr touch prod'
    WHERE id = 'aaaaaaaa-1111-1111-1111-111111111101'::uuid
    RETURNING 1
  ) SELECT count(*)::int FROM _u),
  1,
  'menadzment-1: UPDATE absences za Proizvodnju → 1 red'
);

SELECT is(
  (WITH _u2 AS (
    UPDATE public.absences SET note = 'kwr illegal'
    WHERE id = 'aaaaaaaa-2222-2222-2222-222222222202'::uuid
    RETURNING 1
  ) SELECT count(*)::int FROM _u2),
  0,
  'menadzment-1: UPDATE absences za Komercijalu → 0 redova'
);

-- 3) menadzment-1 DELETE vacation_entitlement van scope-a
SELECT is(
  (WITH _d1 AS (
    DELETE FROM public.vacation_entitlements
    WHERE id = 'bbbbbbbb-2222-2222-2222-222222222202'::uuid
    RETURNING 1
  ) SELECT count(*)::int FROM _d1),
  0,
  'menadzment-1: DELETE vacation_entitlement van scope-a → 0 redova'
);

-- 4–5) menadzment-1 ne sme INSERT/DELETE employees
SELECT throws_ok(
  $q$
    INSERT INTO public.employees (id, full_name, department, email)
    VALUES ('eeeeeeee-9999-9999-9999-999999999999', 'Novi', 'Proizvodnja', 'novi-kwr@test.local');
  $q$,
  '42501',
  NULL,
  'menadzment-1: INSERT employees → RLS (42501)'
);

SELECT is(
  (WITH _de AS (
    DELETE FROM public.employees
    WHERE id = 'eeeeeeee-2222-2222-2222-222222222202'::uuid
    RETURNING 1
  ) SELECT count(*)::int FROM _de),
  0,
  'menadzment-1: DELETE employees → 0 redova'
);

-- 6) menadzment-3 (NULL scope legacy) UPDATE Komercijala
SELECT test_set_jwt_email('kadr-write-mgr3@test.local');
SELECT is(
  (WITH _u3 AS (
    UPDATE public.absences SET note = 'kwr null scope'
    WHERE id = 'aaaaaaaa-2222-2222-2222-222222222202'::uuid
    RETURNING 1
  ) SELECT count(*)::int FROM _u3),
  1,
  'menadzment-3 (NULL scope): UPDATE absences Komercijala → 1 red'
);

-- 7–8) HR i admin
SELECT test_set_jwt_email('kadr-write-hr@test.local');
SELECT is(
  (WITH _hr AS (
    UPDATE public.absences SET note = 'kwr hr'
    WHERE id = 'aaaaaaaa-2222-2222-2222-222222222202'::uuid
    RETURNING 1
  ) SELECT count(*)::int FROM _hr),
  1,
  'HR: UPDATE bilo koje odsustvo → 1 red'
);

SELECT test_set_jwt_email('kadr-write-admin@test.local');
SELECT is(
  (WITH _ad AS (
    INSERT INTO public.absences (id, employee_id, type, date_from, date_to, days_count, note)
    VALUES (
      'aaaaaaaa-3333-3333-3333-333333333303',
      'eeeeeeee-2222-2222-2222-222222222202',
      'godisnji',
      '2026-08-01',
      '2026-08-02',
      2,
      'admin insert'
    )
    RETURNING 1
  ) SELECT count(*)::int FROM _ad),
  1,
  'admin: INSERT absences → 1 red'
);

-- 9) viewer ne menja
SELECT test_set_jwt_email('kadr-write-viewer-self@test.local');
SELECT is(
  (WITH _vw AS (
    UPDATE public.absences SET note = 'kwr viewer'
    WHERE id = 'aaaaaaaa-1111-1111-1111-111111111101'::uuid
    RETURNING 1
  ) SELECT count(*)::int FROM _vw),
  0,
  'viewer: UPDATE absences → 0 redova'
);

-- 10) current_user_is_hr() za menadzment = false (regresija)
SELECT test_set_jwt_email('kadr-write-mgr1@test.local');
SELECT is(public.current_user_is_hr(), false,
  'current_user_is_hr() za ulogu menadzment → false'
);

-- 11) current_user_is_hr() za HR = true
SELECT test_set_jwt_email('kadr-write-hr@test.local');
SELECT is(public.current_user_is_hr(), true,
  'current_user_is_hr() za hr → true'
);

-- 12) vr_insert self-submit (viewer + submitted_by = jwt)
SELECT test_set_jwt_email('kadr-write-viewer-self@test.local');
SELECT is(
  (WITH _vr AS (
    INSERT INTO public.vacation_requests (
      id, employee_id, year, date_from, date_to, days_count, note, status, submitted_by
    )
    VALUES (
      'dddddddd-9999-9999-9999-999999999999',
      'eeeeeeee-3333-3333-3333-333333333303',
      2026,
      '2026-07-01',
      '2026-07-10',
      8,
      'self GO',
      'pending',
      'kadr-write-viewer-self@test.local'
    )
    RETURNING 1
  ) SELECT count(*)::int FROM _vr),
  1,
  'vr_insert: self-submit (submitted_by = jwt) za viewer → 1 red'
);

-- 13) employee_children: HR ne vidi red (admin-only u restrict_employee_pii)
SELECT test_set_jwt_email('kadr-write-hr@test.local');
SELECT is(
  (SELECT count(*)::int FROM public.employee_children
   WHERE id = 'cccccccc-1111-1111-1111-111111111101'::uuid),
  0,
  'HR: SELECT employee_children → 0 redova (admin-only)'
);

-- 14) PM: INSERT absence za Komercijala
SELECT test_set_jwt_email('kadr-write-pm@test.local');
SELECT is(
  (WITH _pm AS (
    INSERT INTO public.absences (id, employee_id, type, date_from, date_to, days_count, note)
    VALUES (
      'aaaaaaaa-4444-4444-4444-444444444404',
      'eeeeeeee-2222-2222-2222-222222222202',
      'godisnji',
      '2026-09-01',
      '2026-09-02',
      2,
      'pm insert kom'
    )
    RETURNING 1
  ) SELECT count(*)::int FROM _pm),
  1,
  'pm: INSERT absences za Komercijalu → 1 red'
);

-- 15) menadzment-1: INSERT absence van scope-a → RLS
SELECT test_set_jwt_email('kadr-write-mgr1@test.local');
SELECT throws_ok(
  $q$
    INSERT INTO public.absences (id, employee_id, type, date_from, date_to, days_count, note)
    VALUES (
      'aaaaaaaa-5555-5555-5555-555555555505',
      'eeeeeeee-2222-2222-2222-222222222202',
      'godisnji',
      '2026-10-01',
      '2026-10-02',
      2,
      'mgr illegal insert'
    );
  $q$,
  '42501',
  NULL,
  'menadzment-1: INSERT absences van scope-a → 42501'
);

-- 16–17) HR INSERT employee; viewer ne INSERT child
SELECT test_set_jwt_email('kadr-write-hr@test.local');
SELECT is(
  (WITH _hei AS (
    INSERT INTO public.employees (id, full_name, department, email)
    VALUES ('eeeeeeee-8888-8888-8888-888888888808', 'HR novi', 'Proizvodnja', 'hr-novi-kwr@test.local')
    RETURNING 1
  ) SELECT count(*)::int FROM _hei),
  1,
  'HR: INSERT employees → 1 red'
);

SELECT test_set_jwt_email('kadr-write-viewer-self@test.local');
SELECT throws_ok(
  $q$
    INSERT INTO public.employee_children (id, employee_id, first_name)
    VALUES ('cccccccc-2222-2222-2222-222222222202', 'eeeeeeee-3333-3333-3333-333333333303', 'X');
  $q$,
  '42501',
  NULL,
  'viewer: INSERT employee_children → admin-only (42501)'
);

-- 18) admin vidi dete
SELECT test_set_jwt_email('kadr-write-admin@test.local');
SELECT is(
  (SELECT count(*)::int FROM public.employee_children
   WHERE id = 'cccccccc-1111-1111-1111-111111111101'::uuid),
  1,
  'admin: SELECT employee_children → 1 red'
);

SELECT * FROM finish();

ROLLBACK;

-- ============================================================================
-- pgTAP: kadr_dashboard_mini_reports — scope (admin / HR / menadžment / viewer)
-- ============================================================================
-- Preduslov: extend_kadr_managed_departments_scope + employees/absences/work_hours
-- Ručno: psql … -v ON_ERROR_STOP=1 -f sql/tests/security_kadr_mini_reports_rpc.sql
-- ============================================================================

BEGIN;
SET search_path = public, extensions;

SELECT plan(15);

CREATE OR REPLACE FUNCTION test_mr_set_jwt_email(p_email text)
RETURNS void LANGUAGE sql AS $$
  SELECT set_config(
    'request.jwt.claims',
    jsonb_build_object('email', p_email)::text,
    true
  );
$$;

ALTER TABLE public.user_roles
  ADD COLUMN IF NOT EXISTS managed_departments TEXT[];

ALTER TABLE public.user_roles
  ADD COLUMN IF NOT EXISTS managed_sub_department_ids int[];

SET LOCAL row_security = off;

INSERT INTO public.sub_departments (id, department_id, name, sort_order)
VALUES
  (89001, 5, 'KADR_MR_SUB_A', 0),
  (89002, 5, 'KADR_MR_SUB_B', 0)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

DELETE FROM public.user_roles
WHERE lower(email) IN (
  lower('kadr-mr-admin@test.local'),
  lower('kadr-mr-hr@test.local'),
  lower('kadr-mr-mgr1@test.local'),
  lower('kadr-mr-mgr3@test.local'),
  lower('kadr-mr-viewer@test.local')
);

INSERT INTO public.user_roles (
  email, role, project_id, is_active, managed_departments, managed_sub_department_ids
)
VALUES
  ('kadr-mr-admin@test.local', 'admin', NULL, true, NULL, NULL),
  ('kadr-mr-hr@test.local', 'hr', NULL, true, NULL, NULL),
  ('kadr-mr-mgr1@test.local', 'menadzment', NULL, true, NULL, ARRAY[89001]::int[]),
  ('kadr-mr-mgr3@test.local', 'menadzment', NULL, true, NULL, NULL),
  ('kadr-mr-viewer@test.local', 'viewer', NULL, true, NULL, NULL);

INSERT INTO public.employees (id, full_name, department, email, is_active, sub_department_id)
VALUES
  (
    'eeeeeeee-1111-1111-1111-111111111101',
    'Mini A',
    'KADR_MR_DEPT_A',
    'kadr-mr-emp-a@test.local',
    true,
    89001
  ),
  (
    'eeeeeeee-2222-2222-2222-222222222202',
    'Mini B',
    'KADR_MR_DEPT_B',
    'kadr-mr-emp-b@test.local',
    true,
    89002
  )
ON CONFLICT (id) DO UPDATE SET
  sub_department_id = EXCLUDED.sub_department_id,
  department = EXCLUDED.department,
  is_active = EXCLUDED.is_active;

DELETE FROM public.absences
WHERE id = 'ffffffff-1111-1111-1111-111111111111'::uuid;

INSERT INTO public.absences (id, employee_id, type, date_from, date_to, days_count, note)
VALUES (
  'ffffffff-1111-1111-1111-111111111111',
  'eeeeeeee-1111-1111-1111-111111111101',
  'godisnji',
  date_trunc('month', current_date::timestamp)::date,
  date_trunc('month', current_date::timestamp)::date,
  1,
  'mini reports absence month'
);

DELETE FROM public.work_hours
WHERE id = 'ffffffff-2222-2222-2222-222222222222'::uuid;

INSERT INTO public.work_hours (id, employee_id, work_date, hours, note)
VALUES (
  'ffffffff-2222-2222-2222-222222222222',
  'eeeeeeee-1111-1111-1111-111111111101',
  date_trunc('month', current_date::timestamp)::date,
  8,
  'mini reports wh month'
);

SET LOCAL row_security = on;

CREATE TEMP TABLE _mr_snap (lbl text PRIMARY KEY, j jsonb);

-- admin
SELECT test_mr_set_jwt_email('kadr-mr-admin@test.local');
INSERT INTO _mr_snap VALUES ('admin', public.kadr_dashboard_mini_reports());
SELECT is(
  (SELECT j ->> 'scope_kind' FROM _mr_snap WHERE lbl = 'admin'),
  'admin',
  'admin → scope_kind'
);
SELECT is(
  (SELECT jsonb_array_length(j -> 'employees_by_department') FROM _mr_snap WHERE lbl = 'admin'),
  2,
  'admin → dva odeljenja u agregatu'
);
SELECT ok(
  (SELECT jsonb_array_length(j -> 'hours_per_day') FROM _mr_snap WHERE lbl = 'admin') >= 28,
  'admin → hours_per_day pokriva mesec'
);
SELECT ok(
  (SELECT jsonb_array_length(j -> 'absences_by_type') FROM _mr_snap WHERE lbl = 'admin') >= 1,
  'admin → absences_by_type nije prazan'
);

-- HR
SELECT test_mr_set_jwt_email('kadr-mr-hr@test.local');
INSERT INTO _mr_snap VALUES ('hr', public.kadr_dashboard_mini_reports());
SELECT is(
  (SELECT j ->> 'scope_kind' FROM _mr_snap WHERE lbl = 'hr'),
  'hr',
  'HR → scope_kind'
);
SELECT is(
  (SELECT jsonb_array_length(j -> 'employees_by_department') FROM _mr_snap WHERE lbl = 'hr'),
  2,
  'HR → pun agregat odeljenja'
);

-- menadžment scoped
SELECT test_mr_set_jwt_email('kadr-mr-mgr1@test.local');
INSERT INTO _mr_snap VALUES ('mgr1', public.kadr_dashboard_mini_reports());
SELECT is(
  (SELECT j ->> 'scope_kind' FROM _mr_snap WHERE lbl = 'mgr1'),
  'menadzment_scoped',
  'mgr1 → scope_kind'
);
SELECT is(
  (SELECT jsonb_array_length(j -> 'employees_by_department') FROM _mr_snap WHERE lbl = 'mgr1'),
  1,
  'mgr1 → jedno odeljenje'
);
SELECT is(
  (SELECT j -> 'employees_by_department' -> 0 ->> 'department' FROM _mr_snap WHERE lbl = 'mgr1'),
  'KADR_MR_DEPT_A',
  'mgr1 → samo dept A'
);

-- menadžment pun obim (NULL managed)
SELECT test_mr_set_jwt_email('kadr-mr-mgr3@test.local');
INSERT INTO _mr_snap VALUES ('mgr3', public.kadr_dashboard_mini_reports());
SELECT is(
  (SELECT j ->> 'scope_kind' FROM _mr_snap WHERE lbl = 'mgr3'),
  'menadzment_full',
  'mgr3 → scope_kind'
);
SELECT is(
  (SELECT jsonb_array_length(j -> 'employees_by_department') FROM _mr_snap WHERE lbl = 'mgr3'),
  2,
  'mgr3 → sva odeljenja'
);

-- viewer
SELECT test_mr_set_jwt_email('kadr-mr-viewer@test.local');
INSERT INTO _mr_snap VALUES ('viewer', public.kadr_dashboard_mini_reports());
SELECT is(
  (SELECT j ->> 'scope_kind' FROM _mr_snap WHERE lbl = 'viewer'),
  'no_access',
  'viewer → no_access'
);
SELECT is(
  (SELECT jsonb_array_length(j -> 'employees_by_department') FROM _mr_snap WHERE lbl = 'viewer'),
  0,
  'viewer → prazno employees_by_department'
);
SELECT is(
  (SELECT jsonb_array_length(j -> 'hours_per_day') FROM _mr_snap WHERE lbl = 'viewer'),
  0,
  'viewer → prazno hours_per_day'
);
SELECT is(
  (SELECT jsonb_array_length(j -> 'absences_by_type') FROM _mr_snap WHERE lbl = 'viewer'),
  0,
  'viewer → prazno absences_by_type'
);

SELECT * FROM finish();
ROLLBACK;

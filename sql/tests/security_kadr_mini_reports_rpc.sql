-- ============================================================================
-- pgTAP: kadr_dashboard_mini_reports — scope (admin / HR / menadžment / viewer)
-- ============================================================================
-- Preduslov: extend_kadr_managed_departments_scope + employees/absences/work_hours
-- Ručno: psql … -v ON_ERROR_STOP=1 -f sql/tests/security_kadr_mini_reports_rpc.sql
-- Supabase SQL editor: lepi ceo fajl i pokreni odjednom (ista sesija za JWT/set_config).
-- ============================================================================

BEGIN;
SET search_path = public, extensions;

SELECT plan(19);

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

-- Bez TEMP TABLE: u Supabase SQL editor / poolingu sesije se ne drže između statement-a.

-- admin
SELECT test_mr_set_jwt_email('kadr-mr-admin@test.local');
SELECT is(
  (SELECT public.kadr_dashboard_mini_reports() ->> 'scope_kind'),
  'admin',
  'admin → scope_kind'
);
SELECT ok(
  EXISTS (
    SELECT 1
    FROM jsonb_array_elements((SELECT public.kadr_dashboard_mini_reports() -> 'employees_by_department')) AS elem
    WHERE elem->>'department' = 'KADR_MR_DEPT_A'
      AND (elem->>'count')::int >= 1
  ),
  'admin → donut uključuje seed sektor A (globalni agregat)'
);
SELECT ok(
  EXISTS (
    SELECT 1
    FROM jsonb_array_elements((SELECT public.kadr_dashboard_mini_reports() -> 'employees_by_department')) AS elem
    WHERE elem->>'department' = 'KADR_MR_DEPT_B'
      AND (elem->>'count')::int >= 1
  ),
  'admin → donut uključuje seed sektor B'
);
SELECT ok(
  (
    SELECT
      jsonb_typeof(r -> 'hours_per_day') = 'array'
      AND jsonb_array_length(r -> 'hours_per_day') = (
        EXTRACT(
          day
          FROM (
            date_trunc('month', current_date) + interval '1 month - 1 day'
          )::date
        )::int
      )
    FROM (SELECT public.kadr_dashboard_mini_reports() AS r) s
  ),
  'admin → hours_per_day: niz, jedna stavka po danu u mesecu'
);
SELECT ok(
  (SELECT jsonb_array_length((public.kadr_dashboard_mini_reports())->'absences_by_type')) >= 1,
  'admin → absences_by_type nije prazan'
);

-- HR
SELECT test_mr_set_jwt_email('kadr-mr-hr@test.local');
SELECT is(
  (SELECT public.kadr_dashboard_mini_reports() ->> 'scope_kind'),
  'hr',
  'HR → scope_kind'
);
SELECT ok(
  EXISTS (
    SELECT 1
    FROM jsonb_array_elements((SELECT public.kadr_dashboard_mini_reports() -> 'employees_by_department')) AS elem
    WHERE elem->>'department' = 'KADR_MR_DEPT_A'
      AND (elem->>'count')::int >= 1
  ),
  'HR → donut uključuje sektor A'
);
SELECT ok(
  EXISTS (
    SELECT 1
    FROM jsonb_array_elements((SELECT public.kadr_dashboard_mini_reports() -> 'employees_by_department')) AS elem
    WHERE elem->>'department' = 'KADR_MR_DEPT_B'
      AND (elem->>'count')::int >= 1
  ),
  'HR → donut uključuje sektor B'
);

-- menadžment scoped
SELECT test_mr_set_jwt_email('kadr-mr-mgr1@test.local');
SELECT is(
  (SELECT public.kadr_dashboard_mini_reports() ->> 'scope_kind'),
  'menadzment_scoped',
  'mgr1 → scope_kind'
);
SELECT ok(
  (
    SELECT jsonb_array_length((public.kadr_dashboard_mini_reports()) -> 'employees_by_department') >= 1
  ),
  'mgr1 → donut: bar jedan segment u scope-u'
);
SELECT ok(
  EXISTS (
    SELECT 1
    FROM jsonb_array_elements((SELECT public.kadr_dashboard_mini_reports() -> 'employees_by_department')) AS elem
    WHERE elem ->> 'department' = 'KADR_MR_SUB_A'
      AND (elem ->> 'count')::int >= 1
  ),
  'mgr1 → agregat po sub_departments.name (KADR_MR_SUB_A), ne po sektor tekstu'
);
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements((SELECT public.kadr_dashboard_mini_reports() -> 'employees_by_department')) AS elem
    WHERE elem ->> 'department' = 'KADR_MR_DEPT_A'
  ),
  'mgr1 → scoped donut ne grupiše po employees.department (KADR_MR_DEPT_A)'
);

-- menadžment pun obim (NULL managed)
SELECT test_mr_set_jwt_email('kadr-mr-mgr3@test.local');
SELECT is(
  (SELECT public.kadr_dashboard_mini_reports() ->> 'scope_kind'),
  'menadzment_full',
  'mgr3 → scope_kind'
);
SELECT ok(
  EXISTS (
    SELECT 1
    FROM jsonb_array_elements((SELECT public.kadr_dashboard_mini_reports() -> 'employees_by_department')) AS elem
    WHERE elem->>'department' = 'KADR_MR_DEPT_A'
      AND (elem->>'count')::int >= 1
  ),
  'mgr3 full → donut uključuje sektor A'
);
SELECT ok(
  EXISTS (
    SELECT 1
    FROM jsonb_array_elements((SELECT public.kadr_dashboard_mini_reports() -> 'employees_by_department')) AS elem
    WHERE elem->>'department' = 'KADR_MR_DEPT_B'
      AND (elem->>'count')::int >= 1
  ),
  'mgr3 full → donut uključuje sektor B'
);

-- viewer
SELECT test_mr_set_jwt_email('kadr-mr-viewer@test.local');
SELECT is(
  (SELECT public.kadr_dashboard_mini_reports() ->> 'scope_kind'),
  'no_access',
  'viewer → no_access'
);
SELECT is(
  (SELECT jsonb_array_length((public.kadr_dashboard_mini_reports())->'employees_by_department')),
  0,
  'viewer → prazno employees_by_department'
);
SELECT is(
  (SELECT jsonb_array_length((public.kadr_dashboard_mini_reports())->'hours_per_day')),
  0,
  'viewer → prazno hours_per_day'
);
SELECT is(
  (SELECT jsonb_array_length((public.kadr_dashboard_mini_reports())->'absences_by_type')),
  0,
  'viewer → prazno absences_by_type'
);

SELECT * FROM finish();
ROLLBACK;

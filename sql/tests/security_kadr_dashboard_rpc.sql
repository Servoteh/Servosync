-- ============================================================================
-- pgTAP: kadr_dashboard_kpis — scope / viewer
-- ============================================================================
-- Preduslov: extend_kadr_managed_departments_scope + add_kadr_dashboard_kpis_rpc
-- Ručno: psql … -v ON_ERROR_STOP=1 -f sql/tests/security_kadr_dashboard_rpc.sql
-- ============================================================================

BEGIN;
SET search_path = public, extensions;

SELECT plan(15);

CREATE OR REPLACE FUNCTION test_set_jwt_email(p_email text)
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
  (88001, 5, 'KADR_DASH_SUB_A', 0),
  (88002, 5, 'KADR_DASH_SUB_B', 0)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  department_id = EXCLUDED.department_id;

INSERT INTO public.user_roles (email, role, project_id, is_active, managed_departments, managed_sub_department_ids)
VALUES
  ('kadr-dash-admin@test.local', 'admin', NULL, true, NULL, NULL),
  ('kadr-dash-hr@test.local', 'hr', NULL, true, NULL, NULL),
  ('kadr-dash-mgr1@test.local', 'menadzment', NULL, true, NULL, ARRAY[88001]::int[]),
  ('kadr-dash-mgr3@test.local', 'menadzment', NULL, true, NULL, NULL),
  ('kadr-dash-viewer@test.local', 'viewer', NULL, true, NULL, NULL)
ON CONFLICT (email) DO UPDATE SET
  role = EXCLUDED.role,
  is_active = EXCLUDED.is_active,
  managed_departments = EXCLUDED.managed_departments,
  managed_sub_department_ids = EXCLUDED.managed_sub_department_ids;

INSERT INTO public.employees (id, full_name, department, email, is_active, sub_department_id)
VALUES
  (
    'dddddddd-1111-1111-1111-111111111101',
    'KPI Radnik A',
    'KADR_DASH_DEPT_A',
    'kpi-emp-a@test.local',
    true,
    88001
  ),
  (
    'dddddddd-2222-2222-2222-222222222202',
    'KPI Radnik B',
    'KADR_DASH_DEPT_B',
    'kpi-emp-b@test.local',
    true,
    88002
  )
ON CONFLICT (id) DO UPDATE SET
  sub_department_id = EXCLUDED.sub_department_id,
  department = EXCLUDED.department,
  is_active = EXCLUDED.is_active;

DELETE FROM public.absences
WHERE id = 'bbbbbbbb-1111-1111-1111-111111111111'::uuid;

INSERT INTO public.absences (id, employee_id, type, date_from, date_to, days_count, note)
VALUES (
  'bbbbbbbb-1111-1111-1111-111111111111',
  'dddddddd-1111-1111-1111-111111111101',
  'godisnji',
  current_date,
  current_date,
  1,
  'kpi dash absence today'
);

DELETE FROM public.vacation_requests
WHERE id IN (
  'cccccccc-1111-1111-1111-111111111101'::uuid,
  'cccccccc-2222-2222-2222-222222222202'::uuid
);

INSERT INTO public.vacation_requests (
  id, employee_id, year, date_from, date_to, days_count, note, status, submitted_by
)
VALUES
  (
    'cccccccc-1111-1111-1111-111111111101',
    'dddddddd-1111-1111-1111-111111111101',
    extract(year from current_date)::int,
    current_date + 10,
    current_date + 14,
    5,
    'kpi pending a',
    'pending',
    'kpi-submitter@test.local'
  ),
  (
    'cccccccc-2222-2222-2222-222222222202',
    'dddddddd-2222-2222-2222-222222222202',
    extract(year from current_date)::int,
    current_date + 10,
    current_date + 14,
    5,
    'kpi pending b',
    'pending',
    'kpi-submitter@test.local'
  );

DELETE FROM public.work_hours
WHERE employee_id = 'dddddddd-1111-1111-1111-111111111101'::uuid
  AND work_date = date_trunc('month', current_date::timestamp)::date;

INSERT INTO public.work_hours (id, employee_id, work_date, hours, note)
VALUES (
  'eeeeeeee-1111-1111-1111-111111111101',
  'dddddddd-1111-1111-1111-111111111101',
  date_trunc('month', current_date::timestamp)::date,
  8,
  'kpi grid seed'
);

SET LOCAL row_security = on;

CREATE TEMP TABLE _kpi_snap (lbl text PRIMARY KEY, j jsonb);

-- 1–3) admin
SELECT test_set_jwt_email('kadr-dash-admin@test.local');
INSERT INTO _kpi_snap VALUES ('admin', public.kadr_dashboard_kpis());
SELECT is(
  (SELECT j ->> 'scope_kind' FROM _kpi_snap WHERE lbl = 'admin'),
  'admin',
  'admin → scope_kind'
);
SELECT ok(
  ((SELECT j ->> 'active_employees' FROM _kpi_snap WHERE lbl = 'admin')::int >= 2),
  'admin → active_employees uključuje seed'
);

-- 4–5) HR
SELECT test_set_jwt_email('kadr-dash-hr@test.local');
INSERT INTO _kpi_snap VALUES ('hr', public.kadr_dashboard_kpis());
SELECT is(
  (SELECT j ->> 'scope_kind' FROM _kpi_snap WHERE lbl = 'hr'),
  'hr',
  'HR → scope_kind'
);
SELECT ok(
  ((SELECT j ->> 'pending_vac_requests' FROM _kpi_snap WHERE lbl = 'hr')::int >= 2),
  'HR → vidi oba pending GO'
);

-- 6–9) menadžment scoped
SELECT test_set_jwt_email('kadr-dash-mgr1@test.local');
INSERT INTO _kpi_snap VALUES ('mgr1', public.kadr_dashboard_kpis());
SELECT is(
  (SELECT j ->> 'scope_kind' FROM _kpi_snap WHERE lbl = 'mgr1'),
  'menadzment_scoped',
  'menadžment-1 → scope_kind'
);
SELECT is(
  ((SELECT j ->> 'active_employees' FROM _kpi_snap WHERE lbl = 'mgr1')::int),
  (
    SELECT count(*)::int
    FROM public.employees e
    WHERE e.is_active IS TRUE
      AND e.sub_department_id = 88001
  ),
  'menadžment-1 → active_employees samo u scope sub_dept'
);
SELECT is(
  ((SELECT j ->> 'pending_vac_requests' FROM _kpi_snap WHERE lbl = 'mgr1')::int),
  1,
  'menadžment-1 → jedan pending GO'
);
SELECT is(
  ((SELECT j ->> 'on_absence_today' FROM _kpi_snap WHERE lbl = 'mgr1')::int),
  1,
  'menadžment-1 → odsustvo danas (dept A)'
);

-- 10–11) menadžment pun obim — isti broj aktivnih kao HR
SELECT test_set_jwt_email('kadr-dash-mgr3@test.local');
INSERT INTO _kpi_snap VALUES ('mgr3', public.kadr_dashboard_kpis());
SELECT is(
  (SELECT j ->> 'scope_kind' FROM _kpi_snap WHERE lbl = 'mgr3'),
  'menadzment_full',
  'menadžment-3 → scope_kind'
);
SELECT is(
  ((SELECT j ->> 'active_employees' FROM _kpi_snap WHERE lbl = 'mgr3')::int),
  ((SELECT j ->> 'active_employees' FROM _kpi_snap WHERE lbl = 'hr')::int),
  'menadžment NULL scope → isti active kao HR'
);

-- 12–16) viewer — sve nule (bez „legacy punog“ obima)
SELECT test_set_jwt_email('kadr-dash-viewer@test.local');
INSERT INTO _kpi_snap VALUES ('viewer', public.kadr_dashboard_kpis());
SELECT is(
  (SELECT j ->> 'scope_kind' FROM _kpi_snap WHERE lbl = 'viewer'),
  'viewer',
  'viewer → scope_kind'
);
SELECT is(
  ((SELECT j ->> 'active_employees' FROM _kpi_snap WHERE lbl = 'viewer')::int),
  0,
  'viewer → active_employees = 0 (bez scope)'
);
SELECT is(
  ((SELECT j ->> 'on_absence_today' FROM _kpi_snap WHERE lbl = 'viewer')::int),
  0,
  'viewer → on_absence_today = 0'
);
SELECT is(
  ((SELECT j ->> 'pending_vac_requests' FROM _kpi_snap WHERE lbl = 'viewer')::int),
  0,
  'viewer → pending_vac_requests = 0'
);
SELECT is(
  ((SELECT j ->> 'grid_fill_percent' FROM _kpi_snap WHERE lbl = 'viewer')::numeric),
  0::numeric,
  'viewer → grid_fill_percent = 0'
);

SELECT * FROM finish();
ROLLBACK;

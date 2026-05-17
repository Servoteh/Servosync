-- ============================================================================
-- pgTAP: kadr_dashboard_action_stack — scope / menadžment / missing grid
-- ============================================================================
-- Preduslovi (mora pre pokretanja ovog fajla):
--   1) CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
--      (inače: function plan(integer) does not exist — vidi sql/tests/README.md)
--   2) Primena SQL migracije koja kreira RPC:
--        sql/migrations/add_kadr_dashboard_action_stack_rpc.sql
--      (inače: function public.kadr_dashboard_action_stack(integer) does not exist)
--   Ako je pgTAP u šemi public, zameni extensions.plan / extensions.finish sa plan / finish.
-- Ostale migracije: extend_kadr_managed_departments_scope, vacation_requests, KPI helperi…
-- Ručno: psql … -v ON_ERROR_STOP=1 -f sql/tests/security_kadr_action_stack_rpc.sql
-- ============================================================================

BEGIN;
SET search_path = public, extensions;

SELECT extensions.plan(7);

CREATE OR REPLACE FUNCTION test_as_set_jwt_email(p_email text)
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
  (600001, 5, 'KADR_AS_SUB_A', 0),
  (600002, 5, 'KADR_AS_SUB_B', 0)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

DELETE FROM public.user_roles
WHERE lower(email) IN (
  lower('kadr-as-admin@test.local'),
  lower('kadr-as-hr@test.local'),
  lower('kadr-as-mgr1@test.local'),
  lower('kadr-as-mgr3@test.local'),
  lower('kadr-as-viewer@test.local')
);

INSERT INTO public.user_roles (
  email, role, project_id, is_active, managed_departments, managed_sub_department_ids
)
VALUES
  ('kadr-as-admin@test.local', 'admin', NULL, true, NULL, NULL),
  ('kadr-as-hr@test.local', 'hr', NULL, true, NULL, NULL),
  ('kadr-as-mgr1@test.local', 'menadzment', NULL, true, NULL, ARRAY[600001]::int[]),
  ('kadr-as-mgr3@test.local', 'menadzment', NULL, true, NULL, NULL),
  ('kadr-as-viewer@test.local', 'viewer', NULL, true, NULL, NULL);

INSERT INTO public.employees (
  id, full_name, department, email, is_active, work_type, sub_department_id
)
VALUES
  (
    'aaaaaaaa-1111-1111-1111-111111111101',
    'AS Radnik A',
    'KADR_AS_DEPT_A',
    'kadr-as-emp-a@test.local',
    true,
    'ugovor',
    600001
  ),
  (
    'aaaaaaaa-2222-2222-2222-222222222202',
    'AS Radnik B',
    'KADR_AS_DEPT_B',
    'kadr-as-emp-b@test.local',
    true,
    'ugovor',
    600002
  ),
  (
    'aaaaaaaa-3333-3333-3333-333333333303',
    '!!! AS Missing Grid',
    'KADR_AS_DEPT_A',
    'kadr-as-miss@test.local',
    true,
    'ugovor',
    600001
  )
ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  department = EXCLUDED.department,
  is_active = EXCLUDED.is_active,
  work_type = EXCLUDED.work_type,
  sub_department_id = EXCLUDED.sub_department_id;

DELETE FROM public.vacation_requests
WHERE id IN (
  'aaaaaaaa-4444-4444-4444-444444444401'::uuid,
  'aaaaaaaa-4444-4444-4444-444444444402'::uuid
);

INSERT INTO public.vacation_requests (
  id, employee_id, year, date_from, date_to, days_count, note, status, submitted_by
)
VALUES
  (
    'aaaaaaaa-4444-4444-4444-444444444401',
    'aaaaaaaa-1111-1111-1111-111111111101',
    EXTRACT(year FROM CURRENT_DATE)::int,
    CURRENT_DATE + 10,
    CURRENT_DATE + 14,
    5,
    'action stack pending A',
    'pending',
    'kadr-as-sub@test.local'
  ),
  (
    'aaaaaaaa-4444-4444-4444-444444444402',
    'aaaaaaaa-2222-2222-2222-222222222202',
    EXTRACT(year FROM CURRENT_DATE)::int,
    CURRENT_DATE + 10,
    CURRENT_DATE + 14,
    5,
    'action stack pending B',
    'pending',
    'kadr-as-sub@test.local'
  );

-- Prošli mesec: bez sati za AS Missing Grid (i bez odsustva celog meseca)
DELETE FROM public.work_hours
WHERE employee_id = 'aaaaaaaa-3333-3333-3333-333333333303'::uuid
  AND work_date >= date_trunc('month', current_date::timestamp)::date - interval '1 month'
  AND work_date < date_trunc('month', current_date::timestamp)::date;

DELETE FROM public.absences
WHERE employee_id = 'aaaaaaaa-3333-3333-3333-333333333303'::uuid;

SET LOCAL row_security = on;

-- viewer → prazno
SELECT test_as_set_jwt_email('kadr-as-viewer@test.local');
SELECT is(
  jsonb_array_length(public.kadr_dashboard_action_stack(50)),
  0,
  'viewer → prazan stack'
);

-- menadžment scoped → samo jedan pending GO
SELECT test_as_set_jwt_email('kadr-as-mgr1@test.local');
SELECT is(
  (
    SELECT count(*)::int
    FROM jsonb_array_elements(public.kadr_dashboard_action_stack(50)) t
    WHERE t->>'type' = 'pending_vac_request'
  ),
  1,
  'mgr scoped → jedan pending GO'
);

-- menadžment NULL scope → oba pending GO (bez HR-only stavki ako nema seed-a u drugim tabelama)
SELECT test_as_set_jwt_email('kadr-as-mgr3@test.local');
SELECT is(
  (
    SELECT count(*)::int
    FROM jsonb_array_elements(public.kadr_dashboard_action_stack(50)) t
    WHERE t->>'type' = 'pending_vac_request'
  ),
  2,
  'mgr full → oba pending GO'
);

-- admin → uključuje missing_grid za AS Missing Grid
SELECT test_as_set_jwt_email('kadr-as-admin@test.local');
SELECT ok(
  EXISTS (
    SELECT 1
    FROM jsonb_array_elements(public.kadr_dashboard_action_stack(200)) t
    WHERE t->>'type' = 'missing_grid_prev_month'
      AND t->>'id' = 'missing_grid_aaaaaaaa-3333-3333-3333-333333333303'
  ),
  'admin → missing_grid za zaposlenog bez sati u prošlom mesecu'
);

-- posle unosa sati u prošlom mesecu — nema te stavke
SET LOCAL row_security = off;
DELETE FROM public.work_hours
WHERE id = 'aaaaaaaa-5555-5555-5555-555555555501'::uuid;
INSERT INTO public.work_hours (id, employee_id, work_date, hours, note)
VALUES (
  'aaaaaaaa-5555-5555-5555-555555555501',
  'aaaaaaaa-3333-3333-3333-333333333303',
  (date_trunc('month', current_date::timestamp) - interval '1 month')::date,
  8,
  'action stack grid seed prev month'
);
SET LOCAL row_security = on;

SELECT test_as_set_jwt_email('kadr-as-admin@test.local');
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(public.kadr_dashboard_action_stack(200)) t
    WHERE t->>'type' = 'missing_grid_prev_month'
      AND t->>'id' = 'missing_grid_aaaaaaaa-3333-3333-3333-333333333303'
  ),
  'admin → missing_grid nestaje kad postoje sati u prošlom mesecu'
);

-- HR ima bar pending stavke (ista semantika kao admin za GO deo)
SELECT test_as_set_jwt_email('kadr-as-hr@test.local');
SELECT ok(
  (
    SELECT count(*)::int
    FROM jsonb_array_elements(public.kadr_dashboard_action_stack(50)) t
    WHERE t->>'type' = 'pending_vac_request'
  ) >= 2,
  'HR → vidi oba pending GO'
);

-- Sortiranje po prioritetu (opadajuće)
SELECT test_as_set_jwt_email('kadr-as-admin@test.local');
SELECT ok(
  (
    WITH ordered AS (
      SELECT (t.elem->>'priority')::int AS p,
             row_number() OVER (ORDER BY (t.elem->>'priority')::int DESC) AS rn
      FROM jsonb_array_elements(public.kadr_dashboard_action_stack(25)) AS t(elem)
    )
    SELECT COALESCE((SELECT p FROM ordered WHERE rn = 1), 0)
        >= COALESCE((SELECT p FROM ordered WHERE rn = 2), (SELECT p FROM ordered WHERE rn = 1), 0)
  ),
  'action stack: opadajući priority'
);

SELECT * FROM extensions.finish();
ROLLBACK;

-- ============================================================================
-- pgTAP: menadžment scope preko managed_sub_department_ids + sub_department_id
-- ============================================================================
-- Preduslov: refactor_managed_to_sub_department_ids.sql (plus CI bootstrap org stub).
-- Ručno: psql … -v ON_ERROR_STOP=1 -f sql/tests/security_kadr_sub_dept_scope.sql
-- ============================================================================

BEGIN;
SET search_path = public, extensions;

SELECT plan(10);

CREATE OR REPLACE FUNCTION test_sd_set_jwt_email(p_email text)
RETURNS void LANGUAGE sql AS $$
  SELECT set_config(
    'request.jwt.claims',
    jsonb_build_object('email', p_email)::text,
    true
  );
$$;

ALTER TABLE public.user_roles
  ADD COLUMN IF NOT EXISTS managed_departments text[];

ALTER TABLE public.user_roles
  ADD COLUMN IF NOT EXISTS managed_sub_department_ids int[];

SET LOCAL row_security = off;

DELETE FROM public.user_roles
WHERE lower(email) IN (
  lower('kadr-sd-admin@test.local'),
  lower('kadr-sd-hr@test.local'),
  lower('kadr-sd-mgr12@test.local'),
  lower('kadr-sd-mgr13@test.local'),
  lower('kadr-sd-mgr-null@test.local'),
  lower('kadr-sd-viewer@test.local')
);

INSERT INTO public.sub_departments (id, department_id, name, sort_order)
VALUES
  (77001, 5, 'SD_SCOPE_A', 0),
  (77002, 5, 'SD_SCOPE_B', 0),
  (77003, 5, 'SD_SCOPE_C', 0)
ON CONFLICT (id) DO UPDATE SET
  department_id = EXCLUDED.department_id,
  name = EXCLUDED.name,
  sort_order = EXCLUDED.sort_order;

INSERT INTO public.user_roles (
  email, role, project_id, is_active, managed_departments, managed_sub_department_ids
)
VALUES
  ('kadr-sd-admin@test.local', 'admin', NULL, true, NULL, NULL),
  ('kadr-sd-hr@test.local', 'hr', NULL, true, NULL, NULL),
  ('kadr-sd-mgr12@test.local', 'menadzment', NULL, true, NULL, ARRAY[77001, 77002]),
  ('kadr-sd-mgr13@test.local', 'menadzment', NULL, true, NULL, ARRAY[77001, 77003]),
  ('kadr-sd-mgr-null@test.local', 'menadzment', NULL, true, NULL, NULL),
  ('kadr-sd-viewer@test.local', 'viewer', NULL, true, NULL, NULL);

INSERT INTO public.employees (
  id, full_name, department, email, is_active, sub_department_id
)
VALUES
  (
    'd0000001-0001-0001-0001-000000000001',
    'SD Emp A',
    'KADR_SD_DEPT',
    'kadr-sd-emp-a@test.local',
    true,
    77001
  ),
  (
    'd0000002-0002-0002-0002-000000000002',
    'SD Emp B',
    'KADR_SD_DEPT',
    'kadr-sd-emp-b@test.local',
    true,
    77002
  ),
  (
    'd0000003-0003-0003-0003-000000000003',
    'SD Emp C',
    'KADR_SD_DEPT',
    'kadr-sd-emp-c@test.local',
    true,
    77003
  ),
  (
    'd0000004-0004-0004-0004-000000000004',
    'SD Emp No Sub',
    'KADR_SD_DEPT',
    'kadr-sd-emp-ns@test.local',
    true,
    NULL
  )
ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  department = EXCLUDED.department,
  is_active = EXCLUDED.is_active,
  sub_department_id = EXCLUDED.sub_department_id;

SET LOCAL row_security = on;

SELECT test_sd_set_jwt_email('kadr-sd-mgr12@test.local');
SELECT is(
  public.current_user_managed_sub_department_ids(),
  ARRAY[77001, 77002]::int[],
  'mgr12: managed_sub_department_ids'
);
SELECT is(
  public.current_user_manages_employee('d0000001-0001-0001-0001-000000000001'::uuid),
  true,
  'mgr12: vidi sub_dept 77001'
);
SELECT is(
  public.current_user_manages_employee('d0000003-0003-0003-0003-000000000003'::uuid),
  false,
  'mgr12: ne vidi sub_dept 77003'
);

SELECT test_sd_set_jwt_email('kadr-sd-mgr13@test.local');
SELECT is(
  public.current_user_manages_employee('d0000003-0003-0003-0003-000000000003'::uuid),
  true,
  'mgr13: vidi sub_dept 77003'
);
SELECT is(
  public.current_user_manages_employee('d0000002-0002-0002-0002-000000000002'::uuid),
  false,
  'mgr13: ne vidi sub_dept 77002'
);

SELECT test_sd_set_jwt_email('kadr-sd-mgr-null@test.local');
SELECT ok(
  public.current_user_managed_sub_department_ids() IS NULL,
  'mgr NULL scope: managed_sub_department_ids IS NULL'
);
SELECT is(
  public.current_user_manages_employee('d0000002-0002-0002-0002-000000000002'::uuid),
  true,
  'mgr NULL scope: pun obim'
);

SELECT test_sd_set_jwt_email('kadr-sd-hr@test.local');
SELECT is(
  public.current_user_manages_employee('d0000003-0003-0003-0003-000000000003'::uuid),
  true,
  'HR: pun obim'
);

SELECT test_sd_set_jwt_email('kadr-sd-viewer@test.local');
SELECT is(
  public.current_user_manages_employee('d0000001-0001-0001-0001-000000000001'::uuid),
  false,
  'viewer: ne upravlja'
);

SELECT test_sd_set_jwt_email('kadr-sd-mgr12@test.local');
SELECT is(
  public.current_user_manages_employee('d0000004-0004-0004-0004-000000000004'::uuid),
  false,
  'scoped mgr: zaposleni bez sub_department_id → false'
);

SELECT * FROM finish();
ROLLBACK;

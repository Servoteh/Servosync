-- ============================================================================
-- pgTAP (DRAFT): current_user_managed_departments + current_user_manages_employee
-- ============================================================================
-- Preduslov: primenjena migr extend_kadr_managed_departments_scope.sql
--            + auth.jwt() stub preko request.jwt.claims (sql/ci/00_bootstrap).
--
-- NE pokretati u CI dok migracija nije u lancu; fajl dokumentuje očekivano ponašanje
-- za 4 fiktivna naloga + negativni viewer.
--
-- Pokretanje (lokalno, posle bootstrap + migracija):
--   psql … -v ON_ERROR_STOP=1 -f sql/tests/security_kadr_managed_departments_scope.sql
-- ============================================================================

BEGIN;
SET search_path = public, extensions;

SELECT plan(13);

-- Privremeno za seed (isto kao security_has_edit_role.sql)
SET LOCAL row_security = off;

ALTER TABLE public.user_roles
  ADD COLUMN IF NOT EXISTS managed_departments text[];

ALTER TABLE public.user_roles
  ADD COLUMN IF NOT EXISTS managed_sub_department_ids int[];

INSERT INTO public.sub_departments (id, department_id, name, sort_order)
VALUES
  (65001, 5, 'Odeljenje A', 0),
  (65002, 5, 'Odeljenje B', 0)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

DELETE FROM public.user_roles
WHERE lower(email) IN (
  lower('kadr-audit-admin@test.local'),
  lower('kadr-audit-hr@test.local'),
  lower('kadr-audit-mgr-null@test.local'),
  lower('kadr-audit-mgr-scoped@test.local'),
  lower('kadr-audit-pm@test.local'),
  lower('kadr-audit-viewer@test.local')
);

INSERT INTO public.user_roles (
  email, role, project_id, is_active, managed_departments, managed_sub_department_ids
)
VALUES
  ('kadr-audit-admin@test.local', 'admin', NULL, true, NULL, NULL),
  ('kadr-audit-hr@test.local', 'hr', NULL, true, NULL, NULL),
  ('kadr-audit-mgr-null@test.local', 'menadzment', NULL, true, NULL, NULL),
  ('kadr-audit-mgr-scoped@test.local', 'menadzment', NULL, true, ARRAY['Odeljenje A']::text[], ARRAY[65001]::int[]),
  ('kadr-audit-pm@test.local', 'pm', NULL, true, NULL, NULL),
  ('kadr-audit-viewer@test.local', 'viewer', NULL, true, NULL, NULL);

INSERT INTO public.employees (id, full_name, department, email, is_active, sub_department_id)
VALUES
  ('baaaaaaa-bbbb-bbbb-bbbb-bbbbbbbbbba1', 'Zaposleni A', 'Odeljenje A', 'emp-a-kadr@test.local', true, 65001),
  ('baaaaaaa-bbbb-bbbb-bbbb-bbbbbbbbbba2', 'Zaposleni B', 'Odeljenje B', 'emp-b-kadr@test.local', true, 65002)
ON CONFLICT (id) DO UPDATE SET
  sub_department_id = EXCLUDED.sub_department_id,
  department = EXCLUDED.department,
  is_active = EXCLUDED.is_active;

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

-- ─── current_user_managed_departments (deprecated stub) + sub_department_ids ─
SELECT test_set_jwt_email('kadr-audit-mgr-scoped@test.local');
SELECT ok(
  public.current_user_managed_departments() IS NULL,
  'DEPRECATED stub: current_user_managed_departments uvek NULL'
);
SELECT is(
  public.current_user_managed_sub_department_ids(),
  ARRAY[65001]::int[],
  'scoped menadžment: current_user_managed_sub_department_ids'
);

SELECT test_set_jwt_email('kadr-audit-mgr-null@test.local');
SELECT ok(
  public.current_user_managed_departments() IS NULL,
  'menadzment NULL scope: stub i managed_sub_department_ids NULL'
);
SELECT ok(
  public.current_user_managed_sub_department_ids() IS NULL,
  'menadzment bez managed_sub_department_ids → NULL (legacy pun obim)'
);

SELECT test_set_jwt_email('kadr-audit-hr@test.local');
SELECT ok(
  public.current_user_managed_departments() IS NULL,
  'hr: current_user_managed_departments stub NULL'
);

-- ─── current_user_manages_employee ────────────────────────────────────────
SELECT test_set_jwt_email('kadr-audit-mgr-scoped@test.local');
SELECT is(
  public.current_user_manages_employee('baaaaaaa-bbbb-bbbb-bbbb-bbbbbbbbbba1'::uuid),
  true,
  'scoped menadzment: zaposleni u Odeljenju A → true'
);
SELECT is(
  public.current_user_manages_employee('baaaaaaa-bbbb-bbbb-bbbb-bbbbbbbbbba2'::uuid),
  false,
  'scoped menadzment: zaposleni u Odeljenju B → false'
);

SELECT test_set_jwt_email('kadr-audit-mgr-null@test.local');
SELECT is(
  public.current_user_manages_employee('baaaaaaa-bbbb-bbbb-bbbb-bbbbbbbbbba2'::uuid),
  true,
  'menadzment bez ograničenja (NULL): bilo koji zaposleni → true'
);

SELECT test_set_jwt_email('kadr-audit-hr@test.local');
SELECT is(
  public.current_user_manages_employee('baaaaaaa-bbbb-bbbb-bbbb-bbbbbbbbbba2'::uuid),
  true,
  'hr: bilo koji zaposleni → true'
);

SELECT test_set_jwt_email('kadr-audit-pm@test.local');
SELECT is(
  public.current_user_manages_employee('baaaaaaa-bbbb-bbbb-bbbb-bbbbbbbbbba2'::uuid),
  true,
  'pm: bilo koji zaposleni → true'
);

SELECT test_set_jwt_email('kadr-audit-viewer@test.local');
SELECT is(
  public.current_user_manages_employee('baaaaaaa-bbbb-bbbb-bbbb-bbbbbbbbbba1'::uuid),
  false,
  'viewer: manages_employee = false'
);

SELECT test_set_jwt_email('kadr-audit-admin@test.local');
SELECT is(
  public.current_user_manages_employee('baaaaaaa-bbbb-bbbb-bbbb-bbbbbbbbbba2'::uuid),
  true,
  'admin: bilo koji zaposleni → true'
);

SELECT test_clear_jwt();
SELECT is(
  public.current_user_manages_employee('baaaaaaa-bbbb-bbbb-bbbb-bbbbbbbbbba1'::uuid),
  false,
  'bez JWT: manages_employee = false'
);

SELECT * FROM finish();

ROLLBACK;

-- ============================================================================
-- pgTAP: KPI active_employees scope + mini_reports hibridno grupisanje
-- ============================================================================
-- Preduslov: fix_kadr_dashboard_active_employees_scope.sql primenjen u lancu.
-- Ručno: psql … -v ON_ERROR_STOP=1 -f sql/tests/security_kadr_dashboard_scope_fix.sql
-- ============================================================================

BEGIN;
SET search_path = public, extensions;

SELECT plan(8);

CREATE OR REPLACE FUNCTION test_sf_set_jwt_email(p_email text)
RETURNS void LANGUAGE sql AS $$
  SELECT set_config(
    'request.jwt.claims',
    jsonb_build_object('email', p_email)::text,
    true
  );
$$;

-- employees_by_department mora biti JSON niz; inače jsonb_array_elements puca ili vraća prazno.
CREATE OR REPLACE FUNCTION test_sf_mr_emp_arr(mr jsonb)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE jsonb_typeof(mr -> 'employees_by_department')
    WHEN 'array' THEN mr -> 'employees_by_department'
    ELSE '[]'::jsonb
  END;
$$;

ALTER TABLE public.user_roles
  ADD COLUMN IF NOT EXISTS managed_departments text[];

ALTER TABLE public.user_roles
  ADD COLUMN IF NOT EXISTS managed_sub_department_ids int[];

SET LOCAL row_security = off;

INSERT INTO public.sub_departments (id, department_id, name, sort_order)
VALUES
  (90001, 5, 'KADR_SF_SUB_ALFA_7d4e1926', 0),
  (90002, 5, 'KADR_SF_SUB_BETA_7d4e1926', 0),
  (90003, 5, 'KADR_SF_SUB_OUT_7d4e1926', 0)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  department_id = EXCLUDED.department_id,
  sort_order = EXCLUDED.sort_order;

DELETE FROM public.user_roles
WHERE lower(email) IN (
  lower('kadr-sf-hr@test.local'),
  lower('kadr-sf-mgr1@test.local'),
  lower('kadr-sf-mgr3@test.local')
);

INSERT INTO public.user_roles (
  email, role, project_id, is_active, managed_sub_department_ids
)
VALUES
  ('kadr-sf-hr@test.local', 'hr', NULL, true, NULL),
  ('kadr-sf-mgr1@test.local', 'menadzment', NULL, true, ARRAY[90001, 90002]),
  ('kadr-sf-mgr3@test.local', 'menadzment', NULL, true, NULL);

INSERT INTO public.employees (
  id, full_name, department, email, is_active, sub_department_id
)
VALUES
  (
    'f0000001-0001-0001-0001-000000000001',
    'SF Emp A',
    'KADR_SF_SECTOR_ALFA_7d4e1926',
    'kadr-sf-a@test.local',
    true,
    90001
  ),
  (
    'f0000002-0002-0002-0002-000000000002',
    'SF Emp B',
    'KADR_SF_SECTOR_ALFA_7d4e1926',
    'kadr-sf-b@test.local',
    true,
    90002
  ),
  (
    'f0000003-0003-0003-0003-000000000003',
    'SF Emp C',
    'KADR_SF_SECTOR_ALFA_7d4e1926',
    'kadr-sf-c@test.local',
    true,
    90003
  ),
  (
    'f0000004-0004-0004-0004-000000000004',
    'SF Emp D',
    'KADR_SF_SECTOR_BETA_7d4e1926',
    'kadr-sf-d@test.local',
    true,
    90001
  )
ON CONFLICT (id) DO UPDATE SET
  department = EXCLUDED.department,
  is_active = EXCLUDED.is_active,
  sub_department_id = EXCLUDED.sub_department_id;

-- Prazan int[] nije isto što i NULL za v_no_scope u RPC-u (NULL = menadzment pun obim).
UPDATE public.user_roles
SET managed_sub_department_ids = NULL
WHERE lower(email) = lower('kadr-sf-mgr3@test.local');

UPDATE public.user_roles
SET managed_sub_department_ids = ARRAY[90001, 90002]::int[]
WHERE lower(email) = lower('kadr-sf-mgr1@test.local');

-- RLS ostaje isključen i tokom pgTAP provera: inače invoker COUNT/JOIN može da
-- vidi uži skup od kadr_dashboard_* (SECURITY DEFINER).

-- 1) HR — KPI active = svi aktivni u bazi
SELECT test_sf_set_jwt_email('kadr-sf-hr@test.local');
SELECT is(
  (public.kadr_dashboard_kpis()->>'active_employees')::numeric::bigint,
  (SELECT count(*)::bigint FROM public.employees WHERE is_active IS TRUE),
  'HR → active_employees = ukupan broj aktivnih'
);

-- 2) Menadžment sužen — KPI active samo sub_dept u nizu (isti niz kao RPC)
SELECT test_sf_set_jwt_email('kadr-sf-mgr1@test.local');
SELECT is(
  (public.kadr_dashboard_kpis()->>'active_employees')::numeric::bigint,
  (
    SELECT count(*)::bigint
    FROM public.employees e
    WHERE e.is_active IS TRUE
      AND e.sub_department_id = ANY (public.current_user_managed_sub_department_ids())
  ),
  'Scoped menadžment → active_employees samo u managed_sub_dept'
);

-- 3–4) Menadžment NULL scope — odvojeno: scope_kind mora biti menadzment_full, zatim active
SELECT test_sf_set_jwt_email('kadr-sf-mgr3@test.local');
SELECT is(
  (public.kadr_dashboard_kpis()->>'scope_kind'),
  'menadzment_full',
  'Menadžment pun obim → KPI scope_kind = menadzment_full'
);
SELECT is(
  (public.kadr_dashboard_kpis()->>'active_employees')::numeric::bigint,
  (SELECT count(*)::bigint FROM public.employees WHERE is_active IS TRUE),
  'Menadžment pun obim → active_employees = ceo kadar'
);

-- 5–6) mini_reports: HR donut po sektoru
SELECT test_sf_set_jwt_email('kadr-sf-hr@test.local');
SELECT is(
  (
    SELECT (t.e ->> 'count')::numeric::bigint
    FROM (SELECT public.kadr_dashboard_mini_reports() AS mr) p,
    LATERAL jsonb_array_elements(test_sf_mr_emp_arr(p.mr)) AS t (e)
    WHERE t.e ->> 'department' = 'KADR_SF_SECTOR_ALFA_7d4e1926'
    LIMIT 1
  ),
  (
    SELECT count(*)::bigint
    FROM public.employees ex
    WHERE ex.is_active IS TRUE
      AND COALESCE(ex.department, 'Bez odeljenja') = 'KADR_SF_SECTOR_ALFA_7d4e1926'
  ),
  'HR donut ALFA: json count = COUNT aktivnih (isti ključ kao RPC COALESCE department)'
);
SELECT is(
  (
    SELECT (t.e ->> 'count')::numeric::bigint
    FROM (SELECT public.kadr_dashboard_mini_reports() AS mr) p,
    LATERAL jsonb_array_elements(test_sf_mr_emp_arr(p.mr)) AS t (e)
    WHERE t.e ->> 'department' = 'KADR_SF_SECTOR_BETA_7d4e1926'
    LIMIT 1
  ),
  (
    SELECT count(*)::bigint
    FROM public.employees ex
    WHERE ex.is_active IS TRUE
      AND COALESCE(ex.department, 'Bez odeljenja') = 'KADR_SF_SECTOR_BETA_7d4e1926'
  ),
  'HR donut BETA: json count = COUNT aktivnih (isti ključ kao RPC COALESCE department)'
);

-- 7–8) mini_reports: scoped menadžment — segment ALFA i zbir = SQL headcount u istom scope-u
SELECT test_sf_set_jwt_email('kadr-sf-mgr1@test.local');
SELECT is(
  (
    SELECT (t.e ->> 'count')::numeric::bigint
    FROM (SELECT public.kadr_dashboard_mini_reports() AS mr) p,
    LATERAL jsonb_array_elements(test_sf_mr_emp_arr(p.mr)) AS t (e)
    WHERE t.e ->> 'department' = 'KADR_SF_SUB_ALFA_7d4e1926'
    LIMIT 1
  ),
  (
    SELECT s.cnt::numeric::bigint
    FROM (
      SELECT
        COALESCE(sd.name, 'Bez pododeljenja') AS dept,
        COUNT(*)::int AS cnt
      FROM public.employees e
      LEFT JOIN public.sub_departments sd ON sd.id = e.sub_department_id
      WHERE e.is_active IS TRUE
        AND e.sub_department_id = ANY (public.current_user_managed_sub_department_ids())
      GROUP BY COALESCE(sd.name, 'Bez pododeljenja')
    ) s
    WHERE s.dept = 'KADR_SF_SUB_ALFA_7d4e1926'
  ),
  'Scoped donut ALFA: json = isti GROUP BY kao u RPC scoped grani'
);
SELECT is(
  (
    SELECT coalesce(sum((t.e ->> 'count')::numeric), 0::numeric)::bigint
    FROM (SELECT public.kadr_dashboard_mini_reports() AS mr) p,
    LATERAL jsonb_array_elements(test_sf_mr_emp_arr(p.mr)) AS t (e)
  ),
  (
    SELECT coalesce(sum(s.cnt), 0)::numeric::bigint
    FROM (
      SELECT
        COALESCE(sd.name, 'Bez pododeljenja') AS dept,
        COUNT(*)::int AS cnt
      FROM public.employees e
      LEFT JOIN public.sub_departments sd ON sd.id = e.sub_department_id
      WHERE e.is_active IS TRUE
        AND e.sub_department_id = ANY (public.current_user_managed_sub_department_ids())
      GROUP BY COALESCE(sd.name, 'Bez pododeljenja')
    ) s
  ),
  'Scoped → zbir donut segmenata = SUM(cnt) iz istog GROUP BY kao RPC'
);

SELECT * FROM finish();
ROLLBACK;

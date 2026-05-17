-- Kadrovska — menadžment scope preko pododeljenja (Sprint 3.4+).
-- Kanonski: user_roles.managed_sub_department_ids int[] + employees.sub_department_id.
-- user_roles.managed_departments text[] ostaje u tabeli (deprecated), vidi COMMENT ispod.
--
-- Depends: extend_kadr_managed_departments_scope.sql, harden_kadr_menadzment_write_scope.sql,
--          employees.sub_department_id, sub_departments.
-- Idempotentno (ADD COLUMN IF NOT EXISTS, CREATE OR REPLACE).

ALTER TABLE public.user_roles
  ADD COLUMN IF NOT EXISTS managed_sub_department_ids int[] DEFAULT NULL;

COMMENT ON COLUMN public.user_roles.managed_departments IS
  'DEPRECATED 2026-05-17. Koristi managed_sub_department_ids. '
  'Ostaje u tabeli za rollback safety. Briše se u kasnijem sprintu posle 2 nedelje stabilnog rada.';

-- Helper: niz pododeljenja za JWT menadžera (NULL = legacy pun obim za ulogu menadžment).
CREATE OR REPLACE FUNCTION public.current_user_managed_sub_department_ids()
RETURNS int[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT ur.managed_sub_department_ids
  FROM public.user_roles AS ur
  WHERE lower(ur.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    AND ur.role = 'menadzment'
    AND ur.is_active IS TRUE
  ORDER BY ur.project_id NULLS FIRST
  LIMIT 1
$$;

COMMENT ON FUNCTION public.current_user_managed_sub_department_ids() IS
  'managed_sub_department_ids za JWT email i role=menadzment. NULL = HR nije ograničio pododeljenja (legacy pun obim za menadžment).';

REVOKE ALL ON FUNCTION public.current_user_managed_sub_department_ids() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.current_user_managed_sub_department_ids() TO authenticated, service_role;

-- Rollback / paralelna bezbednost: stari helper ostaje u šemi ali više ne čita
-- managed_departments (tekstualni paritet sa employees.department je uklonjen iz upotrebe).
CREATE OR REPLACE FUNCTION public.current_user_managed_departments()
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT NULL::text[];
$$;

COMMENT ON FUNCTION public.current_user_managed_departments() IS
  'DEPRECATED 2026-05-17: stub vraća NULL. Za menadžment scope koristiti '
  'current_user_managed_sub_department_ids() i employees.sub_department_id. '
  'Stara definicija: git istorija extend_kadr_managed_departments_scope.sql.';

REVOKE ALL ON FUNCTION public.current_user_managed_departments() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.current_user_managed_departments() TO authenticated, service_role;

-- Per-zaposlen: admin / HR / PM / LeadPM = pun obim; menadžment = NULL managed_sub_department_ids → pun;
-- inače sub_department_id mora biti u nizu.
CREATE OR REPLACE FUNCTION public.current_user_manages_employee(p_emp_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT CASE
    WHEN public.current_user_is_admin() THEN true
    WHEN public.current_user_is_hr() THEN true
    WHEN EXISTS (
      SELECT 1
      FROM public.user_roles AS ur
      WHERE lower(ur.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
        AND ur.role IN ('pm', 'leadpm')
        AND ur.is_active IS TRUE
    ) THEN true
    WHEN public.current_user_managed_sub_department_ids() IS NULL THEN
      EXISTS (
        SELECT 1
        FROM public.user_roles AS ur
        WHERE lower(ur.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
          AND ur.role = 'menadzment'
          AND ur.is_active IS TRUE
      )
    ELSE EXISTS (
      SELECT 1
      FROM public.employees AS e
      WHERE e.id = p_emp_id
        AND e.sub_department_id IS NOT NULL
        AND e.sub_department_id = any (public.current_user_managed_sub_department_ids())
    )
  END
$$;

COMMENT ON FUNCTION public.current_user_manages_employee(uuid) IS
  'RLS/UI: menadžment obuhvata zaposlene čije pododeljenje je u managed_sub_department_ids; '
  'NULL managed_sub_department_ids = legacy pun obim za menadžment.';

REVOKE ALL ON FUNCTION public.current_user_manages_employee(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.current_user_manages_employee(uuid) TO authenticated, service_role;

-- Produkcioni scope za tri aktivna menadžera (ID pododeljenja u skladu sa živom šemom).
UPDATE public.user_roles
SET managed_sub_department_ids = ARRAY[20, 21, 22, 23]
WHERE lower(email) = lower('dusko.kostic@servoteh.com')
  AND role = 'menadzment'
  AND is_active IS TRUE;

UPDATE public.user_roles
SET managed_sub_department_ids = ARRAY[1, 3, 4, 5]
WHERE lower(email) = lower('miljan.nikodijevic@servoteh.com')
  AND role = 'menadzment'
  AND is_active IS TRUE;

UPDATE public.user_roles
SET managed_sub_department_ids = ARRAY[2]
WHERE lower(email) = lower('strahinja.petrovic@servoteh.com')
  AND role = 'menadzment'
  AND is_active IS TRUE;

-- FE fallback RPC: dodaj scope kolone u odgovor (direktan SELECT i dalje može više polja).
-- Menja se RETURNS TABLE — Postgres zahteva DROP pre CREATE (42P13).
DROP FUNCTION IF EXISTS public.get_my_user_roles();

CREATE FUNCTION public.get_my_user_roles()
RETURNS TABLE (
  email                     text,
  role                      text,
  project_id                uuid,
  is_active                 boolean,
  managed_departments       text[],
  managed_sub_department_ids int[]
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
  SELECT
    ur.email,
    ur.role,
    ur.project_id,
    ur.is_active,
    ur.managed_departments,
    ur.managed_sub_department_ids
  FROM public.user_roles AS ur
  WHERE lower(ur.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    AND ur.is_active IS TRUE;
$$;

REVOKE ALL ON FUNCTION public.get_my_user_roles() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_user_roles() TO authenticated;

NOTIFY pgrst, 'reload schema';

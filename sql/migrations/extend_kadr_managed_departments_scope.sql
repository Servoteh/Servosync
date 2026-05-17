-- ═══════════════════════════════════════════════════════════════════════════
-- DRAFT migracija (ne izvršavati na produkciji bez revizije).
--
-- Cilj: department scope za menadžment na vacation_requests (RLS) koristeći
--   user_roles.managed_departments + JWT email (pattern kao fix_user_roles_rls).
--
-- Zamenjuje pogrešnu staru definiciju current_user_managed_departments()
-- (user_id u add_rbac_managed_departments.sql često ne postoji na user_roles).
--
-- Napomena: current_user_is_hr_or_admin() uključuje i 'menadzment', pa ga ovde
-- NE koristimo u current_user_manages_employee — inače bi scope uvek bio pun.
--
-- Depends: add_kadr_vacation_requests.sql, add_rbac_managed_departments.sql (kolona),
--          fix_user_roles_rls_recursion.sql (current_user_is_admin), …
-- Idempotentno: DROP/CREATE POLICY po uzoru na postojeće.
-- ═══════════════════════════════════════════════════════════════════════════

-- ┌───────────────────────────────────────────────────────────────────────────
-- │ ROLLBACK / istorijske definicije (referenca; ručno restore ako treba)
-- └───────────────────────────────────────────────────────────────────────────
--
-- --- Iz add_kadr_vacation_requests.sql (original current_user_can_manage_vacreq):
-- CREATE OR REPLACE FUNCTION current_user_can_manage_vacreq()
-- RETURNS boolean
-- LANGUAGE sql
-- SECURITY DEFINER
-- STABLE
-- AS $$
--   SELECT EXISTS (
--     SELECT 1 FROM user_roles
--     WHERE lower(email) = lower(auth.jwt() ->> 'email')
--       AND role IN ('admin', 'hr', 'menadzment', 'leadpm', 'pm')
--       AND is_active = true
--   )
-- $$;
--
-- --- Iz add_rbac_managed_departments.sql (stari current_user_managed_departments):
-- CREATE OR REPLACE FUNCTION public.current_user_managed_departments()
-- RETURNS TEXT[]
-- LANGUAGE sql
-- STABLE
-- SECURITY DEFINER
-- SET search_path = public
-- AS $$
--   SELECT ur.managed_departments
--     FROM public.user_roles ur
--    WHERE ur.user_id = auth.uid()
--    LIMIT 1;
-- $$;

-- ── a) Tekstovi nad kojima menadžment bira scope (paritet sa employees.department)
CREATE OR REPLACE FUNCTION public.current_user_managed_departments()
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT ur.managed_departments
  FROM public.user_roles AS ur
  WHERE lower(ur.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    AND ur.role = 'menadzment'
    AND ur.is_active IS TRUE
  ORDER BY ur.project_id NULLS FIRST
  LIMIT 1
$$;

COMMENT ON FUNCTION public.current_user_managed_departments() IS
  'managed_departments sa user_roles reda za JWT email i role=menadzment. '
  'NULL = HR nije ograničio odeljenja (legacy: pun obim). Prazan niz = nema podudaranja.';

-- ── b) Po-zaposlenom: admin / hr / pm / leadpm = pun obim;
--       menadzment = NULL managed → pun; inače match na employees.department.
CREATE OR REPLACE FUNCTION public.current_user_manages_employee(p_emp_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT CASE
    WHEN public.current_user_is_admin() THEN true
    WHEN EXISTS (
      SELECT 1
      FROM public.user_roles AS ur
      WHERE lower(ur.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
        AND ur.role = 'hr'
        AND ur.is_active IS TRUE
    ) THEN true
    WHEN EXISTS (
      SELECT 1
      FROM public.user_roles AS ur
      WHERE lower(ur.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
        AND ur.role IN ('leadpm', 'pm')
        AND ur.is_active IS TRUE
    ) THEN true
    WHEN EXISTS (
      SELECT 1
      FROM public.user_roles AS ur
      WHERE lower(ur.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
        AND ur.role = 'menadzment'
        AND ur.is_active IS TRUE
    ) THEN
      CASE
        WHEN public.current_user_managed_departments() IS NULL THEN true
        ELSE EXISTS (
          SELECT 1
          FROM public.employees AS e
          WHERE e.id = p_emp_id
            AND e.department IS NOT NULL
            AND e.department = any (public.current_user_managed_departments())
        )
      END
    ELSE false
  END
$$;

COMMENT ON FUNCTION public.current_user_manages_employee(uuid) IS
  'RLS / UI paritet: da li trenutni korisnik sme da upravlja podacima zaposlenog '
  'p_emp_id u kontekstu GO zahteva. menadzment + non-NULL managed_departments → filter.';

-- ── c) current_user_can_manage_vacreq() — isti potpis (0 argumenata).
--     Semantika: „ima šešir upravljača“ (UI / ostali pozivi). Per-red RLS za
--     vacation_requests koristi current_user_manages_employee(employee_id).
CREATE OR REPLACE FUNCTION public.current_user_can_manage_vacreq()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT exists (
    SELECT 1
    FROM public.user_roles AS ur
    WHERE lower(ur.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      AND ur.role IN ('admin', 'hr', 'menadzment', 'leadpm', 'pm')
      AND ur.is_active IS TRUE
  )
$$;

COMMENT ON FUNCTION public.current_user_can_manage_vacreq() IS
  'TRUE ako korisnik ima bilo koju od GO-upravljačkih uloga (admin/hr/menadzment/pm/leadpm). '
  'Za red vacation_requests koristiti current_user_manages_employee(employee_id).';

-- ── d) GRANT-ovi
REVOKE ALL ON FUNCTION public.current_user_managed_departments() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.current_user_managed_departments() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_managed_departments() TO service_role;

REVOKE ALL ON FUNCTION public.current_user_manages_employee(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.current_user_manages_employee(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_manages_employee(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.current_user_can_manage_vacreq() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.current_user_can_manage_vacreq() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_can_manage_vacreq() TO service_role;

-- ── e) vacation_requests: manager grana mora znati employee_id reda
DROP POLICY IF EXISTS vr_select ON public.vacation_requests;
DROP POLICY IF EXISTS vr_update ON public.vacation_requests;

CREATE POLICY vr_select ON public.vacation_requests
  FOR SELECT
  TO authenticated
  USING (
    lower(submitted_by) = lower(coalesce(auth.jwt() ->> 'email', ''))
    OR employee_id IN (
      SELECT e.id
      FROM public.employees AS e
      WHERE lower(e.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    )
    OR public.current_user_manages_employee(employee_id)
  );

CREATE POLICY vr_update ON public.vacation_requests
  FOR UPDATE
  TO authenticated
  USING (public.current_user_manages_employee(employee_id))
  WITH CHECK (public.current_user_manages_employee(employee_id));

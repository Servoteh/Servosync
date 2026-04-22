-- ═══════════════════════════════════════════════════════════
-- MIGRATION: Menadžment dobija pun EDIT pristup celom modulu
--            Kadrovska (zaposleni, odsustva, godišnji, ugovori,
--            sati, mesečni grid, notifikacije) — JEDINO Zarade
--            ostaju strogo admin-only.
--
-- Šta se menja:
--   1) public.has_edit_role()
--      → uz ('pm','leadpm') sada vraća TRUE i za ('admin','hr','menadzment').
--      → Praktično: sve `kadr_*` / `employees` / `absences` / `contracts` /
--        `work_hours` / `vacation_*` RLS politike sa qual=`has_edit_role()`
--        automatski počinju da dozvoljavaju INSERT/UPDATE/DELETE menadzment-u.
--
--   2) public.current_user_is_hr_or_admin()
--      → dodaje rolu 'menadzment' (uz 'admin' i 'hr').
--      → Time menadzment dobija edit i nad osetljivim sekcijama:
--          • employee_children
--          • kadr_notification_config
--          • kadr_notification_log
--
--   3) Zarade NIJE dirano:
--      → public.salary_terms i public.salary_payroll RLS koristi
--        public.current_user_is_admin() (ne hr_or_admin) — ostaje admin-only.
--      → public.canAccessSalary() u UI-u (state/auth.js) ostaje admin-only.
--
-- Idempotentno: CREATE OR REPLACE FUNCTION.
-- ═══════════════════════════════════════════════════════════

-- 1) has_edit_role() — širi krug ovlašćenja --------------------------------
CREATE OR REPLACE FUNCTION public.has_edit_role(proj_id uuid DEFAULT NULL::uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  auth_email TEXT := lower(coalesce(auth.jwt()->>'email', ''));
BEGIN
  IF auth_email = '' THEN
    RETURN false;
  END IF;

  -- Globalna rola (project_id IS NULL): admin, hr, menadzment, pm, leadpm.
  IF EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE lower(email) = auth_email
      AND project_id IS NULL
      AND role IN ('admin','hr','menadzment','pm','leadpm')
      AND is_active = true
  ) THEN
    RETURN true;
  END IF;

  -- Project-specifična rola (samo pm/leadpm — admin/hr/menadzment se daje
  -- isključivo globalno; ne mešamo per-project menadžment koncept).
  IF proj_id IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE lower(email) = auth_email
      AND project_id = proj_id
      AND role IN ('pm','leadpm')
      AND is_active = true
  ) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

COMMENT ON FUNCTION public.has_edit_role(uuid) IS
  'TRUE za pm/leadpm (globalno ili per-project) i za globalne admin/hr/menadzment role. '
  'Sinhronizovano sa src/state/auth.js → canEdit() / canEditKadrovska().';


-- 2) current_user_is_hr_or_admin() — uključi i menadzment -------------------
CREATE OR REPLACE FUNCTION public.current_user_is_hr_or_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE LOWER(email) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
      AND role IN ('admin','hr','menadzment')
      AND is_active = TRUE
  );
$$;

COMMENT ON FUNCTION public.current_user_is_hr_or_admin() IS
  'TRUE za admin / hr / menadzment globalne role. Koristi se u RLS politikama '
  'osetljivih sekcija Kadrovske (employee_children, kadr_notification_*).';


-- 3) Sanity / verifikacija (komentar — pusti ručno po želji) ----------------
-- SELECT has_edit_role()                AS edit_global,
--        current_user_is_hr_or_admin()  AS hr_or_admin
-- FROM auth.users
-- WHERE email IN ('miljan.nikodijevic@servoteh.com','zoran.jarakovic@servoteh.com');

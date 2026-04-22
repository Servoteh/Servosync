-- ═══════════════════════════════════════════════════════════
-- MIGRATION: Seed — Menadžment nalozi (Miljan, Zoran)
--
-- IMPORTANT (security): ovaj fajl NE sadrži ni jedan password.
-- Auth nalozi (email + bcrypt password) su kreirani RUČNO u
-- Supabase Dashboard → Authentication → Users.
-- Ova migracija samo mapira email → role u public.user_roles.
--
-- Šta radi:
--   - Dodaje (ili reaktivira) mapiranja role `menadzment` za:
--       miljan.nikodijevic@servoteh.com  → Miljan Nikodijević
--       zoran.jarakovic@servoteh.com     → Zoran Jaraković
--   - project_id = NULL → globalna dodela (sve projekte).
--   - must_change_password = TRUE → forsira zamenu passworda
--     pri prvom login-u (isti obrazac kao add_admin_roles.sql).
--
-- Rola `menadzment` mora postojati u CHECK constraint-u
-- `user_roles_role_allowed` (dodato u add_pm_teme_v2.sql).
--
-- Bezbedno za re-run (idempotentno: NOT EXISTS + UPDATE grana).
-- ═══════════════════════════════════════════════════════════

-- 0) Sanity check: rola `menadzment` je dozvoljena -----------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_roles_role_allowed'
      AND conrelid = 'public.user_roles'::regclass
      AND pg_get_constraintdef(oid) LIKE '%menadzment%'
  ) THEN
    RAISE EXCEPTION
      'user_roles_role_allowed CHECK ne dozvoljava rolu ''menadzment''. '
      'Prvo primeni sql/migrations/add_pm_teme_v2.sql.';
  END IF;
END $$;

-- 1) Insert ako još ne postoji -------------------------------------------
INSERT INTO public.user_roles (
  email, role, project_id, is_active, full_name, team,
  must_change_password, created_at, updated_at, created_by
)
SELECT v.email, 'menadzment', NULL::uuid, TRUE, v.fname, v.team,
       TRUE, now(), now(), 'nenad@servoteh.com'
FROM (VALUES
  ('miljan.nikodijevic@servoteh.com', 'Miljan Nikodijević', 'Menadžment'),
  ('zoran.jarakovic@servoteh.com',    'Zoran Jaraković',    'Menadžment')
) AS v(email, fname, team)
WHERE NOT EXISTS (
  SELECT 1 FROM public.user_roles ur
  WHERE lower(ur.email) = lower(v.email)
    AND ur.role = 'menadzment'
    AND ur.project_id IS NULL
);

-- 2) Reaktiviraj ako su prethodno deaktivirani, popuni meta ako fali -----
--    Ne diramo must_change_password — ako je korisnik već promenio,
--    ne forsiramo ponovnu zamenu.
UPDATE public.user_roles ur
SET    is_active  = TRUE,
       full_name  = COALESCE(NULLIF(ur.full_name, ''), v.fname),
       team       = COALESCE(NULLIF(ur.team, ''),      v.team),
       updated_at = now()
FROM (VALUES
  ('miljan.nikodijevic@servoteh.com', 'Miljan Nikodijević', 'Menadžment'),
  ('zoran.jarakovic@servoteh.com',    'Zoran Jaraković',    'Menadžment')
) AS v(email, fname, team)
WHERE lower(ur.email) = lower(v.email)
  AND ur.role = 'menadzment'
  AND ur.project_id IS NULL;

-- 3) Verifikacija --------------------------------------------------------
-- SELECT email, role, full_name, team, is_active, must_change_password
-- FROM public.user_roles
-- WHERE role = 'menadzment'
--   AND lower(email) IN ('miljan.nikodijevic@servoteh.com',
--                        'zoran.jarakovic@servoteh.com')
-- ORDER BY email;
-- Treba: 2 reda, oba is_active = TRUE.

-- ═══════════════════════════════════════════════════════════
-- HOTFIX: user_roles RLS infinite recursion
--
-- Bug u prethodnoj migraciji add_admin_roles.sql:
--   "user_roles_read_own_or_admin" policy je u svom telu radila
--   SELECT iz user_roles → Postgres detektuje infinite recursion
--   na policy → API vraća grešku → effectiveRole pada na 'viewer'.
--
-- Fix:
--   1) Drop stare rekurzivne politike.
--   2) Napravi SECURITY DEFINER helper public.current_user_is_admin()
--      koja unutar svog tela bypass-uje RLS (jer se izvršava kao
--      vlasnik funkcije = postgres). Bez rekurzije.
--   3) Recreate-uj 2 odvojene SELECT politike (svako vidi svoj
--      red; admin vidi sve preko helper funkcije) i 1 ALL policy
--      za pisanje (samo admin).
--   4) GRANT EXECUTE na helper za authenticated.
--
-- Bezbedno za re-run.
-- ═══════════════════════════════════════════════════════════

-- 1) Skini stare rekurzivne politike --------------------------------------
DROP POLICY IF EXISTS "user_roles_read_own_or_admin" ON user_roles;
DROP POLICY IF EXISTS "user_roles_admin_write"        ON user_roles;
-- Skini i eventualne starije nazive (best-effort)
DROP POLICY IF EXISTS "users_read_own_or_admin"       ON user_roles;
DROP POLICY IF EXISTS "users_admin_write"             ON user_roles;

-- 2) SECURITY DEFINER helper za detekciju admin-a -------------------------
--    STABLE: rezultat se ne menja unutar jedne SQL naredbe.
--    SECURITY DEFINER: izvršava se kao vlasnik funkcije → bypass RLS
--    na user_roles unutar tela funkcije (nema rekurzije).
--    SET search_path: hardening protiv search_path attack-a.
CREATE OR REPLACE FUNCTION public.current_user_is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM   public.user_roles
    WHERE  LOWER(email) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
      AND  role = 'admin'
      AND  is_active = TRUE
  );
$$;

REVOKE ALL    ON FUNCTION public.current_user_is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_is_admin() TO   authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_is_admin() TO   anon;

-- 3) RLS mora biti enabled (idempotent) ----------------------------------
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

-- 4) Nove politike --------------------------------------------------------

-- 4a) Svako autentifikovan vidi SVOJ red (po email-u iz JWT-a).
--     Nema reference na user_roles unutar policy → nema rekurzije.
CREATE POLICY "user_roles_read_self" ON user_roles
  FOR SELECT
  TO authenticated
  USING (
    LOWER(email) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
  );

-- 4b) Admin vidi SVE redove (preko SECURITY DEFINER helper-a).
--     Pošto helper bypass-uje RLS, policy se evaluira bez rekurzije.
CREATE POLICY "user_roles_read_admin_all" ON user_roles
  FOR SELECT
  TO authenticated
  USING ( public.current_user_is_admin() );

-- 4c) Pisanje (INSERT/UPDATE/DELETE) — samo aktivan admin.
CREATE POLICY "user_roles_admin_write" ON user_roles
  FOR ALL
  TO authenticated
  USING      ( public.current_user_is_admin() )
  WITH CHECK ( public.current_user_is_admin() );

-- 5) Verifikacija --------------------------------------------------------
-- a) Politike postoje?
-- SELECT polname, polcmd FROM pg_policy
-- WHERE polrelid='user_roles'::regclass
-- ORDER BY polname;
-- Treba: user_roles_admin_write, user_roles_read_admin_all, user_roles_read_self
--
-- b) Helper funkcija postoji?
-- SELECT proname, prosecdef FROM pg_proc
-- WHERE proname='current_user_is_admin' AND pronamespace='public'::regnamespace;
-- Treba: 1 red, prosecdef=t
--
-- c) Test (kao authenticated korisnik kroz REST API):
--    GET /rest/v1/user_roles?select=email,role&limit=10
--    → admin treba da vidi sve, non-admin treba da vidi samo svoj red.

-- ═══════════════════════════════════════════════════════════
-- MIGRATION: Podešavanja — Admin / HR uloge u user_roles
--
-- IMPORTANT (security): ovaj fajl NE sadrži ni jedan password.
-- Auth nalozi (email + bcrypt password) se kreiraju RUČNO u
-- Supabase Dashboard → Authentication → Users.
-- Ova tabela mapira samo email → role.
--
-- Šta radi:
--   1) Proširuje user_roles (full_name, team, created_at, updated_at,
--      created_by, must_change_password).
--   2) Postavlja CHECK na role: admin | leadpm | pm | hr | viewer.
--   3) UNIQUE(lower(email), role, project_id) — sprečava duplikate
--      i radi case-insensitive na email-u.
--   4) Indeks na lower(email) za brže lookup-e iz auth flow-a.
--   5) Seed mapiranja role-a za 3 inicijalna user-a:
--        nenad@servoteh.com           → admin
--        nevena.knezevic@servoteh.com → admin
--        nikola.mrkajic@servoteh.com  → hr
--      Idempotentno (ON CONFLICT DO UPDATE).
--   6) RLS politike: ulogovan user vidi svoj red ILI sve ako je admin;
--      piše samo admin.
--
-- Bezbedno za re-run.
-- ═══════════════════════════════════════════════════════════

-- 0) Sanity check ----------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'user_roles') THEN
    RAISE EXCEPTION 'Missing user_roles table. Initial schema must be applied first.';
  END IF;
END $$;

-- 1) Proširene kolone ------------------------------------------------------
ALTER TABLE user_roles
  ADD COLUMN IF NOT EXISTS full_name              TEXT,
  ADD COLUMN IF NOT EXISTS team                   TEXT,
  ADD COLUMN IF NOT EXISTS created_at             TIMESTAMPTZ DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at             TIMESTAMPTZ DEFAULT now(),
  ADD COLUMN IF NOT EXISTS created_by             TEXT,
  ADD COLUMN IF NOT EXISTS must_change_password   BOOLEAN     DEFAULT FALSE;

-- 2) CHECK constraint na role (admin | leadpm | pm | hr | viewer) ---------
DO $$
BEGIN
  -- Skini stari named check ako postoji
  BEGIN
    ALTER TABLE user_roles DROP CONSTRAINT IF EXISTS user_roles_role_check;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  -- Normalizuj postojeće vrednosti pre dodavanja constrainta
  UPDATE user_roles SET role = lower(trim(role)) WHERE role IS NOT NULL;
  UPDATE user_roles SET role = 'viewer'
    WHERE role IS NULL OR role NOT IN ('admin','leadpm','pm','hr','viewer');

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_roles_role_allowed'
      AND conrelid = 'user_roles'::regclass
  ) THEN
    ALTER TABLE user_roles
      ADD CONSTRAINT user_roles_role_allowed
      CHECK (role IN ('admin','leadpm','pm','hr','viewer'));
  END IF;
END $$;

-- 3) UNIQUE(lower(email), role, COALESCE(project_id::text,'__NULL__')) ---
--    project_id može biti NULL → koristimo COALESCE u expression indeksu
--    da bi NULL globalne dodele bile takođe jedinstvene po (email, role).
DO $$
BEGIN
  -- Eliminiši eventualne duplikate pre constrain-ta (zadrži najnoviji red)
  WITH ranked AS (
    SELECT id,
           row_number() OVER (
             PARTITION BY lower(email), role, COALESCE(project_id::text,'__NULL__')
             ORDER BY COALESCE(updated_at, created_at, now()) DESC
           ) AS rn
    FROM user_roles
  )
  DELETE FROM user_roles WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public' AND indexname = 'user_roles_email_role_proj_uq'
  ) THEN
    EXECUTE $i$
      CREATE UNIQUE INDEX user_roles_email_role_proj_uq
        ON user_roles (lower(email), role, COALESCE(project_id::text, '__NULL__'))
    $i$;
  END IF;
END $$;

-- 4) Lookup index na lower(email) -----------------------------------------
CREATE INDEX IF NOT EXISTS idx_user_roles_email_lower
  ON user_roles (lower(email));

-- 5) updated_at trigger (best-effort) -------------------------------------
CREATE OR REPLACE FUNCTION user_roles_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_user_roles_set_updated_at ON user_roles;
CREATE TRIGGER trg_user_roles_set_updated_at
  BEFORE UPDATE ON user_roles
  FOR EACH ROW EXECUTE FUNCTION user_roles_set_updated_at();

-- 6) Seed mapiranja role-a za 3 inicijalna user-a -------------------------
--    NEMA passworda — nalog mora već postojati u Auth.
--    project_id = NULL → globalno (sve projekte).
--    Idempotentno: koristi NOT EXISTS umesto ON CONFLICT (jer je unique
--    indeks expression-based, pa konflikt target nije direktno upotrebljiv).
INSERT INTO user_roles (email, role, project_id, is_active, full_name, team, must_change_password, created_at, updated_at)
SELECT v.email, v.role, NULL::uuid, TRUE, v.fname, v.team, TRUE, now(), now()
FROM (VALUES
  ('nenad@servoteh.com',           'admin', 'Nenad Jaraković',  'Uprava'),
  ('nevena.knezevic@servoteh.com', 'admin', 'Nevena Knežević',  'Administracija'),
  ('nikola.mrkajic@servoteh.com',  'hr',    'Nikola Mrkajić',   'Administracija')
) AS v(email, role, fname, team)
WHERE NOT EXISTS (
  SELECT 1 FROM user_roles ur
  WHERE lower(ur.email) = lower(v.email)
    AND ur.role = v.role
    AND ur.project_id IS NULL
);

-- Re-aktiviraj ako su prethodno deaktivirani, ali NE diraj must_change_password
UPDATE user_roles ur
SET    is_active = TRUE,
       full_name = COALESCE(NULLIF(ur.full_name, ''), v.fname),
       team      = COALESCE(NULLIF(ur.team, ''),      v.team),
       updated_at = now()
FROM (VALUES
  ('nenad@servoteh.com',           'admin', 'Nenad Jaraković',  'Uprava'),
  ('nevena.knezevic@servoteh.com', 'admin', 'Nevena Knežević',  'Administracija'),
  ('nikola.mrkajic@servoteh.com',  'hr',    'Nikola Mrkajić',   'Administracija')
) AS v(email, role, fname, team)
WHERE lower(ur.email) = lower(v.email)
  AND ur.role = v.role
  AND ur.project_id IS NULL;

-- 7) RLS politike ---------------------------------------------------------
--    Čitaju: svoj red ILI bilo šta ako si aktivan admin.
--    Pišu (INSERT/UPDATE/DELETE): samo aktivan admin.
--
--    VAŽNO: Policy ne sme direktno da SELECT-uje user_roles iz svog tela
--    (Postgres detektuje infinite recursion). Zato koristimo
--    SECURITY DEFINER helper public.current_user_is_admin() koji bypass-uje
--    RLS unutar svog tela. Vidi i sql/migrations/fix_user_roles_rls_recursion.sql
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

-- Helper: da li je trenutni JWT user aktivan admin?
CREATE OR REPLACE FUNCTION public.current_user_is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE LOWER(email) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
      AND role = 'admin'
      AND is_active = TRUE
  );
$$;
REVOKE ALL    ON FUNCTION public.current_user_is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_is_admin() TO   authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_is_admin() TO   anon;

-- Skini eventualne stare/rekurzivne politike
DROP POLICY IF EXISTS "user_roles_read_own_or_admin" ON user_roles;
DROP POLICY IF EXISTS "user_roles_read_self"         ON user_roles;
DROP POLICY IF EXISTS "user_roles_read_admin_all"    ON user_roles;
DROP POLICY IF EXISTS "user_roles_admin_write"       ON user_roles;

-- SELECT: svako vidi SVOJ red
CREATE POLICY "user_roles_read_self" ON user_roles
  FOR SELECT
  TO authenticated
  USING (
    LOWER(email) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
  );

-- SELECT: admin vidi sve (preko SECURITY DEFINER helper-a → bez rekurzije)
CREATE POLICY "user_roles_read_admin_all" ON user_roles
  FOR SELECT
  TO authenticated
  USING ( public.current_user_is_admin() );

-- INSERT/UPDATE/DELETE: samo aktivan admin
CREATE POLICY "user_roles_admin_write" ON user_roles
  FOR ALL
  TO authenticated
  USING      ( public.current_user_is_admin() )
  WITH CHECK ( public.current_user_is_admin() );

-- 8) Verifikacija ---------------------------------------------------------
-- SELECT email, role, full_name, team, is_active, must_change_password
-- FROM user_roles
-- WHERE role IN ('admin','hr')
-- ORDER BY role, email;
-- Treba: 3 reda.

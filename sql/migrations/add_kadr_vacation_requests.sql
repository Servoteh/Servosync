-- ═══════════════════════════════════════════════════════════════════
-- MIGRATION: Kadrovska — Zahtevi za godišnji odmor (Faza K5)
--
-- Šta uvodi:
--   * Tabela `vacation_requests` — zaposleni podnosi zahtev; HR/admin
--     odobrava ili odbija. Svaki zaposleni vidi samo svoje zahteve.
--   * Helper funkcija `current_user_can_manage_vacreq()` — TRUE za
--     role: admin, hr, menadzment, leadpm, pm.
--   * RLS:
--       SELECT  — svako vidi SAMO SVOJE (submitted_by = jwt email)
--                  ILI ima upravljačku rolu
--       INSERT  — svaki authenticated, WITH CHECK submitted_by = jwt email
--       UPDATE  — samo upravljačka rola (odobravanje / odbijanje)
--       DELETE  — samo admin / hr
--
-- Depends on:
--   add_kadrovska_module.sql   (tabela employees)
--   add_admin_roles.sql        (user_roles + current_user_is_admin)
--   schema.sql                 (update_updated_at trigger)
--
-- Idempotentno — safe za re-run.
-- ═══════════════════════════════════════════════════════════════════

-- 0) Sanity check ────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'employees') THEN
    RAISE EXCEPTION 'Missing employees. Run add_kadrovska_module.sql first.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'user_roles') THEN
    RAISE EXCEPTION 'Missing user_roles. Run add_admin_roles.sql first.';
  END IF;
END $$;

-- 1) Helper funkcija ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION current_user_can_manage_vacreq()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE lower(email) = lower(auth.jwt() ->> 'email')
      AND role IN ('admin', 'hr', 'menadzment', 'leadpm', 'pm')
      AND is_active = true
  )
$$;

-- 2) Tabela vacation_requests ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS vacation_requests (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id      UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  year             INT  NOT NULL,
  date_from        DATE NOT NULL,
  date_to          DATE NOT NULL,
  days_count       INT  NOT NULL DEFAULT 0,
  note             TEXT NOT NULL DEFAULT '',
  status           TEXT NOT NULL DEFAULT 'pending',
  reviewed_by      TEXT,          -- email osobe koja je odobrila/odbila
  reviewed_at      TIMESTAMPTZ,
  rejection_note   TEXT,
  submitted_by     TEXT NOT NULL,  -- email podnosioca (auth.jwt() ->> 'email')
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT vr_status_chk     CHECK (status IN ('pending','approved','rejected')),
  CONSTRAINT vr_dates_chk      CHECK (date_to >= date_from),
  CONSTRAINT vr_days_chk       CHECK (days_count >= 0)
);

-- 3) Indeksi ──────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'ix_vr_employee') THEN
    CREATE INDEX ix_vr_employee    ON vacation_requests (employee_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'ix_vr_submitted_by') THEN
    CREATE INDEX ix_vr_submitted_by ON vacation_requests (lower(submitted_by));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'ix_vr_status') THEN
    CREATE INDEX ix_vr_status       ON vacation_requests (status);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'ix_vr_year') THEN
    CREATE INDEX ix_vr_year         ON vacation_requests (year);
  END IF;
END $$;

-- 4) Trigger za updated_at ────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_vr_updated_at'
  ) THEN
    CREATE TRIGGER trg_vr_updated_at
      BEFORE UPDATE ON vacation_requests
      FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  END IF;
END $$;

-- 5) RLS ──────────────────────────────────────────────────────────────
ALTER TABLE vacation_requests ENABLE ROW LEVEL SECURITY;

-- Ukloni stare politike ako postoje (idempotentnost)
DROP POLICY IF EXISTS vr_select      ON vacation_requests;
DROP POLICY IF EXISTS vr_insert      ON vacation_requests;
DROP POLICY IF EXISTS vr_update      ON vacation_requests;
DROP POLICY IF EXISTS vr_delete      ON vacation_requests;

-- SELECT: zaposleni vidi SAMO SVOJE zahteve (submitted_by = email ili
--         zaposleni je vezan za taj email); upravljačka rola vidi sve.
CREATE POLICY vr_select ON vacation_requests
  FOR SELECT TO authenticated
  USING (
    lower(submitted_by) = lower(auth.jwt() ->> 'email')
    OR employee_id IN (
      SELECT id FROM employees
      WHERE lower(email) = lower(auth.jwt() ->> 'email')
    )
    OR current_user_can_manage_vacreq()
  );

-- INSERT: svaki authenticated korisnik može da podnese, ali submitted_by
--         MORA biti njegov sopstveni email (sprečava lazno pripisivanje).
CREATE POLICY vr_insert ON vacation_requests
  FOR INSERT TO authenticated
  WITH CHECK (
    lower(submitted_by) = lower(auth.jwt() ->> 'email')
  );

-- UPDATE: samo upravljačka rola (odobravanje / odbijanje)
CREATE POLICY vr_update ON vacation_requests
  FOR UPDATE TO authenticated
  USING (current_user_can_manage_vacreq())
  WITH CHECK (current_user_can_manage_vacreq());

-- DELETE: samo admin / hr
CREATE POLICY vr_delete ON vacation_requests
  FOR DELETE TO authenticated
  USING (current_user_is_hr_or_admin());

-- 6) Komentar ─────────────────────────────────────────────────────────
COMMENT ON TABLE vacation_requests IS
  'K5: Zahtevi zaposlenih za godišnji odmor. '
  'submitted_by = email podnosioca (JWT). '
  'status: pending → approved/rejected (HR/admin/menadzment).';

-- ═══════════════════════════════════════════════════════════════════════════
-- KADROVSKA — Sertifikati / licence / obuke (Faza K7)
--
-- Tabela koja prati sertifikate i licence zaposlenih: vozačke kategorije,
-- viljuškarska dozvola, varilačka licenca, ZNR obuka, ISO sertifikati itd.
--
-- Skup tipova nije fiksiran (TEXT) jer firma može da uvodi nove tipove kad
-- god joj treba; UI ih grupiše po `cert_type`.
--
-- Svaki red ima izdat datum i opcionalan datum isteka. Za istek se koristi
-- isti notifikacioni pipeline kao za lekarski pregled (cert_expiring) —
-- vidi `kadr_schedule_hr_reminders()` u add_kadr_notifications.sql kasnije.
--
-- Depends on: add_kadrovska_module.sql, add_kadr_employee_extended.sql.
-- Idempotentno, safe za re-run.
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename='employees') THEN
    RAISE EXCEPTION 'Missing employees. Run add_kadrovska_module.sql first.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='current_user_is_hr_or_admin') THEN
    RAISE EXCEPTION 'Missing current_user_is_hr_or_admin(). Run add_kadr_employee_extended.sql first.';
  END IF;
END $$;

-- 1) Tabela --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS kadr_certificates (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id   UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  /* Tip i naziv sertifikata. */
  cert_type     TEXT NOT NULL,             -- 'driver_license', 'forklift', 'welding', 'znr', 'iso', 'other'
  cert_name     TEXT NOT NULL,             -- npr. 'B kategorija', 'IPAF 3a/3b', 'EN ISO 9606-1', ...
  /* Izdavalac / br. dokumenta. */
  issuer        TEXT,
  document_no   TEXT,
  /* Datumi: izdat, ističe (opc.), oba: dokle važi. */
  issued_on     DATE NOT NULL,
  expires_on    DATE,                       -- NULL = ne ističe (npr. obuka jednom)
  /* Trošak (opciono — bitno za izveštaje o trošku obuka). */
  cost_rsd      NUMERIC(12, 2) NOT NULL DEFAULT 0,
  /* Link na sken/PDF (Storage URL). */
  document_url  TEXT,
  note          TEXT,
  /* Audit. */
  created_by    UUID REFERENCES auth.users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT kadr_certificates_dates_chk CHECK (expires_on IS NULL OR expires_on >= issued_on),
  CONSTRAINT kadr_certificates_cost_chk  CHECK (cost_rsd >= 0)
);

CREATE INDEX IF NOT EXISTS idx_kadr_certs_emp ON kadr_certificates(employee_id);
CREATE INDEX IF NOT EXISTS idx_kadr_certs_type ON kadr_certificates(cert_type);
CREATE INDEX IF NOT EXISTS idx_kadr_certs_expires
  ON kadr_certificates(expires_on)
  WHERE expires_on IS NOT NULL;

-- 2) updated_at trigger --------------------------------------------------
DROP TRIGGER IF EXISTS trg_kadr_certs_updated_at ON kadr_certificates;
CREATE TRIGGER trg_kadr_certs_updated_at
  BEFORE UPDATE ON kadr_certificates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 3) RLS -----------------------------------------------------------------
ALTER TABLE kadr_certificates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS kadr_certificates_select ON kadr_certificates;
CREATE POLICY kadr_certificates_select ON kadr_certificates
  FOR SELECT TO authenticated
  USING (current_user_is_hr_or_admin());

DROP POLICY IF EXISTS kadr_certificates_insert ON kadr_certificates;
CREATE POLICY kadr_certificates_insert ON kadr_certificates
  FOR INSERT TO authenticated
  WITH CHECK (current_user_is_hr_or_admin());

DROP POLICY IF EXISTS kadr_certificates_update ON kadr_certificates;
CREATE POLICY kadr_certificates_update ON kadr_certificates
  FOR UPDATE TO authenticated
  USING (current_user_is_hr_or_admin())
  WITH CHECK (current_user_is_hr_or_admin());

DROP POLICY IF EXISTS kadr_certificates_delete ON kadr_certificates;
CREATE POLICY kadr_certificates_delete ON kadr_certificates
  FOR DELETE TO authenticated
  USING (current_user_is_hr_or_admin());

GRANT SELECT, INSERT, UPDATE, DELETE ON kadr_certificates TO authenticated;

-- 4) View koji daje status (ok / expired / expiring_soon / lifetime) ----
CREATE OR REPLACE VIEW v_kadr_certificate_status AS
SELECT
  c.id,
  c.employee_id,
  e.full_name    AS employee_name,
  e.first_name   AS employee_first_name,
  e.last_name    AS employee_last_name,
  e.position     AS employee_position,
  e.department   AS employee_department,
  e.is_active    AS employee_active,
  c.cert_type,
  c.cert_name,
  c.issuer,
  c.document_no,
  c.issued_on,
  c.expires_on,
  c.cost_rsd,
  c.document_url,
  c.note,
  CASE
    WHEN c.expires_on IS NULL                                      THEN 'lifetime'
    WHEN c.expires_on < CURRENT_DATE                               THEN 'expired'
    WHEN c.expires_on < CURRENT_DATE + INTERVAL '30 days'          THEN 'expiring_soon'
    ELSE 'ok'
  END AS status,
  CASE
    WHEN c.expires_on IS NOT NULL THEN (c.expires_on - CURRENT_DATE)::int
    ELSE NULL
  END AS days_to_expiry
FROM kadr_certificates c
JOIN employees e ON e.id = c.employee_id;

GRANT SELECT ON v_kadr_certificate_status TO authenticated;

-- 5) Verifikacija --------------------------------------------------------
-- SELECT * FROM v_kadr_certificate_status WHERE status IN ('expired','expiring_soon') ORDER BY days_to_expiry NULLS FIRST;

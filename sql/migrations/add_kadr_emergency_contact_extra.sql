-- ═══════════════════════════════════════════════════════════════════════════
-- KADROVSKA — Hitan kontakt: dodatna polja (Faza K7)
--
-- Polja `emergency_contact_name` i `emergency_contact_phone` već postoje;
-- dodajemo:
--   * emergency_contact_relation  TEXT   — srodstvo (otac/majka/supruga/sin/...)
--   * emergency_contact_phone_alt TEXT   — alternativni broj (posao, drugi mob)
--
-- View-ovi `employees_view`, `v_employees_with_org`, `employees_safe` se
-- ažuriraju da uključe nova polja (samo HR/admin / admin gde važi).
--
-- Depends on: add_kadrovska_module.sql, add_kadr_employee_extended.sql.
-- Idempotentno, safe za re-run.
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename='employees') THEN
    RAISE EXCEPTION 'Missing employees. Run add_kadrovska_module.sql first.';
  END IF;
END $$;

-- 1) Nova polja ----------------------------------------------------------
ALTER TABLE employees
  ADD COLUMN IF NOT EXISTS emergency_contact_relation  TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_phone_alt TEXT;

-- 2) Verifikacija --------------------------------------------------------
-- SELECT column_name FROM information_schema.columns
--  WHERE table_name='employees'
--    AND column_name LIKE 'emergency_contact_%';

-- NAPOMENA: Ako postoji view employees_view koji eksponira PII polja,
-- treba ga ažurirati posebnom migracijom (sledeća rebuild migracija
-- restrict_employee_pii_admin_only.sql već uvodi pattern, isti nasleđujemo).

-- ═══════════════════════════════════════════════════════════════════════════
-- KADROVSKA — Lekarski pregledi (Faza K6 — istorija + workflow)
--
-- Iako u `employees` već postoje skalarna polja `medical_exam_date` i
-- `medical_exam_expires` (poslednji pregled), nedostaje istorija svih pregleda
-- (gde je rađen, koji tip, koliko košta, scan dokumenta). Ova migracija dodaje
-- punu istoriju kao zasebnu tabelu i trigger koji sinhronizuje skalarna polja
-- sa najnovijim unosom (kompatibilnost sa K4 notifikacijama: medical_expiring).
--
-- RLS:
--   * SELECT  — samo HR/admin (preko current_user_is_hr_or_admin())
--   * INSERT/UPDATE/DELETE — samo HR/admin
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
CREATE TABLE IF NOT EXISTS kadr_medical_exams (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id   UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  exam_date     DATE NOT NULL,                          -- kad je obavljen
  valid_until   DATE,                                    -- kad ističe (opc.)
  exam_type     TEXT NOT NULL DEFAULT 'redovan',         -- redovan | prethodni | periodicni | ciljani | vanredni
  institution   TEXT,                                    -- ustanova / lekar
  cost_rsd      NUMERIC(12, 2) NOT NULL DEFAULT 0,
  document_url  TEXT,                                    -- link/scan (Storage)
  note          TEXT,
  created_by    UUID REFERENCES auth.users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT kadr_medical_exams_dates_chk CHECK (valid_until IS NULL OR valid_until >= exam_date),
  CONSTRAINT kadr_medical_exams_type_chk CHECK (exam_type IN ('redovan','prethodni','periodicni','ciljani','vanredni')),
  CONSTRAINT kadr_medical_exams_cost_chk CHECK (cost_rsd >= 0)
);

CREATE INDEX IF NOT EXISTS idx_kadr_medical_exams_emp_date
  ON kadr_medical_exams(employee_id, exam_date DESC);

CREATE INDEX IF NOT EXISTS idx_kadr_medical_exams_valid
  ON kadr_medical_exams(valid_until)
  WHERE valid_until IS NOT NULL;

-- 2) updated_at trigger --------------------------------------------------
DROP TRIGGER IF EXISTS trg_kadr_medical_exams_updated_at ON kadr_medical_exams;
CREATE TRIGGER trg_kadr_medical_exams_updated_at
  BEFORE UPDATE ON kadr_medical_exams
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 3) Sync trigger: po insert/update/delete ažuriraj employees.medical_exam_*
--    sa najnovijim redom. Ako više ne postoji nijedan red — postavlja NULL.
CREATE OR REPLACE FUNCTION public.kadr_medical_exams_sync_employee()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $sync$
DECLARE
  v_emp UUID;
  v_latest_date   DATE;
  v_latest_until  DATE;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_emp := OLD.employee_id;
  ELSE
    v_emp := NEW.employee_id;
  END IF;

  SELECT exam_date, valid_until
    INTO v_latest_date, v_latest_until
    FROM kadr_medical_exams
    WHERE employee_id = v_emp
    ORDER BY exam_date DESC, created_at DESC
    LIMIT 1;

  UPDATE employees
     SET medical_exam_date    = v_latest_date,
         medical_exam_expires = v_latest_until
   WHERE id = v_emp;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$sync$;

DROP TRIGGER IF EXISTS trg_kadr_medical_exams_sync ON kadr_medical_exams;
CREATE TRIGGER trg_kadr_medical_exams_sync
  AFTER INSERT OR UPDATE OR DELETE ON kadr_medical_exams
  FOR EACH ROW EXECUTE FUNCTION public.kadr_medical_exams_sync_employee();

-- 4) RLS -----------------------------------------------------------------
ALTER TABLE kadr_medical_exams ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS kadr_medical_exams_select ON kadr_medical_exams;
CREATE POLICY kadr_medical_exams_select ON kadr_medical_exams
  FOR SELECT TO authenticated
  USING (current_user_is_hr_or_admin());

DROP POLICY IF EXISTS kadr_medical_exams_insert ON kadr_medical_exams;
CREATE POLICY kadr_medical_exams_insert ON kadr_medical_exams
  FOR INSERT TO authenticated
  WITH CHECK (current_user_is_hr_or_admin());

DROP POLICY IF EXISTS kadr_medical_exams_update ON kadr_medical_exams;
CREATE POLICY kadr_medical_exams_update ON kadr_medical_exams
  FOR UPDATE TO authenticated
  USING (current_user_is_hr_or_admin())
  WITH CHECK (current_user_is_hr_or_admin());

DROP POLICY IF EXISTS kadr_medical_exams_delete ON kadr_medical_exams;
CREATE POLICY kadr_medical_exams_delete ON kadr_medical_exams
  FOR DELETE TO authenticated
  USING (current_user_is_hr_or_admin());

GRANT SELECT, INSERT, UPDATE, DELETE ON kadr_medical_exams TO authenticated;

-- 5) View koji daje "izveštaj o istek/zakasnio" (za reportsTab) ----------
CREATE OR REPLACE VIEW v_kadr_medical_exam_status AS
SELECT
  e.id           AS employee_id,
  e.full_name    AS employee_name,
  e.first_name   AS employee_first_name,
  e.last_name    AS employee_last_name,
  e.position     AS employee_position,
  e.department   AS employee_department,
  e.is_active    AS employee_active,
  e.medical_exam_date,
  e.medical_exam_expires,
  CASE
    WHEN e.medical_exam_expires IS NULL AND e.medical_exam_date IS NULL THEN 'never'
    WHEN e.medical_exam_expires IS NULL                                    THEN 'unknown_expiry'
    WHEN e.medical_exam_expires < CURRENT_DATE                            THEN 'expired'
    WHEN e.medical_exam_expires < CURRENT_DATE + INTERVAL '30 days'       THEN 'expiring_soon'
    ELSE 'ok'
  END AS status,
  CASE
    WHEN e.medical_exam_expires IS NOT NULL
    THEN (e.medical_exam_expires - CURRENT_DATE)::int
    ELSE NULL
  END AS days_to_expiry
FROM employees e
WHERE e.is_active = true;

GRANT SELECT ON v_kadr_medical_exam_status TO authenticated;

-- 6) Verifikacija --------------------------------------------------------
-- SELECT * FROM v_kadr_medical_exam_status WHERE status IN ('expired','expiring_soon','never') ORDER BY days_to_expiry NULLS FIRST;

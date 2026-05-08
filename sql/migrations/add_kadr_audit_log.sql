-- ═══════════════════════════════════════════════════════════════════════════
-- KADROVSKA — Audit log (Faza K8, compliance-driven)
--
-- Beleži sve INSERT/UPDATE/DELETE operacije nad osetljivim tabelama:
--   * salary_terms          (ugovori o zaradi)
--   * salary_payroll        (mesečni obračun)
--   * contracts             (ugovori o radu)
--   * vacation_entitlements (godišnji odmor — pravo na dane)
--   * vacation_balances     (saldo GO)
--   * kadr_medical_exams    (lekarski pregledi)
--   * kadr_certificates     (sertifikati/licence)
--
-- Svaki red sadrži:
--   * actor_user_id   — auth.uid() ko je napravio promenu
--   * action          — 'INSERT' | 'UPDATE' | 'DELETE'
--   * table_name      — naziv tabele
--   * row_id          — UUID/PK reda
--   * employee_id     — (ako se može derivovati) na koga se promena odnosi
--   * before / after  — JSONB snapshot reda (za UPDATE/DELETE — before; INSERT/UPDATE — after)
--   * changed_at      — timestamp
--
-- RLS: SELECT samo admin. INSERT — kroz triggere (SECURITY DEFINER).
--
-- Idempotentno, safe za re-run.
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='current_user_is_admin') THEN
    RAISE EXCEPTION 'Missing current_user_is_admin(). Run admin roles migration first.';
  END IF;
END $$;

-- 1) Tabela --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS kadr_audit_log (
  id            BIGSERIAL PRIMARY KEY,
  actor_user_id UUID,
  actor_email   TEXT,
  action        TEXT NOT NULL,
  table_name    TEXT NOT NULL,
  row_id        TEXT,                    -- TEXT da pokrije UUID/INT PK uniformno
  employee_id   UUID,
  before_data   JSONB,
  after_data    JSONB,
  changed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT kadr_audit_action_chk CHECK (action IN ('INSERT','UPDATE','DELETE'))
);

CREATE INDEX IF NOT EXISTS idx_kadr_audit_table_time   ON kadr_audit_log(table_name, changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_kadr_audit_emp_time     ON kadr_audit_log(employee_id, changed_at DESC) WHERE employee_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_kadr_audit_actor_time   ON kadr_audit_log(actor_user_id, changed_at DESC) WHERE actor_user_id IS NOT NULL;

-- 2) RLS — samo admin čita. Trigger upisuje preko SECURITY DEFINER. -----
ALTER TABLE kadr_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS kadr_audit_log_select ON kadr_audit_log;
CREATE POLICY kadr_audit_log_select ON kadr_audit_log
  FOR SELECT TO authenticated
  USING (current_user_is_admin());

GRANT SELECT ON kadr_audit_log TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE kadr_audit_log_id_seq TO authenticated;

-- 3) Generički trigger funkcija -----------------------------------------
-- Svaka audit-ovana tabela poziva ovaj trigger sa argumentom = TEXT putanje
-- ka employee_id polju (npr. 'employee_id', ili NULL ako tabela nema employee_id).
CREATE OR REPLACE FUNCTION public.kadr_audit_log_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $aud$
DECLARE
  v_emp_field TEXT;
  v_emp UUID;
  v_row_id TEXT;
  v_before JSONB;
  v_after  JSONB;
  v_email TEXT;
BEGIN
  v_emp_field := COALESCE(TG_ARGV[0], 'employee_id');

  IF TG_OP = 'DELETE' THEN
    v_before := to_jsonb(OLD);
    v_after  := NULL;
    v_row_id := COALESCE(v_before ->> 'id', '');
    BEGIN v_emp := (v_before ->> v_emp_field)::uuid; EXCEPTION WHEN others THEN v_emp := NULL; END;
  ELSIF TG_OP = 'INSERT' THEN
    v_before := NULL;
    v_after  := to_jsonb(NEW);
    v_row_id := COALESCE(v_after ->> 'id', '');
    BEGIN v_emp := (v_after ->> v_emp_field)::uuid; EXCEPTION WHEN others THEN v_emp := NULL; END;
  ELSE  -- UPDATE
    v_before := to_jsonb(OLD);
    v_after  := to_jsonb(NEW);
    v_row_id := COALESCE(v_after ->> 'id', v_before ->> 'id', '');
    BEGIN v_emp := COALESCE((v_after ->> v_emp_field)::uuid, (v_before ->> v_emp_field)::uuid); EXCEPTION WHEN others THEN v_emp := NULL; END;
  END IF;

  /* Pokušaj naći email aktera za audit display. */
  BEGIN
    SELECT u.email INTO v_email FROM auth.users u WHERE u.id = auth.uid();
  EXCEPTION WHEN others THEN
    v_email := NULL;
  END;

  INSERT INTO kadr_audit_log (
    actor_user_id, actor_email, action, table_name, row_id, employee_id,
    before_data, after_data
  ) VALUES (
    auth.uid(), v_email, TG_OP, TG_TABLE_NAME, v_row_id, v_emp,
    v_before, v_after
  );

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$aud$;

-- 4) Triggeri po tabelama (samo ako tabele postoje) ---------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename='salary_terms') THEN
    DROP TRIGGER IF EXISTS trg_audit_salary_terms ON salary_terms;
    CREATE TRIGGER trg_audit_salary_terms
      AFTER INSERT OR UPDATE OR DELETE ON salary_terms
      FOR EACH ROW EXECUTE FUNCTION kadr_audit_log_trigger('employee_id');
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename='salary_payroll') THEN
    DROP TRIGGER IF EXISTS trg_audit_salary_payroll ON salary_payroll;
    CREATE TRIGGER trg_audit_salary_payroll
      AFTER INSERT OR UPDATE OR DELETE ON salary_payroll
      FOR EACH ROW EXECUTE FUNCTION kadr_audit_log_trigger('employee_id');
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename='contracts') THEN
    DROP TRIGGER IF EXISTS trg_audit_contracts ON contracts;
    CREATE TRIGGER trg_audit_contracts
      AFTER INSERT OR UPDATE OR DELETE ON contracts
      FOR EACH ROW EXECUTE FUNCTION kadr_audit_log_trigger('employee_id');
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename='vacation_entitlements') THEN
    DROP TRIGGER IF EXISTS trg_audit_vacation_entitlements ON vacation_entitlements;
    CREATE TRIGGER trg_audit_vacation_entitlements
      AFTER INSERT OR UPDATE OR DELETE ON vacation_entitlements
      FOR EACH ROW EXECUTE FUNCTION kadr_audit_log_trigger('employee_id');
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename='vacation_balances') THEN
    DROP TRIGGER IF EXISTS trg_audit_vacation_balances ON vacation_balances;
    CREATE TRIGGER trg_audit_vacation_balances
      AFTER INSERT OR UPDATE OR DELETE ON vacation_balances
      FOR EACH ROW EXECUTE FUNCTION kadr_audit_log_trigger('employee_id');
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename='kadr_medical_exams') THEN
    DROP TRIGGER IF EXISTS trg_audit_medical_exams ON kadr_medical_exams;
    CREATE TRIGGER trg_audit_medical_exams
      AFTER INSERT OR UPDATE OR DELETE ON kadr_medical_exams
      FOR EACH ROW EXECUTE FUNCTION kadr_audit_log_trigger('employee_id');
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename='kadr_certificates') THEN
    DROP TRIGGER IF EXISTS trg_audit_certificates ON kadr_certificates;
    CREATE TRIGGER trg_audit_certificates
      AFTER INSERT OR UPDATE OR DELETE ON kadr_certificates
      FOR EACH ROW EXECUTE FUNCTION kadr_audit_log_trigger('employee_id');
  END IF;
END $$;

-- 5) Pomoćni view sa imenom zaposlenog ----------------------------------
CREATE OR REPLACE VIEW v_kadr_audit_log AS
SELECT
  l.id,
  l.actor_user_id,
  l.actor_email,
  l.action,
  l.table_name,
  l.row_id,
  l.employee_id,
  e.full_name  AS employee_name,
  l.before_data,
  l.after_data,
  l.changed_at
FROM kadr_audit_log l
LEFT JOIN employees e ON e.id = l.employee_id;

GRANT SELECT ON v_kadr_audit_log TO authenticated;

-- 6) Verifikacija --------------------------------------------------------
-- SELECT id, action, table_name, employee_name, actor_email, changed_at
-- FROM v_kadr_audit_log
-- ORDER BY changed_at DESC LIMIT 50;

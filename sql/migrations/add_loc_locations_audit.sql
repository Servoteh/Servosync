-- ============================================================================
-- LOKACIJE DELOVA — audit master definicija hala/polica
-- ============================================================================
-- Zavisi od: add_audit_log.sql i add_loc_module.sql.
-- Kači generički audit trigger na `loc_locations` i izlaže ograničen RPC koji
-- menadžerske uloge smeju da koriste bez direktnog čitanja celog `audit_log`.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables
    WHERE schemaname = 'public' AND tablename = 'audit_log'
  ) THEN
    RAISE EXCEPTION 'add_loc_locations_audit: public.audit_log ne postoji; prvo primeni add_audit_log.sql';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'audit_row_change'
  ) THEN
    RAISE EXCEPTION 'add_loc_locations_audit: public.audit_row_change() ne postoji';
  END IF;
END$$;

DROP TRIGGER IF EXISTS trg_audit_loc_locations ON public.loc_locations;
CREATE TRIGGER trg_audit_loc_locations
  AFTER INSERT OR UPDATE OR DELETE ON public.loc_locations
  FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

CREATE OR REPLACE FUNCTION public.loc_locations_audit(p_limit int DEFAULT 100)
RETURNS TABLE (
  id bigint,
  record_id text,
  action text,
  actor_email text,
  actor_uid uuid,
  changed_at timestamptz,
  old_data jsonb,
  new_data jsonb,
  diff_keys text[]
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    al.id,
    al.record_id,
    al.action,
    al.actor_email,
    al.actor_uid,
    al.changed_at,
    al.old_data,
    al.new_data,
    al.diff_keys
  FROM public.audit_log AS al
  WHERE al.table_name = 'loc_locations'
    AND public.loc_can_manage_locations()
  ORDER BY al.changed_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 300);
$$;

REVOKE ALL ON FUNCTION public.loc_locations_audit(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.loc_locations_audit(int) TO authenticated;

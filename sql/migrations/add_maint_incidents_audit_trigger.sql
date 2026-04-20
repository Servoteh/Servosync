-- ============================================================================
-- ODRŽAVANJE — automatski zapis u maint_incident_events pri UPDATE incidenata
-- ============================================================================
-- Pokreni u Supabase SQL Editoru posle add_maintenance_module.sql.
-- Klijent više ne duplira status_change / assigned (vidi maintIncidentDialog.js).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.maint_incidents_log_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_actor uuid;
BEGIN
  v_actor := auth.uid();

  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO public.maint_incident_events (incident_id, actor, event_type, from_value, to_value, comment)
    VALUES (NEW.id, v_actor, 'status_change', OLD.status::text, NEW.status::text, NULL);
  END IF;

  IF OLD.assigned_to IS DISTINCT FROM NEW.assigned_to THEN
    INSERT INTO public.maint_incident_events (incident_id, actor, event_type, from_value, to_value, comment)
    VALUES (
      NEW.id,
      v_actor,
      'assigned',
      OLD.assigned_to::text,
      NEW.assigned_to::text,
      NULL
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS maint_incidents_audit ON public.maint_incidents;
CREATE TRIGGER maint_incidents_audit
  AFTER UPDATE ON public.maint_incidents
  FOR EACH ROW
  EXECUTE FUNCTION public.maint_incidents_log_changes();

COMMENT ON FUNCTION public.maint_incidents_log_changes() IS
  'Upisuje status_change i/ili assigned u maint_incident_events posle UPDATE-a.';

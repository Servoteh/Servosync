-- ============================================================================
-- ODRŽAVANJE — pooštravanje RLS za incidente + proširenje audit trigera
-- ============================================================================
-- Pokreni u Supabase SQL Editoru posle:
--   * add_maintenance_module.sql
--   * add_maint_incidents_audit_trigger.sql  (ova migracija prepisuje funkciju i trigger)
--
-- Šta menja:
--   (1) Zatvaranje incidenta (status = 'closed') smeju samo ERP admin ili šef/admin iz
--       maint_user_profiles. Baza više ne oslanjanje na UI za ovo pravilo.
--   (2) Pri INSERT-u incidenta automatski se upisuje 'created' događaj u
--       maint_incident_events (klijent više ne šalje ručno).
-- ============================================================================

-- ── (1) Helper + preoštrena UPDATE politika ─────────────────────────────────

CREATE OR REPLACE FUNCTION public.maint_can_close_incident()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.maint_is_erp_admin()
      OR public.maint_profile_role() IN ('chief', 'admin');
$$;

COMMENT ON FUNCTION public.maint_can_close_incident() IS
  'True samo ako tekući korisnik sme da postavi status = closed (šef/admin maint ili ERP admin).';

DROP POLICY IF EXISTS maint_incidents_update ON public.maint_incidents;
CREATE POLICY maint_incidents_update ON public.maint_incidents
  FOR UPDATE USING (
    public.maint_machine_visible(machine_code)
    AND (
      public.maint_is_erp_admin()
      OR public.maint_profile_role() IN ('technician', 'chief', 'admin')
    )
  )
  WITH CHECK (
    public.maint_machine_visible(machine_code)
    AND (
      status <> 'closed'
      OR public.maint_can_close_incident()
    )
  );

-- ── (2) Proširen audit trigger: INSERT → 'created', UPDATE → status/assigned ──

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

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.maint_incident_events (incident_id, actor, event_type, from_value, to_value, comment)
    VALUES (NEW.id, v_actor, 'created', NULL, NEW.status::text, NULL);
    RETURN NEW;
  END IF;

  -- UPDATE
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
  AFTER INSERT OR UPDATE ON public.maint_incidents
  FOR EACH ROW
  EXECUTE FUNCTION public.maint_incidents_log_changes();

COMMENT ON FUNCTION public.maint_incidents_log_changes() IS
  'Audit za maint_incidents: INSERT upisuje "created", UPDATE upisuje "status_change"/"assigned".';

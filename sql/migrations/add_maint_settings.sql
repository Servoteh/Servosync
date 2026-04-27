-- ============================================================================
-- ODRŽAVANJE (CMMS) — centralna podešavanja modula
-- ============================================================================
-- MORA posle:
--   * add_maintenance_module.sql
--   * add_maint_work_orders.sql
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.maint_settings (
  id                            INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  auto_create_wo_major          BOOLEAN NOT NULL DEFAULT true,
  auto_create_wo_critical       BOOLEAN NOT NULL DEFAULT true,
  safety_marker_requires_wo     BOOLEAN NOT NULL DEFAULT true,
  default_wo_priority           public.maint_wo_priority NOT NULL DEFAULT 'p4_planirano',
  major_wo_due_hours            INT NOT NULL DEFAULT 48,
  critical_wo_due_hours         INT NOT NULL DEFAULT 8,
  preventive_due_warning_days   INT NOT NULL DEFAULT 7,
  notification_enabled          BOOLEAN NOT NULL DEFAULT true,
  notify_on_major_incident      BOOLEAN NOT NULL DEFAULT true,
  notify_on_critical_incident   BOOLEAN NOT NULL DEFAULT true,
  notify_on_overdue_preventive  BOOLEAN NOT NULL DEFAULT true,
  notification_channels         public.maint_notification_channel[] NOT NULL DEFAULT ARRAY['in_app']::public.maint_notification_channel[],
  status_labels                 JSONB NOT NULL DEFAULT '{
    "running": "Radi",
    "degraded": "Smetnje",
    "down": "Zastoj",
    "maintenance": "Održavanje"
  }'::jsonb,
  wo_status_labels              JSONB NOT NULL DEFAULT '{
    "new": "Nov",
    "triage": "Trijaža",
    "planned": "Planirano",
    "in_progress": "U radu",
    "waiting_parts": "Čeka delove",
    "done": "Završeno",
    "cancelled": "Otkazano"
  }'::jsonb,
  notes                         TEXT,
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by                    UUID REFERENCES auth.users (id) ON DELETE SET NULL,
  CONSTRAINT maint_settings_due_hours_positive CHECK (
    major_wo_due_hours > 0
    AND critical_wo_due_hours > 0
    AND preventive_due_warning_days >= 0
  )
);

INSERT INTO public.maint_settings (id)
VALUES (1)
ON CONFLICT (id) DO NOTHING;

DROP TRIGGER IF EXISTS maint_settings_touch_updated ON public.maint_settings;
CREATE TRIGGER maint_settings_touch_updated
  BEFORE UPDATE ON public.maint_settings
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

ALTER TABLE public.maint_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS maint_settings_select ON public.maint_settings;
CREATE POLICY maint_settings_select ON public.maint_settings
  FOR SELECT USING (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('operator', 'technician', 'chief', 'admin')
  );

DROP POLICY IF EXISTS maint_settings_update ON public.maint_settings;
CREATE POLICY maint_settings_update ON public.maint_settings
  FOR UPDATE USING (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
  )
  WITH CHECK (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
  );

GRANT SELECT, UPDATE ON public.maint_settings TO authenticated;

COMMIT;

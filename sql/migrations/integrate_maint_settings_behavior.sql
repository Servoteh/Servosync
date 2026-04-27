-- ============================================================================
-- ODRŽAVANJE (CMMS) — primena maint_settings na auto-WO i incident notifikacije
-- ============================================================================
-- MORA posle:
--   * add_maint_settings.sql
--   * extend_maint_incidents_assets.sql
--   * add_maint_notification_outbox.sql
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.maint_incidents_autocreate_work_order()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_asset UUID;
  v_tcode public.maint_asset_type;
  v_pri public.maint_wo_priority;
  v_st public.maint_wo_status;
  v_t public.maint_wo_type := 'incident';
  v_wo UUID;
  v_settings public.maint_settings%ROWTYPE;
  v_safety BOOLEAN := COALESCE(NEW.safety_marker, false);
  v_due_hours INT;
BEGIN
  IF NEW.work_order_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_settings
  FROM public.maint_settings
  WHERE id = 1;

  IF NOT FOUND THEN
    v_settings.auto_create_wo_major := true;
    v_settings.auto_create_wo_critical := true;
    v_settings.safety_marker_requires_wo := true;
    v_settings.default_wo_priority := 'p4_planirano'::public.maint_wo_priority;
    v_settings.major_wo_due_hours := 48;
    v_settings.critical_wo_due_hours := 8;
  END IF;

  IF NOT (
    (NEW.severity = 'critical' AND COALESCE(v_settings.auto_create_wo_critical, true))
    OR (NEW.severity = 'major' AND COALESCE(v_settings.auto_create_wo_major, true))
    OR (v_safety AND COALESCE(v_settings.safety_marker_requires_wo, true))
  ) THEN
    RETURN NEW;
  END IF;

  IF NEW.asset_id IS NOT NULL THEN
    SELECT a.asset_id, a.asset_type
    INTO v_asset, v_tcode
    FROM public.maint_assets a
    WHERE a.asset_id = NEW.asset_id;
  ELSE
    SELECT m.asset_id, 'machine'::public.maint_asset_type
    INTO v_asset, v_tcode
    FROM public.maint_machines m
    WHERE m.machine_code = NEW.machine_code
    LIMIT 1;
  END IF;

  IF v_asset IS NULL THEN
    RETURN NEW;
  END IF;

  v_pri := CASE
    WHEN NEW.severity = 'critical' OR v_safety THEN 'p1_zastoj'::public.maint_wo_priority
    WHEN NEW.severity = 'major' THEN COALESCE(v_settings.default_wo_priority, 'p2_smetnja'::public.maint_wo_priority)
    ELSE COALESCE(v_settings.default_wo_priority, 'p4_planirano'::public.maint_wo_priority)
  END;
  v_st := CASE NEW.severity WHEN 'critical' THEN 'potvrden'::public.maint_wo_status ELSE 'novi'::public.maint_wo_status END;
  v_due_hours := CASE
    WHEN NEW.severity = 'critical' OR v_safety THEN COALESCE(v_settings.critical_wo_due_hours, 8)
    ELSE COALESCE(v_settings.major_wo_due_hours, 48)
  END;

  INSERT INTO public.maint_work_orders (
    type, asset_id, asset_type, source_incident_id, title, description,
    priority, status, reported_by, assigned_to, safety_marker, due_at
  ) VALUES (
    v_t, v_asset, v_tcode, NEW.id, NEW.title, NEW.description,
    v_pri, v_st, NEW.reported_by, NEW.assigned_to, v_safety, now() + make_interval(hours => v_due_hours)
  ) RETURNING wo_id INTO v_wo;

  UPDATE public.maint_incidents
  SET work_order_id = v_wo
  WHERE id = NEW.id;

  RETURN NEW;
END;
$fn$;

CREATE TABLE IF NOT EXISTS public.maint_notification_rules (
  rule_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type        TEXT NOT NULL,
  severity          TEXT,
  asset_type        public.maint_asset_type,
  target_role       public.maint_maint_role,
  channel           public.maint_notification_channel NOT NULL,
  delay_minutes     INT NOT NULL DEFAULT 0,
  escalation_level  INT NOT NULL DEFAULT 0,
  enabled           BOOLEAN NOT NULL DEFAULT true,
  notes             TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by        UUID REFERENCES auth.users (id) ON DELETE SET NULL,
  CONSTRAINT maint_notification_rules_event_nonempty CHECK (length(trim(event_type)) > 0),
  CONSTRAINT maint_notification_rules_delay_nonnegative CHECK (delay_minutes >= 0 AND escalation_level >= 0)
);

CREATE INDEX IF NOT EXISTS idx_maint_notification_rules_match
  ON public.maint_notification_rules (event_type, severity, asset_type, enabled);

INSERT INTO public.maint_notification_rules (event_type, severity, target_role, channel, delay_minutes, escalation_level, notes)
VALUES
  ('incident_created', 'major', 'chief', 'in_app', 0, 0, 'Default: major incident to chief'),
  ('incident_created', 'critical', 'chief', 'in_app', 0, 0, 'Default: critical incident to chief'),
  ('incident_created', 'critical', 'admin', 'in_app', 15, 1, 'Default escalation: critical incident to admin')
ON CONFLICT DO NOTHING;

DROP TRIGGER IF EXISTS maint_notification_rules_touch_updated ON public.maint_notification_rules;
CREATE TRIGGER maint_notification_rules_touch_updated
  BEFORE UPDATE ON public.maint_notification_rules
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

ALTER TABLE public.maint_notification_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS maint_notification_rules_select ON public.maint_notification_rules;
CREATE POLICY maint_notification_rules_select ON public.maint_notification_rules
  FOR SELECT USING (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'management', 'admin')
  );

DROP POLICY IF EXISTS maint_notification_rules_insert ON public.maint_notification_rules;
CREATE POLICY maint_notification_rules_insert ON public.maint_notification_rules
  FOR INSERT WITH CHECK (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
  );

DROP POLICY IF EXISTS maint_notification_rules_update ON public.maint_notification_rules;
CREATE POLICY maint_notification_rules_update ON public.maint_notification_rules
  FOR UPDATE USING (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
  )
  WITH CHECK (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
  );

GRANT SELECT, INSERT, UPDATE ON public.maint_notification_rules TO authenticated;

CREATE OR REPLACE FUNCTION public.maint_incidents_enqueue_notify()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_subject TEXT;
  v_body TEXT;
  v_settings public.maint_settings%ROWTYPE;
  v_have_settings BOOLEAN := false;
  v_rule RECORD;
  v_asset_type public.maint_asset_type;
  v_count INT := 0;
  v_notification_id UUID;
BEGIN
  SELECT * INTO v_settings
  FROM public.maint_settings
  WHERE id = 1;
  v_have_settings := FOUND;

  IF v_have_settings AND COALESCE(v_settings.notification_enabled, true) IS FALSE THEN
    RETURN NEW;
  END IF;

  IF NEW.severity = 'major' AND v_have_settings AND COALESCE(v_settings.notify_on_major_incident, true) IS FALSE THEN
    RETURN NEW;
  END IF;
  IF NEW.severity = 'critical' AND v_have_settings AND COALESCE(v_settings.notify_on_critical_incident, true) IS FALSE THEN
    RETURN NEW;
  END IF;
  IF NEW.severity NOT IN ('major', 'critical') THEN
    RETURN NEW;
  END IF;

  v_asset_type := NEW.asset_type;
  v_subject := format('[Održavanje] %s incident: %s', upper(NEW.severity::text), NEW.title);
  v_body := format('Sredstvo %s — %s (%s). Status: %s.',
    COALESCE(NEW.machine_code, NEW.asset_id::text, '—'),
    NEW.title,
    NEW.severity,
    NEW.status);

  FOR v_rule IN
    SELECT *
    FROM public.maint_notification_rules r
    WHERE r.enabled
      AND r.event_type = 'incident_created'
      AND (r.severity IS NULL OR r.severity = NEW.severity::text)
      AND (r.asset_type IS NULL OR r.asset_type = v_asset_type)
      AND (
        NOT v_have_settings
        OR v_settings.notification_channels IS NULL
        OR r.channel = ANY(v_settings.notification_channels)
      )
    ORDER BY r.escalation_level ASC, r.delay_minutes ASC
  LOOP
    v_notification_id := public.maint_enqueue_notification(
      v_rule.channel,
      NULL,
      NULL,
      v_subject,
      v_body,
      'maint_incident',
      NEW.id,
      NEW.machine_code,
      v_rule.escalation_level,
      jsonb_build_object(
        'severity', NEW.severity,
        'reported_by', NEW.reported_by,
        'assigned_to', NEW.assigned_to,
        'target_role', v_rule.target_role,
        'rule_id', v_rule.rule_id
      )
    );
    UPDATE public.maint_notification_log
    SET scheduled_at = now() + make_interval(mins => COALESCE(v_rule.delay_minutes, 0)),
        next_attempt_at = now() + make_interval(mins => COALESCE(v_rule.delay_minutes, 0))
    WHERE id = v_notification_id;
    v_count := v_count + 1;
  END LOOP;

  IF v_count = 0 THEN
    PERFORM public.maint_enqueue_notification(
      'in_app'::public.maint_notification_channel,
      NULL,
      NULL,
      v_subject,
      v_body,
      'maint_incident',
      NEW.id,
      NEW.machine_code,
      0,
      jsonb_build_object('severity', NEW.severity, 'reported_by', NEW.reported_by, 'assigned_to', NEW.assigned_to)
    );
  END IF;

  RETURN NEW;
END;
$$;

COMMIT;

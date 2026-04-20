-- ============================================================================
-- MODUL ODRŽAVANJE MAŠINA — Faza 1 (Postgres + RLS + view-ovi)
-- ============================================================================
-- Pokreni JEDNOM u Supabase SQL Editoru (posle backup-a).
--
-- Zavisi od: auth.users, public.user_roles (admin global), public.bigtehn_machines_cache
--   (rj_code — logički ID mašine; bez FK na cache zbog sync brisanja/punjenja).
--
-- Konvencija: tabele/funkcije prefiks maint_* da ne sudaraju sa budućim "user_profiles".
-- Aplikacija koristi machine_code TEXT (= rj_code iz BigTehn cache-a).
--
-- DOWN (ručno, rollback test):
--   DROP VIEW IF EXISTS public.v_maint_machine_current_status CASCADE;
--   DROP VIEW IF EXISTS public.v_maint_task_due_dates CASCADE;
--   DROP VIEW IF EXISTS public.v_maint_machine_last_check CASCADE;
--   DROP POLICY IF EXISTS ... (po tabelama);
--   DROP TABLE IF EXISTS public.maint_notification_log CASCADE;
--   DROP TABLE IF EXISTS public.maint_machine_status_override CASCADE;
--   DROP TABLE IF EXISTS public.maint_machine_notes CASCADE;
--   DROP TABLE IF EXISTS public.maint_incident_events CASCADE;
--   DROP TABLE IF EXISTS public.maint_incidents CASCADE;
--   DROP TABLE IF EXISTS public.maint_checks CASCADE;
--   DROP TABLE IF EXISTS public.maint_tasks CASCADE;
--   DROP TABLE IF EXISTS public.maint_user_profiles CASCADE;
--   DROP FUNCTION IF EXISTS public.maint_* CASCADE;
--   DROP TYPE IF EXISTS public.maint_* CASCADE;
-- ============================================================================

-- ── Enum tipovi (idempotentno) ───────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE public.maint_maint_role AS ENUM (
    'operator', 'technician', 'chief', 'management', 'admin'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.maint_interval_unit AS ENUM ('hours', 'days', 'weeks', 'months');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.maint_task_severity AS ENUM ('normal', 'important', 'critical');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.maint_check_result AS ENUM ('ok', 'warning', 'fail', 'skipped');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.maint_incident_severity AS ENUM ('minor', 'major', 'critical');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.maint_incident_status AS ENUM (
    'open', 'acknowledged', 'in_progress', 'awaiting_parts', 'resolved', 'closed'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.maint_operational_status AS ENUM ('running', 'degraded', 'down', 'maintenance');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.maint_notification_channel AS ENUM ('telegram', 'email', 'in_app');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.maint_notification_status AS ENUM ('queued', 'sent', 'failed');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── Helper: admin iz postojeće user_roles (globalni admin) ────────────────
CREATE OR REPLACE FUNCTION public.maint_is_erp_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles ur
    WHERE ur.is_active = true
      AND ur.project_id IS NULL
      AND lower(ur.email) = lower(coalesce(auth.jwt()->>'email', ''))
      AND lower(ur.role::text) = 'admin'
  );
$$;

-- Široko čitanje fabrike za ERP uloge (bez obaveznog maint_user_profiles reda).
CREATE OR REPLACE FUNCTION public.maint_has_floor_read_access()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.maint_is_erp_admin()
    OR EXISTS (
      SELECT 1
      FROM public.user_roles ur
      WHERE ur.is_active = true
        AND ur.project_id IS NULL
        AND lower(ur.email) = lower(coalesce(auth.jwt()->>'email', ''))
        AND lower(ur.role::text) IN ('admin', 'pm', 'leadpm', 'menadzment')
    );
$$;

-- ── Profil održavanja (jedan red po auth korisniku) ───────────────────────
CREATE TABLE IF NOT EXISTS public.maint_user_profiles (
  user_id               UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name             TEXT NOT NULL,
  role                  public.maint_maint_role NOT NULL DEFAULT 'operator',
  telegram_chat_id      TEXT,
  assigned_machine_codes TEXT[] NOT NULL DEFAULT '{}',
  active                BOOLEAN NOT NULL DEFAULT true,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_maint_profiles_role
  ON public.maint_user_profiles (role) WHERE active = true;

CREATE OR REPLACE FUNCTION public.maint_profile_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.role::text
  FROM public.maint_user_profiles p
  WHERE p.user_id = auth.uid() AND p.active = true
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.maint_assigned_machine_codes()
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(
    (SELECT assigned_machine_codes
     FROM public.maint_user_profiles
     WHERE user_id = auth.uid() AND active = true
     LIMIT 1),
    ARRAY[]::text[]
  );
$$;

-- Mašina vidljiva korisniku (operator samo dodeljene; ostali širi pristup).
CREATE OR REPLACE FUNCTION public.maint_machine_visible(p_machine_code text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.maint_has_floor_read_access()
    OR public.maint_profile_role() IN ('chief', 'technician', 'management', 'admin')
    OR (
      public.maint_profile_role() = 'operator'
      AND coalesce(cardinality(public.maint_assigned_machine_codes()), 0) > 0
      AND p_machine_code = ANY (public.maint_assigned_machine_codes())
    );
$$;

-- ── Šabloni preventivnih kontrola (po jednoj mašini, faza 1) ──────────────
CREATE TABLE IF NOT EXISTS public.maint_tasks (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  machine_code          TEXT NOT NULL,
  title                 TEXT NOT NULL,
  description           TEXT,
  instructions          TEXT,
  interval_value        INT NOT NULL CHECK (interval_value > 0),
  interval_unit         public.maint_interval_unit NOT NULL,
  severity              public.maint_task_severity NOT NULL DEFAULT 'normal',
  required_role         public.maint_maint_role NOT NULL DEFAULT 'operator',
  grace_period_days     INT NOT NULL DEFAULT 3 CHECK (grace_period_days >= 0),
  active                BOOLEAN NOT NULL DEFAULT true,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by            UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by            UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT maint_tasks_machine_code_nonempty CHECK (length(trim(machine_code)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_maint_tasks_machine ON public.maint_tasks (machine_code) WHERE active = true;

-- ── Log izvršenih kontrola ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.maint_checks (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id               UUID NOT NULL REFERENCES public.maint_tasks(id) ON DELETE CASCADE,
  machine_code          TEXT NOT NULL,
  performed_by          UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  performed_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  result                public.maint_check_result NOT NULL,
  notes                 TEXT,
  attachment_urls       TEXT[] NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by            UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_maint_checks_machine_time
  ON public.maint_checks (machine_code, performed_at DESC);
CREATE INDEX IF NOT EXISTS idx_maint_checks_task_time
  ON public.maint_checks (task_id, performed_at DESC);

-- ── Incidenti ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.maint_incidents (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  machine_code          TEXT NOT NULL,
  reported_by           UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  reported_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  title                 TEXT NOT NULL,
  description           TEXT,
  severity              public.maint_incident_severity NOT NULL DEFAULT 'minor',
  status                public.maint_incident_status NOT NULL DEFAULT 'open',
  assigned_to           UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  resolved_at           TIMESTAMPTZ,
  closed_at             TIMESTAMPTZ,
  resolution_notes      TEXT,
  downtime_minutes      INT,
  attachment_urls       TEXT[] NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by            UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT maint_incidents_machine_nonempty CHECK (length(trim(machine_code)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_maint_incidents_machine ON public.maint_incidents (machine_code);
CREATE INDEX IF NOT EXISTS idx_maint_incidents_open
  ON public.maint_incidents (status) WHERE status NOT IN ('resolved', 'closed');
CREATE INDEX IF NOT EXISTS idx_maint_incidents_assigned
  ON public.maint_incidents (assigned_to) WHERE status NOT IN ('resolved', 'closed');

CREATE TABLE IF NOT EXISTS public.maint_incident_events (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id           UUID NOT NULL REFERENCES public.maint_incidents(id) ON DELETE CASCADE,
  actor                 UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  at                    TIMESTAMPTZ NOT NULL DEFAULT now(),
  event_type            TEXT NOT NULL,
  from_value            TEXT,
  to_value              TEXT,
  comment               TEXT
);

CREATE INDEX IF NOT EXISTS idx_maint_incident_events_incident
  ON public.maint_incident_events (incident_id, at);

-- ── Napomene po mašini ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.maint_machine_notes (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  machine_code          TEXT NOT NULL,
  author                UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  content               TEXT NOT NULL,
  pinned                BOOLEAN NOT NULL DEFAULT false,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at            TIMESTAMPTZ,
  CONSTRAINT maint_notes_machine_nonempty CHECK (length(trim(machine_code)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_maint_notes_machine
  ON public.maint_machine_notes (machine_code, pinned DESC, created_at DESC)
  WHERE deleted_at IS NULL;

-- ── Manuelni override statusa ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.maint_machine_status_override (
  machine_code          TEXT PRIMARY KEY,
  status                public.maint_operational_status NOT NULL,
  reason                TEXT NOT NULL,
  set_by                UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  set_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_until           TIMESTAMPTZ,
  CONSTRAINT maint_override_machine_nonempty CHECK (length(trim(machine_code)) > 0)
);

-- ── Log notifikacija (Edge Function + service role) ──────────────────────
CREATE TABLE IF NOT EXISTS public.maint_notification_log (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel               public.maint_notification_channel NOT NULL,
  recipient             TEXT NOT NULL,
  recipient_user_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  subject               TEXT,
  body                  TEXT NOT NULL,
  related_entity_type   TEXT,
  related_entity_id     UUID,
  machine_code          TEXT,
  escalation_level      INT NOT NULL DEFAULT 0,
  status                public.maint_notification_status NOT NULL DEFAULT 'queued',
  error                 TEXT,
  sent_at               TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_maint_notif_entity
  ON public.maint_notification_log (related_entity_type, related_entity_id);
CREATE INDEX IF NOT EXISTS idx_maint_notif_machine
  ON public.maint_notification_log (machine_code, created_at DESC);

-- ── updated_at trigger (reuse ako postoji public.touch_updated_at) ───────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'touch_updated_at'
  ) THEN
    CREATE OR REPLACE FUNCTION public.touch_updated_at()
    RETURNS TRIGGER AS $f$
    BEGIN NEW.updated_at = now(); RETURN NEW; END;
    $f$ LANGUAGE plpgsql;
  END IF;
END $$;

DROP TRIGGER IF EXISTS maint_profiles_touch_updated ON public.maint_user_profiles;
CREATE TRIGGER maint_profiles_touch_updated
  BEFORE UPDATE ON public.maint_user_profiles
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS maint_tasks_touch_updated ON public.maint_tasks;
CREATE TRIGGER maint_tasks_touch_updated
  BEFORE UPDATE ON public.maint_tasks
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS maint_checks_touch_updated ON public.maint_checks;
CREATE TRIGGER maint_checks_touch_updated
  BEFORE UPDATE ON public.maint_checks
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS maint_incidents_touch_updated ON public.maint_incidents;
CREATE TRIGGER maint_incidents_touch_updated
  BEFORE UPDATE ON public.maint_incidents
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS maint_notes_touch_updated ON public.maint_machine_notes;
CREATE TRIGGER maint_notes_touch_updated
  BEFORE UPDATE ON public.maint_machine_notes
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- ── View: poslednja kontrola po (task, mašina) ─────────────────────────────
CREATE OR REPLACE VIEW public.v_maint_machine_last_check
WITH (security_invoker = true) AS
SELECT DISTINCT ON (task_id, machine_code)
  task_id,
  machine_code,
  performed_at,
  result
FROM public.maint_checks
ORDER BY task_id, machine_code, performed_at DESC;

-- ── View: sledeći rokovi (bez machine_group; samo maint_tasks.machine_code) ─
CREATE OR REPLACE VIEW public.v_maint_task_due_dates
WITH (security_invoker = true) AS
SELECT
  t.id AS task_id,
  t.machine_code,
  t.title,
  t.severity,
  t.interval_value,
  t.interval_unit,
  t.grace_period_days,
  coalesce(
    lc.performed_at + (
      CASE t.interval_unit
        WHEN 'hours' THEN (t.interval_value::text || ' hours')::interval
        WHEN 'days' THEN (t.interval_value::text || ' days')::interval
        WHEN 'weeks' THEN ((t.interval_value * 7)::text || ' days')::interval
        WHEN 'months' THEN (t.interval_value::text || ' months')::interval
      END
    ),
    now()
  ) AS next_due_at,
  lc.performed_at AS last_performed_at
FROM public.maint_tasks t
LEFT JOIN public.v_maint_machine_last_check lc
  ON lc.task_id = t.id AND lc.machine_code = t.machine_code
WHERE t.active = true;

-- ── View: izvedeni status po mašini (iz bigtehn_machines_cache) ────────────
CREATE OR REPLACE VIEW public.v_maint_machine_current_status
WITH (security_invoker = true) AS
SELECT
  m.rj_code AS machine_code,
  coalesce(
    mso.status,
    CASE
      WHEN EXISTS (
        SELECT 1 FROM public.maint_incidents i
        WHERE i.machine_code = m.rj_code
          AND i.status NOT IN ('resolved', 'closed')
          AND i.severity = 'critical'
      ) THEN 'down'::public.maint_operational_status
      WHEN EXISTS (
        SELECT 1 FROM public.maint_incidents i
        WHERE i.machine_code = m.rj_code
          AND i.status NOT IN ('resolved', 'closed')
          AND i.severity = 'major'
      ) THEN 'degraded'::public.maint_operational_status
      WHEN EXISTS (
        SELECT 1 FROM public.v_maint_task_due_dates d
        WHERE d.machine_code = m.rj_code
          AND d.severity = 'critical'
          AND d.next_due_at < (now() - (d.grace_period_days::text || ' days')::interval)
      ) THEN 'degraded'::public.maint_operational_status
      WHEN EXISTS (
        SELECT 1 FROM public.v_maint_task_due_dates d
        WHERE d.machine_code = m.rj_code
          AND d.next_due_at < now()
      ) THEN 'degraded'::public.maint_operational_status
      ELSE 'running'::public.maint_operational_status
    END
  ) AS status,
  (SELECT count(*)::int FROM public.maint_incidents i
   WHERE i.machine_code = m.rj_code AND i.status NOT IN ('resolved', 'closed')) AS open_incidents_count,
  (SELECT count(*)::int FROM public.v_maint_task_due_dates d
   WHERE d.machine_code = m.rj_code AND d.next_due_at < now()) AS overdue_checks_count,
  mso.reason AS override_reason,
  mso.valid_until AS override_valid_until
FROM public.bigtehn_machines_cache m
LEFT JOIN public.maint_machine_status_override mso
  ON mso.machine_code = m.rj_code
 AND (mso.valid_until IS NULL OR mso.valid_until > now());

COMMENT ON VIEW public.v_maint_machine_current_status IS
  'Status samo za mašine u bigtehn_machines_cache; incidenti na nepoznatom kodu ne ulaze u ovaj view.';

-- ── RLS ───────────────────────────────────────────────────────────────────
ALTER TABLE public.maint_user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maint_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maint_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maint_incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maint_incident_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maint_machine_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maint_machine_status_override ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maint_notification_log ENABLE ROW LEVEL SECURITY;

-- maint_user_profiles
DROP POLICY IF EXISTS maint_profiles_select ON public.maint_user_profiles;
CREATE POLICY maint_profiles_select ON public.maint_user_profiles
  FOR SELECT USING (auth.uid() = user_id OR public.maint_is_erp_admin());

DROP POLICY IF EXISTS maint_profiles_insert ON public.maint_user_profiles;
CREATE POLICY maint_profiles_insert ON public.maint_user_profiles
  FOR INSERT WITH CHECK (public.maint_is_erp_admin());

DROP POLICY IF EXISTS maint_profiles_update ON public.maint_user_profiles;
CREATE POLICY maint_profiles_update ON public.maint_user_profiles
  FOR UPDATE USING (public.maint_is_erp_admin() OR auth.uid() = user_id)
  WITH CHECK (public.maint_is_erp_admin() OR auth.uid() = user_id);

DROP POLICY IF EXISTS maint_profiles_delete ON public.maint_user_profiles;
CREATE POLICY maint_profiles_delete ON public.maint_user_profiles
  FOR DELETE USING (public.maint_is_erp_admin());

-- maint_tasks (šablone: čitanje po vidljivosti mašine; pisanje chief + ERP admin)
DROP POLICY IF EXISTS maint_tasks_select ON public.maint_tasks;
CREATE POLICY maint_tasks_select ON public.maint_tasks
  FOR SELECT USING (
    public.maint_machine_visible(machine_code)
  );

DROP POLICY IF EXISTS maint_tasks_insert ON public.maint_tasks;
CREATE POLICY maint_tasks_insert ON public.maint_tasks
  FOR INSERT WITH CHECK (
    public.maint_is_erp_admin()
    OR public.maint_profile_role() IN ('chief', 'admin')
  );

DROP POLICY IF EXISTS maint_tasks_update ON public.maint_tasks;
CREATE POLICY maint_tasks_update ON public.maint_tasks
  FOR UPDATE USING (
    public.maint_is_erp_admin()
    OR public.maint_profile_role() IN ('chief', 'admin')
  )
  WITH CHECK (
    public.maint_is_erp_admin()
    OR public.maint_profile_role() IN ('chief', 'admin')
  );

DROP POLICY IF EXISTS maint_tasks_delete ON public.maint_tasks;
CREATE POLICY maint_tasks_delete ON public.maint_tasks
  FOR DELETE USING (
    public.maint_is_erp_admin()
    OR public.maint_profile_role() IN ('chief', 'admin')
  );

-- maint_checks
DROP POLICY IF EXISTS maint_checks_select ON public.maint_checks;
CREATE POLICY maint_checks_select ON public.maint_checks
  FOR SELECT USING (public.maint_machine_visible(machine_code));

DROP POLICY IF EXISTS maint_checks_insert ON public.maint_checks;
CREATE POLICY maint_checks_insert ON public.maint_checks
  FOR INSERT WITH CHECK (
    performed_by = auth.uid()
    AND public.maint_machine_visible(machine_code)
  );

DROP POLICY IF EXISTS maint_checks_update ON public.maint_checks;
CREATE POLICY maint_checks_update ON public.maint_checks
  FOR UPDATE USING (
    public.maint_machine_visible(machine_code)
    AND (
      performed_by = auth.uid()
      OR public.maint_is_erp_admin()
      OR public.maint_profile_role() IN ('chief', 'technician', 'admin')
    )
  )
  WITH CHECK (public.maint_machine_visible(machine_code));

-- maint_incidents
DROP POLICY IF EXISTS maint_incidents_select ON public.maint_incidents;
CREATE POLICY maint_incidents_select ON public.maint_incidents
  FOR SELECT USING (public.maint_machine_visible(machine_code));

DROP POLICY IF EXISTS maint_incidents_insert ON public.maint_incidents;
CREATE POLICY maint_incidents_insert ON public.maint_incidents
  FOR INSERT WITH CHECK (
    reported_by = auth.uid()
    AND public.maint_machine_visible(machine_code)
    AND (
      public.maint_is_erp_admin()
      OR public.maint_profile_role() IN ('operator', 'technician', 'chief', 'admin')
    )
  );

DROP POLICY IF EXISTS maint_incidents_update ON public.maint_incidents;
CREATE POLICY maint_incidents_update ON public.maint_incidents
  FOR UPDATE USING (
    public.maint_machine_visible(machine_code)
    AND (
      public.maint_is_erp_admin()
      OR public.maint_profile_role() IN ('technician', 'chief', 'admin')
    )
  )
  WITH CHECK (public.maint_machine_visible(machine_code));

-- maint_incident_events (timeline)
DROP POLICY IF EXISTS maint_inc_events_select ON public.maint_incident_events;
CREATE POLICY maint_inc_events_select ON public.maint_incident_events
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.maint_incidents i
      WHERE i.id = incident_id AND public.maint_machine_visible(i.machine_code)
    )
  );

DROP POLICY IF EXISTS maint_inc_events_insert ON public.maint_incident_events;
CREATE POLICY maint_inc_events_insert ON public.maint_incident_events
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.maint_incidents i
      WHERE i.id = incident_id AND public.maint_machine_visible(i.machine_code)
    )
    AND (actor IS NULL OR actor = auth.uid())
  );

-- maint_machine_notes
DROP POLICY IF EXISTS maint_notes_select ON public.maint_machine_notes;
CREATE POLICY maint_notes_select ON public.maint_machine_notes
  FOR SELECT USING (
    deleted_at IS NULL AND public.maint_machine_visible(machine_code)
  );

DROP POLICY IF EXISTS maint_notes_insert ON public.maint_machine_notes;
CREATE POLICY maint_notes_insert ON public.maint_machine_notes
  FOR INSERT WITH CHECK (
    author = auth.uid()
    AND public.maint_machine_visible(machine_code)
    AND (
      public.maint_is_erp_admin()
      OR public.maint_profile_role() IN ('operator', 'technician', 'chief', 'admin')
    )
  );

DROP POLICY IF EXISTS maint_notes_update ON public.maint_machine_notes;
CREATE POLICY maint_notes_update ON public.maint_machine_notes
  FOR UPDATE USING (
    public.maint_machine_visible(machine_code)
    AND (
      public.maint_is_erp_admin()
      OR public.maint_profile_role() IN ('chief', 'admin')
      OR (
        author = auth.uid()
        AND created_at > now() - interval '24 hours'
        AND public.maint_profile_role() IN ('operator', 'technician')
      )
    )
  )
  WITH CHECK (public.maint_machine_visible(machine_code));

-- maint_machine_status_override
DROP POLICY IF EXISTS maint_override_select ON public.maint_machine_status_override;
CREATE POLICY maint_override_select ON public.maint_machine_status_override
  FOR SELECT USING (public.maint_machine_visible(machine_code));

DROP POLICY IF EXISTS maint_override_insert ON public.maint_machine_status_override;
CREATE POLICY maint_override_insert ON public.maint_machine_status_override
  FOR INSERT WITH CHECK (
    public.maint_is_erp_admin()
    OR public.maint_profile_role() IN ('chief', 'admin')
  );

DROP POLICY IF EXISTS maint_override_update ON public.maint_machine_status_override;
CREATE POLICY maint_override_update ON public.maint_machine_status_override
  FOR UPDATE USING (
    public.maint_is_erp_admin()
    OR public.maint_profile_role() IN ('chief', 'admin')
  )
  WITH CHECK (
    public.maint_is_erp_admin()
    OR public.maint_profile_role() IN ('chief', 'admin')
  );

DROP POLICY IF EXISTS maint_override_delete ON public.maint_machine_status_override;
CREATE POLICY maint_override_delete ON public.maint_machine_status_override
  FOR DELETE USING (
    public.maint_is_erp_admin()
    OR public.maint_profile_role() IN ('chief', 'admin')
  );

-- maint_notification_log (čitaju chief/management/admin profil ili ERP admin)
DROP POLICY IF EXISTS maint_notif_select ON public.maint_notification_log;
CREATE POLICY maint_notif_select ON public.maint_notification_log
  FOR SELECT USING (
    public.maint_is_erp_admin()
    OR public.maint_profile_role() IN ('chief', 'management', 'admin')
  );

DROP POLICY IF EXISTS maint_notif_insert ON public.maint_notification_log;
CREATE POLICY maint_notif_insert ON public.maint_notification_log
  FOR INSERT WITH CHECK (false);

-- ── Grantovi (authenticated čita view/tabele prema RLS) ───────────────────
GRANT SELECT ON public.v_maint_machine_last_check TO authenticated;
GRANT SELECT ON public.v_maint_task_due_dates TO authenticated;
GRANT SELECT ON public.v_maint_machine_current_status TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.maint_user_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.maint_tasks TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.maint_checks TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.maint_incidents TO authenticated;
GRANT SELECT, INSERT ON public.maint_incident_events TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.maint_machine_notes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.maint_machine_status_override TO authenticated;
GRANT SELECT ON public.maint_notification_log TO authenticated;

-- service_role za Edge funkcije zaobilazi RLS automatski

GRANT EXECUTE ON FUNCTION public.maint_is_erp_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.maint_has_floor_read_access() TO authenticated;
GRANT EXECUTE ON FUNCTION public.maint_profile_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.maint_assigned_machine_codes() TO authenticated;
GRANT EXECUTE ON FUNCTION public.maint_machine_visible(text) TO authenticated;

-- Ručni seed (primer): zameni UUID i ime.
-- INSERT INTO public.maint_user_profiles (user_id, full_name, role, assigned_machine_codes)
-- VALUES ('00000000-0000-0000-0000-000000000000'::uuid, 'Šef održavanja', 'chief', '{}');

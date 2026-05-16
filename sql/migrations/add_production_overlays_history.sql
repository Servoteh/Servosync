-- =====================================================================
-- PP Sprint 1G (M11): Audit history za production_overlays
-- =====================================================================
-- Forenzički log za sve promene tracked field-ova u production_overlays.
-- AFTER INSERT/UPDATE trigger upisuje po jedan red u history tabelu za
-- svaki field koji se stvarno promenio (IS DISTINCT FROM).
--
-- Tracked: local_status, assigned_machine_code, cam_ready, shift_note,
--          cooperation_status, archived_at + INSERT event ("_created").
--
-- DRAFT — NE izvršavati automatski; ručno aplicirati u Supabase Studio.
-- Bootstrap INSERT na kraju je opcioni (komentar).
-- =====================================================================


-- ─────────────────────────────────────────────────────────────────────
-- 1. Tabela production_overlays_history
-- ─────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.production_overlays_history (
  id              BIGSERIAL PRIMARY KEY,

  -- Logički FK na production_overlays(id) — bez constraint-a, history
  -- preživljava i ako se overlay ikada obriše (trenutno se ne briše).
  overlay_id      BIGINT NOT NULL,

  -- Denormalizovano za pretragu po RN-u / liniji bez join-a.
  work_order_id   BIGINT NOT NULL,
  line_id         BIGINT NOT NULL,

  -- Koji field se promenio. '_created' označava INSERT event (overlay
  -- je prvi put kreiran).
  field_name      TEXT   NOT NULL,

  -- Stara i nova vrednost. NULL za _created (nema "stare" vrednosti).
  -- TEXT je univerzalan — bool se kastuje, archived_at se kastuje.
  old_value       TEXT,
  new_value       TEXT,

  -- Akter promene. Primarni izvor: NEW.updated_by; fallback
  -- current_user_email(); poslednji fallback 'unknown'.
  changed_by      TEXT,
  changed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT poh_field_check CHECK (field_name IN (
    '_created',
    'local_status',
    'assigned_machine_code',
    'cam_ready',
    'shift_note',
    'cooperation_status',
    'archived_at'
  ))
);

COMMENT ON TABLE public.production_overlays_history IS
  'M11 audit history: po jedan red po promeni tracked field-a u production_overlays. Forenzika "ko-kada-šta". History preživljava brisanje overlay-a (logički FK bez constraint-a).';


-- ─────────────────────────────────────────────────────────────────────
-- 2. Indeksi
-- ─────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS poh_idx_overlay
  ON public.production_overlays_history (overlay_id, changed_at DESC);

CREATE INDEX IF NOT EXISTS poh_idx_line
  ON public.production_overlays_history (work_order_id, line_id, changed_at DESC);

CREATE INDEX IF NOT EXISTS poh_idx_field
  ON public.production_overlays_history (field_name, changed_at DESC);

CREATE INDEX IF NOT EXISTS poh_idx_changed_by
  ON public.production_overlays_history (changed_by, changed_at DESC);


-- ─────────────────────────────────────────────────────────────────────
-- 3. RLS
-- ─────────────────────────────────────────────────────────────────────

ALTER TABLE public.production_overlays_history ENABLE ROW LEVEL SECURITY;

-- SELECT za sve authenticated korisnike (history je deo PP modula)
DROP POLICY IF EXISTS "poh_select_authenticated" ON public.production_overlays_history;
CREATE POLICY "poh_select_authenticated"
  ON public.production_overlays_history FOR SELECT
  TO authenticated
  USING (true);

-- Eksplicitno blokirаj klijentske write — samo trigger upisuje pod
-- SECURITY DEFINER (pattern iz Sprint 1E za production_reassign_audit).
DROP POLICY IF EXISTS "poh_no_client_write" ON public.production_overlays_history;
CREATE POLICY "poh_no_client_write"
  ON public.production_overlays_history FOR INSERT
  TO authenticated
  WITH CHECK (false);

DROP POLICY IF EXISTS "poh_no_client_update" ON public.production_overlays_history;
CREATE POLICY "poh_no_client_update"
  ON public.production_overlays_history FOR UPDATE
  TO authenticated
  USING (false)
  WITH CHECK (false);

DROP POLICY IF EXISTS "poh_no_client_delete" ON public.production_overlays_history;
CREATE POLICY "poh_no_client_delete"
  ON public.production_overlays_history FOR DELETE
  TO authenticated
  USING (false);

-- Defense-in-depth REVOKE (ako neko ikad DISABLE RLS za debug)
REVOKE INSERT, UPDATE, DELETE, TRUNCATE
  ON public.production_overlays_history
  FROM authenticated, anon;


-- ─────────────────────────────────────────────────────────────────────
-- 4. Trigger funkcija
-- ─────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.production_overlays_audit_history()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_changed_by text;
BEGIN
  -- Primarni izvor: NEW.updated_by (ono što je RPC ili klijent eksplicitno
  -- postavio). Fallback: trenutni user email iz auth.jwt (npr. ako klijent
  -- ne postavi updated_by). Poslednji fallback: 'unknown'.
  v_changed_by := COALESCE(NEW.updated_by, public.current_user_email(), 'unknown');

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.production_overlays_history (
      overlay_id, work_order_id, line_id, field_name, old_value, new_value, changed_by
    ) VALUES (
      NEW.id, NEW.work_order_id, NEW.line_id, '_created',
      NULL, NEW.local_status, COALESCE(NEW.created_by, v_changed_by)
    );
    RETURN NEW;
  END IF;

  -- UPDATE: po jedan INSERT za svaki tracked field koji se stvarno promenio

  IF NEW.local_status IS DISTINCT FROM OLD.local_status THEN
    INSERT INTO public.production_overlays_history (
      overlay_id, work_order_id, line_id, field_name, old_value, new_value, changed_by
    ) VALUES (
      NEW.id, NEW.work_order_id, NEW.line_id, 'local_status',
      OLD.local_status, NEW.local_status, v_changed_by
    );
  END IF;

  IF NEW.assigned_machine_code IS DISTINCT FROM OLD.assigned_machine_code THEN
    INSERT INTO public.production_overlays_history (
      overlay_id, work_order_id, line_id, field_name, old_value, new_value, changed_by
    ) VALUES (
      NEW.id, NEW.work_order_id, NEW.line_id, 'assigned_machine_code',
      OLD.assigned_machine_code, NEW.assigned_machine_code, v_changed_by
    );
  END IF;

  IF NEW.cam_ready IS DISTINCT FROM OLD.cam_ready THEN
    INSERT INTO public.production_overlays_history (
      overlay_id, work_order_id, line_id, field_name, old_value, new_value, changed_by
    ) VALUES (
      NEW.id, NEW.work_order_id, NEW.line_id, 'cam_ready',
      OLD.cam_ready::text, NEW.cam_ready::text, v_changed_by
    );
  END IF;

  IF NEW.shift_note IS DISTINCT FROM OLD.shift_note THEN
    INSERT INTO public.production_overlays_history (
      overlay_id, work_order_id, line_id, field_name, old_value, new_value, changed_by
    ) VALUES (
      NEW.id, NEW.work_order_id, NEW.line_id, 'shift_note',
      OLD.shift_note, NEW.shift_note, v_changed_by
    );
  END IF;

  IF NEW.cooperation_status IS DISTINCT FROM OLD.cooperation_status THEN
    INSERT INTO public.production_overlays_history (
      overlay_id, work_order_id, line_id, field_name, old_value, new_value, changed_by
    ) VALUES (
      NEW.id, NEW.work_order_id, NEW.line_id, 'cooperation_status',
      OLD.cooperation_status, NEW.cooperation_status, v_changed_by
    );
  END IF;

  IF NEW.archived_at IS DISTINCT FROM OLD.archived_at THEN
    INSERT INTO public.production_overlays_history (
      overlay_id, work_order_id, line_id, field_name, old_value, new_value, changed_by
    ) VALUES (
      NEW.id, NEW.work_order_id, NEW.line_id, 'archived_at',
      OLD.archived_at::text, NEW.archived_at::text, v_changed_by
    );
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.production_overlays_audit_history() IS
  'M11 trigger funkcija: AFTER INSERT/UPDATE na production_overlays. Upisuje po jedan red u production_overlays_history za svaki tracked field koji se promenio. SECURITY DEFINER da bi mogla da pisi uprkos REVOKE-u na history tabeli.';


-- ─────────────────────────────────────────────────────────────────────
-- 5. Trigger
-- ─────────────────────────────────────────────────────────────────────

DROP TRIGGER IF EXISTS po_audit_history ON public.production_overlays;
CREATE TRIGGER po_audit_history
  AFTER INSERT OR UPDATE ON public.production_overlays
  FOR EACH ROW
  EXECUTE FUNCTION public.production_overlays_audit_history();


-- ─────────────────────────────────────────────────────────────────────
-- 6. Bootstrap postojećih redova (OPCIONO — Jara može da preskoči)
-- ─────────────────────────────────────────────────────────────────────
-- Označi sve postojeće overlay-e (~674 redova) kao "_created" event sa
-- trenutnim local_status kao "snapshot zatečenog stanja na dan migracije".
-- Bez ovoga, history počinje iz nule i ne zna ništa o postojećim redovima.
--
-- Pokrenuti SAMO ako je migracija aplicirana po prvi put. Idempotent
-- guard: WHERE NOT EXISTS sprečava duplikate ako se bootstrap pokreće
-- ponovo.
/*
INSERT INTO public.production_overlays_history (
  overlay_id, work_order_id, line_id, field_name, old_value, new_value, changed_by, changed_at
)
SELECT
  o.id, o.work_order_id, o.line_id, '_created',
  NULL, o.local_status,
  COALESCE(o.created_by, o.updated_by, 'system:bootstrap-1g'),
  COALESCE(o.created_at, NOW())
FROM public.production_overlays o
WHERE NOT EXISTS (
  SELECT 1 FROM public.production_overlays_history h
  WHERE h.overlay_id = o.id AND h.field_name = '_created'
);
*/


-- ─────────────────────────────────────────────────────────────────────
-- 7. PostgREST reload
-- ─────────────────────────────────────────────────────────────────────

NOTIFY pgrst, 'reload schema';


-- =====================================================================
-- VERIFIKACIJA (posle apply-a)
-- =====================================================================
--
-- Trigger postoji:
/*
SELECT trigger_name, event_manipulation, action_statement
FROM information_schema.triggers
WHERE event_object_table = 'production_overlays';
-- Treba 2 reda: postojeći touch_updated_at + novi po_audit_history
*/
--
-- Tabela ima RLS i policy-je:
/*
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'production_overlays_history'
ORDER BY cmd, policyname;
-- Treba 4 policy-ja
*/
--
-- Manuelni smoke test:
/*
-- Trigger CAM toggle iz UI, pa proveri history:
SELECT changed_at, field_name, old_value, new_value, changed_by
FROM public.production_overlays_history
WHERE work_order_id = <neki_postojeci_RN>
ORDER BY changed_at DESC
LIMIT 10;
*/
--
-- Reorder performance test:
/*
-- Pre reorder: count redova history
SELECT count(*) FROM public.production_overlays_history;
-- Posle reorder od 100 redova: count mora da bude isti
-- (shift_sort_order NIJE tracked field).
*/
-- =====================================================================

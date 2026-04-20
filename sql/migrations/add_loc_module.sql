-- ============================================================================
-- LOKACIJE DELOVA — loc_* tabele, triggeri, RLS, RPC loc_create_movement
-- ============================================================================
-- Ako dobiješ „relation loc_locations does not exist" — prvo pokreni SAMO:
--   sql/migrations/add_loc_module_step1_tables.sql
-- pa zatim ovaj fajl (ceo ili od linije „updated_at" nadalje).
--
-- Pokreni JEDNOM u Supabase SQL Editoru (posle backup-a).
--
-- Zavisi od: public.user_roles (email + role), auth.users (auth.uid()).
-- Worker (MSSQL sync) je odvojen — ova migracija samo Postgres + queue redovi.
--
-- DOWN (ručno, ako treba rollback test):
--   DROP FUNCTION IF EXISTS public.loc_create_movement(jsonb);
--   DROP FUNCTION IF EXISTS public.loc_after_movement_insert() CASCADE;
--   DROP FUNCTION IF EXISTS public.loc_locations_guard_and_path() CASCADE;
--   DROP FUNCTION IF EXISTS public.loc_locations_after_path_change() CASCADE;
--   DROP FUNCTION IF EXISTS public.loc_recompute_descendants(uuid) CASCADE;
--   DROP FUNCTION IF EXISTS public.loc_auth_roles() CASCADE;
--   DROP FUNCTION IF EXISTS public.loc_can_manage_locations() CASCADE;
--   DROP FUNCTION IF EXISTS public.loc_is_admin() CASCADE;
--   DROP TABLE IF EXISTS public.loc_sync_outbound_events CASCADE;
--   DROP TABLE IF EXISTS public.loc_location_movements CASCADE;
--   DROP TABLE IF EXISTS public.loc_item_placements CASCADE;
--   DROP TABLE IF EXISTS public.loc_locations CASCADE;
--   DROP TYPE IF EXISTS public.loc_sync_status_enum CASCADE;
--   DROP TYPE IF EXISTS public.loc_movement_type_enum CASCADE;
--   DROP TYPE IF EXISTS public.loc_placement_status_enum CASCADE;
--   DROP TYPE IF EXISTS public.loc_type_enum CASCADE;
-- ============================================================================

-- ── Enum tipovi (idempotentno) ───────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE public.loc_type_enum AS ENUM (
    'WAREHOUSE','RACK','SHELF','BIN','PROJECT','PRODUCTION','ASSEMBLY','SERVICE',
    'FIELD','TRANSIT','OFFICE','TEMP','SCRAPPED','OTHER'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.loc_placement_status_enum AS ENUM (
    'ACTIVE','IN_TRANSIT','PENDING_CONFIRMATION','UNKNOWN'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.loc_movement_type_enum AS ENUM (
    'INITIAL_PLACEMENT','TRANSFER','ASSIGN_TO_PROJECT','RETURN_FROM_PROJECT',
    'SEND_TO_SERVICE','RETURN_FROM_SERVICE','SEND_TO_FIELD','RETURN_FROM_FIELD',
    'SCRAP','CORRECTION','INVENTORY_ADJUSTMENT'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.loc_sync_status_enum AS ENUM (
    'PENDING','IN_PROGRESS','SYNCED','FAILED','DEAD_LETTER'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- ── loc_locations ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.loc_locations (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  location_code    TEXT NOT NULL,
  name             TEXT NOT NULL,
  location_type    public.loc_type_enum NOT NULL,
  parent_id        UUID REFERENCES public.loc_locations(id) ON DELETE RESTRICT,
  path_cached      TEXT NOT NULL DEFAULT '',
  depth            SMALLINT NOT NULL DEFAULT 0,
  is_active        BOOLEAN NOT NULL DEFAULT true,
  capacity_note    TEXT,
  notes            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT loc_locations_no_self_parent CHECK (parent_id IS NULL OR parent_id <> id)
);

CREATE UNIQUE INDEX IF NOT EXISTS loc_locations_code_uq
  ON public.loc_locations (location_code);

CREATE INDEX IF NOT EXISTS loc_locations_parent_idx ON public.loc_locations (parent_id);
CREATE INDEX IF NOT EXISTS loc_locations_type_active_idx
  ON public.loc_locations (location_type) WHERE is_active;
CREATE INDEX IF NOT EXISTS loc_locations_path_gin_idx
  ON public.loc_locations USING gin (to_tsvector('simple', coalesce(name,'') || ' ' || coalesce(path_cached,'')));

-- ── loc_location_movements (append-only: bez UPDATE/DELETE u aplikaciji) ───
CREATE TABLE IF NOT EXISTS public.loc_location_movements (
  id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_ref_table             TEXT NOT NULL,
  item_ref_id                TEXT NOT NULL,
  from_location_id           UUID REFERENCES public.loc_locations(id) ON DELETE SET NULL,
  to_location_id             UUID NOT NULL REFERENCES public.loc_locations(id) ON DELETE RESTRICT,
  movement_type              public.loc_movement_type_enum NOT NULL,
  movement_reason            TEXT,
  note                       TEXT,
  moved_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
  moved_by                   UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  approved_by                UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_at                TIMESTAMPTZ,
  correction_of_movement_id  UUID REFERENCES public.loc_location_movements(id) ON DELETE SET NULL,
  sync_status                public.loc_sync_status_enum NOT NULL DEFAULT 'PENDING',
  created_at                 TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS loc_mov_item_idx
  ON public.loc_location_movements (item_ref_table, item_ref_id, moved_at DESC);
CREATE INDEX IF NOT EXISTS loc_mov_to_idx
  ON public.loc_location_movements (to_location_id, moved_at DESC);
CREATE INDEX IF NOT EXISTS loc_mov_sync_pending_idx
  ON public.loc_location_movements (sync_status)
  WHERE sync_status IN ('PENDING','FAILED');

-- ── loc_item_placements (trenutno stanje; jedan red po stavci) ────────────
CREATE TABLE IF NOT EXISTS public.loc_item_placements (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_ref_table      TEXT NOT NULL,
  item_ref_id         TEXT NOT NULL,
  location_id         UUID NOT NULL REFERENCES public.loc_locations(id) ON DELETE RESTRICT,
  placement_status    public.loc_placement_status_enum NOT NULL DEFAULT 'ACTIVE',
  last_movement_id    UUID REFERENCES public.loc_location_movements(id) ON DELETE SET NULL,
  placed_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  placed_by           UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  notes               TEXT,
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT loc_item_placements_item_uq UNIQUE (item_ref_table, item_ref_id)
);

CREATE INDEX IF NOT EXISTS loc_placements_loc_idx ON public.loc_item_placements (location_id);
CREATE INDEX IF NOT EXISTS loc_placements_item_lookup_idx ON public.loc_item_placements (item_ref_table, item_ref_id);

-- ── loc_sync_outbound_events (queue ka MSSQL worker-u) ───────────────────
CREATE TABLE IF NOT EXISTS public.loc_sync_outbound_events (
  id                 UUID PRIMARY KEY,
  source_table       TEXT NOT NULL,
  source_record_id   UUID NOT NULL,
  target_procedure   TEXT NOT NULL DEFAULT 'dbo.sp_ApplyLocationEvent',
  payload            JSONB NOT NULL,
  status             public.loc_sync_status_enum NOT NULL DEFAULT 'PENDING',
  attempts           SMALLINT NOT NULL DEFAULT 0,
  last_error         TEXT,
  locked_by_worker   TEXT,
  locked_at          TIMESTAMPTZ,
  next_retry_at      TIMESTAMPTZ,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  synced_at          TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS loc_sync_status_idx
  ON public.loc_sync_outbound_events (status, created_at)
  WHERE status IN ('PENDING','FAILED');

-- ── updated_at ───────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.loc_touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS loc_locations_touch_updated ON public.loc_locations;
CREATE TRIGGER loc_locations_touch_updated
  BEFORE UPDATE ON public.loc_locations
  FOR EACH ROW EXECUTE FUNCTION public.loc_touch_updated_at();

DROP TRIGGER IF EXISTS loc_placements_touch_updated ON public.loc_item_placements;
CREATE TRIGGER loc_placements_touch_updated
  BEFORE UPDATE ON public.loc_item_placements
  FOR EACH ROW EXECUTE FUNCTION public.loc_touch_updated_at();

-- ── Hijerarhija: ciklus + path_cached / depth (jedan BEFORE redosled) ─────
CREATE OR REPLACE FUNCTION public.loc_locations_guard_and_path()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.parent_id IS NOT NULL THEN
    IF NEW.parent_id = NEW.id THEN
      RAISE EXCEPTION 'loc_locations: parent_id ne može biti isti kao id';
    END IF;
    IF EXISTS (
      WITH RECURSIVE ancestor_chain AS (
        SELECT loc_locations.id, loc_locations.parent_id, 1 AS lvl
        FROM public.loc_locations
        WHERE loc_locations.id = NEW.parent_id
        UNION ALL
        SELECT l.id, l.parent_id, ac.lvl + 1
        FROM public.loc_locations l
        INNER JOIN ancestor_chain ac ON l.id = ac.parent_id
        WHERE ac.lvl < 200
      )
      SELECT 1 FROM ancestor_chain WHERE ancestor_chain.id = NEW.id LIMIT 1
    ) THEN
      RAISE EXCEPTION 'loc_locations: ciklus u hijerarhiji';
    END IF;
  END IF;

  IF NEW.parent_id IS NULL THEN
    NEW.depth := 0;
    NEW.path_cached := NEW.name;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM public.loc_locations llx WHERE llx.id = NEW.parent_id) THEN
      RAISE EXCEPTION 'loc_locations: parent ne postoji';
    END IF;
    NEW.depth := (
      SELECT ll.depth + 1 FROM public.loc_locations AS ll WHERE ll.id = NEW.parent_id
    );
    NEW.path_cached := (
      SELECT ll.path_cached || ' ' || chr(8250) || ' ' || NEW.name
      FROM public.loc_locations AS ll WHERE ll.id = NEW.parent_id
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS loc_locations_cycle_check ON public.loc_locations;
DROP TRIGGER IF EXISTS loc_locations_before_path_trg ON public.loc_locations;
CREATE TRIGGER loc_locations_guard_and_path_trg
  BEFORE INSERT OR UPDATE OF parent_id, name ON public.loc_locations
  FOR EACH ROW EXECUTE FUNCTION public.loc_locations_guard_and_path();

-- ── Rekurzivno ažuriranje potomaka kad se promeni parent ili ime ────────
CREATE OR REPLACE FUNCTION public.loc_recompute_descendants(p_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN EXECUTE format(
    'SELECT id FROM public.loc_locations WHERE parent_id = %L::uuid',
    p_id
  ) LOOP
    UPDATE public.loc_locations AS l SET
      depth = (SELECT par.depth + 1 FROM public.loc_locations AS par WHERE par.id = l.parent_id),
      path_cached = (
        SELECT par.path_cached || ' ' || chr(8250) || ' ' || l.name
        FROM public.loc_locations AS par
        WHERE par.id = l.parent_id
      )
    WHERE l.id = r.id;
    PERFORM public.loc_recompute_descendants(r.id);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.loc_locations_after_path_change()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND (
    NEW.parent_id IS DISTINCT FROM OLD.parent_id OR NEW.name IS DISTINCT FROM OLD.name
  ) THEN
    PERFORM public.loc_recompute_descendants(NEW.id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS loc_locations_after_path_trg ON public.loc_locations;
CREATE TRIGGER loc_locations_after_path_trg
  AFTER UPDATE OF parent_id, name ON public.loc_locations
  FOR EACH ROW EXECUTE FUNCTION public.loc_locations_after_path_change();

-- ── Posle INSERT movement: placement + sync queue ────────────────────────
CREATE OR REPLACE FUNCTION public.loc_after_movement_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  pl_status public.loc_placement_status_enum;
BEGIN
  IF NEW.movement_type IN ('SEND_TO_SERVICE', 'SEND_TO_FIELD') THEN
    pl_status := 'IN_TRANSIT'::public.loc_placement_status_enum;
  ELSE
    pl_status := 'ACTIVE'::public.loc_placement_status_enum;
  END IF;

  INSERT INTO public.loc_item_placements (
    item_ref_table, item_ref_id, location_id, placement_status,
    last_movement_id, placed_at, placed_by, notes
  ) VALUES (
    NEW.item_ref_table, NEW.item_ref_id, NEW.to_location_id, pl_status,
    NEW.id, NEW.moved_at, NEW.moved_by, NULL
  )
  ON CONFLICT (item_ref_table, item_ref_id) DO UPDATE SET
    location_id = EXCLUDED.location_id,
    placement_status = EXCLUDED.placement_status,
    last_movement_id = EXCLUDED.last_movement_id,
    placed_at = EXCLUDED.placed_at,
    placed_by = EXCLUDED.placed_by,
    updated_at = now();

  INSERT INTO public.loc_sync_outbound_events (
    id, source_table, source_record_id, target_procedure, payload, status
  ) VALUES (
    NEW.id,
    'loc_location_movements',
    NEW.id,
    'dbo.sp_ApplyLocationEvent',
    jsonb_build_object(
      'event_uuid', NEW.id::text,
      'item_ref_table', NEW.item_ref_table,
      'item_ref_id', NEW.item_ref_id,
      'from_location_code', (SELECT llfc.location_code FROM public.loc_locations AS llfc WHERE llfc.id = NEW.from_location_id),
      'to_location_code', (SELECT lltc.location_code FROM public.loc_locations AS lltc WHERE lltc.id = NEW.to_location_id),
      'movement_type', NEW.movement_type::text,
      'moved_at', to_jsonb(NEW.moved_at),
      'moved_by', NEW.moved_by::text,
      'note', NEW.note
    ),
    'PENDING'::public.loc_sync_status_enum
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS loc_mov_after_insert ON public.loc_location_movements;
CREATE TRIGGER loc_mov_after_insert
  AFTER INSERT ON public.loc_location_movements
  FOR EACH ROW EXECUTE FUNCTION public.loc_after_movement_insert();

-- ── Role helperi (bez rekurzije na RLS user_roles) ─────────────────────────
CREATE OR REPLACE FUNCTION public.loc_auth_roles()
RETURNS TEXT[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(
    array_agg(DISTINCT lower(ur.role::text)) FILTER (WHERE ur.role IS NOT NULL),
    ARRAY[]::text[]
  )
  FROM public.user_roles ur
  WHERE ur.is_active = true
    AND lower(ur.email) = lower(coalesce(auth.jwt()->>'email', ''));
$$;

CREATE OR REPLACE FUNCTION public.loc_can_manage_locations()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.loc_auth_roles() && ARRAY['admin','leadpm','pm']::text[];
$$;

CREATE OR REPLACE FUNCTION public.loc_is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.loc_auth_roles() && ARRAY['admin']::text[];
$$;

-- ── RPC: kreiranje pokreta (jedini očekivani INSERT u movements za FE) ────
CREATE OR REPLACE FUNCTION public.loc_create_movement(payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item_table TEXT;
  v_item_id TEXT;
  v_to UUID;
  v_from UUID;
  v_mtype public.loc_movement_type_enum;
  v_uid UUID;
  v_cur UUID;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  v_item_table := nullif(trim(payload->>'item_ref_table'), '');
  v_item_id := nullif(trim(payload->>'item_ref_id'), '');
  v_mtype := (payload->>'movement_type')::public.loc_movement_type_enum;

  IF payload ? 'to_location_id' AND nullif(trim(payload->>'to_location_id'), '') IS NOT NULL THEN
    v_to := (payload->>'to_location_id')::uuid;
  ELSE
    v_to := NULL;
  END IF;

  IF v_item_table IS NULL OR v_item_id IS NULL OR v_to IS NULL OR v_mtype IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_fields');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.loc_locations loc_chk
    WHERE loc_chk.id = (SELECT v_to) AND loc_chk.is_active
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_to_location');
  END IF;

  IF payload ? 'from_location_id' AND nullif(trim(payload->>'from_location_id'), '') IS NOT NULL THEN
    v_from := (payload->>'from_location_id')::uuid;
  ELSE
    v_from := NULL;
  END IF;

  v_cur := (
    SELECT lp.location_id
    FROM public.loc_item_placements lp
    WHERE lp.item_ref_table = (SELECT v_item_table)
      AND lp.item_ref_id = (SELECT v_item_id)
    LIMIT 1
  );

  IF v_mtype = 'INITIAL_PLACEMENT' THEN
    IF v_cur IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'error', 'already_placed');
    END IF;
    v_from := NULL;
  ELSE
    IF v_cur IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'error', 'no_current_placement');
    END IF;
    IF v_from IS NOT NULL AND v_from <> v_cur THEN
      RETURN jsonb_build_object('ok', false, 'error', 'from_mismatch');
    END IF;
    v_from := v_cur;
  END IF;

  RETURN (
    WITH ins AS (
      INSERT INTO public.loc_location_movements (
        item_ref_table, item_ref_id, from_location_id, to_location_id,
        movement_type, movement_reason, note, moved_at, moved_by
      ) VALUES (
        v_item_table,
        v_item_id,
        v_from,
        v_to,
        v_mtype,
        nullif(trim(payload->>'movement_reason'), ''),
        nullif(trim(payload->>'note'), ''),
        coalesce((payload->>'moved_at')::timestamptz, now()),
        v_uid
      )
      RETURNING id
    )
    SELECT jsonb_build_object('ok', true, 'id', ins.id) FROM ins
  );
EXCEPTION
  WHEN others THEN
    RETURN jsonb_build_object('ok', false, 'error', 'exception', 'detail', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.loc_create_movement(jsonb) TO authenticated;

-- ── RLS ───────────────────────────────────────────────────────────────────
ALTER TABLE public.loc_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loc_locations FORCE ROW LEVEL SECURITY;
ALTER TABLE public.loc_item_placements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loc_item_placements FORCE ROW LEVEL SECURITY;
ALTER TABLE public.loc_location_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loc_location_movements FORCE ROW LEVEL SECURITY;
ALTER TABLE public.loc_sync_outbound_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loc_sync_outbound_events FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS loc_locations_select ON public.loc_locations;
CREATE POLICY loc_locations_select ON public.loc_locations
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS loc_locations_insert ON public.loc_locations;
CREATE POLICY loc_locations_insert ON public.loc_locations
  FOR INSERT TO authenticated
  WITH CHECK (public.loc_can_manage_locations());

DROP POLICY IF EXISTS loc_locations_update ON public.loc_locations;
CREATE POLICY loc_locations_update ON public.loc_locations
  FOR UPDATE TO authenticated
  USING (public.loc_can_manage_locations())
  WITH CHECK (public.loc_can_manage_locations());

DROP POLICY IF EXISTS loc_placements_select ON public.loc_item_placements;
CREATE POLICY loc_placements_select ON public.loc_item_placements
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS loc_mov_select ON public.loc_location_movements;
CREATE POLICY loc_mov_select ON public.loc_location_movements
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS loc_sync_select ON public.loc_sync_outbound_events;
CREATE POLICY loc_sync_select ON public.loc_sync_outbound_events
  FOR SELECT TO authenticated USING (public.loc_is_admin());

-- INSERT na movements samo kroz SECURITY DEFINER — bez INSERT policy za authenticated

-- ── Seed: minimalan magacin (opciono; zakomentarisati ako ne treba) ─────
-- INSERT INTO public.loc_locations (location_code, name, location_type, parent_id, path_cached, depth, is_active)
-- VALUES ('M1', 'Magacin 1', 'WAREHOUSE', NULL, 'Magacin 1', 0, true)
-- ON CONFLICT DO NOTHING;

COMMENT ON TABLE public.loc_locations IS 'Master registar lokacija (hijerarhija + operativne)';
COMMENT ON TABLE public.loc_item_placements IS 'Trenutna lokacija po stavci (upsert iz triggera)';
COMMENT ON TABLE public.loc_location_movements IS 'Istorija pokreta (append-only)';
COMMENT ON TABLE public.loc_sync_outbound_events IS 'Outbound queue za MSSQL worker';

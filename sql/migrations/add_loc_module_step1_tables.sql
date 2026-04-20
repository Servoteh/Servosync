-- ============================================================================
-- LOKACIJE — KORAK 1 od 2: SAMO enum tipovi + tabele + indeksi
-- ============================================================================
-- Pokreni OVO PRVO u Supabase SQL Editoru.
--
-- Posle uspešnog izvršavanja u Table Editor-u moraju da postoje tabele:
--   loc_locations, loc_location_movements, loc_item_placements, loc_sync_outbound_events
--
-- Zatim pokreni KORAK 2: ceo fajl add_loc_module.sql OD LINIJE koja počinje sa
--   "-- ── updated_at ──"
--   (ili ceo add_loc_module.sql od linije 158 — sve posle indeksa)
--
-- Ili jednostavno: ponovo pokreni ceo add_loc_module.sql — CREATE IF NOT EXISTS
-- neće duplirati tabele.
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

-- ── loc_location_movements ───────────────────────────────────────────────
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

-- ── loc_item_placements ───────────────────────────────────────────────────
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

-- ── loc_sync_outbound_events ─────────────────────────────────────────────
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

-- Provera (opciono u novom query-ju):
-- SELECT public.to_regclass('public.loc_locations') AS loc_locations_ok;

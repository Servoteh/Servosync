-- ============================================================================
-- pgTAP: strukturni testovi za modul Lokacije (tabele, enumi, RLS, funkcije).
-- ============================================================================
-- Preduslov: CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
-- Pokreni ceo fajl u Supabase SQL Editoru.

BEGIN;
SET search_path = public, extensions;

SELECT plan(34);

-- ── Enumi postoje i sadrže očekivane vrednosti ─────────────────────────
SELECT has_type('public', 'loc_type_enum', 'enum loc_type_enum postoji');
SELECT has_type('public', 'loc_placement_status_enum', 'enum loc_placement_status_enum postoji');
SELECT has_type('public', 'loc_movement_type_enum', 'enum loc_movement_type_enum postoji');
SELECT has_type('public', 'loc_sync_status_enum', 'enum loc_sync_status_enum postoji');

SELECT ok(
  (SELECT 'WAREHOUSE' = ANY(enum_range(NULL::public.loc_type_enum)::text[])),
  'loc_type_enum sadrži WAREHOUSE'
);
SELECT ok(
  (SELECT 'TRANSFER' = ANY(enum_range(NULL::public.loc_movement_type_enum)::text[])),
  'loc_movement_type_enum sadrži TRANSFER'
);
SELECT ok(
  (SELECT 'INITIAL_PLACEMENT' = ANY(enum_range(NULL::public.loc_movement_type_enum)::text[])),
  'loc_movement_type_enum sadrži INITIAL_PLACEMENT'
);
SELECT ok(
  (SELECT 'DEAD_LETTER' = ANY(enum_range(NULL::public.loc_sync_status_enum)::text[])),
  'loc_sync_status_enum sadrži DEAD_LETTER'
);

-- ── Tabele postoje ─────────────────────────────────────────────────────
SELECT has_table('public', 'loc_locations', 'tabela loc_locations');
SELECT has_table('public', 'loc_item_placements', 'tabela loc_item_placements');
SELECT has_table('public', 'loc_location_movements', 'tabela loc_location_movements');
SELECT has_table('public', 'loc_sync_outbound_events', 'tabela loc_sync_outbound_events');

-- ── Ključne kolone ─────────────────────────────────────────────────────
SELECT has_column('public', 'loc_locations', 'location_code', 'loc_locations.location_code');
SELECT has_column('public', 'loc_locations', 'path_cached', 'loc_locations.path_cached');
SELECT has_column('public', 'loc_locations', 'depth', 'loc_locations.depth');
SELECT has_column('public', 'loc_locations', 'parent_id', 'loc_locations.parent_id');
SELECT has_column('public', 'loc_location_movements', 'movement_type', 'loc_location_movements.movement_type');
SELECT has_column('public', 'loc_item_placements', 'placement_status', 'loc_item_placements.placement_status');
SELECT has_column('public', 'loc_sync_outbound_events', 'attempts', 'loc_sync_outbound_events.attempts');
SELECT has_column('public', 'loc_sync_outbound_events', 'next_retry_at', 'loc_sync_outbound_events.next_retry_at');

-- ── Funkcionalni unique index (CI) ─────────────────────────────────────
SELECT ok(
  EXISTS(
    SELECT 1
      FROM pg_indexes
     WHERE schemaname = 'public'
       AND indexname = 'loc_locations_code_ci_uq'
  ),
  'case-insensitive unique index loc_locations_code_ci_uq postoji (step2)'
);

-- ── RLS enabled ────────────────────────────────────────────────────────
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.loc_locations'::regclass),
  'RLS je omogućen na loc_locations'
);
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.loc_item_placements'::regclass),
  'RLS je omogućen na loc_item_placements'
);
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.loc_location_movements'::regclass),
  'RLS je omogućen na loc_location_movements'
);
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.loc_sync_outbound_events'::regclass),
  'RLS je omogućen na loc_sync_outbound_events'
);

-- ── Funkcije postoje ───────────────────────────────────────────────────
SELECT has_function('public', 'loc_create_movement', ARRAY['jsonb'], 'RPC loc_create_movement(jsonb)');
SELECT has_function('public', 'loc_is_admin', 'helper loc_is_admin()');
SELECT has_function('public', 'loc_can_manage_locations', 'helper loc_can_manage_locations()');
SELECT has_function('public', 'loc_purge_synced_events', ARRAY['integer'], 'loc_purge_synced_events(integer)');
SELECT has_function('public', 'loc_claim_sync_events', ARRAY['text', 'integer'], 'loc_claim_sync_events(text,integer)');
SELECT has_function('public', 'loc_mark_sync_synced', ARRAY['uuid'], 'loc_mark_sync_synced(uuid)');
SELECT has_function('public', 'loc_mark_sync_failed', ARRAY['uuid', 'text'], 'loc_mark_sync_failed(uuid,text)');

-- ── Trigger funkcije ───────────────────────────────────────────────────
SELECT has_function('public', 'loc_locations_guard_and_path', 'trigger fn loc_locations_guard_and_path');
SELECT has_function('public', 'loc_after_movement_insert', 'trigger fn loc_after_movement_insert');

SELECT * FROM finish();
ROLLBACK;

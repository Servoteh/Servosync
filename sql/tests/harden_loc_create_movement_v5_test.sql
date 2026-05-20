-- ============================================================================
-- pgTAP: harden_loc_create_movement_v5 (Sprint LOC-Härd-1)
-- ============================================================================
-- Zahteva primenjene migracije:
--   add_loc_module → step2 → step3 → step5 → v2 → v3 → v4
--   add_loc_location_hierarchy_rules
--   harden_loc_create_movement_v5
--
-- JWT simulacija: request.jwt.claim.sub GUC + bootstrap auth.uid() stub
-- (sql/ci/00_bootstrap.sql seeduje korisnike 000...0001 i 000...0002).
--
-- Pokriva odluke iz docs/lokacije/sprint-1-analiza.md:
--   1. idempotent replay (isti client_event_uuid → drugi poziv vraća postojeći id, NE dupla qty)
--   2. INITIAL_PLACEMENT akumulacija na istu policu (opcija B; quantity sabira)
--   3. INITIAL_PLACEMENT na različite police → dva placement reda
--   4. insufficient_quantity (kapacitet check pod advisory lock-om)
--   5. parent_inactive (M5 fix — deaktivirana hala blokira premeštanje na policu u njoj)
--   6. optional client_event_uuid — RPC sam generiše ako klijent ne pošalje
-- ============================================================================

BEGIN;
SET search_path = public, extensions;

SELECT plan(16);

-- ─── Seed lokacija (kao postgres, RLS off) ───────────────────────────────
SET LOCAL row_security = off;

INSERT INTO public.loc_locations (id, location_code, name, location_type, is_active)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'TST5-H1', 'Test HALA 1', 'WAREHOUSE', true),
  ('22222222-2222-2222-2222-222222222222', 'TST5-H2', 'Test HALA 2 (deaktivirati će se)', 'WAREHOUSE', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.loc_locations (id, location_code, name, location_type, parent_id, is_active)
VALUES
  ('33333333-3333-3333-3333-333333333333', 'P1', 'Polica P1 u H1', 'SHELF',
     '11111111-1111-1111-1111-111111111111', true),
  ('44444444-4444-4444-4444-444444444444', 'P2', 'Polica P2 u H1', 'SHELF',
     '11111111-1111-1111-1111-111111111111', true),
  ('55555555-5555-5555-5555-555555555555', 'P3', 'Polica P3 u H2 (parent će biti deaktiviran)', 'SHELF',
     '22222222-2222-2222-2222-222222222222', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_roles (email, role, is_active) VALUES
  ('pgtap-user-1@ci.local', 'admin', true)
ON CONFLICT (email) DO UPDATE SET role = EXCLUDED.role, is_active = EXCLUDED.is_active;

SET LOCAL row_security = on;

RESET ROLE;
GRANT SELECT ON TABLE public.loc_location_movements TO authenticated;
GRANT SELECT ON TABLE public.loc_item_placements TO authenticated;

-- ─── Postavi authenticated context ───────────────────────────────────────
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('email','pgtap-user-1@ci.local')::text,
                  true);
SELECT set_config('request.jwt.claim.sub',
                  '00000000-0000-0000-0000-000000000001',
                  true);

-- =========================================================================
-- 1) Idempotent replay (H15)
-- =========================================================================
DO $t1$
DECLARE
  v_uuid uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01';
  r1 jsonb;
  r2 jsonb;
BEGIN
  r1 := public.loc_create_movement(jsonb_build_object(
    'item_ref_table',     'bigtehn_rn',
    'item_ref_id',        'TP-IDEMP-1',
    'order_no',           '9000',
    'movement_type',      'INITIAL_PLACEMENT',
    'quantity',           5,
    'to_location_id',     '33333333-3333-3333-3333-333333333333',
    'client_event_uuid',  v_uuid::text
  ));
  r2 := public.loc_create_movement(jsonb_build_object(
    'item_ref_table',     'bigtehn_rn',
    'item_ref_id',        'TP-IDEMP-1',
    'order_no',           '9000',
    'movement_type',      'INITIAL_PLACEMENT',
    'quantity',           99,                /* drugačija količina, ali isti UUID */
    'to_location_id',     '33333333-3333-3333-3333-333333333333',
    'client_event_uuid',  v_uuid::text
  ));
  PERFORM set_config('t1.r1', r1::text, true);
  PERFORM set_config('t1.r2', r2::text, true);
END $t1$;

SELECT is(
  (current_setting('t1.r1')::jsonb->>'ok')::boolean,
  true,
  'idempotent replay: prvi poziv ok=true'
);
SELECT is(
  (current_setting('t1.r2')::jsonb->>'idempotent')::boolean,
  true,
  'idempotent replay: drugi poziv vraća idempotent=true'
);
SELECT is(
  current_setting('t1.r1')::jsonb->>'id',
  current_setting('t1.r2')::jsonb->>'id',
  'idempotent replay: drugi poziv vraća isti id kao prvi'
);
SELECT is(
  (SELECT count(*)::int FROM public.loc_location_movements
    WHERE client_event_uuid = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01'::uuid),
  1,
  'idempotent replay: samo jedan movement (drugi poziv nije duplirao)'
);
SELECT is(
  (SELECT lp.quantity::numeric FROM public.loc_item_placements lp
    WHERE lp.item_ref_table = 'bigtehn_rn'
      AND lp.item_ref_id    = 'TP-IDEMP-1'
      AND lp.order_no       = '9000'
      AND lp.location_id    = '33333333-3333-3333-3333-333333333333'
    LIMIT 1),
  5::numeric,
  'idempotent replay: quantity ostaje 5 (drugi poziv NIJE dodao 99)'
);

-- =========================================================================
-- 2) INITIAL_PLACEMENT akumulacija na istu policu (H2 / opcija B)
-- =========================================================================
DO $t2$
DECLARE
  r1 jsonb;
  r2 jsonb;
BEGIN
  r1 := public.loc_create_movement(jsonb_build_object(
    'item_ref_table',     'bigtehn_rn',
    'item_ref_id',        'TP-ACC-1',
    'order_no',           '9100',
    'movement_type',      'INITIAL_PLACEMENT',
    'quantity',           2,
    'to_location_id',     '33333333-3333-3333-3333-333333333333',
    'client_event_uuid',  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'
  ));
  r2 := public.loc_create_movement(jsonb_build_object(
    'item_ref_table',     'bigtehn_rn',
    'item_ref_id',        'TP-ACC-1',
    'order_no',           '9100',
    'movement_type',      'INITIAL_PLACEMENT',
    'quantity',           3,                 /* drugi unos za isti (item, order, loc) */
    'to_location_id',     '33333333-3333-3333-3333-333333333333',
    'client_event_uuid',  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02'
  ));
  PERFORM set_config('t2.r1', r1::text, true);
  PERFORM set_config('t2.r2', r2::text, true);
END $t2$;

SELECT is(
  (current_setting('t2.r1')::jsonb->>'ok')::boolean,
  true,
  'akumulacija INITIAL: prvi poziv ok=true (qty=2)'
);
SELECT is(
  (current_setting('t2.r2')::jsonb->>'ok')::boolean,
  true,
  'akumulacija INITIAL: drugi INITIAL na istu policu NE vraća already_placed (opcija B)'
);
SELECT is(
  (SELECT quantity::numeric FROM public.loc_item_placements
     WHERE item_ref_table = 'bigtehn_rn'
       AND item_ref_id    = 'TP-ACC-1'
       AND order_no       = '9100'
       AND location_id    = '33333333-3333-3333-3333-333333333333'),
  5::numeric,
  'akumulacija INITIAL: trigger sabira 2+3=5'
);

-- =========================================================================
-- 3) INITIAL_PLACEMENT na različite police u istoj hali → dva reda
-- =========================================================================
DO $t3$
DECLARE
  r1 jsonb;
  r2 jsonb;
BEGIN
  r1 := public.loc_create_movement(jsonb_build_object(
    'item_ref_table',     'bigtehn_rn',
    'item_ref_id',        'TP-MULTI-1',
    'order_no',           '9200',
    'movement_type',      'INITIAL_PLACEMENT',
    'quantity',           4,
    'to_location_id',     '33333333-3333-3333-3333-333333333333',  -- P1
    'client_event_uuid',  'cccccccc-cccc-cccc-cccc-cccccccccc01'
  ));
  r2 := public.loc_create_movement(jsonb_build_object(
    'item_ref_table',     'bigtehn_rn',
    'item_ref_id',        'TP-MULTI-1',
    'order_no',           '9200',
    'movement_type',      'INITIAL_PLACEMENT',
    'quantity',           7,
    'to_location_id',     '44444444-4444-4444-4444-444444444444',  -- P2 (druga polica)
    'client_event_uuid',  'cccccccc-cccc-cccc-cccc-cccccccccc02'
  ));
  PERFORM set_config('t3.r1', r1::text, true);
  PERFORM set_config('t3.r2', r2::text, true);
END $t3$;

SELECT is(
  (current_setting('t3.r2')::jsonb->>'ok')::boolean,
  true,
  'multi-location: drugi INITIAL na DRUGU policu ok=true'
);
SELECT is(
  (SELECT count(*)::int FROM public.loc_item_placements
     WHERE item_ref_table = 'bigtehn_rn'
       AND item_ref_id    = 'TP-MULTI-1'
       AND order_no       = '9200'),
  2,
  'multi-location: dva placement reda (P1 i P2)'
);

-- =========================================================================
-- 4) Insufficient quantity (H1 — kapacitet pod advisory lock-om)
-- =========================================================================
DO $t4$
DECLARE
  r jsonb;
BEGIN
  /* Imamo TP-ACC-1 na P1 sa qty=5 (iz testa 2). Pokušaj TRANSFER 6 → mora pasti. */
  r := public.loc_create_movement(jsonb_build_object(
    'item_ref_table',     'bigtehn_rn',
    'item_ref_id',        'TP-ACC-1',
    'order_no',           '9100',
    'movement_type',      'TRANSFER',
    'quantity',           6,
    'from_location_id',   '33333333-3333-3333-3333-333333333333',
    'to_location_id',     '44444444-4444-4444-4444-444444444444',
    'client_event_uuid',  'dddddddd-dddd-dddd-dddd-dddddddddd01'
  ));
  PERFORM set_config('t4.r', r::text, true);
END $t4$;

SELECT is(
  (current_setting('t4.r')::jsonb->>'ok')::boolean,
  false,
  'insufficient_quantity: TRANSFER preko available vraća ok=false'
);
SELECT is(
  current_setting('t4.r')::jsonb->>'error',
  'insufficient_quantity',
  'insufficient_quantity: tačan error code'
);
SELECT is(
  (current_setting('t4.r')::jsonb->>'available')::numeric,
  5::numeric,
  'insufficient_quantity: vraća available=5'
);

-- =========================================================================
-- 5) parent_inactive (M5 — deaktivirana HALA blokira premeštanje)
-- =========================================================================
SET LOCAL row_security = off;
UPDATE public.loc_locations SET is_active = false
 WHERE id = '22222222-2222-2222-2222-222222222222';
SET LOCAL row_security = on;

DO $t5$
DECLARE
  r jsonb;
BEGIN
  r := public.loc_create_movement(jsonb_build_object(
    'item_ref_table',     'bigtehn_rn',
    'item_ref_id',        'TP-PI-1',
    'order_no',           '9300',
    'movement_type',      'INITIAL_PLACEMENT',
    'quantity',           1,
    'to_location_id',     '55555555-5555-5555-5555-555555555555',  -- P3 u deaktiviranoj H2
    'client_event_uuid',  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee01'
  ));
  PERFORM set_config('t5.r', r::text, true);
END $t5$;

SELECT is(
  current_setting('t5.r')::jsonb->>'error',
  'parent_inactive',
  'parent_inactive: deaktivirana HALA blokira premeštanje na aktivnu policu u njoj'
);

-- =========================================================================
-- 6) Optional client_event_uuid — RPC sam generiše (Q1=A)
-- =========================================================================
DO $t6$
DECLARE
  r jsonb;
BEGIN
  r := public.loc_create_movement(jsonb_build_object(
    'item_ref_table',  'bigtehn_rn',
    'item_ref_id',     'TP-NO-UUID',
    'order_no',        '9400',
    'movement_type',   'INITIAL_PLACEMENT',
    'quantity',        2,
    'to_location_id',  '33333333-3333-3333-3333-333333333333'
    /* NEMA client_event_uuid u payload-u */
  ));
  PERFORM set_config('t6.r', r::text, true);
END $t6$;

SELECT is(
  (current_setting('t6.r')::jsonb->>'ok')::boolean,
  true,
  'opcioni UUID: poziv bez client_event_uuid prolazi (RPC sam generiše)'
);
SELECT isnt(
  (SELECT client_event_uuid::text FROM public.loc_location_movements
     WHERE id = (current_setting('t6.r')::jsonb->>'id')::uuid),
  NULL,
  'opcioni UUID: movement red ima ne-NULL client_event_uuid (auto-generated)'
);

-- ─── Cleanup ─────────────────────────────────────────────────────────────
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;

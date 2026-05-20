-- ============================================================================
-- pgTAP: harden_loc_create_movement_v5_roles (Sprint LOC-Härd-2)
-- ============================================================================
-- Zahteva primenjene migracije:
--   add_loc_module → step2 → step3 → step5 → v2 → v3 → v4 → v5 (Härd-1) → v5_roles (Härd-2)
--   add_loc_location_hierarchy_rules
--
-- JWT simulacija: request.jwt.claim.sub + request.jwt.claims (email) GUC.
-- Bootstrap seedovani auth.users: 000...0001, 000...0002.
--
-- Pokriva sprint plan Härd-2:
--   * test_authz_admin_passes
--   * test_authz_random_authenticated_blocked
--   * test_authz_proizvodnja_employee_passes (department_id = 2)
--   * test_authz_magacin_employee_passes (sub_departments.name = 'Magacin i logistika')
--   * helper sanity: loc_can_create_movement() funkcija postoji i ima GRANT
-- ============================================================================

BEGIN;
SET search_path = public, extensions;

SELECT plan(11);

-- ─── Seed organizacione strukture (CI bootstrap ima samo deo) ────────────
SET LOCAL row_security = off;

/* departments — Proizvodnja (2), Montaža (3), Infrastruktura (8).
 * Ne diramo postojeći red 5 iz bootstrap-a. */
INSERT INTO public.departments (id, name, sort_order) VALUES
  (2, 'Proizvodnja', 20),
  (3, 'Montaža', 30),
  (7, 'Marketing', 45),
  (8, 'Infrastruktura, logistika i nabavka', 80)
ON CONFLICT (id) DO NOTHING;

/* sub_departments — samo „Magacin i logistika" je potreban za testove
 * (zaposleni u Proizvodnji prolazi i bez sub_department-a). */
INSERT INTO public.sub_departments (id, department_id, name, sort_order) VALUES
  (8030, 8, 'Magacin i logistika', 30)
ON CONFLICT (id) DO NOTHING;

/* Bumpni sequence da naredni INSERT-i ne udaraju u nizak id. */
SELECT setval(pg_get_serial_sequence('public.departments', 'id'),
              GREATEST((SELECT COALESCE(MAX(id), 1) FROM public.departments), 100));
SELECT setval(pg_get_serial_sequence('public.sub_departments', 'id'),
              GREATEST((SELECT COALESCE(MAX(id), 1) FROM public.sub_departments), 100000));

-- ─── Seed user_roles ─────────────────────────────────────────────────────
INSERT INTO public.user_roles (email, role, is_active) VALUES
  ('h2-admin@test.local',  'admin',  true),
  ('h2-viewer@test.local', 'viewer', true)
ON CONFLICT (email) DO NOTHING;

-- ─── Seed auth.users (mapiranje email ↔ uid) ─────────────────────────────
/* Bootstrap već ima 000…0001 i 000…0002. Postavi email na njih ili napravi nove. */
INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-0000000000a1', 'h2-admin@test.local'),
  ('00000000-0000-0000-0000-0000000000a2', 'h2-no-role@test.local'),
  ('00000000-0000-0000-0000-0000000000a3', 'h2-proizvodnja@test.local'),
  ('00000000-0000-0000-0000-0000000000a4', 'h2-magacin@test.local'),
  ('00000000-0000-0000-0000-0000000000a5', 'h2-inactive@test.local'),
  ('00000000-0000-0000-0000-0000000000a6', 'h2-marketing@test.local')
ON CONFLICT (id) DO NOTHING;

-- ─── Seed employees ──────────────────────────────────────────────────────
INSERT INTO public.employees (
  id, full_name, email, is_active, department_id, sub_department_id
) VALUES
  ('a0000000-0000-0000-0000-0000000000a3',
   'Proizvodnja Zaposleni', 'h2-proizvodnja@test.local', true, 2, NULL),
  ('a0000000-0000-0000-0000-0000000000a4',
   'Magacin Zaposleni', 'h2-magacin@test.local', true, 8, 8030),
  ('a0000000-0000-0000-0000-0000000000a5',
   'Proizvodnja Neaktivan', 'h2-inactive@test.local', false, 2, NULL),
  ('a0000000-0000-0000-0000-0000000000a6',
   'Marketing Zaposleni', 'h2-marketing@test.local', true, 7, NULL)
ON CONFLICT (id) DO NOTHING;

-- ─── Seed test lokacije (kasnije će biti to_location_id) ─────────────────
INSERT INTO public.loc_locations (id, location_code, name, location_type, is_active)
VALUES
  ('66666666-6666-6666-6666-666666666666', 'TST6-H1', 'H2 Test HALA', 'WAREHOUSE', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.loc_locations (id, location_code, name, location_type, parent_id, is_active)
VALUES
  ('77777777-7777-7777-7777-777777777777', 'PP', 'H2 Test polica', 'SHELF',
   '66666666-6666-6666-6666-666666666666', true)
ON CONFLICT (id) DO NOTHING;

SET LOCAL row_security = on;

-- =========================================================================
-- 1) Helper sanity — funkcija postoji
-- =========================================================================
SELECT has_function(
  'public', 'loc_can_create_movement', ARRAY[]::text[],
  'public.loc_can_create_movement() postoji'
);

-- =========================================================================
-- Helper za test scenarije: pozovi loc_create_movement sa standardnim
-- payload-om i vrati JSONB rezultat. Različite test grane samo menjaju
-- jwt.claim.sub + jwt.claims.email pre poziva.
-- =========================================================================
CREATE OR REPLACE FUNCTION pg_temp.h2_call_create(
  p_uuid uuid DEFAULT gen_random_uuid()
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN public.loc_create_movement(jsonb_build_object(
    'item_ref_table',    'bigtehn_rn',
    'item_ref_id',       'TP-H2-' || substr(p_uuid::text, 1, 8),
    'order_no',          '9000',
    'movement_type',     'INITIAL_PLACEMENT',
    'quantity',          1,
    'to_location_id',    '77777777-7777-7777-7777-777777777777',
    'client_event_uuid', p_uuid::text
  ));
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'error', SQLERRM);
END;
$$;

-- =========================================================================
-- 2) Admin uloga → prolazi
-- =========================================================================
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('sub','00000000-0000-0000-0000-0000000000a1',
                                     'email','h2-admin@test.local')::text,
                  true);

SELECT is(
  (pg_temp.h2_call_create('aaaa0001-0000-0000-0000-000000000001'::uuid)->>'ok')::boolean,
  true,
  'authz: admin uloga (user_roles) → loc_create_movement prolazi'
);

-- =========================================================================
-- 3) Random authenticated (nema ulogu i nije zaposleni) → blokiran
-- =========================================================================
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a2', true);
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('sub','00000000-0000-0000-0000-0000000000a2',
                                     'email','h2-no-role@test.local')::text,
                  true);

SELECT is(
  pg_temp.h2_call_create('aaaa0002-0000-0000-0000-000000000002'::uuid)->>'error',
  'not_authorized',
  'authz: nepoznat authenticated korisnik bez uloge i bez employee zapisa → not_authorized'
);
SELECT is(
  (pg_temp.h2_call_create('aaaa0002-0000-0000-0000-000000000020'::uuid)->>'ok')::boolean,
  false,
  'authz: nepoznat korisnik → ok=false'
);

-- =========================================================================
-- 4) Employee u Proizvodnji (dept 2) → prolazi
-- =========================================================================
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a3', true);
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('sub','00000000-0000-0000-0000-0000000000a3',
                                     'email','h2-proizvodnja@test.local')::text,
                  true);

SELECT is(
  (pg_temp.h2_call_create('aaaa0003-0000-0000-0000-000000000003'::uuid)->>'ok')::boolean,
  true,
  'authz: employee u Proizvodnji (department_id=2) → prolazi bez user_roles'
);

-- =========================================================================
-- 5) Employee u „Magacin i logistika" (sub_dept 8030, dept 8) → prolazi
-- =========================================================================
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a4', true);
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('sub','00000000-0000-0000-0000-0000000000a4',
                                     'email','h2-magacin@test.local')::text,
                  true);

SELECT is(
  (pg_temp.h2_call_create('aaaa0004-0000-0000-0000-000000000004'::uuid)->>'ok')::boolean,
  true,
  'authz: employee u sub_dept "Magacin i logistika" (department_id=8) → prolazi'
);

-- =========================================================================
-- 6) Neaktivan employee u Proizvodnji → blokiran (is_active=false filter)
-- =========================================================================
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a5', true);
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('sub','00000000-0000-0000-0000-0000000000a5',
                                     'email','h2-inactive@test.local')::text,
                  true);

SELECT is(
  pg_temp.h2_call_create('aaaa0005-0000-0000-0000-000000000005'::uuid)->>'error',
  'not_authorized',
  'authz: neaktivan employee (is_active=false) → not_authorized'
);

-- =========================================================================
-- 7) Employee u Marketingu (dept 7, nije u Härd-2 listi) → blokiran
-- =========================================================================
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a6', true);
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('sub','00000000-0000-0000-0000-0000000000a6',
                                     'email','h2-marketing@test.local')::text,
                  true);

SELECT is(
  pg_temp.h2_call_create('aaaa0006-0000-0000-0000-000000000006'::uuid)->>'error',
  'not_authorized',
  'authz: employee van Härd-2 liste (dept 7 Marketing) → not_authorized'
);

-- =========================================================================
-- 8) Viewer uloga (nije u listi) + bez employee zapisa → blokiran
-- =========================================================================
INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-0000000000a7', 'h2-viewer@test.local')
ON CONFLICT (id) DO NOTHING;

SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a7', true);
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('sub','00000000-0000-0000-0000-0000000000a7',
                                     'email','h2-viewer@test.local')::text,
                  true);

SELECT is(
  pg_temp.h2_call_create('aaaa0007-0000-0000-0000-000000000007'::uuid)->>'error',
  'not_authorized',
  'authz: viewer uloga bez employee zapisa → not_authorized'
);

-- =========================================================================
-- 9) Nije autentifikovan (JWT nije postavljen) → not_authenticated
-- =========================================================================
SELECT set_config('request.jwt.claim.sub', '', true);
SELECT set_config('request.jwt.claims', '', true);

SELECT is(
  pg_temp.h2_call_create('aaaa0009-0000-0000-0000-000000000009'::uuid)->>'error',
  'not_authenticated',
  'authz: bez JWT-a → not_authenticated (Härd-2 ne preteže Härd-1 auth check)'
);

-- =========================================================================
-- 10) Idempotent replay — admin pozove dvaput sa istim UUID → idempotent
--     (verifikuje da Härd-2 nije pokvario Härd-1 ponašanje)
-- =========================================================================
SET LOCAL row_security = off;
INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-0000000000a8', 'h2-admin-idemp@test.local')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.user_roles (email, role, is_active) VALUES
  ('h2-admin-idemp@test.local', 'admin', true)
ON CONFLICT (email) DO NOTHING;
SET LOCAL row_security = on;

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a8', true);
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('sub','00000000-0000-0000-0000-0000000000a8',
                                     'email','h2-admin-idemp@test.local')::text,
                  true);

DO $t10$
DECLARE
  v_uuid uuid := 'bbbb0010-0000-0000-0000-000000000010';
  r1 jsonb;
  r2 jsonb;
BEGIN
  r1 := pg_temp.h2_call_create(v_uuid);
  r2 := pg_temp.h2_call_create(v_uuid);
  PERFORM set_config('t10.r1', r1::text, true);
  PERFORM set_config('t10.r2', r2::text, true);
END $t10$;

SELECT is(
  (current_setting('t10.r2')::jsonb->>'idempotent')::boolean,
  true,
  'H-2 ne ruši H-1 idempotency: drugi poziv vraća idempotent=true'
);
SELECT is(
  current_setting('t10.r1')::jsonb->>'id',
  current_setting('t10.r2')::jsonb->>'id',
  'H-2 ne ruši H-1 idempotency: isti id'
);

-- ─── Cleanup ─────────────────────────────────────────────────────────────
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;

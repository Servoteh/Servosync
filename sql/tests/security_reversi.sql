-- ============================================================================
-- pgTAP: Reversi modul — RLS, rev_can_manage, RPC, view v_rev_my_issued_tools
-- ============================================================================
-- JWT: request.jwt.claims (auth.jwt) + request.jwt.claim.sub (auth.uid) u CI.
-- ============================================================================

BEGIN;
SET search_path = public, extensions;

SELECT plan(11);

-- ─── Seed: user_roles + auth binding + zaposleni + lokacija + alat ─────────
SET LOCAL row_security = off;

INSERT INTO public.user_roles (email, role, project_id, is_active) VALUES
  ('rev-no-role@test.local',  'user',     NULL, true),
  ('rev-viewer@test.local',  'viewer',   NULL, true),
  ('rev-admin@test.local',   'admin',    NULL, true),
  ('rev-mag@test.local',     'magacioner', NULL, true),
  ('rev-pm@test.local',      'pm',       NULL, true)
ON CONFLICT DO NOTHING;

UPDATE auth.users SET email = 'rev-mag@test.local'
WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

INSERT INTO public.employees (id, full_name, email, is_active) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Rev Test A', 'rev-test-a@ci.local', true),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Rev Test B', 'rev-test-b@ci.local', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.loc_locations (id, location_code, name, location_type, is_active) VALUES
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'REV-TST-LOC', 'Test magacin reversi', 'WAREHOUSE', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.rev_tools (id, oznaka, naziv, status) VALUES
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'T-1', 'Test alat', 'active')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.rev_documents (
  id, doc_number, doc_type, recipient_type,
  recipient_employee_id, recipient_employee_name, recipient_loc_id,
  issued_by, status
) VALUES
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    'REV-TOOL-2099-9998',
    'TOOL',
    'EMPLOYEE',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Rev Test A',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '00000000-0000-0000-0000-000000000001'::uuid,
    'OPEN'
  ),
  (
    'ffffffff-ffff-ffff-ffff-ffffffffffff',
    'REV-TOOL-2099-9999',
    'TOOL',
    'EMPLOYEE',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Rev Test B',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '00000000-0000-0000-0000-000000000001'::uuid,
    'OPEN'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.rev_document_lines (
  id, document_id, line_type, tool_id, quantity, line_status
) VALUES
  (
    '11111111-1111-1111-1111-111111111111',
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    'TOOL',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    1,
    'ISSUED'
  ),
  (
    '22222222-2222-2222-2222-222222222222',
    'ffffffff-ffff-ffff-ffff-ffffffffffff',
    'TOOL',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    1,
    'ISSUED'
  )
ON CONFLICT (id) DO NOTHING;

SET LOCAL row_security = on;

-- =========================================================================
-- Test 1: Korisnik bez uloge (nema red u user_roles) NE može INSERT u rev_tools
-- =========================================================================
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('email','rev-no-role@test.local')::text,
                  true);
SELECT set_config('request.jwt.claim.sub',
                  '00000000-0000-0000-0000-000000000002'::text,
                  true);

SELECT throws_ok(
  $$ INSERT INTO public.rev_tools (oznaka, naziv) VALUES ('X', 'Y') $$,
  '42501',
  NULL,
  'korisnik bez uloge u user_roles NE može INSERT u rev_tools (RLS)'
);

-- =========================================================================
-- Test 2: Korisnik sa ulogom viewer NE može INSERT u rev_tools
-- =========================================================================
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('email','rev-viewer@test.local')::text,
                  true);

SELECT throws_ok(
  $$ INSERT INTO public.rev_tools (oznaka, naziv) VALUES ('X2', 'Y2') $$,
  '42501',
  NULL,
  'viewer NE može INSERT u rev_tools'
);

-- =========================================================================
-- Test 3: Korisnik sa ulogom admin MOŽE INSERT u rev_tools
-- =========================================================================
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('email','rev-admin@test.local')::text,
                  true);
SELECT set_config('request.jwt.claim.sub',
                  '00000000-0000-0000-0000-000000000001'::text,
                  true);

SELECT lives_ok(
  $$ INSERT INTO public.rev_tools (oznaka, naziv) VALUES ('ADM-1', 'Admin alat') $$,
  'admin MOŽE INSERT u rev_tools'
);

-- =========================================================================
-- Test 4: Korisnik sa ulogom magacioner MOŽE INSERT u rev_documents
-- =========================================================================
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('email','rev-mag@test.local')::text,
                  true);

SELECT lives_ok(
  $$ INSERT INTO public.rev_documents (
       doc_number, doc_type, recipient_type, recipient_loc_id, issued_by, status
     ) VALUES (
       'REV-TOOL-2099-9997',
       'TOOL',
       'DEPARTMENT',
       'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid,
       '00000000-0000-0000-0000-000000000001'::uuid,
       'OPEN'
     ) $$,
  'magacioner MOŽE INSERT u rev_documents'
);

-- =========================================================================
-- Test 5: rev_can_manage() false bez odgovarajuće uloge
-- =========================================================================
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('email','rev-viewer@test.local')::text,
                  true);

SELECT is(public.rev_can_manage(), false,
  'rev_can_manage() = false za viewer');

-- =========================================================================
-- Test 6: rev_can_manage() true za magacioner
-- =========================================================================
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('email','rev-mag@test.local')::text,
                  true);

SELECT is(public.rev_can_manage(), true,
  'rev_can_manage() = true za magacioner');

-- =========================================================================
-- Test 7: rev_can_manage() true za pm
-- =========================================================================
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('email','rev-pm@test.local')::text,
                  true);

SELECT is(public.rev_can_manage(), true,
  'rev_can_manage() = true za pm');

-- =========================================================================
-- Test 8: rev_issue_reversal baca 42501 bez prava
-- =========================================================================
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('email','rev-viewer@test.local')::text,
                  true);

SELECT throws_ok(
  $$ SELECT public.rev_issue_reversal('{}'::jsonb) $$,
  '42501',
  NULL,
  'rev_issue_reversal baca 42501 za korisnika bez prava'
);

-- =========================================================================
-- Test 9: rev_next_doc_number('TOOL') oblika REV-TOOL-YYYY-NNNN
-- =========================================================================
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('email','rev-admin@test.local')::text,
                  true);

SELECT ok(
  (SELECT public.rev_next_doc_number('TOOL')) ~ '^REV-TOOL-[0-9]{4}-[0-9]{4}$',
  'rev_next_doc_number(TOOL) odgovara obrascu REV-TOOL-YYYY-NNNN'
);

-- =========================================================================
-- Test 10: v_rev_my_issued_tools — samo zaduženja prijavljenog zaposlenog
-- =========================================================================
SELECT set_config('request.jwt.claims',
                  jsonb_build_object('email','rev-test-a@ci.local')::text,
                  true);

SELECT is_empty(
  $$ SELECT 1 FROM public.v_rev_my_issued_tools
     WHERE document_id = 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid $$,
  'view ne prikazuje dokument drugog zaposlenog (B)'
);

SELECT cmp_ok(
  (SELECT count(*)::int FROM public.v_rev_my_issued_tools
   WHERE document_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'::uuid),
  '>=',
  1,
  'view prikazuje bar jedno zaduženje zaposlenog A'
);

SELECT * FROM finish();
ROLLBACK;

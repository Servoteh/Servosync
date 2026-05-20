-- ============================================================================
-- pgTAP: Reversi rezni alat — RLS, RPC, balance, view
-- ============================================================================
-- Pokriva: catalog INSERT/RLS, balance UPSERT preko apply_delta,
--          rev_issue_cutting_reversal happy path + 42501 bez prava,
--          rev_confirm_cutting_return parcijalni povraćaj,
--          v_rev_my_issued_cutting_tools self-service filter,
--          rev_next_doc_number('CUTTING_TOOL') format.
-- ============================================================================

BEGIN;
SET search_path = public, extensions;

SELECT plan(13);

-- ─── Seed ────────────────────────────────────────────────────────────────────
SET LOCAL row_security = off;

INSERT INTO public.user_roles (email, role, project_id, is_active) VALUES
  ('rzn-viewer@test.local', 'viewer',     NULL, true),
  ('rzn-admin@test.local',  'admin',      NULL, true),
  ('rzn-mag@test.local',    'magacioner', NULL, true)
ON CONFLICT DO NOTHING;

INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-000000000001'::uuid, 'rzn-mag@test.local'),
  ('00000000-0000-0000-0000-000000000002'::uuid, 'rzn-viewer@test.local'),
  ('00000000-0000-0000-0000-000000000003'::uuid, 'rzn-admin@test.local')
ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;

INSERT INTO public.employees (id, full_name, email, is_active) VALUES
  ('a1aaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Rzn Operater A', 'rzn-op-a@ci.local', true),
  ('b2bbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Rzn Operater B', 'rzn-op-b@ci.local', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.loc_locations (id, location_code, name, location_type, is_active) VALUES
  ('c3cccccc-cccc-cccc-cccc-cccccccccccc', 'ALAT-MAG-01', 'Alatnica magacin', 'WAREHOUSE', true)
ON CONFLICT (id) DO NOTHING;

SET LOCAL row_security = on;

-- =========================================================================
-- Test 1: viewer NE može INSERT u rev_cutting_tool_catalog (RLS)
-- =========================================================================
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
  jsonb_build_object('email','rzn-viewer@test.local')::text, true);
SELECT set_config('request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000002'::text, true);

SELECT throws_ok(
  $$ INSERT INTO public.rev_cutting_tool_catalog (oznaka, naziv) VALUES ('VIEW-1','x') $$,
  '42501', NULL,
  'viewer NE može INSERT u rev_cutting_tool_catalog'
);

-- =========================================================================
-- Test 2: magacioner MOŽE INSERT, barcode auto-popunjen RZN-NNNNNN
-- =========================================================================
SELECT set_config('request.jwt.claims',
  jsonb_build_object('email','rzn-mag@test.local')::text, true);
SELECT set_config('request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000001'::text, true);

SELECT lives_ok(
  $$ INSERT INTO public.rev_cutting_tool_catalog
       (id, oznaka, naziv, klasa, compatible_machine_codes, unit)
     VALUES
       ('11111111-1111-1111-1111-111111111111',
        'GL-12','Glodalo D12','glodalo',
        ARRAY['8.3','10.1']::text[], 'kom') $$,
  'magacioner MOŽE INSERT u rev_cutting_tool_catalog'
);

SELECT ok(
  (SELECT barcode FROM public.rev_cutting_tool_catalog
     WHERE id = '11111111-1111-1111-1111-111111111111') ~ '^RZN-[0-9]{6}$',
  'barcode je auto-generisan u formatu RZN-NNNNNN'
);

-- =========================================================================
-- Test 3: rev_next_doc_number('CUTTING_TOOL') format REV-RZN-YYYY-NNNN
-- =========================================================================
SELECT ok(
  (SELECT public.rev_next_doc_number('CUTTING_TOOL')) ~ '^REV-RZN-[0-9]{4}-[0-9]{4}$',
  'rev_next_doc_number(CUTTING_TOOL) → REV-RZN-YYYY-NNNN'
);

-- =========================================================================
-- Test 4: rev_cts_apply_delta UPSERT-uje balance; ne dozvoljava negativno
-- =========================================================================
RESET ROLE;
SET LOCAL row_security = off;
SELECT public.rev_cts_apply_delta(
  '11111111-1111-1111-1111-111111111111'::uuid,
  'c3cccccc-cccc-cccc-cccc-cccccccccccc'::uuid,
  10::numeric);

SELECT is(
  (SELECT on_hand_qty FROM public.rev_cutting_tool_stock
     WHERE catalog_id = '11111111-1111-1111-1111-111111111111'::uuid
       AND location_id = 'c3cccccc-cccc-cccc-cccc-cccccccccccc'::uuid),
  10::numeric(12,3),
  'apply_delta(+10) → balance = 10'
);

SELECT throws_ok(
  $$ SELECT public.rev_cts_apply_delta(
       '11111111-1111-1111-1111-111111111111'::uuid,
       'c3cccccc-cccc-cccc-cccc-cccccccccccc'::uuid,
       (-100)::numeric) $$,
  'P0001', NULL,
  'apply_delta odbija negativan rezultujući balance'
);

-- Pripremi balance za issue (dovoljno za oduzimanje 5 u testu 8)
SELECT public.rev_cts_apply_delta(
  '11111111-1111-1111-1111-111111111111'::uuid,
  'c3cccccc-cccc-cccc-cccc-cccccccccccc'::uuid,
  10::numeric);
SELECT public.rev_cts_apply_delta(
  '11111111-1111-1111-1111-111111111111'::uuid,
  'c3cccccc-cccc-cccc-cccc-cccccccccccc'::uuid,
  50::numeric);

SET LOCAL row_security = on;

-- =========================================================================
-- Test 5: rev_issue_cutting_reversal — viewer dobija 42501
-- =========================================================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
  jsonb_build_object('email','rzn-viewer@test.local')::text, true);

SELECT throws_ok(
  $$ SELECT public.rev_issue_cutting_reversal(
      jsonb_build_object(
        'recipient_machine_code','8.3',
        'issued_to_employee_id','a1aaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'lines', jsonb_build_array(
          jsonb_build_object('catalog_id','11111111-1111-1111-1111-111111111111','quantity',1)
        )
      )
     ) $$,
  '42501', NULL,
  'rev_issue_cutting_reversal odbija viewer-a sa 42501'
);

-- Preduslov za loc_create_movement u issue: placement na izvornoj lokaciji (from_has_no_placement)
SET LOCAL row_security = off;
DELETE FROM public.loc_item_placements p
USING public.rev_cutting_tool_catalog c
WHERE p.item_ref_table = 'rev_cutting_tool_catalog'
  AND p.item_ref_id = c.barcode
  AND c.id = '11111111-1111-1111-1111-111111111111'::uuid;
INSERT INTO public.loc_item_placements (
  item_ref_table, item_ref_id, order_no, location_id, placement_status, quantity
)
SELECT
  'rev_cutting_tool_catalog',
  c.barcode,
  '',
  'c3cccccc-cccc-cccc-cccc-cccccccccccc'::uuid,
  'ACTIVE'::public.loc_placement_status_enum,
  70::numeric(12, 3)
FROM public.rev_cutting_tool_catalog c
WHERE c.id = '11111111-1111-1111-1111-111111111111'::uuid;

-- =========================================================================
-- Test 6: rev_issue_cutting_reversal happy path (admin — loc_create_movement zahteva edit ulogu)
-- =========================================================================
SELECT set_config('request.jwt.claims',
  jsonb_build_object('email','rzn-admin@test.local')::text, true);
SELECT set_config('request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000003'::text, true);

SET LOCAL row_security = off;
SELECT lives_ok(
  $$ SELECT public.rev_issue_cutting_reversal(
      jsonb_build_object(
        'recipient_machine_code','8.3',
        'issued_to_employee_id','a1aaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'issued_to_employee_name','Rzn Operater A',
        'source_location_id','c3cccccc-cccc-cccc-cccc-cccccccccccc',
        'lines', jsonb_build_array(
          jsonb_build_object('catalog_id','11111111-1111-1111-1111-111111111111','quantity',5)
        )
      )
     ) $$,
  'rev_issue_cutting_reversal radi sa CUTTING_TOOL payload-om (admin JWT)'
);
SET LOCAL row_security = on;

-- =========================================================================
-- Test 7: stock_balance: source = 65 (70 - 5)
-- =========================================================================
SELECT is(
  (SELECT on_hand_qty FROM public.rev_cutting_tool_stock
     WHERE catalog_id = '11111111-1111-1111-1111-111111111111'::uuid
       AND location_id = 'c3cccccc-cccc-cccc-cccc-cccccccccccc'::uuid),
  65::numeric(12,3),
  'source location balance = 65 (70 - 5)'
);

SELECT cmp_ok(
  (SELECT on_hand_qty FROM public.rev_cutting_tool_stock s
     JOIN public.rev_recipient_locations rl ON rl.loc_location_id = s.location_id
   WHERE s.catalog_id = '11111111-1111-1111-1111-111111111111'::uuid
     AND rl.recipient_type = 'MACHINE'
     AND rl.recipient_key  = '8.3'),
  '=', 5::numeric,
  'recipient (mašina 8.3) balance = 5'
);

-- =========================================================================
-- Test 8: rev_documents kreiran sa MACHINE recipient i issued_to_employee
-- =========================================================================
SELECT cmp_ok(
  (SELECT count(*)::int FROM public.rev_documents
     WHERE doc_type = 'CUTTING_TOOL'
       AND recipient_type = 'MACHINE'
       AND recipient_machine_code = '8.3'
       AND issued_to_employee_id  = 'a1aaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  '>=', 1,
  'rev_documents ima CUTTING_TOOL/MACHINE/8.3 dokument za operatera A'
);

-- =========================================================================
-- Test 9: v_rev_my_issued_cutting_tools — operater A vidi svoj alat
-- =========================================================================
SELECT set_config('request.jwt.claims',
  jsonb_build_object('email','rzn-op-a@ci.local')::text, true);

SELECT cmp_ok(
  (SELECT count(*)::int FROM public.v_rev_my_issued_cutting_tools
     WHERE recipient_machine_code = '8.3'),
  '>=', 1,
  'operater A vidi svoje rezne alate u v_rev_my_issued_cutting_tools'
);

-- =========================================================================
-- Test 10: v_rev_my_issued_cutting_tools — operater B NE vidi A-jev alat
-- =========================================================================
SELECT set_config('request.jwt.claims',
  jsonb_build_object('email','rzn-op-b@ci.local')::text, true);

SELECT is(
  (SELECT count(*)::int FROM public.v_rev_my_issued_cutting_tools
     WHERE recipient_machine_code = '8.3'),
  0,
  'operater B NE vidi alat operatera A (filter po issued_to_employee_id)'
);

-- =========================================================================
-- Test 11: rev_confirm_cutting_return parcijalni povraćaj (vrati 2 od 5)
-- =========================================================================
SELECT set_config('request.jwt.claims',
  jsonb_build_object('email','rzn-admin@test.local')::text, true);

DO $$
DECLARE
  v_doc_id  uuid;
  v_line_id uuid;
BEGIN
  SELECT id INTO v_doc_id FROM public.rev_documents
    WHERE recipient_machine_code = '8.3' AND doc_type='CUTTING_TOOL' LIMIT 1;
  SELECT id INTO v_line_id FROM public.rev_document_lines
    WHERE document_id = v_doc_id AND line_type='CUTTING_TOOL' LIMIT 1;
  PERFORM public.rev_confirm_cutting_return(jsonb_build_object(
    'doc_id', v_doc_id,
    'return_to_location_id', 'c3cccccc-cccc-cccc-cccc-cccccccccccc',
    'returned_lines', jsonb_build_array(
      jsonb_build_object('line_id', v_line_id, 'returned_quantity', 2)
    )
  ));
END$$;

SELECT pass('rev_confirm_cutting_return radi parcijalan povraćaj');

-- =========================================================================
-- Test 12: posle parcijalnog povraćaja: source = 67 (65 + 2)
-- =========================================================================
SELECT is(
  (SELECT on_hand_qty FROM public.rev_cutting_tool_stock
     WHERE catalog_id = '11111111-1111-1111-1111-111111111111'::uuid
       AND location_id = 'c3cccccc-cccc-cccc-cccc-cccccccccccc'::uuid),
  67::numeric(12,3),
  'source balance = 67 (65 + 2 vraćeno)'
);

-- =========================================================================
-- Test 13: dokument je u statusu PARTIALLY_RETURNED
-- =========================================================================
SELECT is(
  (SELECT status FROM public.rev_documents
     WHERE recipient_machine_code = '8.3'
       AND doc_type='CUTTING_TOOL' LIMIT 1),
  'PARTIALLY_RETURNED',
  'dokument je u PARTIALLY_RETURNED statusu nakon delimičnog vraćanja'
);

SELECT * FROM finish();
ROLLBACK;

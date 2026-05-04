-- ============================================================================
-- pgTAP: Sastanci RLS — Model B SELECT, write parent-scope, locked guard, prefs
-- ============================================================================
-- Zahteva primenjene migracije:
--   add_sastanci_module.sql
--   harden_sastanci_rls_phase2.sql
--   add_sastanci_notification_prefs.sql
--   harden_sastanci_write_rls.sql
--   add_sastanci_locked_guard.sql
--
-- JWT simulacija: request.jwt.claims GUC (sql/ci/00_bootstrap.sql stub auth.jwt()).
-- ============================================================================

BEGIN;
SET search_path = public, extensions;

SELECT plan(22);

-- ─── Helper za JWT simulaciju ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION test_sast_set_jwt_email(p_email text)
RETURNS void
LANGUAGE sql
AS $$
  SELECT set_config(
    'request.jwt.claims',
    jsonb_build_object('email', p_email)::text,
    true
  );
$$;

-- ─── Seed podataka van RLS-a ─────────────────────────────────────────────────
SET LOCAL row_security = off;

INSERT INTO public.user_roles (email, role, project_id, is_active) VALUES
  ('sast-mng@test.local',        'menadzment', NULL, true),
  ('sast-editor-a@test.local',   'pm',         NULL, true),
  ('sast-editor-b@test.local',   'pm',         NULL, true),
  ('sast-organizer@test.local',  'pm',         NULL, true),
  ('sast-vodio@test.local',      'pm',         NULL, true),
  ('sast-viewer@test.local',     'viewer',     NULL, true)
ON CONFLICT DO NOTHING;

INSERT INTO public.projects (id, project_code, project_name, status)
VALUES (
  '55555555-5555-5555-5555-555555555555',
  'SAST-RLS',
  'Sastanci RLS test projekat',
  'active'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.sastanci (
  id, tip, naslov, datum, status,
  vodio_email, zapisnicar_email, created_by_email
) VALUES
  (
    '11111111-1111-1111-1111-111111111111',
    'sedmicni',
    'Sastanci RLS test otvoren',
    CURRENT_DATE,
    'planiran',
    'sast-vodio@test.local',
    'sast-organizer@test.local',
    'sast-organizer@test.local'
  ),
  (
    '22222222-2222-2222-2222-222222222222',
    'sedmicni',
    'Sastanci RLS test zakljucan',
    CURRENT_DATE,
    'planiran',
    'sast-vodio@test.local',
    'sast-organizer@test.local',
    'sast-organizer@test.local'
  )
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status,
  vodio_email = EXCLUDED.vodio_email,
  zapisnicar_email = EXCLUDED.zapisnicar_email,
  created_by_email = EXCLUDED.created_by_email;

INSERT INTO public.sastanak_ucesnici (sastanak_id, email, label, prisutan, pozvan)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'sast-editor-a@test.local', 'Editor A', true, true),
  ('22222222-2222-2222-2222-222222222222', 'sast-editor-a@test.local', 'Editor A', true, true)
ON CONFLICT (sastanak_id, email) DO UPDATE SET
  label = EXCLUDED.label,
  prisutan = EXCLUDED.prisutan,
  pozvan = EXCLUDED.pozvan;

UPDATE public.sastanci
   SET status = 'zakljucan'
 WHERE id = '22222222-2222-2222-2222-222222222222';

INSERT INTO public.akcioni_plan (
  id, sastanak_id, naslov, odgovoran_email, status, created_by_email
) VALUES (
  '33333333-3333-3333-3333-333333333333',
  '11111111-1111-1111-1111-111111111111',
  'Seed akcija',
  'sast-editor-a@test.local',
  'otvoren',
  'sast-organizer@test.local'
) ON CONFLICT (id) DO UPDATE SET
  sastanak_id = EXCLUDED.sastanak_id,
  odgovoran_email = EXCLUDED.odgovoran_email;

INSERT INTO public.presek_aktivnosti (
  id, sastanak_id, rb, redosled, naslov, status
) VALUES (
  '44444444-4444-4444-4444-444444444444',
  '11111111-1111-1111-1111-111111111111',
  1,
  1,
  'Seed aktivnost',
  'u_toku'
) ON CONFLICT (id) DO UPDATE SET
  sastanak_id = EXCLUDED.sastanak_id,
  naslov = EXCLUDED.naslov;

INSERT INTO public.sastanci_notification_prefs (email)
VALUES
  ('sast-editor-a@test.local'),
  ('sast-editor-b@test.local'),
  ('sast-mng@test.local')
ON CONFLICT (email) DO NOTHING;

SET LOCAL row_security = on;

-- ============================================================================
-- GRUPA A: SELECT izolacija (Model B)
-- ============================================================================

-- A1: non-participant, non-organizer, non-management ne vidi sastanak.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-editor-b@test.local');
SELECT is(
  (SELECT count(*)::int FROM public.sastanci WHERE id = '11111111-1111-1111-1111-111111111111'),
  0,
  'A1: ne-ucesnik/ne-organizer ne vidi sastanak'
);

-- A2: učesnik vidi sastanak.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-editor-a@test.local');
SELECT is(
  (SELECT count(*)::int FROM public.sastanci WHERE id = '11111111-1111-1111-1111-111111111111'),
  1,
  'A2: ucesnik vidi sastanak'
);

-- A3: vodio_email vidi sastanak.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-vodio@test.local');
SELECT is(
  (SELECT count(*)::int FROM public.sastanci WHERE id = '11111111-1111-1111-1111-111111111111'),
  1,
  'A3: vodio_email vidi sastanak'
);

-- A4: management vidi sve sastanke.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-mng@test.local');
SELECT cmp_ok(
  (SELECT count(*)::int FROM public.sastanci
   WHERE id IN (
     '11111111-1111-1111-1111-111111111111',
     '22222222-2222-2222-2222-222222222222'
   )),
  '=',
  2,
  'A4: management vidi sve seed sastanke'
);

-- A5: editor koji nije učesnik ne vidi child redove.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-editor-b@test.local');
SELECT is(
  (
    SELECT count(*)::int
    FROM public.akcioni_plan
    WHERE id = '33333333-3333-3333-3333-333333333333'
  )
  +
  (
    SELECT count(*)::int
    FROM public.presek_aktivnosti
    WHERE id = '44444444-4444-4444-4444-444444444444'
  ),
  0,
  'A5: editor koji nije ucesnik ne vidi akcioni_plan/presek_aktivnosti'
);

-- ============================================================================
-- GRUPA B: WRITE parent-scope
-- ============================================================================

-- B1: editor učesnik može insertovati akcioni_plan.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-editor-a@test.local');
SELECT lives_ok(
  $$ INSERT INTO public.akcioni_plan (sastanak_id, naslov, odgovoran_email, status)
     VALUES (
       '11111111-1111-1111-1111-111111111111',
       'B1 ucesnik insert',
       'sast-editor-a@test.local',
       'otvoren'
     ) $$,
  'B1: editor ucesnik moze INSERT akcioni_plan'
);

-- B2: editor koji nije učesnik ne može insertovati akcioni_plan za tuđi sastanak.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-editor-b@test.local');
SELECT throws_ok(
  $$ INSERT INTO public.akcioni_plan (sastanak_id, naslov, odgovoran_email, status)
     VALUES (
       '11111111-1111-1111-1111-111111111111',
       'B2 tudji insert',
       'sast-editor-b@test.local',
       'otvoren'
     ) $$,
  '42501',
  NULL,
  'B2: editor koji nije ucesnik ne moze INSERT akcioni_plan za tudji sastanak'
);

-- B3: editor koji je vodio_email može update-ovati sastanci red.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-vodio@test.local');
SELECT lives_ok(
  $$ UPDATE public.sastanci
        SET napomena = 'B3 update by vodio'
      WHERE id = '11111111-1111-1111-1111-111111111111' $$,
  'B3: vodio_email moze UPDATE sastanci'
);

-- B4: editor koji nije učesnik/organizer/management ne može update-ovati sastanci.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-editor-b@test.local');
SELECT throws_ok(
  $test$
  DO $do$
  DECLARE
    v_rows INT;
  BEGIN
    UPDATE public.sastanci
       SET napomena = 'B4 forbidden update'
     WHERE id = '11111111-1111-1111-1111-111111111111';

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 0 THEN
      RAISE EXCEPTION 'RLS blocked UPDATE on sastanci'
        USING ERRCODE = '42501';
    END IF;
  END
  $do$;
  $test$,
  '42501',
  NULL,
  'B4: editor bez parent-scope ne moze UPDATE sastanci'
);

-- ============================================================================
-- GRUPA C: zaključan guard
-- ============================================================================

-- C1: učesnik ne može insertovati presek_aktivnosti u zaključan sastanak.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-editor-a@test.local');
SELECT throws_ok(
  $$ INSERT INTO public.presek_aktivnosti (sastanak_id, rb, redosled, naslov, status)
     VALUES (
       '22222222-2222-2222-2222-222222222222',
       99,
       99,
       'C1 locked insert',
       'u_toku'
     ) $$,
  '23514',
  NULL,
  'C1: ucesnik ne moze INSERT presek_aktivnosti u zakljucan sastanak'
);

-- C2: management može update-ovati zaključan sastanci red.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-mng@test.local');
SELECT lives_ok(
  $$ UPDATE public.sastanci
        SET napomena = 'C2 management update locked'
      WHERE id = '22222222-2222-2222-2222-222222222222' $$,
  'C2: management moze UPDATE zakljucan sastanak'
);

-- C3: editor/organizer ne može obrisati zaključan sastanak.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-vodio@test.local');
SELECT throws_ok(
  $$ DELETE FROM public.sastanci
      WHERE id = '22222222-2222-2222-2222-222222222222' $$,
  '23514',
  NULL,
  'C3: editor/organizer ne moze DELETE zakljucan sastanak'
);

RESET ROLE;

-- ============================================================================
-- GRUPA D: notification_prefs own-row
-- ============================================================================

-- D1: korisnik vidi samo svoju prefs row.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-editor-a@test.local');
SELECT is(
  (SELECT count(*)::int FROM public.sastanci_notification_prefs),
  1,
  'D1: korisnik vidi samo svoju notification_prefs row'
);

-- D2: korisnik ne može update-ovati tuđu prefs row.
UPDATE public.sastanci_notification_prefs
   SET on_new_akcija = false
 WHERE email = 'sast-editor-b@test.local';
RESET ROLE;
SET LOCAL row_security = off;
SELECT is(
  (SELECT on_new_akcija FROM public.sastanci_notification_prefs WHERE email = 'sast-editor-b@test.local'),
  true,
  'D2: korisnik ne moze UPDATE tudju notification_prefs row'
);
SET LOCAL row_security = on;

-- D3: management vidi sve prefs redove.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-mng@test.local');
SELECT cmp_ok(
  (SELECT count(*)::int FROM public.sastanci_notification_prefs
   WHERE email IN ('sast-editor-a@test.local', 'sast-editor-b@test.local', 'sast-mng@test.local')),
  '=',
  3,
  'D3: management vidi sve notification_prefs redove'
);

RESET ROLE;

-- ============================================================================
-- GRUPA E: Draft teme
-- ============================================================================

-- E1: korisnik sa edit rolom može insertovati draft temu.
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-editor-a@test.local');
SELECT lives_ok(
  $$ INSERT INTO public.pm_teme (
       id, projekat_id, sastanak_id, status, naslov, vrsta, oblast,
       predlozio_email, predlozio_label
     ) VALUES (
       '66666666-6666-6666-6666-666666666666',
       '55555555-5555-5555-5555-555555555555',
       NULL,
       'draft',
       'E1 draft tema',
       'tema',
       'opste',
       'sast-editor-a@test.local',
       'Editor A'
     ) $$,
  'E1: editor može INSERT draft temu'
);

-- E2: predlagač vidi svoj draft.
SELECT is(
  (SELECT count(*)::int FROM public.pm_teme WHERE id = '66666666-6666-6666-6666-666666666666'),
  1,
  'E2: predlagač vidi draft temu koju je predložio'
);

-- E3: drugi editor vidi tuđi draft.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-editor-b@test.local');
SELECT is(
  (SELECT count(*)::int FROM public.pm_teme WHERE id = '66666666-6666-6666-6666-666666666666'),
  1,
  'E3: drugi editor vidi tuđu draft temu'
);

-- E4: korisnik bez edit role ne može insertovati draft temu.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-viewer@test.local');
SELECT throws_ok(
  $$ INSERT INTO public.pm_teme (
       projekat_id, sastanak_id, status, naslov, vrsta, oblast,
       predlozio_email, predlozio_label
     ) VALUES (
       '55555555-5555-5555-5555-555555555555',
       NULL,
       'draft',
       'E4 forbidden draft',
       'tema',
       'opste',
       'sast-viewer@test.local',
       'Viewer'
     ) $$,
  '42501',
  NULL,
  'E4: viewer ne može INSERT draft temu'
);

-- E5: editor može review draft u usvojeno.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-editor-b@test.local');
SELECT lives_ok(
  $$ UPDATE public.pm_teme
        SET status = 'usvojeno',
            resio_email = 'sast-editor-b@test.local',
            resio_at = now()
      WHERE id = '66666666-6666-6666-6666-666666666666'
        AND status = 'draft' $$,
  'E5: editor može update draft u usvojeno'
);

-- Seed dodatni draft za E6/E7.
RESET ROLE;
SET LOCAL row_security = off;
INSERT INTO public.pm_teme (
  id, projekat_id, sastanak_id, status, naslov, vrsta, oblast,
  predlozio_email, predlozio_label, resio_napomena
) VALUES (
  '77777777-7777-7777-7777-777777777777',
  '55555555-5555-5555-5555-555555555555',
  NULL,
  'draft',
  'E6 draft tema',
  'tema',
  'opste',
  'sast-editor-a@test.local',
  'Editor A',
  NULL
) ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status,
  resio_napomena = EXCLUDED.resio_napomena;
SET LOCAL row_security = on;

-- E6: editor ne može review draft direktno u zatvoreno.
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-editor-b@test.local');
SELECT throws_ok(
  $$ UPDATE public.pm_teme
        SET status = 'zatvoreno'
      WHERE id = '77777777-7777-7777-7777-777777777777'
        AND status = 'draft' $$,
  '23514',
  NULL,
  'E6: editor ne može update draft direktno u zatvoreno'
);

-- E7: predlagač vidi napomenu na odbijenoj temi.
RESET ROLE;
SET LOCAL row_security = off;
UPDATE public.pm_teme
   SET status = 'odbijeno',
       resio_napomena = 'Nije za ovaj sastanak'
 WHERE id = '77777777-7777-7777-7777-777777777777';
SET LOCAL row_security = on;
SET LOCAL ROLE authenticated;
SELECT test_sast_set_jwt_email('sast-editor-a@test.local');
SELECT is(
  (SELECT resio_napomena FROM public.pm_teme WHERE id = '77777777-7777-7777-7777-777777777777'),
  'Nije za ovaj sastanak',
  'E7: predlagač vidi napomenu na odbijenoj temi'
);

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;

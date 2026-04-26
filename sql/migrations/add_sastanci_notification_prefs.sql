-- ============================================================================
-- SASTANCI — per-user podešavanja notifikacija (Faza C)
-- ============================================================================
-- Šta dodaje:
--   1) Tabela  `sastanci_notification_prefs`  — 6 toggle-a po korisniku
--   2) RLS: svaki korisnik čita/menja samo sopstveni red; admin/menadzment vide sve
--   3) RPC `sastanci_get_or_create_my_prefs()` — vrati ili kreiraj default red
--      (SECURITY DEFINER, GRANT TO authenticated)
--   4) updated_at trigger (reuse postojeće update_updated_at())
--
-- Preduslov: `public.update_updated_at()`, `public.current_user_is_management()`,
--            `public.has_edit_role()` (sve prisutne od ranije).
--
-- Idempotentno — bezbedno za re-run.
--
-- DOWN:
--   DROP FUNCTION IF EXISTS public.sastanci_get_or_create_my_prefs();
--   DROP TRIGGER IF EXISTS trg_sast_prefs_updated ON public.sastanci_notification_prefs;
--   DROP TABLE IF EXISTS public.sastanci_notification_prefs;
-- ============================================================================

-- ── 1) Tabela ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.sastanci_notification_prefs (
  email               TEXT PRIMARY KEY,   -- lower(email), paritet sa user_roles
  on_new_akcija       BOOLEAN NOT NULL DEFAULT TRUE,
  on_change_akcija    BOOLEAN NOT NULL DEFAULT TRUE,
  on_meeting_invite   BOOLEAN NOT NULL DEFAULT TRUE,
  on_meeting_locked   BOOLEAN NOT NULL DEFAULT TRUE,
  on_action_reminder  BOOLEAN NOT NULL DEFAULT TRUE,
  on_meeting_reminder BOOLEAN NOT NULL DEFAULT TRUE,
  -- Rezervisano za budući override; za sad uvek NULL (koristi se PK email).
  email_address       TEXT,
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  public.sastanci_notification_prefs IS
  'Per-user opt-in/out za svaki tip sastanci notifikacije (Faza C). '
  'Primarni ključ je lower(email) — isti parity pattern kao user_roles.';
COMMENT ON COLUMN public.sastanci_notification_prefs.email IS
  'lower(email) korisnika. PK i ključ za prefs lookup.';
COMMENT ON COLUMN public.sastanci_notification_prefs.email_address IS
  'Override email adresa za slanje (NULL = koristi PK). Rezervisano za buduću iteraciju.';

-- ── 2) updated_at trigger ────────────────────────────────────────────────────

DROP TRIGGER IF EXISTS trg_sast_prefs_updated ON public.sastanci_notification_prefs;
CREATE TRIGGER trg_sast_prefs_updated
  BEFORE UPDATE ON public.sastanci_notification_prefs
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ── 3) RLS ───────────────────────────────────────────────────────────────────

ALTER TABLE public.sastanci_notification_prefs ENABLE ROW LEVEL SECURITY;

-- SELECT: sopstveni red ili admin/menadzment
DROP POLICY IF EXISTS "snp_select_own" ON public.sastanci_notification_prefs;
CREATE POLICY "snp_select_own"
  ON public.sastanci_notification_prefs
  FOR SELECT TO authenticated
  USING (
    email = lower(COALESCE(auth.jwt() ->> 'email', ''))
    OR public.current_user_is_management()
  );

-- INSERT: sopstveni red
DROP POLICY IF EXISTS "snp_insert_own" ON public.sastanci_notification_prefs;
CREATE POLICY "snp_insert_own"
  ON public.sastanci_notification_prefs
  FOR INSERT TO authenticated
  WITH CHECK (
    email = lower(COALESCE(auth.jwt() ->> 'email', ''))
  );

-- UPDATE: sopstveni red ili admin/menadzment
DROP POLICY IF EXISTS "snp_update_own" ON public.sastanci_notification_prefs;
CREATE POLICY "snp_update_own"
  ON public.sastanci_notification_prefs
  FOR UPDATE TO authenticated
  USING (
    email = lower(COALESCE(auth.jwt() ->> 'email', ''))
    OR public.current_user_is_management()
  )
  WITH CHECK (
    email = lower(COALESCE(auth.jwt() ->> 'email', ''))
    OR public.current_user_is_management()
  );

-- DELETE: admin/menadzment only (korisnik briše ceo nalog kroz drugi mehanizam)
DROP POLICY IF EXISTS "snp_delete_admin" ON public.sastanci_notification_prefs;
CREATE POLICY "snp_delete_admin"
  ON public.sastanci_notification_prefs
  FOR DELETE TO authenticated
  USING (public.current_user_is_management());

-- ── 4) RPC: get-or-create my prefs ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.sastanci_get_or_create_my_prefs()
RETURNS public.sastanci_notification_prefs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email TEXT;
  v_row   public.sastanci_notification_prefs;
BEGIN
  v_email := lower(COALESCE(auth.jwt() ->> 'email', ''));
  IF v_email = '' THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO public.sastanci_notification_prefs (email)
  VALUES (v_email)
  ON CONFLICT (email) DO NOTHING;

  SELECT * INTO v_row
  FROM public.sastanci_notification_prefs
  WHERE email = v_email;

  RETURN v_row;
END;
$$;

COMMENT ON FUNCTION public.sastanci_get_or_create_my_prefs() IS
  'Vrati prefs red za ulogovanog korisnika; kreira default red ako ne postoji. '
  'SECURITY DEFINER — zaobilazi RLS INSERT check pri kreiranju.';

REVOKE ALL    ON FUNCTION public.sastanci_get_or_create_my_prefs() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sastanci_get_or_create_my_prefs() TO authenticated;

-- ── 5) Verifikacija ───────────────────────────────────────────────────────────

SELECT 'sastanci_notification_prefs' AS tabela,
       COUNT(*)::TEXT AS redova
FROM   public.sastanci_notification_prefs;

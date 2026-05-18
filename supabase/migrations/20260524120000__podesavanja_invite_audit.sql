-- Podešavanja: admin invite RPC (user_roles + opcioni Auth), settings audit view, predmet_aktivacija audit

-- ── 1) Admin invite: user_roles red (Auth mora postojati ili se kreira preko Edge funkcije) ──

CREATE OR REPLACE FUNCTION public.admin_invite_user_role(
  p_email text,
  p_role text,
  p_full_name text DEFAULT '',
  p_team text DEFAULT '',
  p_project_id uuid DEFAULT NULL,
  p_managed_sub_department_ids int[] DEFAULT NULL,
  p_send_recovery boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text := lower(trim(coalesce(p_email, '')));
  v_role text := lower(trim(coalesce(p_role, 'viewer')));
  v_actor text := public.current_user_email();
  v_uid uuid;
  v_row public.user_roles%ROWTYPE;
BEGIN
  IF NOT public.current_user_is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF v_email = '' OR v_email !~ '^[^@]+@[^@]+\.[^@]+$' THEN
    RAISE EXCEPTION 'invalid_email';
  END IF;
  IF v_role NOT IN ('admin','hr','menadzment','pm','leadpm','viewer','magacioner') THEN
    RAISE EXCEPTION 'invalid_role';
  END IF;

  SELECT id INTO v_uid FROM auth.users WHERE lower(email) = v_email LIMIT 1;

  IF v_uid IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'auth_user_missing',
      'message', 'Auth nalog za ovaj email ne postoji. Koristite „Pozovi korisnika“ (Edge) da se kreira nalog i uloga odjednom.'
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE lower(ur.email) = v_email
      AND ur.is_active = true
      AND (
        (p_project_id IS NULL AND ur.project_id IS NULL)
        OR ur.project_id IS NOT DISTINCT FROM p_project_id
      )
  ) THEN
    RAISE EXCEPTION 'duplicate_active_role';
  END IF;

  INSERT INTO public.user_roles (
    email, role, project_id, is_active, full_name, team,
    managed_sub_department_ids, created_by, must_change_password
  ) VALUES (
    v_email,
    v_role,
    p_project_id,
    true,
    coalesce(nullif(trim(p_full_name), ''), ''),
    coalesce(nullif(trim(p_team), ''), ''),
    CASE WHEN v_role = 'menadzment' THEN p_managed_sub_department_ids ELSE NULL END,
    coalesce(v_actor, ''),
    true
  )
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'ok', true,
    'user_role', to_jsonb(v_row),
    'auth_user_id', v_uid,
    'send_recovery', coalesce(p_send_recovery, true)
  );
END;
$$;

COMMENT ON FUNCTION public.admin_invite_user_role IS
  'Admin-only: INSERT u user_roles ako auth.users već postoji. Za kreiranje Auth naloga koristiti Edge admin-invite-user.';

REVOKE ALL ON FUNCTION public.admin_invite_user_role FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_invite_user_role TO authenticated;

-- ── 2) Settings audit view (public.audit_log) ──

CREATE OR REPLACE VIEW public.v_settings_audit_log AS
SELECT
  id,
  table_name,
  record_id,
  action,
  actor_email,
  actor_uid,
  changed_at,
  old_data,
  new_data,
  diff_keys
FROM public.audit_log
WHERE table_name IN ('user_roles', 'predmet_aktivacija');

COMMENT ON VIEW public.v_settings_audit_log IS
  'Admin read-only: promene na user_roles i production.predmet_aktivacija (preko audit_log triggera).';

GRANT SELECT ON public.v_settings_audit_log TO authenticated;

-- ── 3) Audit trigger na production.predmet_aktivacija ──

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_tables
    WHERE schemaname = 'production' AND tablename = 'predmet_aktivacija'
  ) AND EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'audit_row_change'
  ) THEN
    EXECUTE 'DROP TRIGGER IF EXISTS trg_audit_predmet_aktivacija ON production.predmet_aktivacija';
    EXECUTE '
      CREATE TRIGGER trg_audit_predmet_aktivacija
        AFTER INSERT OR UPDATE OR DELETE ON production.predmet_aktivacija
        FOR EACH ROW EXECUTE FUNCTION public.audit_row_change()';
  END IF;
END $$;

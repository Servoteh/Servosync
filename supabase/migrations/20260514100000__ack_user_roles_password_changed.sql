-- RPC: nakon uspešne promene lozinke (recovery flow ili forsiran UI),
-- skloni must_change_password na sopstvenom user_roles redu.
CREATE OR REPLACE FUNCTION public.ack_user_roles_password_changed()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email text := lower(trim(coalesce(auth.jwt() ->> 'email', '')));
BEGIN
  IF v_email = '' THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;
  UPDATE public.user_roles
  SET must_change_password = false,
      updated_at = now()
  WHERE lower(trim(email)) = v_email
    AND is_active = true;
END;
$$;

REVOKE ALL ON FUNCTION public.ack_user_roles_password_changed() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ack_user_roles_password_changed() TO authenticated;

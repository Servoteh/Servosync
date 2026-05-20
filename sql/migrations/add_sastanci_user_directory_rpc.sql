-- Imenik korisnika za izbor učesnika u modulu Sastanci.
-- SECURITY DEFINER omogućava čitanje user_roles bez admin RLS politike;
-- pristup je ograničen na has_edit_role() (pm/leadpm/menadzment/admin/hr).

CREATE OR REPLACE FUNCTION public.get_sastanci_user_directory()
RETURNS TABLE (
  email     TEXT,
  full_name TEXT,
  role      TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.has_edit_role() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    LOWER(ur.email) AS email,
    COALESCE(NULLIF(TRIM(ur.full_name), ''), LOWER(ur.email)) AS full_name,
    ur.role
  FROM public.user_roles ur
  WHERE ur.is_active = TRUE
    AND ur.email IS NOT NULL
    AND TRIM(ur.email) <> ''
  ORDER BY 2, 1;
END;
$$;

REVOKE ALL ON FUNCTION public.get_sastanci_user_directory() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_sastanci_user_directory() TO authenticated;

COMMENT ON FUNCTION public.get_sastanci_user_directory() IS
  'Aktivni korisnici aplikacije (email + ime) za autocomplete učesnika sastanka.';

NOTIFY pgrst, 'reload schema';

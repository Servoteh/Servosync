-- ============================================================================
-- ODRŽAVANJE — RPC lista korisnika za dodelu incidenata (bez širenja RLS SELECT)
-- ============================================================================
-- Pokreni u Supabase SQL Editoru posle add_maintenance_module.sql.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.maint_assignable_users()
RETURNS TABLE (user_id uuid, full_name text, maint_role text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.user_id, p.full_name, p.role::text AS maint_role
  FROM public.maint_user_profiles p
  WHERE p.active = true
    AND p.role::text IN ('operator', 'technician', 'chief', 'admin')
  ORDER BY p.full_name;
$$;

GRANT EXECUTE ON FUNCTION public.maint_assignable_users() TO authenticated;

COMMENT ON FUNCTION public.maint_assignable_users() IS
  'Korisnici iz maint_user_profiles pogodni za dodelu incidenta (UI padajuća lista).';

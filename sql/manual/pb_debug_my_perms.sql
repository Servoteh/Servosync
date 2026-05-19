-- ============================================================================
-- DEBUG RPC: pb_debug_my_perms
-- ============================================================================
-- Vraća stanje TVOJE autentikovane sesije:
--   - jwt_email   = ono što RLS funkcije vide (auth.jwt() ->> 'email')
--   - jwt_uid     = auth.uid()
--   - is_admin    = current_user_is_admin() (pb_can_edit_tasks koristi ovo)
--   - has_edit    = has_edit_role()
--   - can_edit_tasks = pb_can_edit_tasks() — ako je FALSE, RLS odbija PATCH
--   - admin_rows  = SVE rows iz user_roles koje matchuju tvoj JWT email
--
-- Kako pokrenuti:
--   1) U Supabase SQL Editor pusti CREATE FUNCTION ispod (jednom).
--   2) Iz BROWSER-a (DevTools console na app-u, kao authenticated user):
--      const r = await fetch('https://<PROJ>.supabase.co/rest/v1/rpc/pb_debug_my_perms', {
--        method: 'POST',
--        headers: {
--          'Content-Type': 'application/json',
--          'apikey': '<anon_key>',
--          'Authorization': 'Bearer ' + JSON.parse(localStorage.getItem('sb-<proj>-auth-token')).access_token
--        }
--      });
--      console.table(await r.json());
--
--   3) ILI još jednostavnije — koristi Supabase Dashboard "Run SQL with role":
--      SET ROLE authenticated;
--      SELECT * FROM public.pb_debug_my_perms();
-- ============================================================================

CREATE OR REPLACE FUNCTION public.pb_debug_my_perms()
RETURNS TABLE (
  jwt_email       text,
  jwt_uid         uuid,
  is_admin        boolean,
  has_edit        boolean,
  can_edit_tasks  boolean,
  matching_user_roles_count integer,
  matching_user_roles_data  jsonb
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
  SELECT
    (auth.jwt() ->> 'email')::text                                         AS jwt_email,
    auth.uid()                                                             AS jwt_uid,
    public.current_user_is_admin()                                         AS is_admin,
    public.has_edit_role()                                                 AS has_edit,
    public.pb_can_edit_tasks()                                             AS can_edit_tasks,
    (SELECT count(*)::integer FROM public.user_roles
       WHERE LOWER(email) = LOWER(COALESCE(auth.jwt() ->> 'email', '')))   AS matching_user_roles_count,
    (SELECT jsonb_agg(jsonb_build_object(
        'id', id, 'email', email, 'role', role,
        'is_active', is_active, 'project_id', project_id,
        'updated_at', updated_at
      ))
       FROM public.user_roles
       WHERE LOWER(email) = LOWER(COALESCE(auth.jwt() ->> 'email', '')))   AS matching_user_roles_data;
$$;

REVOKE ALL    ON FUNCTION public.pb_debug_my_perms() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_debug_my_perms() TO authenticated;

-- ============================================================================
-- BONUS: force PostgREST schema reload (možda je cache zaglavljen)
-- ============================================================================
NOTIFY pgrst, 'reload schema';

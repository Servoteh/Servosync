-- PB soft delete RLS (vidi sql/migrations/fix_pb_tasks_soft_delete_rls.sql)

DROP POLICY IF EXISTS pb_tasks_update_editors ON public.pb_tasks;
DROP POLICY IF EXISTS pb_tasks_soft_delete ON public.pb_tasks;

CREATE POLICY pb_tasks_update_editors
  ON public.pb_tasks FOR UPDATE TO authenticated
  USING (
    public.pb_can_edit_tasks()
    AND deleted_at IS NULL
  )
  WITH CHECK (
    public.pb_can_edit_tasks()
    AND deleted_at IS NULL
  );

CREATE POLICY pb_tasks_soft_delete
  ON public.pb_tasks FOR UPDATE TO authenticated
  USING (
    public.pb_can_edit_tasks()
    AND deleted_at IS NULL
  )
  WITH CHECK (
    public.pb_can_edit_tasks()
    AND deleted_at IS NOT NULL
  );

COMMENT ON POLICY pb_tasks_soft_delete ON public.pb_tasks IS
  'Soft delete: PATCH deleted_at na aktivnom zadatku; red više nije vidljiv SELECT politici.';

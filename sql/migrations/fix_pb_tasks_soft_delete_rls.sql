-- PB soft delete: odvojena UPDATE politika za postavljanje deleted_at.
-- Bez ovoga PostgREST PATCH (return=representation) pada jer SELECT politika
-- ne vidi red sa deleted_at IS NOT NULL ("new row violates row-level security").

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

-- Lokacije: ne prikazuj rev_tools placement-e u REST listama (Stavke, dashboard KPI).
-- Reversi i dalje vidi svoje redove preko rev_can_manage() (magacioner, admin, …).

DROP POLICY IF EXISTS loc_placements_select ON public.loc_item_placements;

CREATE POLICY loc_placements_select ON public.loc_item_placements
  FOR SELECT TO authenticated
  USING (
    item_ref_table IS DISTINCT FROM 'rev_tools'
    OR (
      item_ref_table = 'rev_tools'
      AND public.rev_can_manage()
    )
  );

NOTIFY pgrst, 'reload schema';

-- Jednokratno pražnjenje MAGACINA za Reversi (rezni + ručni alat).
-- CUTTING: briše sve redove zalihe na lokacijama tipa WAREHOUSE.
-- HAND (rev_tools): alati čija je aktivna lokacija magacin → status 'scrapped', pa brisanje placement-a na magacin.
--
-- NE dira: rev_cutting_tool_catalog (šifre), OPEN/PARTIAL reverz dokumente na mašinama, zaliha na PRODUCTION lokacijama.
--
-- Pre pokretanja (opciono):
--   SELECT count(*) FROM rev_cutting_tool_stock s
--     JOIN loc_locations l ON l.id = s.location_id AND l.location_type = 'WAREHOUSE';
--   SELECT count(*) FROM rev_tools t
--     JOIN loc_item_placements p ON p.item_ref_table = 'rev_tools' AND p.item_ref_id = t.loc_item_ref_id
--     JOIN loc_locations lo ON lo.id = p.location_id AND lo.location_type = 'WAREHOUSE'
--     WHERE t.status = 'active';

BEGIN;

-- 1) Rezni alat — samo zaliha u magacinima
DELETE FROM public.rev_cutting_tool_stock s
USING public.loc_locations l
WHERE s.location_id = l.id
  AND l.location_type = 'WAREHOUSE';

-- 2) Ručni alat trenutno u magacinu — ukloni iz pregleda (status !== active)
UPDATE public.rev_tools t
SET status = 'scrapped', updated_at = now()
WHERE t.status = 'active'
  AND EXISTS (
    SELECT 1
    FROM public.loc_item_placements p
    JOIN public.loc_locations lo ON lo.id = p.location_id AND lo.location_type = 'WAREHOUSE'
    WHERE p.item_ref_table = 'rev_tools'
      AND p.item_ref_id = t.loc_item_ref_id
  );

-- 3) Obriši zapise o smeštanju na magacinske lokacije (cleanup)
DELETE FROM public.loc_item_placements p
USING public.loc_locations lo
WHERE p.location_id = lo.id
  AND lo.location_type = 'WAREHOUSE'
  AND p.item_ref_table = 'rev_tools';

COMMIT;

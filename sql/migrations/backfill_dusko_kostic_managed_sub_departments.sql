-- D. Kostić (dusko.kostic@servoteh.com): logistika, nabavka, operativna infrastruktura, održavanje opreme.
-- IDs se uzimaju po kanonskim imenima (add_kadr_org_structure.sql) — bez hardkodiranih SERIAL vrednosti.
-- Napomena: ako isti nalog ima i ulogu admin, dashboard i dalje vidi ceo korpus (admin = pun obim).

UPDATE public.user_roles ur
SET managed_sub_department_ids = s.ids
FROM (
  SELECT array_agg(sd.id ORDER BY sd.department_id, sd.sort_order) AS ids
  FROM public.sub_departments sd
  WHERE (sd.department_id = 8 AND sd.name IN (
    'Rukovodstvo infrastrukture',
    'Nabavka',
    'Magacin i logistika',
    'Objekti i bezbednost'
  ))
  OR (sd.department_id = 9 AND sd.name = 'Održavanje opreme')
) s
WHERE lower(ur.email) = lower('dusko.kostic@servoteh.com')
  AND ur.role = 'menadzment'
  AND ur.is_active IS TRUE
  AND s.ids IS NOT NULL;

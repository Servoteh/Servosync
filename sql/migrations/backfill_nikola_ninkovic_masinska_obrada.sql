-- N. Ninković (nikola.ninkovic@servoteh.com): pododeljenje „Mašinska obrada” (Proizvodnja).
-- Depends: add_kadr_org_structure.sql (seed sub_departments).

UPDATE public.user_roles ur
SET managed_sub_department_ids = s.ids
FROM (
  SELECT array_agg(sd.id ORDER BY sd.id) AS ids
  FROM public.sub_departments sd
  WHERE sd.department_id = 2 AND sd.name = 'Mašinska obrada'
) s
WHERE lower(ur.email) = lower('nikola.ninkovic@servoteh.com')
  AND ur.role = 'menadzment'
  AND ur.is_active IS TRUE
  AND s.ids IS NOT NULL;

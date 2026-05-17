-- D. Kostić (dusko.kostic@servoteh.com): infrastruktura — logistika, nabavka, rukovodstvo, objekti.
-- Održavanje i servis (sektor 9) nisu u obuhvatu — COO (Z. Jaraković).
-- Napomena: ako isti nalog ima i ulogu admin, dashboard i dalje vidi ceo korpus (admin = pun obim).

UPDATE public.user_roles ur
SET managed_sub_department_ids = s.ids
FROM (
  SELECT array_agg(sd.id ORDER BY sd.department_id, sd.sort_order) AS ids
  FROM public.sub_departments sd
  WHERE sd.department_id = 8 AND sd.name IN (
    'Rukovodstvo infrastrukture',
    'Nabavka',
    'Magacin i logistika',
    'Objekti i bezbednost'
  )
) s
WHERE lower(ur.email) = lower('dusko.kostic@servoteh.com')
  AND ur.role = 'menadzment'
  AND ur.is_active IS TRUE
  AND s.ids IS NOT NULL;

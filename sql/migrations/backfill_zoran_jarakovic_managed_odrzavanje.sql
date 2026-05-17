-- Z. Jaraković COO (zoran.jarakovic@servoteh.com): Proizvodnja + Montaža + Održavanje
-- (departments.id 2, 3, 9 — sva pododeljenja).
-- Napomena: nalog mora imati user_roles.role = menadzment i is_active.

UPDATE public.user_roles ur
SET managed_sub_department_ids = s.ids
FROM (
  SELECT array_agg(sd.id ORDER BY sd.department_id, sd.sort_order) AS ids
  FROM public.sub_departments sd
  WHERE sd.department_id IN (2, 3, 9)
) s
WHERE lower(ur.email) = lower('zoran.jarakovic@servoteh.com')
  AND ur.role = 'menadzment'
  AND ur.is_active IS TRUE
  AND s.ids IS NOT NULL;

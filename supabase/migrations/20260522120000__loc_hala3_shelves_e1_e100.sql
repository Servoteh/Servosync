-- HALA 3: police E1–E100 (tip SHELF, naziv kao postojeći A-redovi).
-- Idempotentno: preskače kombinaciju (parent_id, location_code) koja već postoji.
-- Hala se bira po location_code = 'HALA 3' i tipu WAREHOUSE (bez fiksnog UUID-a).

INSERT INTO public.loc_locations (location_code, name, location_type, parent_id, is_active)
SELECT 'E' || gs.i::text,
       'Magacin',
       'SHELF'::public.loc_type_enum,
       h.id,
       true
FROM generate_series(1, 100) AS gs(i)
CROSS JOIN LATERAL (
  SELECT id
  FROM public.loc_locations
  WHERE trim(location_code) = 'HALA 3'
    AND location_type = 'WAREHOUSE'::public.loc_type_enum
    AND COALESCE(is_active, true)
  ORDER BY id
  LIMIT 1
) h
WHERE NOT EXISTS (
  SELECT 1
  FROM public.loc_locations x
  WHERE x.parent_id = h.id
    AND x.location_code = ('E' || gs.i::text)
);

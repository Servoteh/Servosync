-- K-kontrolne police (K-A1..5, K-B1..5, K-C1..5, K-M) fizički u Hali 2.
-- Roditelj: root lokacija HALA 2 (kreira se ako ne postoji).

INSERT INTO public.loc_locations (location_code, name, location_type, parent_id, is_active)
SELECT 'HALA 2', 'Hala 2', 'WAREHOUSE'::public.loc_type_enum, NULL, true
WHERE NOT EXISTS (
  SELECT 1 FROM public.loc_locations WHERE lower(trim(location_code)) = 'hala 2'
);

UPDATE public.loc_locations AS child
SET parent_id = (SELECT id FROM public.loc_locations WHERE lower(trim(location_code)) = 'hala 2' LIMIT 1)
WHERE child.location_code IN (
  'K-A1', 'K-A2', 'K-A3', 'K-A4', 'K-A5',
  'K-B1', 'K-B2', 'K-B3', 'K-B4', 'K-B5',
  'K-C1', 'K-C2', 'K-C3', 'K-C4', 'K-C5',
  'K-M'
);

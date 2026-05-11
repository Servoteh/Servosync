-- K-kontrolne police (K-A1..5, K-B1..5, K-C1..5, K-M) pod postojećom HALA 2A
-- (jedinstvena „Hala 2“ u masteru — bez duplog root čvora HALA 2).

INSERT INTO public.loc_locations (location_code, name, location_type, parent_id, is_active)
VALUES ('HALA 2A', 'Hala 2a-proizvodnja', 'WAREHOUSE'::public.loc_type_enum, NULL, true)
ON CONFLICT (location_code) DO NOTHING;

UPDATE public.loc_locations AS child
SET parent_id = (SELECT id FROM public.loc_locations WHERE location_code = 'HALA 2A' LIMIT 1)
WHERE child.location_code IN (
  'K-A1', 'K-A2', 'K-A3', 'K-A4', 'K-A5',
  'K-B1', 'K-B2', 'K-B3', 'K-B4', 'K-B5',
  'K-C1', 'K-C2', 'K-C3', 'K-C4', 'K-C5',
  'K-M'
);

DELETE FROM public.loc_locations WHERE location_code = 'HALA 2';

-- ============================================================================
-- LOKACIJE — pogled: sve HALE i POLICE (šifarnik)
-- ============================================================================
-- Jedan red po HALI (vrsta_reda = 'HALA'), jedan red po POLICI (vrsta_reda = 'POLICA')
-- sa podacima roditeljske hale. POLICE bez roditelja ostaju sa NULL u kolonama hale.
-- Sinhrono sa poslovnom podelom u src/lib/lokacijeTypes.js (HALA / POLICA tipovi).
-- ============================================================================

DROP VIEW IF EXISTS public.loc_hale_i_police_list;

CREATE VIEW public.loc_hale_i_police_list AS
SELECT
  'HALA'::text AS vrsta_reda,
  h.id AS hala_id,
  h.location_code AS hala_sifra,
  h.name AS hala_naziv,
  h.location_type::text AS hala_tip,
  h.path_cached AS hala_putanja,
  h.is_active AS hala_aktivna,
  h.depth AS hala_nivo,
  NULL::uuid AS polica_id,
  NULL::text AS polica_sifra,
  NULL::text AS polica_naziv,
  NULL::text AS polica_tip,
  NULL::text AS polica_putanja,
  NULL::boolean AS polica_aktivna
FROM public.loc_locations h
WHERE h.location_type::text IN (
  'WAREHOUSE', 'PRODUCTION', 'ASSEMBLY', 'FIELD', 'TEMP'
)

UNION ALL

SELECT
  'POLICA'::text AS vrsta_reda,
  hall.id AS hala_id,
  hall.location_code AS hala_sifra,
  hall.name AS hala_naziv,
  hall.location_type::text AS hala_tip,
  hall.path_cached AS hala_putanja,
  hall.is_active AS hala_aktivna,
  hall.depth AS hala_nivo,
  s.id AS polica_id,
  s.location_code AS polica_sifra,
  s.name AS polica_naziv,
  s.location_type::text AS polica_tip,
  s.path_cached AS polica_putanja,
  s.is_active AS polica_aktivna
FROM public.loc_locations s
LEFT JOIN public.loc_locations hall ON hall.id = s.parent_id
WHERE s.location_type::text IN ('SHELF', 'RACK', 'BIN');

ALTER VIEW public.loc_hale_i_police_list SET (security_invoker = true);

COMMENT ON VIEW public.loc_hale_i_police_list IS
  'Izlistavanje definisanih HALA (WAREHOUSE/PRODUCTION/ASSEMBLY/FIELD/TEMP) i POLICA (SHELF/RACK/BIN) iz loc_locations; '
  'POLICA redovi nose i identitet roditeljske hale (LEFT JOIN — sirotinjske police imaju NULL u hala_*).';

GRANT SELECT ON public.loc_hale_i_police_list TO authenticated;

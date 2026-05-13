-- ============================================================================
-- LOKACIJE — Jedinstvena šifra police u okviru hale (parent_id), kratko ime
-- ============================================================================
-- Pre: UNIQUE(lower(location_code)) globalno → police moraju biti HALA 3-A1 itd.
-- Posle:
--   * UNIQUE(scope, lower(location_code)) gde je scope = parent_id ili sentinel
--     za sve root lokacije (hale/servisne ZONE sa parent_id NULL).
--     Sentinel UUID mora ostati neriskiran kao stvarni parent_id FK.
--   * Za police (SHELF/RACK/BIN) skidamo vodeći prefiks `<parent.location_code>-`
--     kad ceo kod još uvek tako počinje (idempotentna normalizacija).
-- Zavisi: loc_locations FK na parent_id; funkcija rev_get_or_create_recipient_location
--   mora koristiti ON CONFLICT koji odgovara novom indeksu.
-- Bezbedno za ponovni run UPDATE-a ako nema prefikša za strip.
-- ============================================================================

-- Jedinstveni indeksi
DROP INDEX IF EXISTS public.loc_locations_code_ci_uq;
DROP INDEX IF EXISTS public.loc_locations_code_uq;

CREATE UNIQUE INDEX IF NOT EXISTS loc_locations_scope_code_ci_uq
ON public.loc_locations (
  COALESCE(parent_id, '00000000-0000-0000-0000-000000000000'::uuid),
  lower(location_code)
);

COMMENT ON INDEX public.loc_locations_scope_code_ci_uq IS
  'Unikat lokacije u okviru roditelja: (parent_id, lower(location_code)). '
  'Root redovi (parent_id NULL) dele sentinel bucket UUID nula tako da kod i dalje '
  'ne može biti dupli među halama bez roditelja.';

-- Normalizacija polica pod halom — samo ako kod eksplicitno počinje kodom roditelja + '-'.
UPDATE public.loc_locations AS s
SET
  location_code = substring(
    s.location_code
    FROM (char_length(p.location_code || '-') + 1)::int
  ),
  updated_at = now()
FROM public.loc_locations AS p
WHERE p.id = s.parent_id
  AND s.location_type::text IN ('SHELF', 'RACK', 'BIN')
  AND s.location_code LIKE p.location_code || '-%';

-- Reversal / mašinski primalac: UPSERT kompatibilno sa novim indeksom
CREATE OR REPLACE FUNCTION public.rev_get_or_create_recipient_location(
  p_recipient_type  text,
  p_recipient_key   text,
  p_recipient_label text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_loc_id   uuid;
  v_loc_code text;
  v_loc_type public.loc_type_enum;
BEGIN
  SELECT loc_location_id INTO v_loc_id
  FROM public.rev_recipient_locations
  WHERE recipient_type = p_recipient_type
    AND recipient_key = p_recipient_key;

  IF v_loc_id IS NOT NULL THEN
    RETURN v_loc_id;
  END IF;

  CASE p_recipient_type
    WHEN 'EMPLOYEE' THEN
      v_loc_type := 'FIELD';
      v_loc_code := 'ZADU-R-' || substr(p_recipient_key, 1, 8);
    WHEN 'DEPARTMENT' THEN
      v_loc_type := 'FIELD';
      v_loc_code := 'ZADU-O-' || p_recipient_key;
    WHEN 'EXTERNAL_COMPANY' THEN
      v_loc_type := 'SERVICE';
      v_loc_code := 'ZADU-K-' || p_recipient_key;
    WHEN 'MACHINE' THEN
      v_loc_type := 'PRODUCTION';
      v_loc_code := 'ZADU-M-' || regexp_replace(p_recipient_key, '[^A-Za-z0-9._-]', '_', 'g');
    ELSE
      RAISE EXCEPTION 'Nepoznat tip primaoca: %', p_recipient_type;
  END CASE;

  INSERT INTO public.loc_locations (
    location_code,
    name,
    location_type,
    is_active,
    notes
  )
  VALUES (
    v_loc_code,
    'Zaduzeno: ' || p_recipient_label,
    v_loc_type,
    true,
    'Automatski kreirana virtuelna lokacija za reversal primalac'
  )
  ON CONFLICT (
    COALESCE(parent_id, '00000000-0000-0000-0000-000000000000'::uuid),
    lower(location_code)
  )
    DO UPDATE SET
      name = EXCLUDED.name,
      is_active = true
  RETURNING id INTO v_loc_id;

  INSERT INTO public.rev_recipient_locations (
    recipient_type,
    recipient_key,
    recipient_label,
    loc_location_id
  )
  VALUES (p_recipient_type, p_recipient_key, p_recipient_label, v_loc_id)
  ON CONFLICT (recipient_type, recipient_key)
    DO UPDATE SET recipient_label = EXCLUDED.recipient_label;

  RETURN v_loc_id;
END;
$$;

REVOKE ALL ON FUNCTION public.rev_get_or_create_recipient_location(text, text, text) FROM PUBLIC;

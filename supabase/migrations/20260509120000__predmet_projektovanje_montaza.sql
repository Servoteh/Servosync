-- Podešavanje predmeta: kolona za kasnju filtraciju u Projektovanju i Planu montaže.
-- Praćenje / Plan proizvodnje ostaju na je_aktivan; ovaj flag će se koristiti u posebnim modulima.

ALTER TABLE production.predmet_aktivacija
  ADD COLUMN IF NOT EXISTS je_projektovanje_montaza boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN production.predmet_aktivacija.je_projektovanje_montaza IS
  'Kada bude uključeno u module: predmet mora imati i je_aktivan i ovaj flag za vidljivost u projektovanju / planu montaže.';

CREATE INDEX IF NOT EXISTS predmet_aktivacija_proj_mont_idx
  ON production.predmet_aktivacija (je_projektovanje_montaza)
  WHERE je_projektovanje_montaza IS TRUE;

-- Trigger: novi red sa oba podrazumevano uključena
CREATE OR REPLACE FUNCTION production.tg_predmet_aktivacija_default()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
BEGIN
  INSERT INTO production.predmet_aktivacija (
    predmet_item_id,
    je_aktivan,
    je_projektovanje_montaza,
    azurirao_user_id,
    azurirano_at
  )
  VALUES (NEW.id, true, true, NULL, now())
  ON CONFLICT (predmet_item_id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- list: dodato polje u JSON
CREATE OR REPLACE FUNCTION production.list_predmet_aktivacija_admin()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
DECLARE
  out_json jsonb;
BEGIN
  IF NOT public.can_manage_predmet_aktivacija() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  WITH rows AS (
    SELECT
      i.id AS item_id,
      i.broj_predmeta,
      i.naziv_predmeta,
      COALESCE(
        NULLIF(trim(both ' ' FROM c.name), ''),
        NULLIF(trim(both ' ' FROM c.short_name), ''),
        ''
      ) AS customer_name,
      COALESCE(pa.je_aktivan, false) AS je_aktivan,
      COALESCE(pa.je_projektovanje_montaza, false) AS je_projektovanje_montaza,
      pa.napomena,
      u.email::text AS azurirao_email,
      pa.azurirano_at
    FROM public.bigtehn_items_cache i
    LEFT JOIN production.predmet_aktivacija pa ON pa.predmet_item_id = i.id
    LEFT JOIN public.bigtehn_customers_cache c ON c.id = i.customer_id
    LEFT JOIN auth.users u ON u.id = pa.azurirao_user_id
  )
  SELECT COALESCE(
    (
      SELECT jsonb_agg(
        jsonb_build_object(
          'item_id', r.item_id,
          'broj_predmeta', COALESCE(r.broj_predmeta, ''),
          'naziv_predmeta', COALESCE(r.naziv_predmeta, ''),
          'customer_name', r.customer_name,
          'je_aktivan', r.je_aktivan,
          'je_projektovanje_montaza', r.je_projektovanje_montaza,
          'napomena', r.napomena,
          'azurirao_email', r.azurirao_email,
          'azurirano_at', r.azurirano_at
        )
        ORDER BY r.je_aktivan DESC, r.broj_predmeta ASC NULLS LAST
      )
      FROM rows r
    ),
    '[]'::jsonb
  )
  INTO out_json;
  RETURN out_json;
END;
$$;

DROP FUNCTION IF EXISTS public.set_predmet_aktivacija(integer, boolean, text);
DROP FUNCTION IF EXISTS production.set_predmet_aktivacija(integer, boolean, text);

CREATE OR REPLACE FUNCTION production.set_predmet_aktivacija(
  p_item_id integer,
  p_aktivan boolean,
  p_napomena text DEFAULT NULL,
  p_projektovanje_montaza boolean DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
BEGIN
  IF NOT public.can_manage_predmet_aktivacija() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF p_item_id IS NULL OR p_item_id <= 0 THEN
    RAISE EXCEPTION 'invalid p_item_id' USING ERRCODE = '22000';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.bigtehn_items_cache i WHERE i.id = p_item_id) THEN
    RAISE EXCEPTION 'nepoznat predmet' USING ERRCODE = '22000';
  END IF;

  INSERT INTO production.predmet_aktivacija (
    predmet_item_id,
    je_aktivan,
    napomena,
    je_projektovanje_montaza,
    azurirao_user_id,
    azurirano_at
  )
  VALUES (
    p_item_id,
    p_aktivan,
    p_napomena,
    COALESCE(p_projektovanje_montaza, true),
    auth.uid(),
    now()
  )
  ON CONFLICT (predmet_item_id) DO UPDATE SET
    je_aktivan = EXCLUDED.je_aktivan,
    napomena = CASE
      WHEN p_napomena IS NULL THEN predmet_aktivacija.napomena
      ELSE EXCLUDED.napomena
    END,
    je_projektovanje_montaza = CASE
      WHEN p_projektovanje_montaza IS NULL THEN predmet_aktivacija.je_projektovanje_montaza
      ELSE EXCLUDED.je_projektovanje_montaza
    END,
    azurirao_user_id = auth.uid(),
    azurirano_at = now();
END;
$$;

GRANT EXECUTE ON FUNCTION production.set_predmet_aktivacija(integer, boolean, text, boolean) TO authenticated;

COMMENT ON FUNCTION production.set_predmet_aktivacija(integer, boolean, text, boolean) IS
  'Upsert predmet_aktivacija; p_napomena NULL = ne menja napomenu; p_projektovanje_montaza NULL = ne menja flag.';

CREATE OR REPLACE FUNCTION public.set_predmet_aktivacija(
  p_item_id integer,
  p_aktivan boolean,
  p_napomena text DEFAULT NULL,
  p_projektovanje_montaza boolean DEFAULT NULL
)
RETURNS void
LANGUAGE sql
VOLATILE
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
  SELECT production.set_predmet_aktivacija(
    p_item_id,
    p_aktivan,
    p_napomena,
    p_projektovanje_montaza
  );
$$;

REVOKE ALL ON FUNCTION public.set_predmet_aktivacija(integer, boolean, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_predmet_aktivacija(integer, boolean, text, boolean) TO authenticated;

COMMENT ON FUNCTION public.set_predmet_aktivacija(integer, boolean, text, boolean) IS
  'Wrapper → production.set_predmet_aktivacija(integer, boolean, text, boolean)';

NOTIFY pgrst, 'reload schema';

-- Projektovanje/montaža: podrazumevano ISKLJUČENO; ručno se uključuje po predmetu.

ALTER TABLE production.predmet_aktivacija
  ALTER COLUMN je_projektovanje_montaza SET DEFAULT false;

COMMENT ON COLUMN production.predmet_aktivacija.je_projektovanje_montaza IS
  'Ručno uključivanje za prikaz u modulima projektovanja/plana montaže (uz je_aktivan). Podrazumevano false.';

UPDATE production.predmet_aktivacija
SET je_projektovanje_montaza = false;

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
  VALUES (NEW.id, true, false, NULL, now())
  ON CONFLICT (predmet_item_id) DO NOTHING;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION production.tg_predmet_aktivacija_default() IS
  'Novi predmet u cache-u: je_aktivan=true, je_projektovanje_montaza=false dok menadžment ne uključi.';

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
    COALESCE(p_projektovanje_montaza, false),
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

NOTIFY pgrst, 'reload schema';

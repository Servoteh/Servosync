-- Top ⭐ prioritet (Plan montaže, PB, Lokacije) — trajno u bazi.
-- Odvojeno od production.predmet_prioritet (admin redosled liste u Praćenju).

CREATE TABLE IF NOT EXISTS production.predmet_plan_prioritet (
  predmet_item_id integer NOT NULL PRIMARY KEY,
  slot smallint NOT NULL CHECK (slot >= 0 AND slot <= 9),
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES auth.users (id),
  CONSTRAINT predmet_plan_prioritet_slot_unique UNIQUE (slot)
);

CREATE INDEX IF NOT EXISTS predmet_plan_prioritet_slot_idx
  ON production.predmet_plan_prioritet (slot);

COMMENT ON TABLE production.predmet_plan_prioritet IS
  'Do 10 predmeta sa zvezdicom za sort u Plan montaži, PB i Lokacijama; ne utiče na production.predmet_prioritet (praćenje).';

ALTER TABLE production.predmet_plan_prioritet ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS predmet_plan_prioritet_select_authenticated ON production.predmet_plan_prioritet;
CREATE POLICY predmet_plan_prioritet_select_authenticated
  ON production.predmet_plan_prioritet FOR SELECT TO authenticated
  USING (true);

REVOKE ALL ON production.predmet_plan_prioritet FROM PUBLIC;
GRANT SELECT ON production.predmet_plan_prioritet TO authenticated;

CREATE OR REPLACE FUNCTION public.get_predmet_plan_prioritet_ids()
RETURNS integer[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
  SELECT COALESCE(
    array_agg(predmet_item_id ORDER BY slot ASC),
    ARRAY[]::integer[]
  )
  FROM production.predmet_plan_prioritet;
$$;

COMMENT ON FUNCTION public.get_predmet_plan_prioritet_ids() IS
  'Top prioritet predmeta (⭐): predmet_item_id redom slot 0..n-1; max 10.';

GRANT EXECUTE ON FUNCTION public.get_predmet_plan_prioritet_ids() TO authenticated;

CREATE OR REPLACE FUNCTION public.set_predmet_plan_prioritet(p_item_ids integer[])
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
DECLARE
  ids integer[];
  n int;
  i int;
BEGIN
  IF NOT public.can_manage_predmet_aktivacija() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  ids := COALESCE(p_item_ids, ARRAY[]::integer[]);
  n := COALESCE(array_length(ids, 1), 0);

  IF n > 10 THEN
    RAISE EXCEPTION 'max 10 prioriteta' USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1 FROM unnest(ids) u GROUP BY u HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'duplikat predmet_item_id' USING ERRCODE = '23514';
  END IF;

  FOR i IN 1..n LOOP
    IF ids[i] IS NULL OR ids[i] <= 0 THEN
      RAISE EXCEPTION 'neispravan predmet_item_id' USING ERRCODE = '23514';
    END IF;
  END LOOP;

  IF n > 0 AND EXISTS (
    SELECT 1
    FROM unnest(ids) AS u(item_id)
    LEFT JOIN public.bigtehn_items_cache b ON b.id = u.item_id
    WHERE b.id IS NULL
    LIMIT 1
  ) THEN
    RAISE EXCEPTION 'nepoznat predmet u cache-u' USING ERRCODE = '23514';
  END IF;

  DELETE FROM production.predmet_plan_prioritet;

  FOR i IN 1..n LOOP
    INSERT INTO production.predmet_plan_prioritet (predmet_item_id, slot, updated_by, updated_at)
    VALUES (ids[i], i - 1, auth.uid(), now());
  END LOOP;
END;
$$;

COMMENT ON FUNCTION public.set_predmet_plan_prioritet(integer[]) IS
  'Zamenjuje ceo top prioritet (admin/menadžment); max 10 predmeta.';

GRANT EXECUTE ON FUNCTION public.set_predmet_plan_prioritet(integer[]) TO authenticated;

NOTIFY pgrst, 'reload schema';

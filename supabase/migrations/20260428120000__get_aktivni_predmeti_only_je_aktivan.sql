-- Praćenje: lista aktivnih predmeta = samo production.predmet_aktivacija.je_aktivan = true
-- (bez preseka sa v_active_bigtehn_work_orders). Plan već koristi
-- v_production_operations_effective koji filtrira samo po je_aktivan.
-- shift_predmet_prioritet: ista baza (svi uključeni predmeti) kao get_aktivni_predmeti.

CREATE OR REPLACE FUNCTION production.get_aktivni_predmeti()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
  WITH filtered AS (
    SELECT pa.predmet_item_id AS item_id
    FROM production.predmet_aktivacija pa
    WHERE pa.je_aktivan IS TRUE
  ),
  joined AS (
    SELECT
      f.item_id,
      i.broj_predmeta,
      i.naziv_predmeta,
      COALESCE(
        NULLIF(trim(both ' ' FROM c.name), ''),
        NULLIF(trim(both ' ' FROM c.short_name), ''),
        ''
      ) AS customer_name,
      p.sort_priority,
      COALESCE(rc.root_count, 0)::integer AS broj_root_rn
    FROM filtered f
    INNER JOIN public.bigtehn_items_cache i ON i.id = f.item_id
    LEFT JOIN public.bigtehn_customers_cache c ON c.id = i.customer_id
    LEFT JOIN production.predmet_prioritet p ON p.predmet_item_id = f.item_id
    LEFT JOIN public.v_bigtehn_rn_root_count rc ON rc.predmet_item_id = f.item_id::bigint
  ),
  ranked AS (
    SELECT
      j.*,
      row_number() OVER (
        ORDER BY j.sort_priority ASC NULLS LAST, j.broj_predmeta ASC NULLS LAST
      )::integer AS redni_broj
    FROM joined j
  )
  SELECT COALESCE(
    (
      SELECT jsonb_agg(
        jsonb_build_object(
          'item_id', r.item_id,
          'broj_predmeta', COALESCE(r.broj_predmeta, ''),
          'naziv_predmeta', COALESCE(r.naziv_predmeta, ''),
          'customer_name', COALESCE(r.customer_name, ''),
          'sort_priority', r.sort_priority,
          'broj_root_rn', r.broj_root_rn,
          'redni_broj', r.redni_broj
        )
        ORDER BY r.sort_priority ASC NULLS LAST, r.broj_predmeta ASC NULLS LAST
      )
      FROM ranked r
    ),
    '[]'::jsonb
  );
$$;

COMMENT ON FUNCTION production.get_aktivni_predmeti() IS
  'Aktivni predmeti: svi u production.predmet_aktivacija sa je_aktivan; sort: prioritet, broj predmeta.';

CREATE OR REPLACE FUNCTION production.shift_predmet_prioritet(
  p_item_id integer,
  p_direction text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
DECLARE
  dir text := lower(trim(p_direction));
  items integer[];
  pos int;
  n int;
  neighbor_pos int;
  tmp int;
  i int;
BEGIN
  IF NOT public.current_user_is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF dir NOT IN ('up', 'down') THEN
    RAISE EXCEPTION 'invalid direction' USING ERRCODE = '22000';
  END IF;

  SELECT coalesce(array_agg(sub.item_id ORDER BY sub.sp NULLS LAST, sub.bp ASC NULLS LAST), ARRAY[]::integer[])
  INTO items
  FROM (
    SELECT
      v.item_id,
      p.sort_priority AS sp,
      i.broj_predmeta AS bp
    FROM (
      SELECT pa.predmet_item_id::integer AS item_id
      FROM production.predmet_aktivacija pa
      WHERE pa.je_aktivan IS TRUE
    ) v
    INNER JOIN public.bigtehn_items_cache i ON i.id = v.item_id
    LEFT JOIN production.predmet_prioritet p ON p.predmet_item_id = v.item_id
  ) sub;

  n := coalesce(array_length(items, 1), 0);
  IF n = 0 THEN
    RETURN;
  END IF;

  pos := array_position(items, p_item_id);
  IF pos IS NULL THEN
    RETURN;
  END IF;

  neighbor_pos := pos + CASE WHEN dir = 'up' THEN -1 ELSE 1 END;
  IF neighbor_pos < 1 OR neighbor_pos > n THEN
    RETURN;
  END IF;

  tmp := items[pos];
  items[pos] := items[neighbor_pos];
  items[neighbor_pos] := tmp;

  FOR i IN 1..n LOOP
    INSERT INTO production.predmet_prioritet (predmet_item_id, sort_priority, updated_by, updated_at)
    VALUES (items[i], i - 1, auth.uid(), now())
    ON CONFLICT (predmet_item_id) DO UPDATE SET
      sort_priority = EXCLUDED.sort_priority,
      updated_by = auth.uid(),
      updated_at = now();
  END LOOP;
END;
$$;

NOTIFY pgrst, 'reload schema';

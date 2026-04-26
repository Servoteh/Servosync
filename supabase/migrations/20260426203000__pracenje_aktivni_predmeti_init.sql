-- ============================================================================
-- Praćenje proizvodnje — aktivni predmeti (ekran 1 + prioritet + podsklopovi)
-- Zavisi od: Faze 0 (v_bigtehn_rn_struktura, v_bigtehn_rn_root_count,
-- bigtehn_rn_components_cache), v_active_bigtehn_work_orders, bigtehn_*_cache,
-- public.current_user_is_admin().
-- ============================================================================

-- ----------------------------------------------------------------------------
-- SEKCIJA 1 — Tabela production.predmet_prioritet
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS production.predmet_prioritet (
  predmet_item_id integer PRIMARY KEY,
  sort_priority integer NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES auth.users (id),

  CONSTRAINT predmet_prioritet_sort_nonneg CHECK (sort_priority >= 0)
);

CREATE INDEX IF NOT EXISTS predmet_prioritet_sort_idx
  ON production.predmet_prioritet (sort_priority);

COMMENT ON TABLE production.predmet_prioritet IS
  'Ručni redosled aktivnih predmeta (ekran 1). PK = bigtehn_items_cache.id (integer). '
  'Namerno bez FK ka bigtehn_items_cache: cache se puni brisanjem/upsert-om van aplikacije, '
  'FK bi blokirao sync.';

COMMENT ON COLUMN production.predmet_prioritet.predmet_item_id IS
  'ID predmeta u bigtehn_items_cache (integer).';
COMMENT ON COLUMN production.predmet_prioritet.sort_priority IS
  'Manji broj = važnije (raniji u listi).';
COMMENT ON COLUMN production.predmet_prioritet.updated_by IS
  'Poslednji admin koji je menjao prioritet (auth.uid()).';

-- ----------------------------------------------------------------------------
-- SEKCIJA 2 — RLS
-- ----------------------------------------------------------------------------
ALTER TABLE production.predmet_prioritet ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS predmet_prioritet_select_authenticated ON production.predmet_prioritet;
CREATE POLICY predmet_prioritet_select_authenticated
  ON production.predmet_prioritet FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS predmet_prioritet_insert_admin ON production.predmet_prioritet;
CREATE POLICY predmet_prioritet_insert_admin
  ON production.predmet_prioritet FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_is_admin());

DROP POLICY IF EXISTS predmet_prioritet_update_admin ON production.predmet_prioritet;
CREATE POLICY predmet_prioritet_update_admin
  ON production.predmet_prioritet FOR UPDATE
  TO authenticated
  USING (public.current_user_is_admin())
  WITH CHECK (public.current_user_is_admin());

DROP POLICY IF EXISTS predmet_prioritet_delete_admin ON production.predmet_prioritet;
CREATE POLICY predmet_prioritet_delete_admin
  ON production.predmet_prioritet FOR DELETE
  TO authenticated
  USING (public.current_user_is_admin());

GRANT SELECT, INSERT, UPDATE, DELETE ON production.predmet_prioritet TO authenticated;

-- ----------------------------------------------------------------------------
-- SEKCIJA 3 — RPC production.get_aktivni_predmeti()
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION production.get_aktivni_predmeti()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
  WITH base AS (
    SELECT DISTINCT wo.item_id::integer AS item_id
    FROM public.v_active_bigtehn_work_orders wo
    WHERE wo.item_id IS NOT NULL
  ),
  joined AS (
    SELECT
      b.item_id,
      i.broj_predmeta,
      i.naziv_predmeta,
      COALESCE(
        NULLIF(trim(both ' ' FROM c.name), ''),
        NULLIF(trim(both ' ' FROM c.short_name), ''),
        ''
      ) AS customer_name,
      p.sort_priority,
      COALESCE(rc.root_count, 0)::integer AS broj_root_rn
    FROM base b
    INNER JOIN public.bigtehn_items_cache i ON i.id = b.item_id
    LEFT JOIN public.bigtehn_customers_cache c ON c.id = i.customer_id
    LEFT JOIN production.predmet_prioritet p ON p.predmet_item_id = b.item_id
    LEFT JOIN public.v_bigtehn_rn_root_count rc ON rc.predmet_item_id = b.item_id::bigint
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
  'Lista aktivnih predmeta (distinct item_id iz v_active_bigtehn_work_orders), sort: '
  'sort_priority ASC NULLS LAST, broj_predmeta ASC; redni_broj 1..N.';

-- ----------------------------------------------------------------------------
-- SEKCIJA 4 — RPC production.get_podsklopovi_predmeta(integer)
-- Vraća ravnu jsonb listu (lakše renderovanje u vanilla JS tree-grid).
-- Redosled: isti root, isti parent (NULL za koren), ident_broj ASC.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION production.get_podsklopovi_predmeta(p_item_id integer)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
  SELECT COALESCE(
    (
      SELECT jsonb_agg(x.row_obj ORDER BY x.root_rn_id, x.parent_rn_id NULLS FIRST, x.ident_broj ASC)
      FROM (
        SELECT
          jsonb_build_object(
            'rn_id', s.rn_id,
            'legacy_idrn', w.id,
            'root_rn_id', s.root_rn_id,
            'ident_broj', COALESCE(w.ident_broj, ''),
            'naziv_dela', COALESCE(w.naziv_dela, ''),
            'status_rn', w.status_rn,
            'nivo', s.nivo,
            'parent_rn_id', s.parent_rn_id,
            'broj_komada', s.broj_komada,
            'is_mes_aktivan', EXISTS (
              SELECT 1
              FROM public.v_active_bigtehn_work_orders a
              WHERE a.id = s.rn_id
            ),
            'path_idrn', to_jsonb(s.path_idrn)
          ) AS row_obj,
          s.root_rn_id,
          s.parent_rn_id,
          w.ident_broj
        FROM public.v_bigtehn_rn_struktura s
        INNER JOIN public.bigtehn_work_orders_cache w ON w.id = s.rn_id
        WHERE s.predmet_item_id = p_item_id::bigint
      ) x
    ),
    '[]'::jsonb
  );
$$;

COMMENT ON FUNCTION production.get_podsklopovi_predmeta(integer) IS
  'Flat jsonb niz RN redova iz v_bigtehn_rn_struktura za predmet; polja za tree (nivo, parent_rn_id, path_idrn).';

-- ----------------------------------------------------------------------------
-- SEKCIJA 5 — RPC production.set_predmet_prioritet(integer, integer)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION production.set_predmet_prioritet(
  p_item_id integer,
  p_sort_priority integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
BEGIN
  IF NOT public.current_user_is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF p_sort_priority < 0 THEN
    RAISE EXCEPTION 'sort_priority must be >= 0' USING ERRCODE = '23514';
  END IF;

  INSERT INTO production.predmet_prioritet (predmet_item_id, sort_priority, updated_by, updated_at)
  VALUES (p_item_id, p_sort_priority, auth.uid(), now())
  ON CONFLICT (predmet_item_id) DO UPDATE SET
    sort_priority = EXCLUDED.sort_priority,
    updated_by = auth.uid(),
    updated_at = now();
END;
$$;

COMMENT ON FUNCTION production.set_predmet_prioritet(integer, integer) IS
  'Admin upsert prioriteta za jedan predmet.';

-- ----------------------------------------------------------------------------
-- SEKCIJA 6 — RPC production.shift_predmet_prioritet(integer, text)
-- Pomeranje u listi kao get_aktivni_predmeti: posle swap-a renumeriše
-- sort_priority 0..N-1 za sve aktivne predmete (INSERT za redove koji još nemaju red).
-- Edge: prvi red + up / poslednji + down → nema suseda, no-op.
-- Edge: prazna lista aktivnih predmeta → no-op.
-- ----------------------------------------------------------------------------
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
      b.item_id,
      p.sort_priority AS sp,
      i.broj_predmeta AS bp
    FROM (
      SELECT DISTINCT wo.item_id::integer AS item_id
      FROM public.v_active_bigtehn_work_orders wo
      WHERE wo.item_id IS NOT NULL
    ) b
    INNER JOIN public.bigtehn_items_cache i ON i.id = b.item_id
    LEFT JOIN production.predmet_prioritet p ON p.predmet_item_id = b.item_id
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
    -- Prvi/poslednji red — nema suseda u tom smeru
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

COMMENT ON FUNCTION production.shift_predmet_prioritet(integer, text) IS
  'Admin: zamena mesta sa susedom u listi aktivnih predmeta (up/down), zatim renumeracija sort_priority.';

-- ----------------------------------------------------------------------------
-- GRANT (authenticated → RPC)
-- ----------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION production.get_aktivni_predmeti() TO authenticated;
GRANT EXECUTE ON FUNCTION production.get_podsklopovi_predmeta(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION production.set_predmet_prioritet(integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION production.shift_predmet_prioritet(integer, text) TO authenticated;

-- ----------------------------------------------------------------------------
-- SEKCIJA 7 — Public wrapperi (PostgREST)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_aktivni_predmeti()
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT production.get_aktivni_predmeti();
$$;

CREATE OR REPLACE FUNCTION public.get_podsklopovi_predmeta(p_item_id integer)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT production.get_podsklopovi_predmeta(p_item_id);
$$;

CREATE OR REPLACE FUNCTION public.set_predmet_prioritet(
  p_item_id integer,
  p_sort_priority integer
)
RETURNS void
LANGUAGE sql
VOLATILE
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT production.set_predmet_prioritet(p_item_id, p_sort_priority);
$$;

CREATE OR REPLACE FUNCTION public.shift_predmet_prioritet(
  p_item_id integer,
  p_direction text
)
RETURNS void
LANGUAGE sql
VOLATILE
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT production.shift_predmet_prioritet(p_item_id, p_direction);
$$;

GRANT EXECUTE ON FUNCTION public.get_aktivni_predmeti() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_podsklopovi_predmeta(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_predmet_prioritet(integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.shift_predmet_prioritet(integer, text) TO authenticated;

COMMENT ON FUNCTION public.get_aktivni_predmeti() IS 'Wrapper → production.get_aktivni_predmeti()';
COMMENT ON FUNCTION public.get_podsklopovi_predmeta(integer) IS 'Wrapper → production.get_podsklopovi_predmeta(integer)';
COMMENT ON FUNCTION public.set_predmet_prioritet(integer, integer) IS 'Wrapper → production.set_predmet_prioritet(integer, integer)';
COMMENT ON FUNCTION public.shift_predmet_prioritet(integer, text) IS 'Wrapper → production.shift_predmet_prioritet(integer, text)';

-- ----------------------------------------------------------------------------
-- SEKCIJA 8 — PostgREST schema reload
-- ----------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';

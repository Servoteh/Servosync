-- Pregled po lokacijama: samo BigTehn RN (bez rev_tools / drugih item_ref_table).

CREATE OR REPLACE FUNCTION public.loc_report_parts_by_locations(
  p_drawing_no text DEFAULT NULL,
  p_order_no text DEFAULT NULL,
  p_tp_no text DEFAULT NULL,
  p_project_search text DEFAULT NULL,
  p_location_id uuid DEFAULT NULL,
  p_location_q text DEFAULT NULL,
  p_sort text DEFAULT 'updated_at',
  p_desc boolean DEFAULT true,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $fn$
DECLARE
  v_lim int := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 500);
  v_off int := GREATEST(COALESCE(p_offset, 0), 0);
  v_sort text := lower(trim(COALESCE(p_sort, 'updated_at')));
  v_dir text := CASE WHEN COALESCE(p_desc, true) THEN 'DESC' ELSE 'ASC' END;
  res jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN '{"total":0,"rows":[]}'::jsonb;
  END IF;
  IF cardinality(public.loc_auth_roles()) = 0 THEN
    RETURN '{"total":0,"rows":[]}'::jsonb;
  END IF;

  IF v_sort NOT IN (
    'updated_at',
    'drawing_no',
    'order_no',
    'location_code',
    'qty_on_location',
    'customer_name',
    'project_code',
    'item_ref_id',
    'rok_izrade'
  ) THEN
    v_sort := 'updated_at';
  END IF;

  EXECUTE format(
    $q$
    WITH base_placements AS (
      SELECT
        pl.id AS placement_id,
        pl.location_id,
        loc.location_code,
        loc.name AS location_name,
        loc.path_cached AS location_path,
        loc.capacity_note AS shelf_note,
        pl.item_ref_table,
        pl.item_ref_id,
        pl.order_no,
        NULLIF(trim(pl.drawing_no), '') AS drawing_no,
        pl.quantity AS qty_on_location,
        pl.placement_status::text AS placement_status,
        pl.updated_at,
        lm.moved_at AS last_moved_at,
        NULLIF(trim(pl.order_no), '') AS ord_key,
        NULLIF(trim(pl.item_ref_id), '') AS tp_key
      FROM public.loc_item_placements pl
      INNER JOIN public.loc_locations loc ON loc.id = pl.location_id
      LEFT JOIN public.loc_location_movements lm ON lm.id = pl.last_movement_id
      WHERE pl.quantity > 0
        AND pl.item_ref_table = 'bigtehn_rn'
    ),
    ident_candidates AS (
      SELECT bp.placement_id, bp.ord_key AS ident_cand, 0 AS match_rank
      FROM base_placements bp
      WHERE bp.ord_key IS NOT NULL AND bp.tp_key IS NULL
      UNION ALL
      SELECT bp.placement_id, bp.ord_key || '/' || bp.tp_key, 0
      FROM base_placements bp
      WHERE bp.ord_key IS NOT NULL AND bp.tp_key IS NOT NULL
      UNION ALL
      SELECT bp.placement_id, bp.ord_key || '-' || bp.tp_key, 0
      FROM base_placements bp
      WHERE bp.ord_key = '9400' AND bp.tp_key ~ '^[0-9]+/[0-9]+$'
      UNION ALL
      SELECT bp.placement_id, bp.ord_key || bp.tp_key, 0
      FROM base_placements bp
      WHERE bp.tp_key ~ '^-[0-9]+/[0-9]+$'
    ),
    exact_wo AS (
      SELECT DISTINCT ON (c.placement_id)
        c.placement_id,
        w.id,
        w.ident_broj,
        w.broj_crteza,
        w.naziv_dela,
        w.materijal,
        w.dimenzija_materijala,
        w.jedinica_mere,
        w.komada,
        w.tezina_neobr,
        w.tezina_obr,
        w.status_rn,
        w.revizija,
        w.rok_izrade,
        w.customer_id
      FROM ident_candidates c
      INNER JOIN public.bigtehn_work_orders_cache w ON w.ident_broj = c.ident_cand
      ORDER BY c.placement_id, c.match_rank, length(w.ident_broj), w.id
    ),
    need_fuzzy AS (
      SELECT bp.*
      FROM base_placements bp
      LEFT JOIN exact_wo e ON e.placement_id = bp.placement_id
      WHERE e.id IS NULL
        AND bp.ord_key IS NOT NULL
        AND bp.tp_key IS NOT NULL
    ),
    wo_parsed AS (
      SELECT
        w.id,
        w.ident_broj,
        w.broj_crteza,
        w.naziv_dela,
        w.materijal,
        w.dimenzija_materijala,
        w.jedinica_mere,
        w.komada,
        w.tezina_neobr,
        w.tezina_obr,
        w.status_rn,
        w.revizija,
        w.rok_izrade,
        w.customer_id,
        split_part(w.ident_broj, '/', 2) AS tp_part,
        split_part(split_part(w.ident_broj, '/', 1), '-', 1) AS ord_root
      FROM public.bigtehn_work_orders_cache w
      WHERE position('/' IN w.ident_broj) > 0
    ),
    fuzzy_ranked AS (
      SELECT
        nf.placement_id,
        wp.id,
        wp.ident_broj,
        wp.broj_crteza,
        wp.naziv_dela,
        wp.materijal,
        wp.dimenzija_materijala,
        wp.jedinica_mere,
        wp.komada,
        wp.tezina_neobr,
        wp.tezina_obr,
        wp.status_rn,
        wp.revizija,
        wp.rok_izrade,
        wp.customer_id,
        COUNT(*) OVER (PARTITION BY nf.placement_id) AS match_cnt,
        ROW_NUMBER() OVER (
          PARTITION BY nf.placement_id
          ORDER BY length(wp.ident_broj), wp.id
        ) AS pick_rn
      FROM need_fuzzy nf
      INNER JOIN wo_parsed wp
        ON wp.tp_part = nf.tp_key AND wp.ord_root = nf.ord_key
      WHERE NOT EXISTS (
        SELECT 1
        FROM public.bigtehn_work_orders_cache e
        WHERE e.ident_broj = nf.ord_key || '/' || nf.tp_key
           OR (
             nf.ord_key = '9400'
             AND nf.tp_key ~ '^[0-9]+/[0-9]+$'
             AND e.ident_broj = nf.ord_key || '-' || nf.tp_key
           )
           OR (
             nf.tp_key ~ '^-[0-9]+/[0-9]+$'
             AND e.ident_broj = nf.ord_key || nf.tp_key
           )
      )
    ),
    fuzzy_wo AS (
      SELECT
        placement_id,
        id,
        ident_broj,
        broj_crteza,
        naziv_dela,
        materijal,
        dimenzija_materijala,
        jedinica_mere,
        komada,
        tezina_neobr,
        tezina_obr,
        status_rn,
        revizija,
        rok_izrade,
        customer_id
      FROM fuzzy_ranked
      WHERE match_cnt = 1 AND pick_rn = 1
    ),
    wo_match AS (
      SELECT * FROM exact_wo
      UNION ALL
      SELECT * FROM fuzzy_wo
    ),
    placed AS (
      SELECT
        bp.placement_id,
        bp.location_id,
        bp.location_code,
        bp.location_name,
        bp.location_path,
        bp.shelf_note,
        bp.item_ref_table,
        bp.item_ref_id,
        bp.order_no,
        bp.drawing_no,
        bp.qty_on_location,
        bp.placement_status,
        bp.updated_at,
        bp.last_moved_at,
        wo.id AS work_order_id,
        wo.ident_broj AS wo_ident_broj,
        wo.broj_crteza AS wo_broj_crteza,
        wo.naziv_dela AS naziv_dela,
        wo.materijal AS materijal,
        wo.dimenzija_materijala AS dimenzija_materijala,
        wo.jedinica_mere AS jedinica_mere,
        wo.komada AS komada_rn,
        wo.tezina_neobr AS tezina_neobr,
        wo.tezina_obr AS tezina_obr,
        wo.status_rn AS status_rn,
        wo.revizija AS revizija,
        wo.rok_izrade AS rok_izrade,
        c.name AS customer_name,
        pr.project_code,
        pr.project_name,
        SUM(bp.qty_on_location) OVER (
          PARTITION BY bp.order_no,
            COALESCE(bp.drawing_no, NULLIF(trim(bp.item_ref_id), ''), '')
        ) AS qty_total_for_bucket
      FROM base_placements bp
      LEFT JOIN wo_match wo ON wo.placement_id = bp.placement_id
      LEFT JOIN public.bigtehn_customers_cache c ON c.id = wo.customer_id
      LEFT JOIN public.projekt_bigtehn_rn pbr
        ON wo.id IS NOT NULL AND pbr.bigtehn_rn_id = wo.id
      LEFT JOIN public.projects pr ON pr.id = pbr.projekat_id
    ),
    filt AS (
      SELECT * FROM placed p
      WHERE ($1 IS NULL OR trim($1) = '' OR COALESCE(p.drawing_no::text, '') ILIKE '%%' || trim($1) || '%%'
            OR p.item_ref_id ILIKE '%%' || trim($1) || '%%'
            OR COALESCE(p.wo_broj_crteza, '') ILIKE '%%' || trim($1) || '%%')
        AND ($2 IS NULL OR trim($2) = '' OR trim(COALESCE(p.order_no, '')) = trim($2)
            OR COALESCE(p.wo_ident_broj, '') ILIKE '%%' || trim($2) || '%%')
        AND ($3 IS NULL OR trim($3) = '' OR trim(COALESCE(p.item_ref_id, '')) = trim($3))
        AND ($4::uuid IS NULL OR p.location_id = $4::uuid)
        AND ($5 IS NULL OR trim($5) = '' OR p.location_code ILIKE '%%' || trim($5) || '%%'
            OR p.location_name ILIKE '%%' || trim($5) || '%%')
        AND ($6 IS NULL OR trim($6) = '' OR COALESCE(p.project_code, '') ILIKE '%%' || trim($6) || '%%'
            OR COALESCE(p.project_name, '') ILIKE '%%' || trim($6) || '%%')
    )
    SELECT jsonb_build_object(
      'total', (SELECT COUNT(*)::bigint FROM filt),
      'rows', COALESCE((
        SELECT jsonb_agg(to_jsonb(t))
        FROM (
          SELECT * FROM filt
          ORDER BY %I %s NULLS LAST, placement_id ASC
          LIMIT %s OFFSET %s
        ) t
      ), '[]'::jsonb)
    )
    $q$,
    v_sort,
    v_dir,
    v_lim,
    v_off
  )
  INTO res
  USING
    p_drawing_no,
    p_order_no,
    p_tp_no,
    p_location_id,
    p_location_q,
    p_project_search;

  RETURN COALESCE(res, '{"total":0,"rows":[]}'::jsonb);
END;
$fn$;

COMMENT ON FUNCTION public.loc_report_parts_by_locations IS
  'Lokacije: pregled smeštaja samo za bigtehn_rn (bez rev_tools). Batch join na cache.';

NOTIFY pgrst, 'reload schema';

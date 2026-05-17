-- ============================================================================
-- LOKACIJE — Pregled po lokacijama: BigTehn join za varijante ident_broj
-- ============================================================================
-- Problem: placement često ima order_no=9400, item_ref_id=415 dok je u cache-u
-- ident_broj npr. 9400-2/415 — stari uslov ne matchuje pa work_order_id NULL i
-- filt isključuje ceo red (stavke tab i dalje vidi lokaciju).
-- Rešenje:
--   1) JOIN na bigtehn_work_orders_cache (ne samo MES aktivni subset).
--   2) Prvo TAČNO: ident_broj = order_no [+ '/' item_ref kao do sada].
--   3) „Sufiks” (9400 × 9400-2) SAMO ako nema tačnog ident_broj reda za taj par
--      I tačno jedan RN u cache-u odgovara (koren pre prvog "-" levo od '/') + TP —
--      inače se ne pogoduje (mogući različiti RN-ovi; operater unosi tačan nalog).
--   4) Ukloni stari filt „mora RN join ako postoji order_no” — lokacija ostaje.
-- ============================================================================

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
    WITH placed AS (
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
        SUM(pl.quantity) OVER (
          PARTITION BY pl.order_no,
            COALESCE(NULLIF(trim(pl.drawing_no), ''), NULLIF(trim(pl.item_ref_id), ''), '')
        ) AS qty_total_for_bucket
      FROM public.loc_item_placements pl
      INNER JOIN public.loc_locations loc ON loc.id = pl.location_id
      LEFT JOIN public.loc_location_movements lm ON lm.id = pl.last_movement_id
      LEFT JOIN LATERAL (
        SELECT x.*
        FROM (
          SELECT w.*, 0 AS match_rank
          FROM public.bigtehn_work_orders_cache w
          WHERE trim(COALESCE(pl.order_no, '')) <> ''
            AND (
              (
                NULLIF(trim(COALESCE(pl.item_ref_id, '')), '') IS NULL
                AND trim(w.ident_broj) = trim(pl.order_no)
              )
              OR (
                NULLIF(trim(COALESCE(pl.item_ref_id, '')), '') IS NOT NULL
                AND trim(w.ident_broj) = trim(pl.order_no) || '/' || trim(pl.item_ref_id)
              )
            )
          UNION ALL
          SELECT w.*, 1 AS match_rank
          FROM public.bigtehn_work_orders_cache w
          WHERE trim(COALESCE(pl.order_no, '')) <> ''
            AND NULLIF(trim(COALESCE(pl.item_ref_id, '')), '') IS NOT NULL
            AND NOT EXISTS (
              SELECT 1 FROM public.bigtehn_work_orders_cache e
              WHERE trim(e.ident_broj) =
                trim(pl.order_no) || '/' || trim(COALESCE(pl.item_ref_id, ''))
            )
            AND position('/' IN trim(w.ident_broj)) > 0
            AND trim(split_part(trim(w.ident_broj), '/', 2)) = trim(pl.item_ref_id)
            AND trim(split_part(split_part(trim(w.ident_broj), '/', 1), '-', 1)) = trim(pl.order_no)
            AND (
              SELECT COUNT(*) FROM public.bigtehn_work_orders_cache c
              WHERE position('/' IN trim(c.ident_broj)) > 0
                AND trim(split_part(trim(c.ident_broj), '/', 2)) = trim(pl.item_ref_id)
                AND trim(split_part(split_part(trim(c.ident_broj), '/', 1), '-', 1)) = trim(pl.order_no)
            ) = 1
        ) x
        ORDER BY x.match_rank, length(trim(x.ident_broj)), x.id
        LIMIT 1
      ) wo ON TRUE
      LEFT JOIN public.bigtehn_customers_cache c ON c.id = wo.customer_id
      LEFT JOIN public.projekt_bigtehn_rn pbr
        ON wo.id IS NOT NULL AND pbr.bigtehn_rn_id = wo.id
      LEFT JOIN public.projects pr ON pr.id = pbr.projekat_id
      WHERE pl.quantity > 0
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
  'Lokacije v2: pregled placement-a + BigTehn meta iz cache-a. Preferira tačno '
  'poklapanje ident_broj; opušteno ROOT/TP poklapanje SAMO ako nema tačnog RN reda '
  'i ostaje jedinstven kandidat (izbegnuto nesvesno mergovanje paralelnih RN). '
  'Bez filtera samo-MES aktivnih RN; lokaciona polja uvek.';

REVOKE ALL ON FUNCTION public.loc_report_parts_by_locations(
  text, text, text, text, uuid, text, text, boolean, int, int
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.loc_report_parts_by_locations(
  text, text, text, text, uuid, text, text, boolean, int, int
) FROM anon;
GRANT EXECUTE ON FUNCTION public.loc_report_parts_by_locations(
  text, text, text, text, uuid, text, text, boolean, int, int
) TO authenticated;

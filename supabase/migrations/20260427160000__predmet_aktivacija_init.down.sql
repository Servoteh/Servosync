-- Rollback: 20260427160000__predmet_aktivacija_init
-- NAPOMENA: DROP production.pracenje_oznaceni_predmeti u UP brisao je podatke
-- ručno obeleženih predmeta. DOWN rekreira praznu tabelu; prioriteti i
-- obeležavanje moraju se ručno ponovo uskladiti.
-- v_production_operations vraćamo na verziju BEZ item_id (G7, kao pre UP).

-- Public wrapperi
DROP FUNCTION IF EXISTS public.set_predmet_aktivacija(integer, boolean, text);
DROP FUNCTION IF EXISTS public.list_predmet_aktivacija_admin();

-- Novi view
DROP VIEW IF EXISTS public.v_production_operations_effective;

-- Trigger
DROP TRIGGER IF EXISTS tr_predmet_aktivacija_after_item_cache_ins ON public.bigtehn_items_cache;
DROP FUNCTION IF EXISTS production.tg_predmet_aktivacija_default();

-- RPC (novi)
DROP FUNCTION IF EXISTS production.set_predmet_aktivacija(integer, boolean, text);
DROP FUNCTION IF EXISTS production.list_predmet_aktivacija_admin();

-- Helper
DROP FUNCTION IF EXISTS public.can_manage_predmet_aktivacija();

-- Tabela aktivacije
DROP TABLE IF EXISTS production.predmet_aktivacija;

-- v_production_operations: restore bez item_id
CREATE OR REPLACE VIEW public.v_production_operations
WITH (security_invoker = true) AS
SELECT
  l.id                                                  AS line_id,
  l.work_order_id                                       AS work_order_id,
  l.operacija                                           AS operacija,
  l.opis_rada                                           AS opis_rada,
  l.alat_pribor                                         AS alat_pribor,
  l.machine_code                                        AS original_machine_code,
  COALESCE(o.assigned_machine_code, l.machine_code)     AS effective_machine_code,
  l.tpz                                                 AS tpz_min,
  l.tk                                                  AS tk_min,
  l.prioritet                                           AS prioritet_bigtehn,

  wo.ident_broj                                         AS rn_ident_broj,
  wo.broj_crteza                                        AS broj_crteza,
  wo.naziv_dela                                         AS naziv_dela,
  wo.materijal                                          AS materijal,
  wo.dimenzija_materijala                               AS dimenzija_materijala,
  wo.komada                                             AS komada_total,
  wo.rok_izrade                                         AS rok_izrade,
  wo.status_rn                                          AS rn_zavrsen,
  wo.zakljucano                                         AS rn_zakljucano,
  wo.napomena                                           AS rn_napomena,

  c.id                                                  AS customer_id,
  c.name                                                AS customer_name,
  c.short_name                                          AS customer_short,

  m.name                                                AS original_machine_name,
  COALESCE(m.no_procedure, FALSE)                       AS is_non_machining,

  o.id                                                  AS overlay_id,
  o.shift_sort_order                                    AS shift_sort_order,
  o.local_status                                        AS local_status,
  o.shift_note                                          AS shift_note,
  o.assigned_machine_code                               AS assigned_machine_code,
  o.archived_at                                         AS overlay_archived_at,
  o.archived_reason                                     AS overlay_archived_reason,
  o.updated_at                                          AS overlay_updated_at,
  o.updated_by                                          AS overlay_updated_by,
  o.created_at                                          AS overlay_created_at,
  o.created_by                                          AS overlay_created_by,

  COALESCE(tr.komada_done, 0)                           AS komada_done,
  COALESCE(tr.real_seconds, 0)                          AS real_seconds,
  COALESCE(tr.is_done, FALSE)                           AS is_done_in_bigtehn,
  tr.last_finished_at                                   AS last_finished_at,
  tr.prijava_count                                      AS prijava_count,

  COALESCE(d.drawings_count, 0)                         AS drawings_count,

  (bd.drawing_no IS NOT NULL)                           AS has_bigtehn_drawing,
  bd.storage_path                                       AS bigtehn_drawing_path,
  bd.size_bytes                                         AS bigtehn_drawing_size,

  wo.is_mes_active                                      AS is_mes_active,

  COALESCE(o.cam_ready, FALSE)                          AS cam_ready,
  o.cam_ready_at                                        AS cam_ready_at,
  o.cam_ready_by                                        AS cam_ready_by,

  m.rj_code                                             AS rj_group_code,
  m.name                                                AS rj_group_label,
  COALESCE(o.cooperation_status, 'none')                AS cooperation_status,
  o.cooperation_partner                                 AS cooperation_partner,
  o.cooperation_set_by                                  AS cooperation_set_by,
  o.cooperation_set_at                                  AS cooperation_set_at,
  o.cooperation_expected_return                         AS cooperation_expected_return,
  (g.rj_group_code IS NOT NULL)                         AS is_cooperation_auto,
  (COALESCE(o.cooperation_status, 'none') <> 'none')    AS is_cooperation_manual,
  (
    g.rj_group_code IS NOT NULL
    OR COALESCE(o.cooperation_status, 'none') <> 'none'
  )                                                     AS is_cooperation_effective,
  CASE
    WHEN g.rj_group_code IS NOT NULL
     AND COALESCE(o.cooperation_status, 'none') <> 'none' THEN 'auto+manual'
    WHEN g.rj_group_code IS NOT NULL THEN 'auto'
    WHEN COALESCE(o.cooperation_status, 'none') <> 'none' THEN 'manual'
    ELSE 'none'
  END                                                   AS cooperation_source

FROM public.bigtehn_work_order_lines_cache l
INNER JOIN public.v_active_bigtehn_work_orders wo
  ON wo.id = l.work_order_id
 AND wo.is_mes_active IS TRUE
LEFT JOIN public.bigtehn_customers_cache    c
  ON c.id = wo.customer_id
LEFT JOIN public.bigtehn_machines_cache     m
  ON m.rj_code = l.machine_code
LEFT JOIN public.production_auto_cooperation_groups g
  ON g.rj_group_code = m.rj_code
 AND g.removed_at IS NULL
LEFT JOIN public.production_overlays        o
  ON o.work_order_id = l.work_order_id
 AND o.line_id       = l.id
LEFT JOIN LATERAL (
  SELECT
    SUM(t.komada)                AS komada_done,
    SUM(t.prn_timer_seconds)     AS real_seconds,
    BOOL_OR(t.is_completed)      AS is_done,
    MAX(t.finished_at)           AS last_finished_at,
    COUNT(*)                     AS prijava_count
  FROM public.bigtehn_tech_routing_cache t
  WHERE t.work_order_id = l.work_order_id
    AND t.operacija     = l.operacija
) tr ON TRUE
LEFT JOIN LATERAL (
  SELECT COUNT(*) AS drawings_count
  FROM public.production_drawings pd
  WHERE pd.work_order_id = l.work_order_id
    AND pd.line_id       = l.id
    AND pd.deleted_at IS NULL
) d ON TRUE
LEFT JOIN public.bigtehn_drawings_cache    bd
  ON bd.drawing_no = wo.broj_crteza
 AND bd.removed_at IS NULL;

-- Kopija get_aktivni_predmeti + set + shift KAO u 20260426220000 (whitelist), sa praznom whitelist
DROP TABLE IF EXISTS production.pracenje_oznaceni_predmeti CASCADE;
CREATE TABLE production.pracenje_oznaceni_predmeti (
  predmet_item_id integer PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES auth.users (id)
);
ALTER TABLE production.pracenje_oznaceni_predmeti ENABLE ROW LEVEL SECURITY;
CREATE POLICY pracenje_oznaceni_select_authenticated
  ON production.pracenje_oznaceni_predmeti FOR SELECT
  TO authenticated
  USING (true);
CREATE POLICY pracenje_oznaceni_insert_admin
  ON production.pracenje_oznaceni_predmeti FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_is_admin());
CREATE POLICY pracenje_oznaceni_delete_admin
  ON production.pracenje_oznaceni_predmeti FOR DELETE
  TO authenticated
  USING (public.current_user_is_admin());
GRANT SELECT, INSERT, DELETE ON production.pracenje_oznaceni_predmeti TO authenticated;

CREATE OR REPLACE FUNCTION production.get_aktivni_predmeti()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
  WITH base AS (
    SELECT o.predmet_item_id::integer AS item_id
    FROM production.pracenje_oznaceni_predmeti o
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
  IF NOT EXISTS (
    SELECT 1 FROM production.pracenje_oznaceni_predmeti w WHERE w.predmet_item_id = p_item_id
  ) THEN
    RAISE EXCEPTION 'predmet nije u listi obeleženih za praćenje' USING ERRCODE = '23514';
  END IF;
  INSERT INTO production.predmet_prioritet (predmet_item_id, sort_priority, updated_by, updated_at)
  VALUES (p_item_id, p_sort_priority, auth.uid(), now())
  ON CONFLICT (predmet_item_id) DO UPDATE SET
    sort_priority = EXCLUDED.sort_priority,
    updated_by = auth.uid(),
    updated_at = now();
END;
$$;

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
      SELECT o.predmet_item_id::integer AS item_id
      FROM production.pracenje_oznaceni_predmeti o
    ) b
    INNER JOIN public.bigtehn_items_cache i ON i.id = b.item_id
    LEFT JOIN production.predmet_prioritet p ON p.predmet_item_id = b.item_id
  ) sub;
  n := coalesce(array_length(items, 1), 0);
  IF n = 0 THEN RETURN; END IF;
  pos := array_position(items, p_item_id);
  IF pos IS NULL THEN RETURN; END IF;
  neighbor_pos := pos + CASE WHEN dir = 'up' THEN -1 ELSE 1 END;
  IF neighbor_pos < 1 OR neighbor_pos > n THEN RETURN; END IF;
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

CREATE OR REPLACE FUNCTION production.pracenje_oznaci_predmet(p_item_id integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
BEGIN
  IF NOT public.current_user_is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF p_item_id IS NULL OR p_item_id <= 0 THEN
    RAISE EXCEPTION 'invalid p_item_id' USING ERRCODE = '22000';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.bigtehn_items_cache i WHERE i.id = p_item_id) THEN
    RAISE EXCEPTION 'nepoznat predmet (nema u bigtehn_items_cache)' USING ERRCODE = '22000';
  END IF;
  INSERT INTO production.pracenje_oznaceni_predmeti (predmet_item_id, created_by, created_at)
  VALUES (p_item_id, auth.uid(), now())
  ON CONFLICT (predmet_item_id) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION production.pracenje_ukloni_oznaku(p_item_id integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
BEGIN
  IF NOT public.current_user_is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF p_item_id IS NULL OR p_item_id <= 0 THEN
    RAISE EXCEPTION 'invalid p_item_id' USING ERRCODE = '22000';
  END IF;
  DELETE FROM production.predmet_prioritet WHERE predmet_item_id = p_item_id;
  DELETE FROM production.pracenje_oznaceni_predmeti WHERE predmet_item_id = p_item_id;
END;
$$;

GRANT EXECUTE ON FUNCTION production.pracenje_oznaci_predmet(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION production.pracenje_ukloni_oznaku(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.pracenje_oznaci_predmet(p_item_id integer)
RETURNS void
LANGUAGE sql
VOLATILE
SET search_path TO 'public', 'pg_temp'
AS $$ SELECT production.pracenje_oznaci_predmet(p_item_id); $$;
CREATE OR REPLACE FUNCTION public.pracenje_ukloni_oznaku(p_item_id integer)
RETURNS void
LANGUAGE sql
VOLATILE
SET search_path TO 'public', 'pg_temp'
AS $$ SELECT production.pracenje_ukloni_oznaku(p_item_id); $$;
GRANT EXECUTE ON FUNCTION public.pracenje_oznaci_predmet(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pracenje_ukloni_oznaku(integer) TO authenticated;

NOTIFY pgrst, 'reload schema';

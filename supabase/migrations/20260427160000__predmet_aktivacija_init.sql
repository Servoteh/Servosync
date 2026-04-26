-- =============================================================================
-- Predmet aktivacija — jedan izvor istine za vidljivost predmeta u
-- Plan proizvodnje (v_production_operations_effective) i Praćenje (get_aktivni_predmeti).
-- Backfill „aktivni skup B”: item_id u v_active_bigtehn_work_orders (pogledaj
-- docs/migration/07-predmet-aktivacija.md). Zamenjuje pracenje_oznaceni_predmeti.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- SEKCIJA 0 — can_manage: admin (current_user_is_admin) ILI global menadzment u user_roles
-- Lista uloga za proširenje: role = 'menadzment' (ne pm / leadpm).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.can_manage_predmet_aktivacija()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    public.current_user_is_admin()
    OR EXISTS (
      SELECT 1
      FROM public.user_roles ur
      WHERE LOWER(ur.email) = LOWER(COALESCE((auth.jwt() ->> 'email'), ''))
        AND COALESCE(ur.is_active, true) IS TRUE
        AND ur.role = 'menadzment'
    );
$$;

REVOKE ALL ON FUNCTION public.can_manage_predmet_aktivacija() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_manage_predmet_aktivacija() TO authenticated;
COMMENT ON FUNCTION public.can_manage_predmet_aktivacija() IS
  'Admin ili globalni menadžment: upravljanje production.predmet_aktivacija i RPC list/set.';

-- ---------------------------------------------------------------------------
-- SEKCIJA 1 — Tabela production.predmet_aktivacija
-- Bez FK ka bigtehn_items_cache: cache se re-sync-uje van FK konstraint-a.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS production.predmet_aktivacija (
  predmet_item_id integer PRIMARY KEY,
  je_aktivan      boolean NOT NULL DEFAULT true,
  napomena        text,
  azurirao_user_id uuid REFERENCES auth.users (id),
  azurirano_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS predmet_aktivacija_je_aktivan_idx
  ON production.predmet_aktivacija (je_aktivan);

COMMENT ON TABLE production.predmet_aktivacija IS
  'Jedan red po predmetu (bigtehn_items_cache.id). Vidljivost u Plan + Praćenje: je_aktivan.';
COMMENT ON COLUMN production.predmet_aktivacija.predmet_item_id IS
  'ID predmeta; namerno bez FK ka bigtehn_items_cache (re-sync / brisanje u cache-u).';
COMMENT ON COLUMN production.predmet_aktivacija.azurirao_user_id IS
  'NULL = sistemski upis (npr. trigger nakon insert u cache).';

-- ---------------------------------------------------------------------------
-- SEKCIJA 3 — RLS
-- ---------------------------------------------------------------------------
ALTER TABLE production.predmet_aktivacija ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS predmet_aktivacija_select_auth ON production.predmet_aktivacija;
CREATE POLICY predmet_aktivacija_select_auth
  ON production.predmet_aktivacija FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS predmet_aktivacija_insert_managers ON production.predmet_aktivacija;
CREATE POLICY predmet_aktivacija_insert_managers
  ON production.predmet_aktivacija FOR INSERT
  TO authenticated
  WITH CHECK (public.can_manage_predmet_aktivacija());

DROP POLICY IF EXISTS predmet_aktivacija_update_managers ON production.predmet_aktivacija;
CREATE POLICY predmet_aktivacija_update_managers
  ON production.predmet_aktivacija FOR UPDATE
  TO authenticated
  USING (public.can_manage_predmet_aktivacija())
  WITH CHECK (public.can_manage_predmet_aktivacija());

DROP POLICY IF EXISTS predmet_aktivacija_delete_managers ON production.predmet_aktivacija;
CREATE POLICY predmet_aktivacija_delete_managers
  ON production.predmet_aktivacija FOR DELETE
  TO authenticated
  USING (public.can_manage_predmet_aktivacija());

GRANT SELECT, INSERT, UPDATE, DELETE ON production.predmet_aktivacija TO authenticated;

-- ---------------------------------------------------------------------------
-- SEKCIJA 6a — v_production_operations: dodata kolona item_id (za join sa aktivacijom)
-- (Kopirano iz add_production_cooperation_g7.sql + wo.item_id::integer)
-- ---------------------------------------------------------------------------
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
  wo.item_id::integer                                   AS item_id,

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

COMMENT ON VIEW public.v_production_operations IS
  'Denormalizovan pregled operacija za Planiranje proizvodnje; uključuje item_id predmeta.';

-- ---------------------------------------------------------------------------
-- SEKCIJA 6b — v_production_operations_effective (samo aktivirani predmeti)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_production_operations_effective
WITH (security_invoker = true) AS
SELECT ops.*
FROM public.v_production_operations ops
WHERE EXISTS (
  SELECT 1
  FROM production.predmet_aktivacija pa
  WHERE pa.predmet_item_id = ops.item_id
    AND pa.je_aktivan IS TRUE
);

COMMENT ON VIEW public.v_production_operations_effective IS
  'Isto kao v_production_operations, filtrirano na production.predmet_aktivacija.je_aktivan.';

GRANT SELECT ON public.v_production_operations_effective TO authenticated;
REVOKE SELECT ON public.v_production_operations_effective FROM anon;

-- ---------------------------------------------------------------------------
-- SEKCIJA 4 — Trigger: novi red u bigtehn_items_cache → default aktivacija
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION production.tg_predmet_aktivacija_default()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
BEGIN
  INSERT INTO production.predmet_aktivacija (predmet_item_id, je_aktivan, azurirao_user_id, azurirano_at)
  VALUES (NEW.id, true, NULL, now())
  ON CONFLICT (predmet_item_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_predmet_aktivacija_after_item_cache_ins ON public.bigtehn_items_cache;
CREATE TRIGGER tr_predmet_aktivacija_after_item_cache_ins
  AFTER INSERT ON public.bigtehn_items_cache
  FOR EACH ROW
  EXECUTE PROCEDURE production.tg_predmet_aktivacija_default();

COMMENT ON FUNCTION production.tg_predmet_aktivacija_default() IS
  'Novi predmet u cache-u dobija red u predmet_aktivacija (je_aktivan=true) ako već nema reda.';

-- ---------------------------------------------------------------------------
-- SEKCIJA 5 — Backfill (skup B = v_active; ostalo false) + prioritet starih oznaka
-- ---------------------------------------------------------------------------
INSERT INTO production.predmet_aktivacija (predmet_item_id, je_aktivan, azurirao_user_id, azurirano_at)
SELECT
  i.id,
  EXISTS (
    SELECT 1
    FROM public.v_active_bigtehn_work_orders w
    WHERE w.item_id = i.id
      AND w.item_id IS NOT NULL
  ) AS je_aktivan,
  NULL,
  now()
FROM public.bigtehn_items_cache i
ON CONFLICT (predmet_item_id) DO NOTHING;

DO $blk$
BEGIN
  IF to_regclass('production.pracenje_oznaceni_predmeti') IS NOT NULL THEN
    UPDATE production.predmet_aktivacija p
    SET
      je_aktivan = true,
      azurirano_at = now()
    FROM production.pracenje_oznaceni_predmeti o
    WHERE p.predmet_item_id = o.predmet_item_id;
  END IF;
END
$blk$;

-- ---------------------------------------------------------------------------
-- SEKCIJA 9 — get_aktivni_predmeti: baza = v_active ∩ predmet_aktivacija
-- ---------------------------------------------------------------------------
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
  filtered AS (
    SELECT b.item_id
    FROM base b
    INNER JOIN production.predmet_aktivacija pa
      ON pa.predmet_item_id = b.item_id
     AND pa.je_aktivan IS TRUE
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
  'Aktivni predmeti: distinct item_id iz v_active_bigtehn_work_orders sa je_aktivan; sort: prioritet, broj predmeta.';

-- ---------------------------------------------------------------------------
-- set_predmet_prioritet + shift: moraju da prate predmet_aktivacija (ne staru tabelu)
-- ---------------------------------------------------------------------------
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
    SELECT 1
    FROM production.predmet_aktivacija pa
    WHERE pa.predmet_item_id = p_item_id
      AND pa.je_aktivan IS TRUE
  ) THEN
    RAISE EXCEPTION 'predmet nije u aktiviranom skupu za praćenje' USING ERRCODE = '23514';
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
      v.item_id,
      p.sort_priority AS sp,
      i.broj_predmeta AS bp
    FROM (
      SELECT DISTINCT w.item_id::integer AS item_id
      FROM public.v_active_bigtehn_work_orders w
      WHERE w.item_id IS NOT NULL
    ) v
    INNER JOIN production.predmet_aktivacija pa
      ON pa.predmet_item_id = v.item_id
     AND pa.je_aktivan IS TRUE
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

-- ---------------------------------------------------------------------------
-- SEKCIJA 7–8 — list / set (admin or menadžment)
-- ---------------------------------------------------------------------------
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

CREATE OR REPLACE FUNCTION production.set_predmet_aktivacija(
  p_item_id integer,
  p_aktivan boolean,
  p_napomena text DEFAULT NULL
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

  INSERT INTO production.predmet_aktivacija (predmet_item_id, je_aktivan, napomena, azurirao_user_id, azurirano_at)
  VALUES (p_item_id, p_aktivan, p_napomena, auth.uid(), now())
  ON CONFLICT (predmet_item_id) DO UPDATE SET
    je_aktivan = EXCLUDED.je_aktivan,
    napomena = CASE
      WHEN p_napomena IS NULL THEN predmet_aktivacija.napomena
      ELSE EXCLUDED.napomena
    END,
    azurirao_user_id = auth.uid(),
    azurirano_at = now();
END;
$$;

GRANT EXECUTE ON FUNCTION production.list_predmet_aktivacija_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION production.set_predmet_aktivacija(integer, boolean, text) TO authenticated;

COMMENT ON FUNCTION production.list_predmet_aktivacija_admin() IS
  'Svi predmeti iz bigtehn_items_cache + activation; admin ili menadžment.';
COMMENT ON FUNCTION production.set_predmet_aktivacija(integer, boolean, text) IS
  'Upsert predmet_aktivacija; p_napomena NULL = ne menja postojeću napomenu.';

-- ---------------------------------------------------------------------------
-- SEKCIJA 10 — Uklanjanje pracenje_oznaceni_predmeti (zamenjeno predmet_aktivacija)
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.pracenje_ukloni_oznaku(integer);
DROP FUNCTION IF EXISTS public.pracenje_oznaci_predmet(integer);
DROP FUNCTION IF EXISTS production.pracenje_ukloni_oznaku(integer);
DROP FUNCTION IF EXISTS production.pracenje_oznaci_predmet(integer);

DROP TABLE IF EXISTS production.pracenje_oznaceni_predmeti;

-- ---------------------------------------------------------------------------
-- SEKCIJA 11 — Public wrapperi
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_predmet_aktivacija_admin()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
  SELECT production.list_predmet_aktivacija_admin();
$$;

CREATE OR REPLACE FUNCTION public.set_predmet_aktivacija(
  p_item_id integer,
  p_aktivan boolean,
  p_napomena text DEFAULT NULL
)
RETURNS void
LANGUAGE sql
VOLATILE
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
  SELECT production.set_predmet_aktivacija(p_item_id, p_aktivan, p_napomena);
$$;

REVOKE ALL ON FUNCTION public.list_predmet_aktivacija_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_predmet_aktivacija(integer, boolean, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_predmet_aktivacija_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_predmet_aktivacija(integer, boolean, text) TO authenticated;

COMMENT ON FUNCTION public.list_predmet_aktivacija_admin() IS 'Wrapper → production.list_predmet_aktivacija_admin()';
COMMENT ON FUNCTION public.set_predmet_aktivacija(integer, boolean, text) IS 'Wrapper → production.set_predmet_aktivacija(integer, boolean, text)';

-- ---------------------------------------------------------------------------
-- SEKCIJA 12
-- ---------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';

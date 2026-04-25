-- ============================================================================
-- PLAN PROIZVODNJE - G4B skart/dorada signal
-- ============================================================================
-- Pouzdan signal ne ide kroz opis operacije, vec kroz BigTehn kvalitet iz
-- tTehPostupak.IDVrstaKvaliteta: 1 = DORADA, 2 = SKART.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.bigtehn_rework_scrap_cache (
  id                  bigint PRIMARY KEY, -- tTehPostupak.IDPostupka
  work_order_id       bigint,
  item_id             bigint,
  ident_broj          text,
  varijanta           integer,
  operacija           integer,
  machine_code        text,
  worker_id           bigint,
  quality_type_id     integer NOT NULL CHECK (quality_type_id IN (1, 2)),
  pieces              numeric NOT NULL DEFAULT 0,
  prn_timer_seconds   integer,
  started_at          timestamptz,
  finished_at         timestamptz,
  is_completed        boolean NOT NULL DEFAULT false,
  dorada_operacije    integer,
  napomena            text,
  synced_at           timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.bigtehn_rework_scrap_cache ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "brsc_read_authenticated" ON public.bigtehn_rework_scrap_cache;
CREATE POLICY "brsc_read_authenticated"
  ON public.bigtehn_rework_scrap_cache FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "brsc_no_client_insert" ON public.bigtehn_rework_scrap_cache;
CREATE POLICY "brsc_no_client_insert"
  ON public.bigtehn_rework_scrap_cache FOR INSERT
  TO authenticated
  WITH CHECK (false);

DROP POLICY IF EXISTS "brsc_no_client_update" ON public.bigtehn_rework_scrap_cache;
CREATE POLICY "brsc_no_client_update"
  ON public.bigtehn_rework_scrap_cache FOR UPDATE
  TO authenticated
  USING (false)
  WITH CHECK (false);

DROP POLICY IF EXISTS "brsc_no_client_delete" ON public.bigtehn_rework_scrap_cache;
CREATE POLICY "brsc_no_client_delete"
  ON public.bigtehn_rework_scrap_cache FOR DELETE
  TO authenticated
  USING (false);

CREATE INDEX IF NOT EXISTS brsc_idx_work_order_operacija
  ON public.bigtehn_rework_scrap_cache (work_order_id, operacija);

CREATE INDEX IF NOT EXISTS brsc_idx_quality
  ON public.bigtehn_rework_scrap_cache (quality_type_id, synced_at DESC);

GRANT SELECT ON public.bigtehn_rework_scrap_cache TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.bigtehn_rework_scrap_cache TO service_role;

DO $$
BEGIN
  IF to_regclass('public.v_production_operations_pre_g4') IS NULL THEN
    ALTER VIEW public.v_production_operations RENAME TO v_production_operations_pre_g4;
  END IF;
END $$;

CREATE OR REPLACE VIEW public.v_production_operations
WITH (security_invoker = true) AS
SELECT
  v.*,
  COALESCE(g4.is_rework, false) AS is_rework,
  COALESCE(g4.is_scrap, false) AS is_scrap,
  COALESCE(g4.rework_pieces, 0) AS rework_pieces,
  COALESCE(g4.scrap_pieces, 0) AS scrap_pieces,
  COALESCE(g4.rework_scrap_count, 0) AS rework_scrap_count
FROM public.v_production_operations_pre_g4 v
LEFT JOIN LATERAL (
  SELECT
    BOOL_OR(c.quality_type_id = 1) AS is_rework,
    BOOL_OR(c.quality_type_id = 2) AS is_scrap,
    COALESCE(SUM(c.pieces) FILTER (WHERE c.quality_type_id = 1), 0) AS rework_pieces,
    COALESCE(SUM(c.pieces) FILTER (WHERE c.quality_type_id = 2), 0) AS scrap_pieces,
    COUNT(*) AS rework_scrap_count
  FROM public.bigtehn_rework_scrap_cache c
  WHERE c.work_order_id = v.work_order_id
    AND c.operacija = v.operacija
) g4 ON true;

GRANT SELECT ON public.v_production_operations TO authenticated;
REVOKE SELECT ON public.v_production_operations FROM anon;

COMMENT ON TABLE public.bigtehn_rework_scrap_cache IS
  'G4B BigTehn cache za pouzdan skart/dorada signal iz tTehPostupak.IDVrstaKvaliteta.';

COMMENT ON VIEW public.v_production_operations IS
  'Denormalizovan pregled operacija za Planiranje proizvodnje sa G4 skart/dorada, G2 spremnost/HITNO, G3 CAM i G7 kooperacija kolonama.';

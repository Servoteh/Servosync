-- ============================================================================
-- PLAN PROIZVODNJE — Sprint F.5a: BigTehn crteži (PDF) iz BigBit foldera
-- ============================================================================
-- Pokreni JEDNOM u Supabase SQL Editoru.
--
-- Šta radi:
--   1) Kreira tabelu `bigtehn_drawings_cache` — metapodaci o PDF crtežima
--      koje Bridge sinhronizuje iz Win folder-a `C:\PDMExport\PDFImportovano`
--      na BigBit virtualnom serveru.
--   2) Kreira Storage bucket `bigtehn-drawings` (privatan, samo PDF, max 50 MB).
--   3) RLS politike — svi authenticated mogu da čitaju (signed URL); Bridge
--      koristi service_role key za upload (bypass RLS).
--   4) Update view `v_production_operations` — dodaje:
--        - has_bigtehn_drawing      BOOLEAN
--        - bigtehn_drawing_path     TEXT (storage_path)
--      Join je po wo.broj_crteza = bd.drawing_no
--      (samo aktivni — removed_at IS NULL).
-- ============================================================================

-- 1) Tabela
CREATE TABLE IF NOT EXISTS public.bigtehn_drawings_cache (
  id              BIGSERIAL PRIMARY KEY,

  -- Naziv crteža = naziv fajla bez ekstenzije (npr. "12345" iz "12345.pdf").
  -- Mora biti unique jer je broj_crteza naš ključ za JOIN sa RN-om.
  drawing_no      TEXT NOT NULL UNIQUE,

  -- Storage path UNUTAR bucket-a (npr. "12345.pdf").
  -- Pri pristupu: storage.objects.bucket_id='bigtehn-drawings' AND name=storage_path.
  storage_path    TEXT NOT NULL,

  -- Originalni Win path za debug/log (npr. "C:\PDMExport\PDFImportovano\12345.pdf").
  original_path   TEXT,

  -- Metapodaci.
  file_name       TEXT NOT NULL,
  mime_type       TEXT,                          -- 'application/pdf'
  size_bytes      BIGINT,
  mtime           TIMESTAMPTZ NOT NULL,           -- file modified time iz Win-a (watermark)
  synced_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Soft-delete: kad je fajl obrisan iz Win foldera. UI filtrira removed_at IS NULL.
  removed_at      TIMESTAMPTZ
);

-- Index na drawing_no je već automatski preko UNIQUE.
-- Dodatni index na mtime za inkrementalni sync (ako nekada pivotiramo logiku).
CREATE INDEX IF NOT EXISTS bdc_idx_mtime
  ON public.bigtehn_drawings_cache (mtime DESC)
  WHERE removed_at IS NULL;

-- Brzi lookup samo aktivnih.
CREATE INDEX IF NOT EXISTS bdc_idx_active
  ON public.bigtehn_drawings_cache (drawing_no)
  WHERE removed_at IS NULL;

-- 2) Storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'bigtehn-drawings',
  'bigtehn-drawings',
  FALSE,                                        -- ne-javan, signed URL
  50 * 1024 * 1024,                             -- 50 MB max po PDF
  ARRAY['application/pdf']::text[]
)
ON CONFLICT (id) DO UPDATE
  SET file_size_limit    = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 3) RLS politike

-- 3a) Tabela bigtehn_drawings_cache
ALTER TABLE public.bigtehn_drawings_cache ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "bdc_read_authenticated" ON public.bigtehn_drawings_cache;
CREATE POLICY "bdc_read_authenticated"
  ON public.bigtehn_drawings_cache FOR SELECT
  TO authenticated
  USING (TRUE);

-- INSERT/UPDATE/DELETE namerno NEMA policy → frontend ne može da menja.
-- Bridge koristi service_role key koji bypass-uje RLS po definiciji.

-- 3b) Storage politike za bucket bigtehn-drawings
DROP POLICY IF EXISTS "bd_storage_read_authenticated" ON storage.objects;
CREATE POLICY "bd_storage_read_authenticated"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'bigtehn-drawings');

-- INSERT/UPDATE/DELETE: nema policy → samo service_role (Bridge) može da piše.

-- ============================================================================
-- 4) View update — dodaj has_bigtehn_drawing i bigtehn_drawing_path
-- ============================================================================
-- VAŽNO: ovo SAMO REPLACE-uje view; sva ostala kolona ostaje ista.
-- ============================================================================

CREATE OR REPLACE VIEW public.v_production_operations AS
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

  -- F.5a: BigTehn crtež (PDF iz BigBit foldera, sinhronizovano kroz Bridge)
  (bd.drawing_no IS NOT NULL)                           AS has_bigtehn_drawing,
  bd.storage_path                                       AS bigtehn_drawing_path,
  bd.size_bytes                                         AS bigtehn_drawing_size

FROM public.bigtehn_work_order_lines_cache l
LEFT JOIN public.bigtehn_work_orders_cache  wo
  ON wo.id = l.work_order_id
LEFT JOIN public.bigtehn_customers_cache    c
  ON c.id = wo.customer_id
LEFT JOIN public.bigtehn_machines_cache     m
  ON m.rj_code = l.machine_code
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

GRANT SELECT ON public.v_production_operations TO authenticated;
GRANT SELECT ON public.v_production_operations TO anon;

-- ============================================================================
-- Smoke test (opciono — odkomentariši):
-- ============================================================================
-- SELECT broj_crteza, has_bigtehn_drawing, bigtehn_drawing_path
-- FROM v_production_operations
-- WHERE has_bigtehn_drawing = TRUE
-- LIMIT 10;
--
-- SELECT COUNT(*) AS total_drawings,
--        SUM(size_bytes) / 1024.0 / 1024.0 AS mb_total
-- FROM bigtehn_drawings_cache
-- WHERE removed_at IS NULL;

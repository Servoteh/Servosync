-- ============================================================================
-- SASTANCI — šabloni (templati) za brzo zakazivanje
-- ============================================================================
-- DRAFT: primeniti ručno u Supabase SQL Editoru posle review-a.
-- Zavisi od: public.has_edit_role(), public.update_updated_at()
-- (schema.sql / postojeće migracije).
-- ============================================================================

DO $init$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_updated_at') THEN
    RAISE EXCEPTION 'Missing update_updated_at(). Run base schema / schema.sql first.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'has_edit_role') THEN
    RAISE EXCEPTION 'Missing has_edit_role(). Run add_menadzment_full_edit_kadrovska.sql or equivalent first.';
  END IF;
END
$init$;

-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sastanci_templates (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  naziv              TEXT NOT NULL,
  tip                TEXT NOT NULL,
  mesto              TEXT,
  vodio_email        TEXT,
  zapisnicar_email   TEXT,
  cadence            TEXT NOT NULL
                       CHECK (cadence IN ('weekly', 'biweekly', 'monthly', 'daily', 'none')),
  cadence_dow        INTEGER,
  cadence_dom        INTEGER,
  vreme              TIME,
  napomena           TEXT,
  is_active          BOOLEAN NOT NULL DEFAULT true,
  created_by_email   TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT sastanci_templates_cadence_dow_chk
    CHECK (cadence_dow IS NULL OR (cadence_dow >= 0 AND cadence_dow <= 6)),
  CONSTRAINT sastanci_templates_cadence_dom_chk
    CHECK (cadence_dom IS NULL OR (cadence_dom >= 1 AND cadence_dom <= 31))
);

CREATE INDEX IF NOT EXISTS idx_sastanci_templates_active
  ON public.sastanci_templates (is_active) WHERE is_active = true;

COMMENT ON TABLE public.sastanci_templates IS
  'Šabloni za ponavljajuće sastanke (cadence). SELECT: svi auth; write: has_edit_role().';

-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sastanci_template_ucesnici (
  template_id        UUID NOT NULL REFERENCES public.sastanci_templates(id) ON DELETE CASCADE,
  email              TEXT NOT NULL,
  label              TEXT,
  PRIMARY KEY (template_id, email)
);

CREATE INDEX IF NOT EXISTS idx_sastanci_tu_email
  ON public.sastanci_template_ucesnici (lower(email));

-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_sastanci_templates_updated ON public.sastanci_templates;
CREATE TRIGGER trg_sastanci_templates_updated
  BEFORE UPDATE ON public.sastanci_templates
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ----------------------------------------------------------------------------
ALTER TABLE public.sastanci_templates       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sastanci_template_ucesnici ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "sast_tpl_select" ON public.sastanci_templates;
CREATE POLICY "sast_tpl_select" ON public.sastanci_templates
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "sast_tpl_write" ON public.sastanci_templates;
CREATE POLICY "sast_tpl_write" ON public.sastanci_templates
  FOR ALL TO authenticated
  USING (public.has_edit_role())
  WITH CHECK (public.has_edit_role());

DROP POLICY IF EXISTS "sast_tu_select" ON public.sastanci_template_ucesnici;
CREATE POLICY "sast_tu_select" ON public.sastanci_template_ucesnici
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "sast_tu_write" ON public.sastanci_template_ucesnici;
CREATE POLICY "sast_tu_write" ON public.sastanci_template_ucesnici
  FOR ALL TO authenticated
  USING (public.has_edit_role())
  WITH CHECK (public.has_edit_role());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.sastanci_templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.sastanci_template_ucesnici TO authenticated;

-- sastanak_odluke — formalne odluke sa sastanka

CREATE TABLE IF NOT EXISTS public.sastanak_odluke (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sastanak_id       UUID NOT NULL REFERENCES public.sastanci(id) ON DELETE CASCADE,
  rb                INT,
  naslov            TEXT NOT NULL,
  opis              TEXT,
  odlucio_email     TEXT,
  odlucio_label     TEXT,
  odluka_datum      DATE,
  uticaj            TEXT,
  veza_tema_id      UUID REFERENCES public.pm_teme(id) ON DELETE SET NULL,
  veza_akcija_id    UUID REFERENCES public.akcioni_plan(id) ON DELETE SET NULL,
  status            TEXT NOT NULL DEFAULT 'na_snazi'
                      CHECK (status IN ('na_snazi', 'opozvana')),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sast_odluke_sastanak ON public.sastanak_odluke(sastanak_id);
CREATE INDEX IF NOT EXISTS idx_sast_odluke_status ON public.sastanak_odluke(status);

DROP TRIGGER IF EXISTS trg_sastanak_odluke_updated ON public.sastanak_odluke;
CREATE TRIGGER trg_sastanak_odluke_updated
  BEFORE UPDATE ON public.sastanak_odluke
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

ALTER TABLE public.sastanak_odluke ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "sast_odluke_select" ON public.sastanak_odluke;
CREATE POLICY "sast_odluke_select" ON public.sastanak_odluke
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "sast_odluke_write" ON public.sastanak_odluke;
CREATE POLICY "sast_odluke_write" ON public.sastanak_odluke
  FOR ALL TO authenticated
  USING (public.has_edit_role())
  WITH CHECK (public.has_edit_role());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.sastanak_odluke TO authenticated;

DROP TRIGGER IF EXISTS sast_trg_locked_guard_sastanak_odluke ON public.sastanak_odluke;
CREATE TRIGGER sast_trg_locked_guard_sastanak_odluke
  BEFORE INSERT OR UPDATE OR DELETE ON public.sastanak_odluke
  FOR EACH ROW EXECUTE FUNCTION public.sast_check_not_locked();

NOTIFY pgrst, 'reload schema';

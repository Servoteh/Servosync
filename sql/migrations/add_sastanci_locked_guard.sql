-- ============================================================================
-- SASTANCI — locked meeting guard (Sprint 1 — H2)
-- ============================================================================
-- Blokira mutacije nad zakljucanim sastancima i njihovim child redovima za
-- non-management korisnike. Management moze da reopen/koriguje zapisnik.
--
-- Bezbedno za re-run: DROP TRIGGER IF EXISTS pre CREATE TRIGGER.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.sast_check_not_locked()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status TEXT;
  v_sid    UUID;
BEGIN
  -- Parent tabela: zakljucan sastanak ne sme da se menja/brise osim management.
  IF TG_TABLE_NAME = 'sastanci' THEN
    IF TG_OP = 'UPDATE' AND OLD.status = 'zakljucan' THEN
      IF NOT public.current_user_is_management() THEN
        RAISE EXCEPTION 'Zaključan sastanak ne može biti menjano (id: %)', OLD.id
          USING ERRCODE = '23514',
                HINT = 'Obratite se administratoru za reopening.';
      END IF;
    END IF;

    IF TG_OP = 'DELETE' AND OLD.status = 'zakljucan' THEN
      IF NOT public.current_user_is_management() THEN
        RAISE EXCEPTION 'Zaključan sastanak ne može biti obrisan (id: %)', OLD.id
          USING ERRCODE = '23514';
      END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;

  -- Child tabele: proveri parent status.
  v_sid := CASE TG_OP
    WHEN 'DELETE' THEN OLD.sastanak_id
    ELSE NEW.sastanak_id
  END;

  IF v_sid IS NULL THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;

  SELECT status INTO v_status
  FROM public.sastanci
  WHERE id = v_sid;

  IF v_status = 'zakljucan' AND NOT public.current_user_is_management() THEN
    RAISE EXCEPTION 'Nije moguće menjati podatke zaključanog sastanka (id: %)', v_sid
      USING ERRCODE = '23514',
            HINT = 'Sastanak je zaključan.';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.sast_check_not_locked() IS
  'Sprint 1 Sastanci guard: blokira non-management mutacije nad zakljucanim sastankom i child redovima.';

DROP TRIGGER IF EXISTS sast_trg_locked_guard_sastanci ON public.sastanci;
CREATE TRIGGER sast_trg_locked_guard_sastanci
  BEFORE INSERT OR UPDATE OR DELETE ON public.sastanci
  FOR EACH ROW EXECUTE FUNCTION public.sast_check_not_locked();

DROP TRIGGER IF EXISTS sast_trg_locked_guard_sastanak_ucesnici ON public.sastanak_ucesnici;
CREATE TRIGGER sast_trg_locked_guard_sastanak_ucesnici
  BEFORE INSERT OR UPDATE OR DELETE ON public.sastanak_ucesnici
  FOR EACH ROW EXECUTE FUNCTION public.sast_check_not_locked();

DROP TRIGGER IF EXISTS sast_trg_locked_guard_pm_teme ON public.pm_teme;
CREATE TRIGGER sast_trg_locked_guard_pm_teme
  BEFORE INSERT OR UPDATE OR DELETE ON public.pm_teme
  FOR EACH ROW EXECUTE FUNCTION public.sast_check_not_locked();

DROP TRIGGER IF EXISTS sast_trg_locked_guard_akcioni_plan ON public.akcioni_plan;
CREATE TRIGGER sast_trg_locked_guard_akcioni_plan
  BEFORE INSERT OR UPDATE OR DELETE ON public.akcioni_plan
  FOR EACH ROW EXECUTE FUNCTION public.sast_check_not_locked();

DROP TRIGGER IF EXISTS sast_trg_locked_guard_presek_aktivnosti ON public.presek_aktivnosti;
CREATE TRIGGER sast_trg_locked_guard_presek_aktivnosti
  BEFORE INSERT OR UPDATE OR DELETE ON public.presek_aktivnosti
  FOR EACH ROW EXECUTE FUNCTION public.sast_check_not_locked();

DROP TRIGGER IF EXISTS sast_trg_locked_guard_presek_slike ON public.presek_slike;
CREATE TRIGGER sast_trg_locked_guard_presek_slike
  BEFORE INSERT OR UPDATE OR DELETE ON public.presek_slike
  FOR EACH ROW EXECUTE FUNCTION public.sast_check_not_locked();

DROP TRIGGER IF EXISTS sast_trg_locked_guard_sastanak_arhiva ON public.sastanak_arhiva;
CREATE TRIGGER sast_trg_locked_guard_sastanak_arhiva
  BEFORE INSERT OR UPDATE OR DELETE ON public.sastanak_arhiva
  FOR EACH ROW EXECUTE FUNCTION public.sast_check_not_locked();

-- Deployed: 2026-05-03
-- Vidi: docs/audit/sastanci-audit-2026-05-03.md H2
-- Management (current_user_is_management()) može reopen zaključan sastanak.

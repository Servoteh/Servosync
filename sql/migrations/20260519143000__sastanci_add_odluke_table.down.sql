BEGIN;

DROP TRIGGER IF EXISTS sast_trg_locked_guard_sastanak_odluke ON public.sastanak_odluke;
DROP TRIGGER IF EXISTS trg_sastanak_odluke_updated ON public.sastanak_odluke;
DROP TABLE IF EXISTS public.sastanak_odluke CASCADE;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- Rollback: aktivni predmeti (Faza A)

DROP FUNCTION IF EXISTS public.shift_predmet_prioritet(integer, text);
DROP FUNCTION IF EXISTS public.set_predmet_prioritet(integer, integer);
DROP FUNCTION IF EXISTS public.get_podsklopovi_predmeta(integer);
DROP FUNCTION IF EXISTS public.get_aktivni_predmeti();

DROP FUNCTION IF EXISTS production.shift_predmet_prioritet(integer, text);
DROP FUNCTION IF EXISTS production.set_predmet_prioritet(integer, integer);
DROP FUNCTION IF EXISTS production.get_podsklopovi_predmeta(integer);
DROP FUNCTION IF EXISTS production.get_aktivni_predmeti();

DROP TABLE IF EXISTS production.predmet_prioritet;

NOTIFY pgrst, 'reload schema';

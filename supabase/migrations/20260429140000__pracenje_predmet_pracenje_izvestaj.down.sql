-- Rollback: 20260429140000__pracenje_predmet_pracenje_izvestaj.sql

BEGIN;

DROP FUNCTION IF EXISTS public.get_predmet_pracenje_izvestaj(integer, bigint, integer);
DROP FUNCTION IF EXISTS public.upsert_pracenje_proizvodnje_napomena(integer, bigint, text, uuid);

DROP FUNCTION IF EXISTS production.get_predmet_pracenje_izvestaj(integer, bigint, integer);
DROP FUNCTION IF EXISTS production.upsert_pracenje_proizvodnje_napomena(integer, bigint, text, uuid);

DROP TABLE IF EXISTS production.pracenje_proizvodnje_napomene;

DROP FUNCTION IF EXISTS production._pracenje_line_is_final_control(text, text, boolean);

NOTIFY pgrst, 'reload schema';

COMMIT;

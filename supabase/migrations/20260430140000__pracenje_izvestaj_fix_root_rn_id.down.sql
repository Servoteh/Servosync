-- Rollback: vraća funkciju na stanje iz 20260429150100 (bez root_rn_id u merged).
-- Primeni samo ako treba da se vrati na prethodni state; u normalnom toku NE koristiti.
-- Najlakše: ponovo primeni 20260429150100__pracenje_predmet_izvestaj_rpc_complete.sql
\i supabase/migrations/20260429150100__pracenje_predmet_izvestaj_rpc_complete.sql

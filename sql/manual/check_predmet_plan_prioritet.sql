-- Provera: da li je migracija predmet_plan_prioritet primenjena na bazi?
-- Pokrenuti u Supabase SQL Editor-u kao admin.

-- 1) Da li tabela postoji?
SELECT to_regclass('production.predmet_plan_prioritet') AS tabela_postoji;

-- 2) Da li RPC funkcije postoje?
SELECT
  to_regprocedure('public.get_predmet_plan_prioritet_ids()')      AS get_rpc,
  to_regprocedure('public.set_predmet_plan_prioritet(integer[])') AS set_rpc;

-- 3) Trenutni sadržaj prioriteta (red 0..9, max 10):
SELECT slot, predmet_item_id, updated_at, updated_by
FROM production.predmet_plan_prioritet
ORDER BY slot;

-- 4) RPC test (kao authenticated user iz UI-a):
SELECT public.get_predmet_plan_prioritet_ids() AS prioritet_ids;

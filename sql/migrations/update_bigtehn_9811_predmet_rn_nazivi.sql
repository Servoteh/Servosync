-- Jednokratni update SAMO naziva predmeta (bigtehn_items_cache.naziv_predmeta).
-- NE dira bigtehn_work_orders_cache.naziv_dela — to je naziv po TP/RN (štampa nalepnica).
--
-- Vraćanje pogrešno prepisanih TP naziva: workers/loc-sync-mssql/scripts/
--   resync-bigtehn-naziv-dela-prefix.js --prefix=9811
BEGIN;

WITH m(br, naziv) AS (
  VALUES
    ('9811',    'Termička linija ST-TO-14'),
    ('9811-1',  'Termička linija 14.-Peć za žarenje 13'),
    ('9811-2',  'Termička linija 14.-Peć za kaljenje 13'),
    ('9811-3',  'Termička linija 14.-Kada za kaljenje'),
    ('9811-4',  'Termička linija 14.-Komora za pranje'),
    ('9811-5',  'Termička linija 14.-Transportna kolica'),
    ('9811-6',  'Termička linija 14-Oprema sa manipulaciju')
),
keys AS (
  SELECT br, naziv,
         REPLACE(br, '-', '/')::text AS br_slash
  FROM m
)
UPDATE public.bigtehn_items_cache i
SET naziv_predmeta = k.naziv,
    synced_at        = NOW()
FROM keys k
WHERE trim(i.broj_predmeta) = k.br
   OR trim(i.broj_predmeta) = k.br_slash;

COMMIT;

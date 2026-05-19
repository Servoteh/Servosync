-- revert_bigtehn_9811_rn_naziv_dela_from_mssql.sql
--
-- SQL ne može sam da vrati stare TP nazive — izvor je dbo.tRN.NazivDela u MSSQL.
-- Pokreni iz workers/loc-sync-mssql (sa .env / MSSQL + SUPABASE_SERVICE_ROLE_KEY):
--
--   node scripts/resync-bigtehn-naziv-dela-prefix.js --prefix=9811
--
-- To ažurira samo bigtehn_work_orders_cache.naziv_dela (+ synced_at) za sve
-- IdentBroj LIKE '9811%'. Predmeti (bigtehn_items_cache) ostaju neizmenjeni.
--
-- Provera posle resync-a:
--   SELECT ident_broj, naziv_dela FROM bigtehn_work_orders_cache
--   WHERE ident_broj LIKE '9811-1/%' ORDER BY ident_broj LIMIT 10;
-- distinct naziv_dela po grani treba biti >> 1.

SELECT 1;

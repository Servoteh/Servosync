# Predmet aktivacija — deploy na povezani Supabase (2026-04-26)

Migracija je primenjena preko **Supabase MCP** u više koraka. Verzije u `supabase_migrations` (lokalni nazivi):

- `predmet_aktivacija_init` — `can_manage_predmet_aktivacija`, tabela, RLS
- `predmet_aktivacija_drop_recreate_production_views` — view-ovi (vidi dole)
- `predmet_aktivacija_backfill_and_functions` — backfill, `get_aktivni` / `set` / `shift` / `list` / `set_predmet_aktivacija`, drop `pracenje_oznaceni_*`, public wrapperi, `NOTIFY pgrst`

**Važno:** `v_production_operations` u ovom projektu **nije** ista šema kao u `add_production_cooperation_g7.sql` (flat join). Na bazi postoji `v_production_operations_pre_g4` + G2 + G4 rework/scrap. Zato **ne koristiti** samo deo view-a iz `20260427160000__predmet_aktivacija_init.sql` (G7) na ovoj bazi.

### View `v_production_operations` (deploy)

- `DROP VIEW IF EXISTS v_production_operations_effective CASCADE;`
- `DROP VIEW IF EXISTS v_production_operations CASCADE;`
- `CREATE VIEW` kao:

```sql
-- item_id: SELECT v.*, wo.item_id::integer FROM v_production_operations_pre_g4 v
--   INNER JOIN v_active_bigtehn_work_orders wo ON wo.id = v.work_order_id
-- G4: isti LATERAL na bigtehn_rework_scrap_cache kao u starom view-u
```

Tačan SQL je u fajlu `20260427160001__predmet_aktivacija_views_pre_g4.sql` (repou).

Ako novi environment nema `pre_g4`, potrebna je posebna strategija (stariji Plan šema).

# Lokacije modul — redosled migracija (runbook)

Rešava nalaz **M30** iz [docs/Lokacije_modul_analiza.md](../Lokacije_modul_analiza.md): migracije lokacija imaju implicitne zavisnosti („Primeni nakon X") koje Supabase SQL Editor ne validira. Ako neko pokrene out-of-order, baza padne sa missing column/constraint.

Ovaj fajl je istina za **redosled apply-a u Supabase produkciji**. CI redosled je u [sql/ci/migrations.txt](../../sql/ci/migrations.txt) (sinhronizovan ali preskače `pg_cron` zavisnosti).

---

## Redosled apply-a (produkcija)

| # | Fajl | Zavisi od | Idempotentno | Rollback |
|---|---|---|---|---|
| 1 | `add_loc_module_step1_tables.sql` | — | da | DROP TABLE loc_* CASCADE |
| 2 | `add_loc_module.sql` | step1 (ili niko — sadrži CREATE IF NOT EXISTS) | da | vidi DOWN sekciju u fajlu |
| 3 | `add_loc_step2_ci_unique.sql` | add_loc_module | da | DROP INDEX loc_locations_code_ci_uq |
| 4 | `add_loc_step3_cleanup.sql` | add_loc_module | da | DROP FUNCTION loc_purge_synced_events |
| 5 | `add_loc_step5_sync_rpcs.sql` | add_loc_module | da | DROP FUNCTION loc_claim_sync_events, loc_mark_sync_* |
| 6 | **`add_loc_step4_pgcron.sql`** | step3 + step5 | da, **zahteva pg_cron** | `cron.unschedule('loc_purge_synced_daily')` |
| 7 | `add_loc_v2_quantity.sql` | step5 (placement schema) | da | DROP CONSTRAINT loc_item_placements_qty_pos_chk, restore stari UNIQUE |
| 8 | `add_loc_v3_order_scope.sql` | v2 | da | DROP CONSTRAINT loc_item_placements_order_no_len_chk, restore (item,id,loc) UNIQUE |
| 9 | `add_loc_v4_drawing_no.sql` | v3 | da | DROP CONSTRAINT loc_*_drawing_no_len_chk, DROP INDEX |
| 10 | `add_loc_menadzment_manage_locations.sql` | add_loc_module | da | restore stari loc_can_manage_locations() body |
| 11 | `add_loc_report_by_locations_rpc.sql` | v4 + bigtehn_work_orders_cache | da | DROP FUNCTION loc_report_parts_by_locations |
| 12 | `add_loc_tps_for_predmet_rpc.sql` → `_v2` → `_v3` | v_active_bigtehn_work_orders | da (svaka prepiše prethodnu) | DROP FUNCTION loc_tps_for_predmet |
| 13 | `add_loc_report_v2_bigtehn_columns.sql` | report_by_locations | da | revert na v1 RPC |
| 14 | `add_loc_report_ident_broj_variant_match.sql` | report_v2_bigtehn_columns | da | revert na prethodnu RPC |
| 15 | `add_loc_locations_audit.sql` | add_audit_log | da | DROP TRIGGER trg_audit_loc_locations, DROP FUNCTION loc_locations_audit |
| 16 | `add_loc_location_hierarchy_rules.sql` | add_loc_module | da | DROP TRIGGER, DROP VIEW |
| 17 | `loc_location_code_scope_unique_strip_prefix.sql` | add_loc_module (UQ swap) | **delom destruktivno** (UPDATE polica) | DROP INDEX loc_locations_scope_code_ci_uq, recreate global UQ |
| 18 | `add_loc_view_hale_i_police_list.sql` | add_loc_module | da | DROP VIEW |
| 19 | **`harden_loc_create_movement_v5.sql`** (Härd-1) | v4 | da | restore v4 RPC body, DROP COLUMN client_event_uuid |
| 20 | **`harden_loc_create_movement_v5_roles.sql`** (Härd-2) | harden_v5 | da | restore prethodni RPC body, DROP FUNCTION loc_can_create_movement |
| 21 | **`add_loc_sync_health_monitor.sql`** (Härd-3) | step5 + step4 (pg_cron); RPC sa fallback ako pg_cron nije dostupan | da | DROP TABLE loc_sync_worker_heartbeat, loc_sync_alerts_outbox; DROP FUNCTION loc_sync_* |

## Provera primenjenih migracija

Supabase nema kanonski „migration tracking" (osim Supabase CLI-a, koji ovaj projekat ne koristi za inkrementalne apply-e). Verifikacija šeme se radi pretragom postojanja konstrukti koje migracija donosi:

```sql
-- Da li je v4 primenjen?
SELECT EXISTS (
  SELECT 1 FROM information_schema.columns
   WHERE table_schema='public'
     AND table_name='loc_location_movements'
     AND column_name='drawing_no'
) AS v4_applied;

-- Da li je Härd-1 primenjen?
SELECT EXISTS (
  SELECT 1 FROM information_schema.columns
   WHERE table_schema='public'
     AND table_name='loc_location_movements'
     AND column_name='client_event_uuid'
) AS hard1_applied;

-- Da li je Härd-2 helper postoji?
SELECT EXISTS (
  SELECT 1 FROM pg_proc p
   JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname='public' AND p.proname='loc_can_create_movement'
) AS hard2_applied;

-- Da li je Härd-3 health monitor postoji?
SELECT EXISTS (
  SELECT 1 FROM information_schema.tables
   WHERE table_schema='public' AND table_name='loc_sync_worker_heartbeat'
) AS hard3_applied;
```

## pg_cron — produkcija vs dev

Migracije koje koriste `cron.schedule`:
- `add_loc_step4_pgcron.sql` — dnevni purge SYNCED stavki.
- `add_loc_sync_health_monitor.sql` — satni health check (alert enqueue).

Obe migracije imaju `EXCEPTION WHEN undefined_table THEN NULL` handler oko cron.schedule-a. U CI-u (Postgres bez pg_cron-a) migracije prolaze, ali job se ne registruje. Na Supabase produkciji proveri:

```sql
SELECT jobid, jobname, schedule, active
  FROM cron.job
 WHERE jobname IN ('loc_purge_synced_daily', 'loc_sync_health_check_hourly');
```

Ako bilo koji job nedostaje — re-run odgovarajuću migraciju.

## Apply procedura

1. **Backup** Supabase baze pre svakog batch apply-a (Studio → Database → Backups).
2. SQL Editor → kopiraj migraciju iz repo-a → Run.
3. Verifikuj `RAISE NOTICE` poruku iz sanity check bloka na dnu svake migracije.
4. Ako migracija u zaglavlju kaže „Primeni nakon X" — prvo pokreni X.
5. Pokreni pgTAP testove (lokalno preko `pg_prove`, vidi [sql/ci/README.md](../../sql/ci/README.md)) pre nego što merge-uješ u main.

## Rollback procedura

Svaka migracija ima `DOWN` blok u zaglavlju ili eksplicitan opis u kolonama gore. Praktično, rollback se izvodi **ručno**:

- DROP nove tabele / kolone / constraint-e koje migracija dodaje.
- `CREATE OR REPLACE FUNCTION` sa prethodnim body-jem (kopiraj iz prethodne migracije u repo-u).
- Ne brišu se redovi sa podacima.

**Härd-3 specifično:**
```sql
-- Rollback add_loc_sync_health_monitor.sql:
BEGIN;
  /* Unschedule cron job ako je registrovan. */
  DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname='loc_sync_health_check_hourly') THEN
      PERFORM cron.unschedule('loc_sync_health_check_hourly');
    END IF;
  EXCEPTION WHEN undefined_table THEN NULL; END $$;

  DROP FUNCTION IF EXISTS public.loc_sync_dispatch_mark_failed(uuid, text);
  DROP FUNCTION IF EXISTS public.loc_sync_dispatch_mark_sent(uuid);
  DROP FUNCTION IF EXISTS public.loc_sync_dispatch_dequeue(int);
  DROP FUNCTION IF EXISTS public.loc_sync_health_check_and_enqueue();
  DROP FUNCTION IF EXISTS public.loc_sync_health_summary();
  DROP FUNCTION IF EXISTS public.loc_sync_admin_emails();
  DROP FUNCTION IF EXISTS public.loc_sync_worker_heartbeat_upsert(text, jsonb);

  DROP TABLE IF EXISTS public.loc_sync_alerts_outbox;
  DROP TABLE IF EXISTS public.loc_sync_worker_heartbeat;
COMMIT;
```

---

**Verzija:** 2026-05-15 · **Autor:** Sprint LOC-Härd-3 · **Vlasnik:** team-erp.

# PP Sprint 1H — pre-flight analiza (H8: orphan `assigned_machine_code` cleanup)

> Datum: 2026-05-16 · Sprint: 1H · Audit ref: H8 u [Plan_proizvodnje_modul_analiza.md](../Plan_proizvodnje_modul_analiza.md)

## Cilj

Noćni pg_cron job koji čisti `production_overlays.assigned_machine_code` ako mašina više ne postoji u `bigtehn_machines_cache`. Insurance policy za scenario gde bridge sync ukloni mašinu iz BigTehn-a — REASSIGN overlay postaje "orphan" i izveštaji su pogrešni.

**Trenutno stanje:** Sprint 0 SQL #9 pokazao **0 orphan-a**. Job je preventiva, ne reaktivni fix.

## Šta job radi

```sql
UPDATE production_overlays
   SET assigned_machine_code = NULL,
       updated_by = 'system:cleanup:orphaned-machines'
 WHERE assigned_machine_code IS NOT NULL
   AND archived_at IS NULL
   AND NOT EXISTS (
     SELECT 1 FROM bigtehn_machines_cache m
     WHERE m.rj_code = production_overlays.assigned_machine_code
   );
```

Posledica:
- Overlay se vraća na "koristi originalnu mašinu iz BigTehn-a" (NULL = original).
- M11 trigger (Sprint 1G) logira promenu u `production_overlays_history` sa `changed_by = 'system:cleanup:orphaned-machines'`.
- UI prikazuje operaciju na originalnoj mašini, šef može da ponovo REASSIGN ako želi.

## Postojeća infrastruktura

[add_loc_step4_pgcron.sql](../../sql/migrations/add_loc_step4_pgcron.sql) već koristi pg_cron za Lokacije retention job (`loc_purge_synced_daily` u 03:15 UTC). Pattern:
- `CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;` — već apliciran
- SECURITY DEFINER cron-only funkcija (NE proverava authoriziciju — zove se samo iz cron-a)
- `REVOKE ALL FROM PUBLIC, anon, authenticated`
- `cron.schedule(jobname, '...', $cron$ SQL $cron$)`
- DO blok za idempotent unschedule pre re-apply-a

Preduslov: **Supabase PAID tier** (pg_cron je dostupan u Supabase Pro+). Za free tier extension nije dostupan i job se ne kreira (CREATE EXTENSION FAIL-uje).

## Plan implementacije

### Schedule

`30 2 * * *` — svaki dan u **02:30 UTC**. Razlozi:
- Različito od Lokacije job-a (03:15 UTC) da se ne pretrpa baza.
- Najmanje aktivnih korisnika (proizvodnja je u dnevnoj smeni).
- Bridge sync ide svakih 15 min — orphan-i se događaju u ~realnom vremenu, ali noćni cleanup je dovoljno često (žrtvujemo do 24h korektnosti u retkom slučaju).

### Logging

Cron job ne piše u poseban tabel — broj obrisanih redova ostaje u `cron.job_run_details`:
```sql
SELECT * FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'po_cleanup_orphaned_machines')
ORDER BY start_time DESC LIMIT 30;
```

Plus M11 history log (Sprint 1G) automatski beleži svaku promenu sa `field_name = 'assigned_machine_code'` i `changed_by = 'system:cleanup:orphaned-machines'`.

### Idempotency

UPDATE je idempotentan po dizajnu — drugi run ne pronalazi orphan-e jer su prvi cleanovani. `WHERE NOT EXISTS` guard štiti.

### Race conditions

Šta ako između UPDATE checka i UPDATE samog koraka bridge sync vrati mašinu u cache? Realan ali redak race. UPDATE bi spustio `assigned_machine_code` na NULL iako mašina sada postoji. Posledica: REASSIGN se vraća, šef može da ponovo postavi. **Niska šteta, ne treba mitigation.** UPDATE bi mogao da koristi `FOR UPDATE` lock, ali to dodaje kompleksnost bez stvarnog benefita.

### Sigurnosna razmatranja

Funkcija je SECURITY DEFINER + `SET search_path = public, pg_temp`. Poziva se SAMO iz cron-a (REVOKE od authenticated). Ako neko sa direct DB pristupom (admin) zove ručno → bezbedno, isti rezultat. Nema `auth.uid()` provere jer cron nema autentifikaciju.

## Risk i rollback

| Aspekt | Vrednost |
|---|---|
| Risk apply-a | Vrlo nizak (0 orphan-a trenutno, no-op u prvom run-u) |
| Risk produkcijskog efekta | Nizak (UPDATE postavlja NULL, ne briše red) |
| Rollback | `SELECT cron.unschedule('po_cleanup_orphaned_machines'); DROP FUNCTION public._po_cleanup_orphaned_machines_cron();` |

## Test plan

Posle apply-a:

1. **Verify schedule:**
   ```sql
   SELECT jobid, jobname, schedule, active 
   FROM cron.job WHERE jobname = 'po_cleanup_orphaned_machines';
   ```
2. **Manual trigger** (može da se uradi van schedule-a):
   ```sql
   SELECT public._po_cleanup_orphaned_machines_cron();
   ```
   - Treba da vrati 0 (jer Sprint 0 SQL #9 = 0 orphan-a).
3. **Simulacija orphan-a** (van produkcije — dev/staging):
   ```sql
   -- Setuj orphan na test overlay
   UPDATE production_overlays SET assigned_machine_code = 'XXX.NONEXISTENT'
   WHERE id = <test_overlay_id>;
   
   -- Run cleanup
   SELECT public._po_cleanup_orphaned_machines_cron(); -- treba 1
   
   -- Verify
   SELECT assigned_machine_code FROM production_overlays WHERE id = <test_overlay_id>; -- NULL
   ```
4. **History audit (M11):**
   ```sql
   SELECT field_name, old_value, new_value, changed_by, changed_at
   FROM production_overlays_history
   WHERE field_name = 'assigned_machine_code' 
     AND changed_by = 'system:cleanup:orphaned-machines'
   ORDER BY changed_at DESC LIMIT 10;
   ```

## Vremenska procena

- Pre-flight: 30 min ✅
- SQL migracija: 30 min
- Apply + verify: 10 min
- **Ukupno: ~1h**

## Stvari koje NEĆE biti u Sprint 1H

- UI obaveštenje da je cleanup pokrenut — overhead bez koristi.
- Alert kad cleanup vrati > N redova (signal da bridge ima problem) — može u Sprint 1I+ ako se desi.
- Cleanup za `archived_at IS NOT NULL` redove (istorija ostaje netaknuta).

## Zavisnost

Sprint 1G (M11 history) mora biti apliciran **pre** Sprint 1H da bi history audit trigger video promene koje radi cleanup job. Ako se 1H aplicira pre 1G, cleanup radi normalno ali nema history zapisa (što je acceptable trade-off, ali bolje držati redosled).

# loc-sync-mssql

Node worker koji prenosi redove iz Supabase tabele `public.loc_sync_outbound_events` u MSSQL preko stored procedure `dbo.sp_ApplyLocationEvent`.

## Arhitektura

```
Supabase (Postgres)                  Ovaj worker                     MSSQL ERP
───────────────────                  ─────────────                    ──────────
loc_create_movement                  poll + claim (RPC)               sp_ApplyLocationEvent
  └─ trigger upisuje u               ─────────────────────▶           (idempotentno:
     loc_sync_outbound_events         loc_claim_sync_events            koristi @EventId
     (PENDING)                        (FOR UPDATE SKIP LOCKED)          kao ključ)
                                          │
                                          ▼
                                      MSSQL proc poziv
                                          │
                          ┌───────────────┴───────────────┐
                          ▼                               ▼
                   uspeh → SYNCED                  greška → FAILED + backoff
                   (loc_mark_sync_synced)          (loc_mark_sync_failed)
                                                   10 pokušaja → DEAD_LETTER
```

## Preduslovi

1. Primenjene SQL migracije:
   - `sql/migrations/add_loc_module.sql`
   - `sql/migrations/add_loc_step3_cleanup.sql`
   - `sql/migrations/add_loc_step5_sync_rpcs.sql` (obavezno — definiše claim/mark RPC-je)
2. U MSSQL-u postoji `dbo.sp_ApplyLocationEvent` sa očekivanim potpisom:

```sql
CREATE PROCEDURE dbo.sp_ApplyLocationEvent
    @EventId  UNIQUEIDENTIFIER,
    @Payload  NVARCHAR(MAX)   -- JSON payload iz Supabase-a
AS
BEGIN
    SET NOCOUNT ON;
    -- ERP-specifična logika (idempotentnost obavezna)
END
```

Ako potpis u vašem ERP-u razlikuje, prilagodite `src/mssqlClient.js`.

## Konfiguracija

```bash
cp .env.example .env
# popunite SUPABASE_* i MSSQL_* vrednosti
```

**Bezbednost:**
- `SUPABASE_SERVICE_ROLE_KEY` obilazi RLS. NE commit-uj u git, NE koristi u browser bundle-u.
- MSSQL korisnik treba samo `EXECUTE` na `dbo.sp_ApplyLocationEvent` (least privilege).

## Pokretanje

```bash
cd workers/loc-sync-mssql
npm install
npm start           # produkcija
npm run dev         # sa --watch
```

## Paralelizam

Više instanci sa različitim `WORKER_ID` vrednostima rade bez konflikta zahvaljujući `FOR UPDATE SKIP LOCKED` u `loc_claim_sync_events`. Preporučuje se start sa 1–2 instance; skaliraj tek ako postoji backlog.

## Operativno

- **Idempotentnost**: `sp_ApplyLocationEvent` mora biti idempotentna po `@EventId` — `markSynced` se dešava nakon poziva, pa u slučaju pada između (retki race) event ide ponovo u FAILED → retry.
- **Backoff**: 2, 4, 8, 16, 32, 64, 128 min (cap 6h). Posle 10 pokušaja `DEAD_LETTER` — ručna inspekcija preko UI `Sync` taba (admin).
- **Retention**: `pg_cron` job `loc_purge_synced_daily` briše SYNCED starije od 90 dana (vidi `sql/migrations/add_loc_step4_pgcron.sql`).

## Nagomilane greške

```sql
SELECT id, attempts, last_error, next_retry_at
  FROM public.loc_sync_outbound_events
 WHERE status = 'DEAD_LETTER'
 ORDER BY created_at DESC;
```

Posle popravke (npr. prepravke SP-ja), redove se može ručno resetovati:

```sql
UPDATE public.loc_sync_outbound_events
   SET status = 'PENDING', attempts = 0, next_retry_at = NULL, last_error = NULL
 WHERE id = '<uuid>';
```

## Testovi

```bash
npm test   # node --test u test/ folderu (za sada skelet)
```

# loc-sync-monitor-dispatch

Šalje mejlove za **Lokacije sync health** iz `loc_sync_alerts_outbox` (worker down, DEAD_LETTER digest).

## Deploy

```bash
supabase functions deploy loc-sync-monitor-dispatch --no-verify-jwt --project-ref <PROJECT_REF>
```

## Edge funkcija — Secrets (Dashboard → Edge Functions → Secrets)

| Ime               | Opis                                      |
|-------------------|-------------------------------------------|
| `RESEND_API_KEY`  | Resend API ključ. Bez ključa = DRY-RUN (log). |
| `RESEND_FROM`     | Opciono, default `noreply@servoteh.rs`.   |

Ostalo (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`) Supabase dopunjuje sam.

Postavi ključ lokalnim CLI-jem ako želiš:

```bash
npx supabase secrets set RESEND_API_KEY=re_xxxxxxxx --project-ref <PROJECT_REF>
```

## Postgres Vault + pg_net (pulse svakih 5 minuta)

Migracija: **`sql/migrations/add_loc_sync_monitor_dispatch_pulse.sql`**

1. U **SQL Editoru** pokreni primer (zameni svoj ref i ceo URL):

```sql
SELECT vault.create_secret(
  'https://YOUR_PROJECT.supabase.co/functions/v1/loc-sync-monitor-dispatch',
  'loc_sync_monitor_dispatch_url',
  'Härd-3: URL za pg_net POST (loc-sync-monitor-dispatch)'
);
```

**Obavezno** je da secret zove baš `loc_sync_monitor_dispatch_url`.

2. **Preporuka (bez anonimnog POST-a):** ceo Authorization header kao drugi Vault secret:

```sql
SELECT vault.create_secret(
  'Bearer YOUR_SERVICE_ROLE_JWT',
  'loc_sync_monitor_dispatch_bearer',
  'Opciono: Bearer za Invoke Edge funkcije (verify_jwt isključen)'
);
```

Možeš i sam JWT bez prefiksa `Bearer` — funkcija ga dodaje.

3. Primeni migraciju pulse + proveru crona:

```sql
SELECT jobid, jobname, schedule, command, active
  FROM cron.job
 WHERE jobname = 'loc_sync_monitor_dispatch_every_5_min';

SELECT public.loc_sync_pulse_monitor_dispatch();
```

Ručni test bez pulse-a:

```bash
curl -sS -X POST "https://YOUR_PROJECT.supabase.co/functions/v1/loc-sync-monitor-dispatch"
```

Uz bearer:

```bash
curl -sS -X POST "https://YOUR_PROJECT.supabase.co/functions/v1/loc-sync-monitor-dispatch" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY"
```

## Worker heartbeat

Docker / proces `loc-sync-mssql` sam šalje heartbeat (Härd-3). Posle migracija restartuj proces da počne ponovo.

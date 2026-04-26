# sastanci-notify-dispatch

Edge function koja obradjuje `public.sastanci_notification_log` outbox — šalje email obaveštenja za:

- `akcija_new` — nova akcija dodeljena korisniku
- `akcija_changed` — promena rok/status/odgovornog na akciji
- `meeting_invite` — pozivnica na novi/zakazani sastanak
- `meeting_locked` — zapisnik finalizovan, PDF dostupan
- `action_reminder` — dnevni podsetnik za akcije kojima ističe rok
- `meeting_reminder` — podsetnik 24h pre sastanka

**WhatsApp kanal:** nije implementiran u Fazi C. Redovi sa `channel='whatsapp'` se automatski označavaju kao `failed` sa porukom "WhatsApp not enabled in this version (Faza C)".

## Zavisnosti (SQL migracije — primeniti redom)

1. `sql/migrations/add_sastanci_notification_prefs.sql`
2. `sql/migrations/add_sastanci_notification_outbox.sql`
3. `sql/migrations/add_sastanci_notification_triggers.sql`
4. `sql/migrations/add_sastanci_arhiva_storage.sql`
5. `sql/migrations/add_sastanci_dispatch_rpc.sql`
6. `sql/migrations/add_sastanci_reminder_jobs.sql`

## Deploy

```bash
supabase functions deploy sastanci-notify-dispatch --no-verify-jwt
```

## Env secrets

Postavi u Supabase Dashboard → Edge Functions → `sastanci-notify-dispatch` → Secrets.

| Name                        | Opis                                               | Default / Required       |
| --------------------------- | -------------------------------------------------- | ------------------------ |
| `SUPABASE_URL`              | URL Supabase projekta                              | auto (Supabase postavlja)|
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key                                   | auto (Supabase postavlja)|
| `RESEND_API_KEY`            | Resend.com API key                                 | opciono (bez → DRY-RUN) |
| `RESEND_FROM`               | Pošiljalac email-a                                 | `noreply@servoteh.rs`    |
| `VITE_PUBLIC_APP_URL`       | URL frontend aplikacije (za linkove u email-u)     | `https://servoteh-plan-montaze.pages.dev/` |
| `SAST_DISPATCH_BATCH`       | Broj redova po pozivu                              | `25`                     |

> **DRY-RUN:** Bez `RESEND_API_KEY` funkcija markira redove kao `sent` i loguje ih u konzolu. Korisno za testiranje schedule-a bez slanja pravih poruka.

## Scheduled Trigger (Supabase Dashboard → Database → Cron Jobs)

Preporučeno: svakih 2 minuta.

```sql
SELECT net.http_post(
  url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/sastanci-notify-dispatch',
  headers := jsonb_build_object(
    'Authorization', 'Bearer <SUPABASE_SERVICE_ROLE_KEY>',
    'Content-Type',  'application/json'
  )
);
```

Schedule: `*/2 * * * *`

## Ručno pokretanje

```bash
curl -X POST "https://<PROJECT_REF>.supabase.co/functions/v1/sastanci-notify-dispatch" \
     -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY"
```

## Reminder cron jobovi

Postavljeni u `add_sastanci_reminder_jobs.sql` — rade direktno u bazi (pg_cron):

| Job | Schedule | Šta radi |
|-----|----------|----------|
| `sast_action_reminders_daily` | `0 7 * * *` (07:00 UTC) | enqueue `action_reminder` za otvorene akcije |
| `sast_meeting_reminders_30min` | `*/30 * * * *` | enqueue `meeting_reminder` za sastanke koji počinju za 15–45 min |

Dispatch cron (ovaj endpoint) procesira ove redove kada stignu u outbox.

## Troubleshooting

```sql
-- Stanje outbox-a
SELECT status, count(*) FROM public.sastanci_notification_log GROUP BY status ORDER BY count DESC;

-- Poslednji failed redovi
SELECT id, kind, recipient_email, error, attempts, last_attempt_at
FROM public.sastanci_notification_log
WHERE status = 'failed'
ORDER BY last_attempt_at DESC NULLS LAST
LIMIT 20;

-- Ručni retry failed → queued
UPDATE public.sastanci_notification_log
SET status = 'queued', next_attempt_at = now(), error = NULL
WHERE status = 'failed'
  AND attempts < max_attempts;

-- Proveri cron jobove
SELECT jobname, schedule, active FROM cron.job
WHERE jobname LIKE 'sast_%';

-- Poslednje izvrsavanje cron joba
SELECT * FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'sast_action_reminders_daily')
ORDER BY start_time DESC LIMIT 5;

-- Prefs korisnika
SELECT * FROM public.sastanci_notification_prefs WHERE email = 'korisnik@servoteh.rs';
```

## Bezbednost

- Svi RPC pozivi nose `X-Audit-Actor: sastanci-notify-dispatch@edge.servoteh` header (vidljiv u audit log-u).
- Dispatch RPC-ovi (`sastanci_dispatch_*`) su dostupni samo `service_role` — ne mogu se zvati iz browser-a.
- `sastanci_enqueue_notification` je `SECURITY DEFINER` — triggeri u bazi zaobilaze RLS INSERT.
- WhatsApp kanal: permanent fail bez retry (Faza C ograničenje).

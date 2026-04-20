# maint-notify-dispatch

Supabase Edge Function koja obrađuje outbox `public.maint_notification_log`
(modul Održavanje mašina → notifikacije).

## Preduslovi u bazi

Pokreni redom (ako već nisu):

1. `sql/migrations/add_maintenance_module.sql`
2. `sql/migrations/add_maint_notifications_plan.sql` (dodaje `whatsapp` enum)
3. `sql/migrations/add_maint_notification_outbox.sql` (outbox kolone + enqueue + trigger)
4. `sql/migrations/add_maint_notify_dispatch_rpc.sql` (RPC-ovi koje worker zove)

## Deploy

```bash
supabase login
supabase link --project-ref <PROJECT_REF>
supabase functions deploy maint-notify-dispatch --no-verify-jwt
```

> `--no-verify-jwt` jer funkciju poziva interni cron koji sam nosi
> `SUPABASE_SERVICE_ROLE_KEY` iz Secrets-a (worker ne prihvata korisničke JWT-ove).

## Env varijable (Secrets)

Auto (Supabase ih popunjava):
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Opciono (bez njih worker radi u **DRY-RUN** režimu — samo `console.log`):
- `WA_ACCESS_TOKEN` — Meta Graph API dugoročni access token.
- `WA_PHONE_NUMBER_ID` — Meta `phone_number_id` verifikovanog broja.
- `WA_TEMPLATE_NAME` — npr. `incident_alert_sr`.
- `WA_TEMPLATE_LANG` — npr. `sr` (default).
- `MAINT_DISPATCH_BATCH` — default `25`.

Postavljanje:

```bash
supabase secrets set \
  WA_ACCESS_TOKEN=... \
  WA_PHONE_NUMBER_ID=... \
  WA_TEMPLATE_NAME=incident_alert_sr \
  WA_TEMPLATE_LANG=sr
```

## Scheduling

Supabase Scheduled Triggers (UI → Database → Webhooks → Scheduled):
- Schedule: `*/1 * * * *` (svakog minuta) za real-time alerting, ili `*/5 * * * *`.
- HTTP Method: `POST`.
- URL: `https://<PROJECT_REF>.functions.supabase.co/maint-notify-dispatch`.
- Headers: `Authorization: Bearer <SERVICE_ROLE>` (cron trigger automatski dodaje).

## Ručna provera (lokalno)

```bash
supabase functions serve maint-notify-dispatch \
  --env-file supabase/.env.local \
  --no-verify-jwt

curl -X POST http://localhost:54321/functions/v1/maint-notify-dispatch
```

## Template u Meti (za WhatsApp Business Cloud API)

Primer `incident_alert_sr` telo:

```
Održavanje: {{1}}

Detalji: {{2}}
```

Worker šalje `subject` kao parametar {{1}} i `body` kao parametar {{2}}.

## Fan-out semantika

Trigger `maint_incidents_enqueue_notify` kreira **stub** red
(`recipient='pending'`, `recipient_user_id=NULL`). Worker prepoznaje takve
redove i umesto slanja zove `maint_dispatch_fanout(parent_id)` koji:

- Čita `maint_user_profiles` (uloge: `chief` uvek, `management` kada je
  `payload.severity = 'critical'`) sa popunjenim `phone` poljem.
- Kreira child redove (`recipient = profile.phone`, `channel = parent.channel`,
  `payload` dobija `fanout_parent` referencu na parent-id).
- Parent obeležava `status='sent'` sa `error='FANOUT_DONE: N recipients'`
  (revizioni trag, nema novih pokušaja).

Child redovi se obrađuju u sledećoj iteraciji batch-a.

## Retry politika

Dequeue bira redove sa `status IN ('queued','failed') AND
next_attempt_at <= now() AND attempts < 8`. Na neuspeh, worker zove
`maint_dispatch_mark_failed(id, err, backoff_sec)` koji postavlja
`next_attempt_at = now() + backoff_sec`.

Backoff (u workeru): 30s, 1m, 2m, 4m, 8m, 16m, 32m, 1h (cap).
Posle 8 pokušaja red ostaje trajno `failed` (dequeue ga ne vraća);
admin može ručno vratiti `status='queued'` i smanjiti `attempts`.

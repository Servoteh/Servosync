# Plan Montaze v5.1.1

Pilot hardening patch za online Supabase test.

## Promene

- Lowercase email role lookup u `index.html`
- Login i session restore normalizuju `currentUser.email` na lowercase
- `user_roles` dobija partial unique indekse preko `lower(email)`
- `has_edit_role()` i RLS su uskladjeni sa `user_roles`, bez oslanjanja na JWT role claim
- `sql/schema.sql` je uskladjen sa aktuelnom v5.1 semom
- Repo cleanup: uklonjeni probni i duplikat fajlovi

## Status

Spremno za pilot Supabase test i GitHub verzionisanje.

## Održavanje mašina — notifikacije (plan)

- Telegram integracija je PAUZIRANA odlukom korisnika (25.04.2026).
- Sledeći kanal: **WhatsApp Business Cloud API** (Meta).
- Priprema u bazi: `add_maint_notifications_plan.sql` dodaje `whatsapp` u
  `maint_notification_channel` enum, bez promene šeme.
- Preduslovi pre implementacije:
  - Verifikovan Meta Business nalog + WhatsApp Business broj.
  - Template poruke (Meta odobrenje, npr. "incident_alert_sr").
  - Supabase secrets: `WA_ACCESS_TOKEN`, `WA_PHONE_NUMBER_ID`,
    `WA_TEMPLATE_NAME`, `WA_TEMPLATE_LANG`.
- Plan implementacije (kada krenemo):
  1. `maint_user_profiles.phone` kolona (E.164 format) + UI polje u
     „Održ. profili”. **Dodato u `add_maint_notification_outbox.sql`.**
  2. Outbox infrastruktura na `maint_notification_log`
     (`scheduled_at`, `next_attempt_at`, `last_attempt_at`, `attempts`, `payload`)
     + AFTER INSERT trigger na `maint_incidents` (severity major/critical →
     stub queued red sa `recipient = 'pending'`). **Dodato u
     `add_maint_notification_outbox.sql`.**
  3. Edge Function `maint-notify-dispatch` (Deno) — **Skelet spreman u
     `supabase/functions/maint-notify-dispatch/`**:
     - Pokreće ga Supabase Scheduled Trigger (npr. svakog minuta).
     - Koristi SECURITY DEFINER RPC-ove iz
       `add_maint_notify_dispatch_rpc.sql`:
       `maint_dispatch_dequeue` (batch sa `FOR UPDATE SKIP LOCKED`),
       `maint_dispatch_fanout` (stub → child redovi po ulogama iz
       `maint_user_profiles`), `maint_dispatch_mark_sent`,
       `maint_dispatch_mark_failed` (backoff).
     - Bez `WA_*` Secrets-a radi u **DRY-RUN** režimu (console.log + mark
       sent), kad se postavi `WA_ACCESS_TOKEN` + `WA_PHONE_NUMBER_ID` +
       `WA_TEMPLATE_NAME` kreće pravo slanje preko
       `graph.facebook.com/v20.0/{phone_number_id}/messages` (template payload
       sa parametrima {{1}}=subject, {{2}}=body).
     - Detalji: `supabase/functions/maint-notify-dispatch/README.md`.
  4. Dnevni cron (pg_cron → webhook) za prekoračene kontrole
     (`v_maint_task_due_dates where next_due_at < now()`).
  5. Retry politika: posle N pokušaja `status = 'failed'` ostaje trajno (bez
     novog `next_attempt_at`); admin može ručno vratiti red u `'queued'`.


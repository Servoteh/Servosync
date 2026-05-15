# Sprint LOC-Härd-3 — Korak 1 analiza

**Status:** OK za prelazak na Korak 2 (admin email tabela je pronađena, ne traži se nova).
**Datum:** 2026-05-15
**Sprint dokument:** `HARDENING_SPRINTS.md` (Härd-3)

---

## 1. Trenutno stanje `loc_sync_outbound_events`

Stanje **nije čitano sa baze** (Cursor ne pokreće upite na produkciji bez potvrde). Šema iz `add_loc_module.sql`:

```sql
status loc_sync_status_enum NOT NULL DEFAULT 'PENDING'   -- PENDING, IN_PROGRESS, SYNCED, FAILED, DEAD_LETTER
attempts SMALLINT NOT NULL DEFAULT 0
locked_by_worker TEXT, locked_at TIMESTAMPTZ
next_retry_at TIMESTAMPTZ
synced_at TIMESTAMPTZ
```

Worker (`add_loc_step5_sync_rpcs.sql`):
- `loc_claim_sync_events` (FOR UPDATE SKIP LOCKED, batch do 100)
- `loc_mark_sync_synced` — finalan uspeh
- `loc_mark_sync_failed` — exp. backoff 2..360min, posle 10 attempts ide u `DEAD_LETTER`.

`add_loc_step4_pgcron.sql` već briše SYNCED stavke starije od 90 dana u 03:15 UTC.

## 2. Worker `workers/loc-sync-mssql/` — postoji

Entry point [src/index.js](../../workers/loc-sync-mssql/src/index.js) ima glavnu petlju sa `claimBatch → processBatch → sleep`. Log-uje:
- `starting worker` (worker_id, batch_size, poll_ms)
- `mssql pool connected`
- `batch processed` (count, ok, failed, duration_ms)
- `loop iteration failed` (error)

Konfiguracija ([src/config.js](../../workers/loc-sync-mssql/src/config.js)):
- `WORKER_ID` env var (default `loc-sync-${pid}`) — stabilan ID za heartbeat.
- `POLL_INTERVAL_MS` (default 5000), `IDLE_INTERVAL_MS` (default 15000).

Worker **NEMA heartbeat ka bazi**. Ako padne, queue tiho raste — niko ne zna.

[supabaseClient.js](../../workers/loc-sync-mssql/src/supabaseClient.js) wrapper ima samo `claimBatch`, `markSynced`, `markFailed`. Treba mu jedna nova metoda `upsertHeartbeat(workerId, details)`.

## 3. Edge Function obrazac

Postoje 4 dispatch funkcije: `pb-notify-dispatch`, `sastanci-notify-dispatch`, `hr-notify-dispatch`, `maint-notify-dispatch`. Svi prate isti pattern:
- env: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API_KEY` (opciono → DRY-RUN), `RESEND_FROM`.
- pozivaju `<modul>_dispatch_dequeue(p_batch)` RPC sa SECURITY DEFINER + SKIP LOCKED.
- za svaki red: pokušaj slanja preko Resend API-ja → mark_sent / mark_failed sa exp. backoff.

Sprint preporuka: **kreirati novu `loc-sync-monitor-dispatch`** (ne reuse pb-dispatch). Razlog: Lokacije nemaju vlastiti notification outbox; svrha sync monitora je kratka i odvojena domena.

## 4. Admin email — gde su

**Nema centralne `admin_emails` tabele.** Postojeći obrasci po projektu:
- `user_roles (email PRIMARY KEY, role, is_active)` — email **direktno u tabeli**, ne preko `auth.users`.
- Filter `WHERE role IN ('admin','menadzment') AND is_active = true` koristi se širom kodbase-a.
- `maint_user_profiles.phone` postoji za WhatsApp (out of scope za Härd-3).
- `sastanci_notification_log.recipient_email` se zadaje **u trenutku enqueue-a** (kreator akcije, učesnik). Nije generička admin lista.

Za Härd-3 DEAD_LETTER digest i worker-down alert → **koristiće se `user_roles WHERE role IN ('admin','menadzment') AND is_active=true`**. Bez nove konfiguracione tabele. Ovo zadovoljava sprint zahtev „bez kreiranja novih konfiguracionih tabela".

## 5. Lokacije notification outbox — postojeći vs. nova tabela

Lokacije **nemaju svoj outbox**. Reuse `sastanci_notification_log` zahteva izmenu FK constraint-a (`related_sastanak_id`, `related_akcija_id` su NOT NULL preko CHECK ili business logike). Reuse `maint_notification_log` zahteva domen mapping na maintenance entitete.

Sprint daje slobodu: „Cursor odlučuje da li da uvodi novu tabelu ili reuse-uje postojeću". **Odluka:** nova `loc_sync_alerts_outbox` sa istim pattern-om kao postojeći (queued/sent/failed, attempts, next_attempt_at, exp. backoff). Tako:
- ne diramo postojeće `sastanci_*` / `maint_*` tabele,
- pratimo postojeći obrazac koji Edge funkcije razumeju,
- jasno odvojena domena (lokacije sync monitoring vs. operativna obaveštenja).

## 6. Plan implementacije

### Korak 2 migracija — `add_loc_sync_health_monitor.sql`
- `loc_sync_worker_heartbeat (worker_id PK, last_seen, details JSONB)` — worker uploaduje svakih 60s.
- RPC `loc_sync_worker_heartbeat_upsert(worker_id, details)` — SECURITY DEFINER, samo service_role.
- `loc_sync_alerts_outbox` — kind, recipient_email, subject, body_text, status, scheduled_at, next_attempt_at, attempts, error, payload.
- RPC `loc_sync_admin_emails()` STABLE SECURITY DEFINER — vraća listu emaila iz `user_roles` filter `role IN ('admin','menadzment') AND is_active`.
- RPC `loc_sync_health_check_and_enqueue()` SECURITY DEFINER — proverava:
  - DEAD_LETTER count > 0 → ako u poslednjih 24h nije bio digest, enqueue za sve admin emails.
  - Worker last_seen > 10 minuta → enqueue worker_down alert za sve admin emails.
  - Worker last_seen > 6 sati (dnevni heartbeat threshold) — ignoriše se ako je u radnom vremenu (nadzor je opcioni).
- RPC `loc_sync_dispatch_dequeue(p_batch)` SECURITY DEFINER, service_role only — Edge funkcija čita queue.
- RPC `loc_sync_dispatch_mark_sent` / `loc_sync_dispatch_mark_failed` SECURITY DEFINER.
- pg_cron job: `loc_sync_health_check_hourly` — svaki sat poziva `loc_sync_health_check_and_enqueue()`.

### Korak 3 — Edge funkcija `loc-sync-monitor-dispatch`
- Kopija sastanci-notify-dispatch pattern-a, prilagođena za `loc_sync_alerts_outbox`.
- Šalje preko Resend API-ja (env `RESEND_API_KEY`, `RESEND_FROM`).
- DRY-RUN ako `RESEND_API_KEY` nije postavljen.
- Supabase Scheduled Trigger svakih 5 minuta.

### Korak 4 — Frontend banner
- Novi helper `fetchLocSyncWorkerHealth()` u `services/lokacije.js` (čita `loc_sync_worker_heartbeat` + `count(DEAD_LETTER)`).
- Novi RPC `loc_sync_health_summary()` STABLE — vraća `{ workers: [...], dead_letter_count: N }`.
- `renderBridgeStaleBanner` ostaje za BigTehn cache. **Nova `renderSyncWorkerBanner`** dodaje paralelan banner za sync worker (red kad worker nije slao heartbeat 10 min, žuti za DEAD_LETTER count > 0).
- Banner se renderuje na dashboard tabu kao i bridge banner.

### Korak 5 — Worker heartbeat
- `supabaseClient.js`: nova metoda `upsertHeartbeat(workerId, details)`.
- `index.js`: `setInterval` svakih 60s poziva heartbeat. Cleanup u shutdown.

### Korak 6 — Runbook (M30)
- `docs/migration/loc_migration_order.md` — tabela: redni broj, ime, zavisnosti, idempotentno?, rollback.
- Query za proveru primenjenih migracija u Supabase (informational_schema lookup).

## 7. Sažetak — bez otvorenih pitanja

Sprint pravila kažu da Korak 2 može da krene odmah ako se admin email tabela pronađe. **Pronađena je: `user_roles WHERE role IN ('admin','menadzment')`**. Krećem direktno u Korak 2 bez čekanja potvrde.

Sve odluke koje sam doneo (nova outbox tabela, nova Edge funkcija, paralelan banner) su pokrivene sprint instrukcijama ("Cursor odlučuje", "napravi novu loc-sync-monitor da ne zaprljaš PB pipeline"). Ako se ne slažeš sa nekom — interrupt-uj i preusmeriću.

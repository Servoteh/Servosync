# CMMS — Automation i notifikacije (roadmap)

Ovaj dokument planira sledeći tehnički sloj posle stabilnog pilota.

## 1. Dnevni snapshot operacija (već u bazi)

View `public.v_maint_cmms_daily_summary` (migracija `add_maint_daily_ops_view.sql`, a na već postojećim bazama i `extend_maint_cmms_daily_summary.sql`) agregira za trenutnog korisnika (RLS):

- broj aktivnih radnih naloga
- otvoreni incidenti
- otvoreni kritični incidenti
- kasni preventivni rokovi
- delovi ispod minimalne zalihe
- otvoreni WO prioriteta P1 (`p1_zastoj`) i P2 (`p2_smetnja`)
- otvoreni WO sa isteklim `due_at` (kasni radni nalozi)

**UI:** dashboard `/maintenance` učitava isti pregled preko `fetchMaintCmmsDailySummary()` (PostgREST `v_maint_cmms_daily_summary?limit=1`).

## 2. Automatsko kreiranje WO za preventivu (cron)

Ručna akcija `Kreiraj WO` već postoji. Za potpuno automatsko kreiranje bez korisnika potrebno je:

- identitet za `reported_by` na WO (npr. servisni nalog `auth.users` ili posebno polje u `maint_settings`), ili
- Edge Function sa `service_role` koja poziva internu migracionu funkciju.

**Preporuka:** prvo pilot sa ručnim `Kreiraj WO`, pa odluka da li firma želi noćni batch.

Ako se koristi **pg_cron** (Supabase paid / self-hosted), prati isti obrazac kao u [`sql/migrations/add_kadr_notifications.sql`](../sql/migrations/add_kadr_notifications.sql):

```sql
-- Pseudokod: samo ako postoji pg_cron
-- SELECT cron.schedule('maint_preventive_daily', '0 6 * * *', $$ SELECT public.maint_...batch...() $$);
```

Implementacija batch funkcije treba da bude idempotentna (bez duplikata WO po `source_preventive_task_id`).

## 3. Kanali van aplikacije (email / WhatsApp / Telegram)

Trenutno se redovi queue-uju u `maint_notification_log`. Za stvarno slanje:

- worker (Edge Function, n8n, ili postojeći dispatch RPC) čita `queued` redove
- razrešava `recipient` po `target_role` iz payload-a pravila
- šalje preko izabranog provajdera

**Checklist pre produkcije:** SPF/DKIM za email, WhatsApp Business API odobrenje, Telegram bot token u Secrets.

## 4. Dashboard „šta danas“

Drugi red KPI na dashboardu pokriva: P1/P2 otvoreni WO, kasni WO (`due_at`), kritične incidente i delove ispod `min_stock` (iz `v_maint_cmms_daily_summary`), uz rezervne brojače iz lokalno učitanih WO kada snapshot nije dostupan.

Dodatno: preventiva danas / ove nedelje i ostali KPI ostaju iz postojećih upita u [`src/ui/odrzavanjeMasina/index.js`](../src/ui/odrzavanjeMasina/index.js). Lista WO podržava filter `?overdue=1` (kasni rok).

## 5. Zaključavanje WO (proces)

Dogovor sa šefom održavanja:

- obavezan komentar pri zatvaranju
- obavezni sati ako je WO duži od X sati
- obavezna lista delova za WO tipa `incident` sa severity `critical`

Te poslovne validacije mogu ići u trigger `BEFORE UPDATE` na `maint_work_orders` kada `status` prelazi u `zavrsen`.

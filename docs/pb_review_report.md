# Projektni biro (PB1–PB3) — izveštaj pregleda i PB4 backlog

**Namena:** Jedinstven dokument za čitanje posle završetka razvoja u Cursor-u.  
**Redosled čitanja:** prvo **Sažetak nalaza** (tabela ispod), zatim ostatak po potrebi.

---

## Sažetak nalaza

| Severity   | Otvoreni nalazi | Objašnjenje |
|-----------|-----------------|-------------|
| **KRITIČNI** | **0** | Nema aktivnih blokada za produkciju u ovom pregledu stanja repozitorijuma. Raniji kritičan propust — **neuspešan production build** jer `sbReqThrow` nije bio eksportovan iz `supabase.js`, pa je CDN/Pages mogao da servira star JS — **rešeno** na `main` (grana `cursor/fix-pb-build-bundle-f9da`). |
| **VISOKI** | **0** | Nema nezakrpljenih propusta koji zahtevaju hitan patch van PB4 planiranja. Sigurnosni DEFINER RPC-i imaju `SET search_path`; Edge dispatch zahteva service_role JWT. |
| **SREDNJI** | Backlog | Hardening RLS-a (vidi §5), performanse velikih fetch-eva (Izveštaji), Gantt performanse pri čestom re-renderu — ulaz za PB4 kada prioritet dozvoljava. |
| **NISKI** | Backlog | UX poboljšanja, WhatsApp kanal, PDF/Excel export, drag-drop Gantt — već u delu dokumentovanih „Potencijalni PB4“ u `Projektni_biro_modul.md`. |

---

## 1. Obuhvat pregleda

- **Frontend:** `src/ui/pb/*.js`, `src/styles/pb.css`, `src/services/pb.js`
- **Backend (SQL):** `sql/migrations/add_pb_module.sql`, `pb_load_stats_mechanical_engineering.sql`, `pb_mechanical_engineers_rpc.sql`, `add_pb_notifications.sql`
- **Edge:** `supabase/functions/pb-notify-dispatch/index.ts`
- **Testovi:** `src/ui/pb/__tests__/*.js`, Vitest suite

---

## 2. Arhitektura (kratko)

| Sloj | Odgovornost |
|------|-------------|
| **Postgres** | `pb_tasks`, `pb_work_reports`, `pb_notification_*`, RLS preko `pb_can_edit_tasks()`, SECURITY DEFINER RPC (`pb_get_load_stats`, `pb_get_mechanical_projecting_engineers`, enqueue/dispatch). |
| **REST/RPC** | Tanki klijent `sbReq` / `sbReqThrow` → PostgREST; PB servis bez supabase-js. |
| **UI** | Vanilla JS, tabovi Plan / Kanban / Gantt / Izveštaji / Analiza / Podešavanja; stanje `sessionStorage` ključ `pb_state_v1`. |
| **Notifikacije** | Outbox `pb_notification_log`, cron `pb_enqueue_notifications`, worker Edge + Resend. |

---

## 3. Nedavni incidenti i zaključci

| Tema | Šta se desilo | Zaključak |
|------|----------------|-----------|
| **„Svi“ umesto „Projektanti“ na Pages** | Kod na `main` je već imao RPC filter; korisnici su videli star bundle. | **Uvek proveriti `npm run build` u CI** pre merge-a; nedostajući export je fatalan jer Vite ne deploy-uje novi hash. |
| **`sbReqThrow` / `stopPbIzvestajiSpeech` / `pbErrorMessage`** | Importovani ali nedostajali u modulima → build fail. | Eksplicitno dodato u `supabase.js` i `shared.js`; `izvestajiTab` registruje SpeechRecognition za cleanup pri promeni taba. |

---

## 4. TODO u kodu → input za PB4

| Lokacija | TODO | Predlog PB4 |
|----------|------|-------------|
| `src/ui/pb/index.js` (file header) | Podeliti render Gantt zaglavlja i redova pri promeni filtera (referenca „E2“ u starijem tekstu). | Smanjiti full re-mount slušalaca; koristiti delegiranje / jedan `AbortController` po render ciklusu gde već nije urađeno. |

*Napomena:* U trenutnom stanju repozitorijuma **nema drugih `TODO(PB4)`** markera u `src/ui/pb/` osim gore; dodatni želje za PB4 su u `docs/Projektni_biro_modul.md` sekcija **„Potencijalni PB4 feature-i“** (Gantt drag-drop, WhatsApp, rezime po inženjeru, PDF/Excel, BigTehn RN integracija).

---

## 5. SREDNJI backlog (sigurnost i model)

- **`pb_work_reports` SELECT** — RLS politika `USING (true)` za sve authenticated (vidi `docs/RBAC_MATRIX.md`). To znači da svaki ulogovani korisnik vidi sve redove izveštaja sati. Ako poslovno treba ograničenje (npr. samo sopstveni + menadžment), potrebna je nova migracija politika — **prioritet SREDNJI** dok se eksplicitno ne traži promena.
- **`pb_notification_config` SELECT** — `USING (true)`; pragovi notifikacija su vidljivi svima; menjanje samo admin — tipično prihvatljivo; dokumentovati ako treba „tajna“ lista primalaca.

---

## 6. SREDNJI backlog (performanse i UX)

- **Izveštaji:** učitavanje velikog broja `pb_work_reports` (npr. godina × limit 8000) — razmotriti server-side agregat ili paginaciju za obračun.
- **Kanban:** optimistic update sa rollback-om — zadržati paritet sa API greškama.
- **Plan load meter:** usklađen sa `pb_get_mechanical_projecting_engineers` predikatom (Mašinsko projektovanje + legacy tekst).

---

## 7. Edge funkcija `pb-notify-dispatch`

- **`verify_jwt: false`** namerno — autentikacija je **Bearer service_role** u telu zahteva (ne ostavljati ključ u frontendu).
- Secrets: `SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API_KEY`, `RESEND_FROM`.
- Posle deploy-a proveriti da cron / scheduler poziva dispatch sa ispravnim secretima.

---

## 8. Checklista pre PB4 planiranja

1. `npm run build` — mora proći.
2. `npm test` — postojeći Vitest.
3. `npm run check:rbac-matrix` / `check:schema-baseline` — ako su u CI-u.
4. Supabase migracije iz `sql/ci/migrations.txt` primenjene na okruženje koje testirate.

---

## 9. Reference

- Modul spec: `docs/Projektni_biro_modul.md`
- Sprint analize: `docs/pb_sprint1_analysis.md`, `pb_sprint2_analysis.md`, `pb_sprint3_analysis.md`
- RBAC: `docs/RBAC_MATRIX.md` (sekcije `pb_*`)

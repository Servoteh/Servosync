# Sastanci — dokumentacija

Modul **Sastanci** upravlja operativnim sastancima (sedmični / projektni), **PM temama** (predlog, odobravanje, dodela), **akcionim planom** i **zapisnicima** (Faza B proširuje zapisnik i presek). Tehnička šema: [SUPABASE_PUBLIC_SCHEMA.md](./SUPABASE_PUBLIC_SCHEMA.md), RLS: [RBAC_MATRIX.md](./RBAC_MATRIX.md), `sql/migrations/add_sastanci_module.sql`, `harden_sastanci_rls_phase2.sql`, templati: `sql/migrations/add_sastanci_templates.sql` (kada se primeni).

Kod: `src/ui/sastanci/`, `src/services/sastanci.js`, `sastanciTemplates.js`, `src/state/sastanci.js`, `src/styles/sastanci.css`, REST: `sbReq()`.

Stack: **Vite + vanilla JS** (nema React-a), isti obrasac kao [Plan_montaze_modul.md](./Plan_montaze_modul.md) / [Kadrovska_modul.md](./Kadrovska_modul.md) — `kadrovska-header`, tab strip, `canEdit()`.

---

## Uloga modula

| | |
|---|---|
| **Svrha** | Redovna operativa: sastanci, dnevni red (PM teme), akcije sa rokovima, arhiva zaključanih. |
| **Korisnici** | Svi ulogovani: `canAccessSastanci()`. Pisanje: `canEditSastanci()` (admin, leadpm, pm, menadžment) — u UI često kroz `canEdit()`; HR i viewer read-only. |
| **Ulaz** | [moduleHub.js](../src/ui/hub/moduleHub.js) — kartica „Sastanci”. Ruta: History API, modul u `src/ui/router.js`. |
| **Auth** | [src/state/auth.js](../src/state/auth.js) — `getCurrentUser()`, `canEdit()`, `canAccessSastanci()`, `canEditSastanci()`, `canPrioritizeTeme()` (samo admin za „za razmatranje” / admin_rang). |

---

## Tabovi i fajlovi

Aktivni tab je u [state/sastanci.js](../src/state/sastanci.js) (`activeTab`), **bez** sessionStorage (za razliku od Kadrovske); korisničke preferencie za list/kalendar: `sessionStorage` ključ `sastanci:sastanci_view` (vidi [constants.js](../src/lib/constants.js) `SESSION_KEYS.SAST_SASTANCI_VIEW`).

| Tab (UI) | `activeTab` | Fajl |
|----------|----------------|------|
| Pregled | `dashboard` | [dashboardTab.js](../src/ui/sastanci/dashboardTab.js) — KPI, 3 widgeta (sledeći sastanak, moje akcije, moje teme), sekcije ispod. |
| Sastanci | `sastanci` | [sastanciTab.js](../src/ui/sastanci/sastanciTab.js) + [sastanciCalendar.js](../src/ui/sastanci/sastanciCalendar.js) — lista / kalendar, templati ([templatesModal.js](../src/ui/sastanci/templatesModal.js)). |
| PM teme | `pm-teme` | [pmTemeTab.js](../src/ui/sastanci/pmTemeTab.js) — sub-tabovi; nakon CTA sa Pregleda: `SAST_INTENT_PM_MOJE`. |
| Po projektu | `pregled-projekti` | [pregledPoProjektuTab.js](../src/ui/sastanci/pregledPoProjektuTab.js) |
| Akcioni plan | `akcioni-plan` | [akcioniPlanTab.js](../src/ui/sastanci/akcioniPlanTab.js) — filter „Samo moje” + `SAST_INTENT_AKCIJONI_MOJE` |
| Arhiva | `arhiva` | [arhivaTab.js](../src/ui/sastanci/arhivaTab.js) |
| Podešavanja | `podesavanja-notif` | [podesavanjaNotifikacijaTab.js](../src/ui/sastanci/podesavanjaNotifikacijaTab.js) — 6 toggle-a za email notifikacije. Deep link: `/sastanci/podesavanja-notifikacija`. |

**Zajednički UI:** [index.js](../src/ui/sastanci/index.js) — root + **FAB** [quickAddTemaButton.js](../src/ui/sastanci/quickAddTemaButton.js) (nova PM tema). Modali: [sastanakModal.js](../src/ui/sastanci/sastanakModal.js), [createSastanakModal.js](../src/ui/sastanci/createSastanakModal.js), [fazaBPlaceholder.js](../src/ui/sastanci/fazaBPlaceholder.js) (meso za Fazu B: pun detalj sastanka).

---

## Servisi

| Servis | Uloga |
|--------|--------|
| [sastanci.js](../src/services/sastanci.js) | Sastanci CRUD, učesnici, `loadDashboardStats`, `loadNextPlaniranSastanak`, `loadUcesniciForMany` |
| [sastanciDetalj.js](../src/services/sastanciDetalj.js) | `getSastanakFull()`, presek CRUD, slike upload/signedURL, `saveSnapshot()`, `zakljucajSaSapisanikom()` |
| [sastanciArhiva.js](../src/services/sastanciArhiva.js) | `uploadSastanakPdf()` → Storage `'sastanci-arhiva'`, `downloadSastanakPdf()` (signed URL), `regenerateSastanakPdf()` |
| [sastanciPrefs.js](../src/services/sastanciPrefs.js) | `getMyPrefs()` (RPC `sastanci_get_or_create_my_prefs`), `updateMyPrefs(patch)` |
| [sastanciTemplates.js](../src/services/sastanciTemplates.js) | Templati + `nextOccurrence`, `instantiateTemplate` |
| [pmTeme.js](../src/services/pmTeme.js) | `loadPmTeme` (uklj. `excludeStatuses`) |
| [akcioniPlan.js](../src/services/akcioniPlan.js) | `v_akcioni_plan`, filter po `odgovoranEmail` |
| [projekti.js](../src/services/projekti.js) | `loadProjektiLite` za selecte |

Status vrednosti `sastanci.status` (baza / UI): `planiran`, `u_toku`, `zavrsen`, `zakljucan` — vidi [sastanci.js SASTANAK_STATUSI](../src/services/sastanci.js).

---

## Baza (Supabase)

- **Faza A/B tabele:** `sastanci`, `sastanak_ucesnici`, `pm_teme`, `akcioni_plan`, `presek_aktivnosti`, `presek_slike`, `sastanak_arhiva` — sve u [add_sastanci_module.sql](../sql/migrations/add_sastanci_module.sql).
- **Faza C tabele (draft migracije, primeniti ručno):**
  - `sastanci_notification_prefs` — per-user toggle-i za 6 tipova notifikacija.
  - `sastanci_notification_log` — outbox tabela (pattern `maint_notification_log`), statusi `queued/sent/failed/skipped`.
- **Storage bucket `'sastanci-arhiva'`** — privatni, max 20 MB, samo `application/pdf`. Putanja: `{sastanak_id}/{timestamp}_zapisnik.pdf`.
- **Triggeri (Faza C):** `sast_notif_akcija_new`, `sast_notif_akcija_changed`, `sast_notif_meeting_locked`, `sast_notif_ucesnik_invite` — sve `SECURITY DEFINER`, enqueue-uju u outbox.
- **pg_cron (Faza C):** `sast_action_reminders_daily` (07:00 UTC), `sast_meeting_reminders_30min` (svakih 30 min).
- Templati: `sastanci_templates`, `sastanci_template_ucesnici` — nacrt u [add_sastanci_templates.sql](../sql/migrations/add_sastanci_templates.sql).

---

## Stilovi

[sastanci.css](../src/styles/sastanci.css) — prefiks `sast-*` / Faza A: `sast-fab`, `sast-kpi-compact`, `sastanak-status-*`, kalendar, widgeti Pregleda.

---

## Hub

Kartica u [moduleHub.js](../src/ui/hub/moduleHub.js) vodi u modul preko `onModuleSelect('sastanci')`.

---

## Konvencije

- UI strings: srpski. JS: `camelCase`, baza: `snake_case`.
- Email kao identitet korisnika (paritet `user_roles`).

---

## PDF zapisnik (Faza C)

PDF se generiše na klijentu (`jsPDF 2.5.1` via CDN) koristeći **Roboto** font (Apache 2.0, `public/fonts/`) koji se fetchuje na runtime. Srpski karakteri (čćžšđ...) su podržani.

**Generisanje:** [src/lib/sastanciPdf.js](../src/lib/sastanciPdf.js) — `generateSastanakPdf(sastanakFull) → Blob`.

**Layout (A4, 20 mm margine):**
- Header na svakoj strani: "SERVOTEH d.o.o." + "ZAPISNIK SA SASTANKA" + br. stranice
- Meta info tabela (datum, vreme, mesto, tip, vodio, zaključio)
- Učesnici (pozvan / prisutan)
- Zapisnik — svaka `presek_aktivnost` sa plain-text sadržajem (`sadrzaj_text`)
- Akcioni plan — tabela sa rokom i statusom
- Potpisi učesnika (koji su prisutni)

**Upload:** [src/services/sastanciArhiva.js](../src/services/sastanciArhiva.js) — `uploadSastanakPdf()` upisuje u Storage i ažurira `sastanak_arhiva.zapisnik_storage_path`.

**Lock flow** ([index.js](../src/ui/sastanci/sastanakDetalj/index.js)):
1. `zakljucajSaSapisanikom()` → status = `zakljucan` + snapshot
2. `generateSastanakPdf()` → `uploadSastanakPdf()`
3. Ako PDF padne → sastanak ostaje zaključan; u Arhiva tabu se prikazuje dugme za ponovni pokušaj

---

## Email notifikacije (Faza C)

**Outbox pattern:** triggeri u bazi upisuju u `sastanci_notification_log`; Edge function `sastanci-notify-dispatch` procesira redove i šalje email putem Resend API.

| Kind | Okidač |
|---|---|
| `akcija_new` | INSERT na `akcioni_plan` sa `odgovoran_email` |
| `akcija_changed` | UPDATE `status/rok/odgovoran_email/naslov` na `akcioni_plan` |
| `meeting_invite` | INSERT na `sastanak_ucesnici` dok je parent `status='planiran'` |
| `meeting_locked` | UPDATE `status='zakljucan'` na `sastanci` |
| `action_reminder` | pg_cron 07:00 UTC — sve otvorene akcije kojima rok ≤ sutra |
| `meeting_reminder` | pg_cron svakih 30 min — sastanci koji počinju za 15–45 min |

**Edge function:** [supabase/functions/sastanci-notify-dispatch/](../supabase/functions/sastanci-notify-dispatch/) — `index.ts` + `templates.ts` + README.

**WhatsApp:** kanal je pripremljen u šemi (`channel='whatsapp'`), ali Edge function ga odmah markira `failed` sa porukom "not enabled in this version (Faza C)".

**Per-user opt-out:** `sastanci_notification_prefs` — 6 boolean toggle-a. Default sve `true`. UI: Podešavanja tab.

---

## Podešavanja notifikacija (Faza C)

7. tab modula Sastanci — `id: 'podesavanja-notif'`.

- 6 toggle-a grupisana u "Akcije" i "Sastanci" sekcije
- WhatsApp toggle prikazan, disabled sa objašnjenjem
- Save dugme → `PATCH /sastanci_notification_prefs`
- Deep link iz email footer-a: `/sastanci/podesavanja-notifikacija`

Servis: [src/services/sastanciPrefs.js](../src/services/sastanciPrefs.js).

---

## Istorija razvoja

### F.C — PDF zapisnik + notifikacije (2026-04-26)

Implementirano (draft fajlovi, ne primenjivati bez review-a):

**SQL (6 migracija):** `add_sastanci_notification_prefs.sql`, `add_sastanci_notification_outbox.sql`, `add_sastanci_notification_triggers.sql`, `add_sastanci_arhiva_storage.sql`, `add_sastanci_dispatch_rpc.sql`, `add_sastanci_reminder_jobs.sql`.

**Edge function:** `supabase/functions/sastanci-notify-dispatch/` (index.ts + templates.ts + README).

**UI:**
- `src/lib/sastanciPdf.js` — jsPDF + Roboto generator
- `public/fonts/Roboto-Regular.ttf`, `Roboto-Bold.ttf` — fontovi committovani u repo
- `src/services/sastanciArhiva.js` — upload/download/regen PDF
- `src/services/sastanciPrefs.js` — prefs CRUD
- `arhivaTab.js` (refactor) — PDF dugmad umesto placeholdera
- `index.js` (detalj, modify) — lock handler: status → PDF → upload
- `podesavanjaNotifikacijaTab.js` — 7. tab sa toggle-ima
- `index.js` (modul, modify) — 7. tab registracija + `sastanciTab` deep link
- `appPaths.js` (modify) — `/sastanci/podesavanja-notifikacija` ruta
- `router.js` (modify) — prosledi `sastanciTab`

---

### F.B — Detalj sastanka (2026-04-26)

**Commit:** `feat(sastanci): Faza B — detalj route, kanban, pripremi/zapisnik/akcije/arhiva tabovi`

Implementirano:

- **Ruta `/sastanci/<uuid>`** — deep link, `buildSastanakDetaljPath()` u `appPaths.js`, router prihvata `opts.sastanakId`.
- **`src/services/sastanciDetalj.js`** — `getSastanakFull()`, `pocniSastanak()`, `zakljucajSaSapisanikom()`, `otvojiPonovo()`, presek CRUD, slike upload/delete/signedURL, `saveSnapshot()`.
- **`src/ui/sastanci/sastanakDetalj/index.js`** — shell sa headerom, status badge, učesnici avatari, status machine dugmad, 4 interna taba.
- **`pripremiTab.js`** — meta edit modal, učesnici tabela (RSVP: pozvan/prisutan), dnevni red (pm_teme sa drag-drop reorder za admina), beleška organizatora (auto-save debounce).
- **`zapisnikTab.js`** — `presek_aktivnosti` CRUD, rich-text editor (`contenteditable` + `document.execCommand` toolbar, custom sanitizer `lib/htmlSanitize.js`), upload slika → Storage `'sastanak-slike'`, drag-drop reorder sekcija.
- **`akcijeTab.js`** — akcioni plan filtriran po `sastanak_id`, inline create/edit/delete modal.
- **`arhivaTab.js`** — info o zaključavanju, snapshot JSON download, refresh snapshot, PDF placeholder (disabled — Faza C).
- **Akcioni plan Kanban** — `akcioniPlanKanban.js`, 3 kolone (Otvorene / Završene / Odložene), HTML5 drag-drop menja status PATCH.
- **PM teme** — sort `adminRang ASC NULLS LAST` → `prioritet ASC`, “📅 Stavi na sastanak” (admin), 🔥 Hitno toggle, 🎯 Za razmatranje toggle, inline rang input.

**Status machine (implementiran, bez novih SQL):**
```
planiran → [Počni]     → u_toku
u_toku   → [Zaključaj] → zakljucan  (+saveSnapshot)
zakljucan → [Otvori]   → u_toku     (admin only — JS PATCH, bez RPC)
zavrsen   → tretira se kao zakljucan (legacy)
```

**SQL za F.B:** Nema novih migracija. Sve tabele (`presek_aktivnosti`, `presek_slike`, `sastanak_arhiva`, Storage bucket `'sastanak-slike'`) su bile u `add_sastanci_module.sql`.

---

### F.A — Quick wins (2026-04-26)

- Pregled: prazan hero + 3 widgeta, kompaktan KPI red; „Vidi sve” prebacuje na PM teme / Akcioni plan sa namenskim filterom (session).
- Sastanci tab: prekidač Lista / Kalendar (`sastanci:sastanci_view`), status pill-ovi po stvarnim DB ključevima, placeholder modal za Fazu B, templatе (nakon SQL migracije).
- Servis + UI templata, FAB za brzu temu, dokumentacija, `add_sastanci_templates.sql` (ručno u Supabase).

---

## Deploy SQL

Za novu instalaciju, primeniti redom u Supabase SQL Editoru:

**Faza A/B (primenjeno):**
1. `add_sastanci_module.sql` — tabele, RLS, Storage `'sastanak-slike'`, `v_akcioni_plan`
2. `harden_sastanci_rls_phase2.sql` — Model B RLS, helperi `is_sastanak_ucesnik`, `current_user_is_management`
3. `add_sastanci_templates.sql` — templati (opciono)

**Faza C (draft — primeniti posle review-a):**
4. `add_sastanci_notification_prefs.sql`
5. `add_sastanci_notification_outbox.sql`
6. `add_sastanci_notification_triggers.sql`
7. `add_sastanci_arhiva_storage.sql`
8. `add_sastanci_dispatch_rpc.sql`
9. `add_sastanci_reminder_jobs.sql`

**Edge function deploy (posle SQL):**
```bash
supabase functions deploy sastanci-notify-dispatch --no-verify-jwt
```
Secrets: `RESEND_API_KEY`, `RESEND_FROM`, `VITE_PUBLIC_APP_URL`.

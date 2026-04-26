# Sastanci modul — Faza C (plan)

**Datum:** 2026-04-26  
**Status:** ČEKA ODOBRENJE — ne pisati kod pre OK

---

## 1. Verifikacija (findings iz analize)

### 1a. RESEND_API_KEY i RESEND_FROM

**Zaključak: visoka sigurnost da postoje.**

`hr-notify-dispatch/index.ts` referencira oba kao Supabase secrets i hardkodira
default `RESEND_FROM = 'noreply@servoteh.rs'`. Funkcija je deployovana i aktivna
— tj. secrets su postavljeni. Nova `sastanci-notify-dispatch` funkcija koristi
iste secrets (Supabase secrets su globalni per-projekat, ne per-function).

### 1b. jsPDF verzija — addFileToVFS podrška

**Zaključak: ✅ podržano.**

`src/lib/pdf.js` učitava `jspdf@2.5.1` sa CDN-a. jsPDF 2.x ima `addFileToVFS()`
i `addFont()` u core-u — nema potrebe za addonom. Nova `src/lib/sastanciPdf.js`
reuse-uje isti CDN load pattern, pa nema nove npm zavisnosti.

Font strategija: Roboto TTF fajlovi idu u `public/fonts/` (servovani sa
sopstvenog origin-a). `sastanciPdf.js` ih učitava via `fetch('/fonts/Roboto-Regular.ttf')`
→ `arrayBuffer()` → base64 → `addFileToVFS()`. Bez CDN fetcha, bez bloat-a u JS
bundle-u, offline-kompatibilno.

### 1c. Logo Servoteh

**Zaključak: logo ne postoji u repou.**

Jedini pronađeni SVG je `public/icons/servoteh-lokacije.svg` (ikona za lokacije
modul, nije logo kompanije). Nema `assets/` foldera. → PDF ide **bez loga**,
samo tekstualni header: "SERVOTEH d.o.o." + "ZAPISNIK SA SASTANKA".

### 1d. `sastanak_arhiva.zapisnik_storage_path` kolona

**Zaključak: ✅ postoji.**

Potvrđeno iz `docs/SUPABASE_PUBLIC_SCHEMA.md`:

```
| sastanak_arhiva | zapisnik_storage_path | text | YES |
| sastanak_arhiva | zapisnik_size_bytes   | bigint | YES |
| sastanak_arhiva | zapisnik_generated_at | timestamptz | YES |
```

Kolona čeka da se popuni — ovo je tačno mesto za storage path PDF-a.

### 1e. Storage bucketi

| Bucket | Postoji? | Napomena |
|---|---|---|
| `sastanak-slike` | ✅ DA | Kreiran u `add_sastanci_module.sql`, 10MB, image+PDF |
| `sastanci-arhiva` | ❌ NE | Treba kreirati — za PDF zapisnike |
| `sastanci-presek` | ❌ NE | Nikada nije kreiran; Faza B koristi `sastanak-slike` |

→ Faza C kreira samo `sastanci-arhiva` (PDF; `application/pdf` MIME, 20MB limit).

### 1f. Status vrednosti (potvrđeno)

```
sastanci.status:       'planiran' | 'u_toku' | 'zavrsen' | 'zakljucan'
akcioni_plan.status:   'otvoren' | 'u_toku' | 'zavrsen' | 'kasni' | 'odlozen' | 'otkazan'
```

Triggeri za notifikacije se vežu za:
- `sastanci.status` → `'zakljucan'` (AFTER UPDATE)
- `akcioni_plan.odgovoran_email` → AFTER INSERT
- `akcioni_plan` (status/rok/odg promena) → AFTER UPDATE

### 1g. pg_cron dostupnost

**Zaključak: ✅ dostupan.**

`add_loc_step4_pgcron.sql` kreira pg_cron job i koristi `extensions` schema
(`CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions`). Projekat je
na PAID Supabase planu — pg_cron je dostupan.

Cron pattern (iz hr-notify-dispatch README): `net.http_post()` iz pg_cron SQL joба.

### 1h. X-Audit-Actor u hr-notify-dispatch

**Gap:** `hr-notify-dispatch/index.ts` NE šalje `X-Audit-Actor` header u `rpc()`
pozivu. Brief traži ovaj header. Nova `sastanci-notify-dispatch` ga MORA
uključiti (reference: `workers/loc-sync-mssql/src/supabaseClient.js`).

### 1i. VITE_PUBLIC_APP_URL

**Gap:** Nije u `.env.example` i nije u `.env`. Potreban za "Promeni
podešavanja" link u footer-u emaila.

→ Dodati u `.env.example` kao `VITE_PUBLIC_APP_URL=https://app.servoteh.rs`
(ili koji god je produkcioni URL). Koristiti u template-ima kao fallback
`'https://app.servoteh.rs'` ako nije set.

---

## 2. Trenutno stanje (Faza A + B)

| Komponenta | Status |
|---|---|
| Dashboard, lista, templati, FAB | ✅ Faza A |
| Deep link `/sastanci/<uuid>`, 4 interna taba | ✅ Faza B |
| Priprema tab (učesnici, dnevni red) | ✅ Faza B |
| Zapisnik tab (rich-text, slike) | ✅ Faza B |
| Akcije tab + Kanban | ✅ Faza B |
| Arhiva tab — PDF dugme DISABLED | ✅ placeholder Faza B |
| Status machine planiran→u_toku→zakljucan+snapshot | ✅ Faza B |
| Reopen (admin) | ✅ Faza B |
| PDF generisanje | ❌ Faza C |
| Email notifikacije | ❌ Faza C |
| Podešavanja notifikacija | ❌ Faza C |

---

## 3. Šta dodajem u Fazi C

### 3.1 Novi fajlovi

| Fajl | Opis |
|---|---|
| `src/lib/fonts/Roboto-Regular.ttf` | Font (Apache 2.0, commit u repo) |
| `src/lib/fonts/Roboto-Bold.ttf` | Font (Apache 2.0, commit u repo) |
| `src/lib/sastanciPdf.js` | PDF generator — `generateSastanakPdf(sastanakFull, opts)→Blob` |
| `src/services/sastanciArhiva.js` | Upload/download/regen PDF, update arhiva record |
| `src/services/sastanciPrefs.js` | `getMyPrefs()`, `updateMyPrefs()` CRUD |
| `src/ui/sastanci/podesavanjaNotifikacijaTab.js` | 7. tab — 6 toggle-a, WhatsApp disabled |
| `supabase/functions/sastanci-notify-dispatch/index.ts` | Edge dispatcher |
| `supabase/functions/sastanci-notify-dispatch/templates.ts` | Email templates (6 kind-a) |
| `supabase/functions/sastanci-notify-dispatch/README.md` | Deploy + secrets + cron |

### 3.2 Modifikovani fajlovi

| Fajl | Izmena |
|---|---|
| `src/ui/sastanci/sastanakDetalj/arhivaTab.js` | Uključi PDF buttons, istorija |
| `src/ui/sastanci/sastanakDetalj/index.js` | Lock handler: status → PDF → (notif via trigger) |
| `src/ui/sastanci/index.js` | Dodaj 7. tab "Podešavanja" ⚙ |
| `src/state/sastanci.js` | Dodaj `SAST_PREFS_VIEW` state ako treba |
| `src/styles/sastanci.css` | Stilovi za prefs tab, toggle-ovi |
| `src/ui/router.js` / `src/lib/appPaths.js` | Alias `/sastanci/podesavanja-notifikacija` |
| `.env.example` | Dodati `VITE_PUBLIC_APP_URL` |
| `docs/Sastanci_modul.md` | Sekcije: PDF, Notifikacije, Podešavanja, F.C istorija |

### 3.3 SQL migracije (6 fajlova — DRAFT, ne pokretati)

| Redosled | Fajl |
|---|---|
| 1 | `sql/migrations/add_sastanci_notification_prefs.sql` |
| 2 | `sql/migrations/add_sastanci_notification_outbox.sql` |
| 3 | `sql/migrations/add_sastanci_notification_triggers.sql` |
| 4 | `sql/migrations/add_sastanci_arhiva_storage.sql` |
| 5 | `sql/migrations/add_sastanci_dispatch_rpc.sql` |
| 6 | `sql/migrations/add_sastanci_reminder_jobs.sql` |

---

## 4. Šema baze — promene

### NOVA tabela: `sastanci_notification_prefs`

```sql
email                  text PRIMARY KEY  -- lower(email), paritet sa user_roles
on_new_akcija          boolean DEFAULT true
on_change_akcija       boolean DEFAULT true
on_meeting_invite      boolean DEFAULT true
on_meeting_locked      boolean DEFAULT true
on_action_reminder     boolean DEFAULT true
on_meeting_reminder    boolean DEFAULT true
email_address          text    -- override (NULL = koristi PK)
updated_at             timestamptz NOT NULL DEFAULT now()
```

RLS: `lower(email) = lower(auth.jwt()->>'email')` OR admin.  
RPC: `sastanci_get_or_create_my_prefs()` — SECURITY DEFINER, vrati ili kreiraj
default red. GRANT TO authenticated.

### NOVA tabela: `sastanci_notification_log` (outbox)

Kolone po brifu. Ključne napomene:
- `kind` text NOT NULL — vrednosti: `'akcija_new' | 'akcija_changed' | 'meeting_invite' | 'meeting_locked' | 'action_reminder' | 'meeting_reminder'`
- `channel` text NOT NULL DEFAULT 'email' CHECK (`'email' | 'whatsapp'`)
- `status` text NOT NULL DEFAULT 'queued' CHECK (`'queued' | 'sent' | 'failed' | 'skipped'`)
- `next_attempt_at` sa exponential backoff (pattern iz `maint_notify_dispatch_rpc`)
- `created_by_email` — NULL za cron, email za ručne akcije

Indeksi:
```sql
CREATE INDEX ON sastanci_notification_log (status, next_attempt_at)
  WHERE status IN ('queued', 'failed');
CREATE INDEX ON sastanci_notification_log (recipient_email, kind, created_at DESC);
CREATE INDEX ON sastanci_notification_log (related_sastanak_id)
  WHERE related_sastanak_id IS NOT NULL;
CREATE INDEX ON sastanci_notification_log (related_akcija_id)
  WHERE related_akcija_id IS NOT NULL;
```

RLS:
- SELECT: `recipient_email = lower(auth.jwt()->>'email')` OR admin/menadzment
- INSERT: `has_edit_role()` (triggeri i edge funkcije pišu)
- UPDATE/DELETE: admin only

### NOVI triggeri na `akcioni_plan`

```
AFTER INSERT  → enqueue 'akcija_new'     za odgovoran_email
AFTER UPDATE  → ako rok|status|odg promenjen:
                enqueue 'akcija_changed'  za NEW.odgovoran_email
                (ako je odg_email promenjen → 'akcija_new' za NEW, ništa za OLD)
```

### NOVI trigger na `sastanci`

```
AFTER UPDATE status → 'zakljucan':
  enqueue 'meeting_locked' za SVE učesnike (JOIN sastanak_ucesnici)
AFTER UPDATE status → 'planiran' (iz NULL/draft — novi insert):
  Ne treba; pozivnica se šalje ručno iz UI pri kreiranju, ili...
```

**⚠ Pitanje #1** — vidi dole.

### NOVI trigger na `sastanak_ucesnici`

```
AFTER INSERT → ako parent sastanak status='planiran':
  enqueue 'meeting_invite' samo za novog učesnika
```

### STORAGE — novi bucket `sastanci-arhiva`

```sql
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('sastanci-arhiva', 'sastanci-arhiva', false,
        20971520,  -- 20 MB
        ARRAY['application/pdf']);
```

Storage RLS:
- SELECT: `has_edit_role()` (ili proveri da li je učesnik tog sastanka — složenije, za sad edit_role)
- INSERT: `has_edit_role()`
- UPDATE: admin only
- DELETE: admin only

### DISPATCH RPC-ovi (samo service_role)

```
sastanci_dispatch_dequeue(p_batch int) → SETOF sastanci_notification_log
sastanci_dispatch_mark_sent(p_ids uuid[]) → int
sastanci_dispatch_mark_failed(p_id uuid, p_error text, p_backoff_sec int) → void
```

Pattern: copy iz `maint_dispatch_dequeue/mark_sent/mark_failed` —
jedino menjamo ime tabele. REVOKE/GRANT isti obrazac.

### REMINDER funkcije (za pg_cron)

```
public.sastanci_enqueue_action_reminders()
  → akcioni_plan WHERE status NOT IN ('zavrsen','otkazan')
                   AND rok <= CURRENT_DATE + 2
                   AND odgovoran_email IS NOT NULL
  → jedan 'action_reminder' red po odgovoran_email (digest u payload-u)

public.sastanci_enqueue_meeting_reminders()
  → sastanci WHERE status='planiran'
               AND datum = (CURRENT_DATE + INTERVAL '1 day')
               AT TIME ZONE 'Europe/Belgrade'
  → 'meeting_reminder' za učesnike; idempotent check da ne duplira
```

pg_cron jobovi:
```sql
SELECT cron.schedule('sast_action_reminders',  '0 7 * * *',  'SELECT public.sastanci_enqueue_action_reminders()');
SELECT cron.schedule('sast_meeting_reminders', '*/30 * * * *', 'SELECT public.sastanci_enqueue_meeting_reminders()');
```

---

## 5. Edge function arhitektura

**`supabase/functions/sastanci-notify-dispatch/index.ts`**

Pattern: direktan reuse `hr-notify-dispatch/index.ts` strukture.

Razlike vs hr-notify-dispatch:
1. `rpc()` helper dodaje `'X-Audit-Actor': 'sastanci-notify-dispatch@edge.servoteh'`
2. Dequeue zove `sastanci_dispatch_dequeue`, ne `kadr_dispatch_dequeue`
3. WhatsApp: odmah `mark_failed('WhatsApp not enabled in this version', no_retry=true)`
4. Email: `buildEmailFor(kind, payload, recipient)` iz `templates.ts`
5. Reply-To: iz `payload.organizator_email` (ako postoji u payload JSON-u)
6. Ako `RESEND_API_KEY` nije set → DRY-RUN (mark_sent + console.log)
7. Resend response: 4xx → mark_failed permanent (no retry); 5xx/network → mark_failed with backoff

Env vars:
```
SUPABASE_URL              (auto)
SUPABASE_SERVICE_ROLE_KEY (auto)
RESEND_API_KEY            (opciono — DRY-RUN bez njega)
RESEND_FROM               (default: noreply@servoteh.rs)
VITE_PUBLIC_APP_URL       (za unsubscribe link)
SAST_DISPATCH_BATCH       (default: 20)
```

**`templates.ts`** — `buildEmailFor(kind, payload, recipient): { subject, html, text }`

| kind | subject | highlight |
|---|---|---|
| `akcija_new` | "Nova akcija: \<naslov\>" | Ko dodeluje, rok, link na sastanak |
| `akcija_changed` | "Akcija ažurirana: \<naslov\>" | Šta se promenilo (diff u payload-u) |
| `meeting_invite` | "Pozivnica: \<naslov\> — \<datum\>" | Datum, vreme, mesto |
| `meeting_locked` | "Zapisnik: \<naslov\>" | Link na PDF (signed URL ili app link) |
| `action_reminder` | "Podsetnik: N tvojih akcija ima rok uskoro" | Lista akcija tabela |
| `meeting_reminder` | "Sutra: \<naslov\> u \<vreme\>" | Mesto, organizator |

HTML: inline CSS, max-width 600px, Servoteh boja `#2563eb`.  
Footer: `Ovo je automatska poruka iz Servoteh sistema. <a href="...">Promeni podešavanja</a>`

---

## 6. PDF arhitektura

**`src/lib/sastanciPdf.js`**

```
generateSastanakPdf(sastanakFull, options) → Promise<Blob>
  options: { includeImages: boolean, includeAkcije: boolean }

Tok:
  1. loadPdfLibs() — reuse iz pdf.js (CDN jsPDF 2.5.1)
  2. Fetch '/fonts/Roboto-Regular.ttf' → arrayBuffer → base64
  3. Fetch '/fonts/Roboto-Bold.ttf' → arrayBuffer → base64
  4. doc.addFileToVFS / addFont za oba
  5. Gradi PDF (A4, 20mm margine)
  6. return doc.output('blob')
```

**Fontovi:** `public/fonts/Roboto-Regular.ttf`, `public/fonts/Roboto-Bold.ttf`
(preuzeti sa fonts.google.com, Apache 2.0, commit u repo — ne skinati u runtime).

**PDF layout (A4):**

```
HEADER (ponovi na svakoj strani):
  Levo: "SERVOTEH d.o.o."
  Sredina: "ZAPISNIK SA SASTANKA"
  Desno: "Strana N od M"

S1 — META:
  Naslov (16pt bold)
  ─────────────────
  Datum | <datum>
  Vreme | <vreme ili —>
  Mesto | <mesto ili —>
  Tip   | <tip>
  Vodio | <label/email>
  Zapisničar | <label/email>
  ─────────────────
  UČESNICI: tabela Ime | Pozvan ✓/✗ | Prisutan ✓/✗

S2+ — DNEVNI RED:
  Za svaku pm_temu vezanu za ovaj sastanak (status usvojeno, sastanak_id=ovaj)

S3+ — ZAPISNIK:
  Za svaku presek_aktivnost (redosled):
    naslov + RB (bold), meta red (odg, rok, status)
    sadrzaj_text (plain paragraphs)
    slike (ako includeImages=true): fetch signedURL → embed, max 4/strana

SN — AKCIONI PLAN (ako includeAkcije=true):
  Tabela: RB | Naslov | Odgovoran | Rok | Status

SN+1 — POTPISI:
  Lista učesnika sa linijom za potpis
```

**`src/services/sastanciArhiva.js`**

```js
uploadSastanakPdf(sastanakId, blob)
  → PUT sastanci-arhiva/<sastanakId>/<ISO>_zapisnik.pdf
  → PATCH sastanak_arhiva SET zapisnik_storage_path, size, generated_at

downloadSastanakPdf(sastanakId)
  → signed URL (TTL 300s) → window.open

regenerateSastanakPdf(sastanakId)
  → getSastanakFull → generateSastanakPdf → uploadSastanakPdf (novi timestamp)
```

**`src/ui/sastanci/sastanakDetalj/index.js` — lock handler (MODIFY):**

```
[Zaključaj] klik:
  1. zakljucajSaSapisanikom(id)            // status + snapshot
  2. getSastanakFull(id)                   // svež podatak
  3. generateSastanakPdf(full)             // → Blob
  4. uploadSastanakPdf(id, blob)           // → path
  Ako 3 ili 4 padne:
    → reload, prikaži banner "PDF neuspešan — klikni Re-generiši"
    → notifikacije su enqueued via DB trigger (ne zavise od PDF-a)
```

**`src/ui/sastanci/sastanakDetalj/arhivaTab.js` (REFACTOR):**
- "📄 Generiši PDF zapisnik" dugme: enabled za `zakljucan`
- "📥 Skini PDF" — ako `zapisnik_storage_path` postoji
- "🔄 Re-generiši PDF" (admin/menadzment)
- Info: ko je generisao + kad

---

## 7. UI — Podešavanja notifikacija

**7. tab u modulu:** `id: 'podesavanja'`, label: `'Podešavanja'`, ikona: `⚙`

```
Naslov: "Notifikacije"
Podnaslov: "Izaberi koje notifikacije primaš putem email-a."

[Akcije]
  [toggle] Nova akcija dodeljena meni         on_new_akcija
  [toggle] Promena moje akcije (rok, status)  on_change_akcija
  [toggle] Dnevni podsetnik za rokove (07:00) on_action_reminder

[Sastanci]
  [toggle] Pozivnica na sastanak              on_meeting_invite
  [toggle] Sastanak zaključan — link na PDF   on_meeting_locked
  [toggle] Podsetnik 24h pre sastanka         on_meeting_reminder

Email: <user.email> (read-only)

[WhatsApp — DISABLED]
  tooltip: "Uskoro — čekamo odobrenje Meta Business naloga"

[Sačuvaj] → toast "Podešavanja sačuvana"
```

Servis: `src/services/sastanciPrefs.js`
- `getMyPrefs()` → poziva `sastanci_get_or_create_my_prefs()` RPC
- `updateMyPrefs(patch)` → PATCH `sastanci_notification_prefs` WHERE email=me

Deep link: `/sastanci/podesavanja-notifikacija` → alias u appPaths za `podesavanja` tab.

---

## 8. Redosled implementacije (po odobrenju)

```
C-SQL:   6 SQL migracija (draft → OK → korisnik pokreće ručno)
C-Edge:  supabase/functions/sastanci-notify-dispatch/ (draft → OK → deploy ručno)
C-Fonts: public/fonts/Roboto-*.ttf (preuzeti + commit)
C-PDF:   src/lib/sastanciPdf.js + src/services/sastanciArhiva.js
C-Arhiva: arhivaTab.js refactor + index.js lock handler
C-Prefs: sastanciPrefs.js + podesavanjaNotifikacijaTab.js
C-Tab:   7. tab u index.js + router alias
C-Docs:  Sastanci_modul.md + SECURITY.md
```

---

## 9. Pitanja — čekaju odgovor pre implementacije

### ❓ Pitanje #1 — BLOKIRAJUĆE: Kad se šalje pozivnica (`meeting_invite`)?

Brief kaže trigger na `sastanci` za `status='zakazan'` — ali u bazi nema
`'zakazan'` status (postoji `'planiran'`). Opcije:

**(A)** Pozivnica se šalje AUTOMATSKI pri INSERT u `sastanak_ucesnici`
(svaki put kad se doda učesnik na `planiran` sastanak) — trigger na
`sastanak_ucesnici AFTER INSERT`.

**(B)** Pozivnica se šalje RUČNO iz UI — dugme "📨 Pošalji pozivnice" u
Priprema tabu, koje enqueue-uje `meeting_invite` za sve učesnike.

**(C)** Nema `meeting_invite` notifikacije u Fazi C — samo `meeting_locked`
(kad je zapisnik gotov) i reminder 24h pre.

**Preporuka: (A)** — automtski trigger pri dodavanju učesnika. Ako se učesnik
doda na već planiran sastanak, odmah dobija pozivnicu. Idempotent check:
da li je isti (sastanak_id, recipient_email, kind='meeting_invite') već
`queued` ili `sent` — ako da, preskoči.

---

### ❓ Pitanje #2 — PDF signed URL u `meeting_locked` emailu

Kad se šalje `meeting_locked` email, link na PDF mora biti ili:
**(A)** Supabase signed URL (TTL npr. 7 dana) — generiše se u momentu slanja
u Edge funkciji. Ako korisnik otvori email posle 7 dana, link je istekao.

**(B)** Link na app (`/sastanci/<id>?tab=arhiva`) — korisnik klikne, prijavi
se i preuzme PDF iz app-a. Dugotrajna veza.

**Preporuka: (B)** — link na app, bez signed URL-a u emailu. Signed URL
se generiše tek kad korisnik klikne "Skini PDF" u app-u.

---

### ❓ Pitanje #3 — Re-generiši PDF: nova verzija ili overwrite?

Brief kaže "novi timestamp, update arhiva" — što znači stara verzija se
gubi (UPSERT, ne insert). Da li hoćemo:

**(A)** Samo jedna verzija PDF-a po sastanku (UPSERT `zapisnik_storage_path`)
→ simpler, manje storage

**(B)** Istorija versija: `sastanak_arhiva` tabela ima jednu kolonu, ali Storage
sadrži sve verzije (stare patheve u payload snapshota). Admin može da doda
`GET /list` i vidi istoriju.

**Preporuka: (A)** — jedna verzija, simpler. Ako treba audit trail, snapshot
JSONB beleži kad je zadnji PDF generisan.

---

### ❓ Pitanje #4 — Enqueue enqueue iz `zakljucajSaSapisanikom` ili samo iz DB triggera?

Kad se sastanak zaključa, `meeting_locked` obaveštenje treba stići svim učesnicima.
Trigger na `AFTER UPDATE status='zakljucan'` to automatski enqueue-uje.
Ali brief kaže "ne šalji ako PDF padne". Da li:

**(A)** Trigger enqueue odmah (pre PDF koraka u JS) — korisnik dobija email
sa linkom ka app-u (pitanje #2B), PDF možda nije tu još.

**(B)** PDF se generiše EERST u JS, tek onda se ručno poziva RPC da enqueue
notifikacije (bez DB triggera za `meeting_locked`).

**Preporuka: (A) ako idemo sa /B app linka** — trigger enqueue odmah, link
vodi na app gde PDF postaje dostupan. Korisnik klikne, PDF je tu (ili banner
"Re-generiši" ako je korak pao).

---

### ❓ Pitanje #5 — 7. tab ili header dropdown za Podešavanja?

Modul već ima 6 tabova. Sa `Podešavanja` kao 7. tabom, tab strip može biti
gužva na manjim ekranima. Alternativa: ⚙ dugme u header-u modula
(pored theme toggle) koje otvara modal overlay.

**Preporuka: Modal** — tab strip je već širok, podešavanja se ne koriste
svakodnevno, modal je čistiji. Ako preferiš 7. tab, mogu i tak.

---

### ❓ Pitanje #6 — `VITE_PUBLIC_APP_URL` vrednost

Šta je produkcioni URL aplikacije? Primeri:
- `https://plan.servoteh.rs`
- `https://app.servoteh.rs`
- `https://servoteh-plan-montaze.pages.dev`

Ovo će biti ugrađeno u email footer link za Podešavanja.

---

## 10. Deploy redosled (posle OK + implementacije)

```
1. Preuzeti Roboto fontove (Google Fonts), staviti u public/fonts/, commit
2. Supabase SQL Editor — pokreni 6 migracija, redom
3. Verifikacija:
   SELECT count(*) FROM sastanci_notification_prefs;
   SELECT count(*) FROM sastanci_notification_log;
   SELECT name FROM storage.buckets WHERE id = 'sastanci-arhiva';
4. Dodati env secrets u Supabase Dashboard ako fale:
   VITE_PUBLIC_APP_URL
   (RESEND_API_KEY i RESEND_FROM verovatno već postoje)
5. supabase functions deploy sastanci-notify-dispatch --no-verify-jwt
6. pg_cron jobovi (Supabase Dashboard → Database → Cron Jobs)
7. Frontend deploy (Cloudflare Pages — auto na merge u main)
8. E2E test:
   a) Dodaj test akciju sa odgovoran_email = sopstveni → čekaj email
   b) Zaključaj test sastanak → PDF u arhivi + email učesnicima
   c) Podešavanja tab → isključi 'Nova akcija' → kreiraj akciju
      → provjeri status='skipped' u notification_log
   d) Manuelno: SELECT public.sastanci_enqueue_action_reminders();
      → provjeri queued red, čekaj 2-5 min → email digest
```

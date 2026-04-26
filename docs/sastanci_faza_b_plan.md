# Sastanci modul — Faza B (analiza + plan)

**Datum plana:** 2026-04-26  
**Status:** ✅ IMPLEMENTIRANO — commit `8135514`

---

## 1. Trenutno stanje (Faza A — merged, HEAD commit c3bdb94)

| Komponenta | Fajl | Status |
|---|---|---|
| Dashboard (widgeti, KPI, 3 kartice) | `dashboardTab.js` | ✅ A1 |
| Lista / Kalendar sastanaka | `sastanciTab.js` + `sastanciCalendar.js` | ✅ A2 |
| Templati + modal + seed | `templatesModal.js` + `src/services/sastanciTemplates.js` | ✅ A3 |
| FAB brza tema | `quickAddTemaButton.js` | ✅ A4 |
| Detalj sastanka | `fazaBPlaceholder.js` (STUB — zamenjuje se u B1) | 🔲 placeholder |
| Akcioni plan | `akcioniPlanTab.js` (lista, filteri, CRUD) | ✅ osnova za B2 refactor |
| PM teme | `pmTemeTab.js` (sub-tabovi, admin rang inline) | ✅ osnova za B3 refactor |
| SQL tabele | `add_sastanci_module.sql` + `add_sastanci_templates.sql` | ✅ primenjeno |
| RLS Model B | `harden_sastanci_rls_phase2.sql` | ✅ primenjeno |

---

## 2. Šema baze — verifikacija (kritično)

### 2.1 Status vrednosti (potvrđene iz `add_sastanci_module.sql` CHECK constraint-a)

| Tabela | Vrednosti u bazi | Napomena za Fazu B |
|---|---|---|
| `sastanci.status` | `'planiran'`, `'u_toku'`, `'zavrsen'`, `'zakljucan'` | **Vidi §5 Pitanje #1** |
| `akcioni_plan.status` | `'otvoren'`, `'u_toku'`, `'zavrsen'`, `'kasni'`, `'odlozen'`, `'otkazan'` | Kanban = otvoren/u_toku/zavrsen |
| `presek_aktivnosti.status` | `'planiran'`, `'u_toku'`, `'zavrsen'`, `'blokirano'`, `'odlozeno'` | U zapisnik tabu |
| `pm_teme.status` | `'predlog'`, `'usvojeno'`, `'odbijeno'`, `'odlozeno'`, `'zatvoreno'` | Kao u Fazi A |

### 2.2 Kolone za zaključavanje (potvrđene)

`sastanci.zakljucan_at` (TIMESTAMPTZ nullable) + `sastanci.zakljucan_by_email` (TEXT nullable) — **postoje**.

### 2.3 pm_teme dodatne kolone (potvrđene iz SUPABASE_PUBLIC_SCHEMA.md)

`hitno` (boolean), `za_razmatranje` (boolean), `admin_rang` (int nullable),  
`admin_rang_by_email` (text nullable), `admin_rang_at` (timestamp nullable) — **sve postoje**.

### 2.4 Storage bucket (potvrđeno)

Bucket **`'sastanak-slike'`** već postoji (`add_sastanci_module.sql`, limit 10 MB, MIME: image/* + PDF).  
→ **Ne treba nova SQL migracija za bucket.** Brief pominje `'sastanci-presek'` — to je netačan naziv, koristićemo postojeći `'sastanak-slike'`. (Vidi §5 Pitanje #2)

### 2.5 Šema promene za Fazu B

Verovatno **nema SQL migracija** za Fazu B. Sve tabele i kolone su gotove.  
Jedina opcija: dodati status vrednosti `'arhiviran'` i `'otkazan'` na `sastanci.status` CHECK — **samo ako §5 Pitanje #1 potvrdi da su potrebne**.

---

## 3. Routing pattern (potvrđen iz router.js + appPaths.js)

### 3.1 Kako maintenance radi sub-route

```javascript
// appPaths.js — regex za /maintenance/machines/<code>
const mm = /^\/maintenance\/machines\/([^/]+)$/.exec(p);
if (mm) {
  return { kind: 'maintenance', moduleId: 'odrzavanje-masina',
           section: 'machine', machineCode: decodeURIComponent(mm[1]) };
}
```

```javascript
// router.js — showMaintenanceFromRoute()
if (route.section === 'machine' && route.machineCode) { ... }
```

### 3.2 Pattern za /sastanci/<uuid>

Dodati u **`appPaths.js`**:
```javascript
const sm = /^\/sastanci\/([0-9a-f-]{36})$/.exec(p);
if (sm) {
  return { kind: 'module', moduleId: 'sastanci', sastanakId: decodeURIComponent(sm[1]) };
}
```

Dodati u **`router.js`** — `showSastanciFromRoute()`:
```javascript
if (route.sastanakId) {
  // renderSastanciModule sa detalj pogledom
}
```

Dodati u **`src/ui/sastanci/index.js`** — ako `opts.sastanakId` postoji, direktno otvori detalj (ne main tab strip).

### 3.3 URL i navigacija

| Akcija | URL | Pogled |
|---|---|---|
| Modul glavna stranica | `/sastanci` | Lista tabova (Faza A) |
| Detalj sastanka | `/sastanci/<uuid>` | Detalj shell (4 interna taba) |
| Direktan link | `/sastanci/<uuid>?tab=zapisnik` | Detalj sa aktivnim tabom |
| Back | History API `history.back()` ili `pushState('/sastanci')` | Lista |

---

## 4. Šta dodajem u Fazi B

### B1 — Sastanak detalj (nova ruta + 4 interna taba)

**Novi fajlovi:**

| Fajl | Opis |
|---|---|
| `src/ui/sastanci/sastanakDetalj/index.js` | Shell: header, status machine dugmad, interni tab strip, aktivni tab key u sessionStorage `'sastanci:detalj_tab'` |
| `src/ui/sastanci/sastanakDetalj/pripremiTab.js` | Mesto+vreme, učesnici (tabela sa RSVP toggle), dnevni red (pm_teme sa drag-drop), beleška organizatora |
| `src/ui/sastanci/sastanakDetalj/zapisnikTab.js` | presek_aktivnosti CRUD, rich-text editor (contenteditable + minimalni whitelist sanitizer — vidi §5 Pitanje #3), upload slika → `'sastanak-slike'` bucket |
| `src/ui/sastanci/sastanakDetalj/akcijeTab.js` | Wrapper oko akcioniPlanTab logike, filter po `sastanak_id`, "+ Nova akcija sa ovog sastanka" |
| `src/ui/sastanci/sastanakDetalj/arhivaTab.js` | Locked info, snapshot JSON download, PDF placeholder (disabled, Faza C) |
| `src/services/sastanciDetalj.js` | `getSastanakFull()`, `lockSastanak()`, `unlockSastanak()`, `archiveSastanak()`, `cancelSastanak()`, presek CRUD, saveSnapshot() |

**Refaktor postojećeg:**

| Fajl | Izmena |
|---|---|
| `src/ui/sastanci/sastanciTab.js` | Klik "Otvori" → `navigateToDetalj(id)` umesto `openFazaBPlaceholderModal` |
| `src/ui/sastanci/dashboardTab.js` | Klik "Pripremi" → `navigateToDetalj(id)` |
| `src/ui/sastanci/index.js` | Podrška za `opts.sastanakId` → render detalj umesto main strip |
| `src/lib/appPaths.js` | Dodati regex za `/sastanci/<uuid>` |
| `src/ui/router.js` | `showSastanciFromRoute()` prihvata `sastanakId` |
| `src/state/sastanci.js` | Dodati `SAST_DETALJ_TAB` session key + getter/setter |
| `src/lib/constants.js` | Dodati `SAST_DETALJ_TAB`, `SAST_AKCIONI_VIEW` ključeve |

**Status machine (po potvrdi §5 Pitanje #1):**

```
planiran  --[Počni sastanak]-->  u_toku
u_toku    --[Zaključaj]------->  zakljucan   + setuje zakljucan_at, zakljucan_by_email
zakljucan --[Otvori ponovo]---->  u_toku      (admin/menadzment only, briše zakljucan_at)
planiran  --[Otkaži]-----------  ???          (§5 Pitanje #1)
```

**Edit gate po statusu:**

| Status | Editing |
|---|---|
| `planiran` | Pun edit |
| `u_toku` | Pun edit (priprema je read-only za pozvanost, prisustvo editable) |
| `zakljucan` | READ-ONLY + banner; admin može "Otvori ponovo" |
| `zavrsen` | READ-ONLY |

### B2 — Akcioni plan Lista/Kanban toggle

**Refaktor:** `src/ui/sastanci/akcioniPlanTab.js`  
**Novi:** `src/ui/sastanci/akcioniPlanKanban.js`, `src/ui/sastanci/akcijaDetailModal.js`

Toggle u zaglavlju: `[📋 Lista] [🗂️ Kanban]` → sessionStorage `'sastanci:akcioni_view'`

**Kanban kolone** (po stvarnim status vrednostima):

| Kolona | Status vrednost |
|---|---|
| 🔵 Otvoreno | `'otvoren'` |
| 🟡 U toku | `'u_toku'` |
| 🟢 Završeno | `'zavrsen'` |

Drag-drop između kolona = PATCH status. Pattern: `poMasiniTab.js` dragstart/dragover/drop (HTML5 API, bez lib).

### B3 — PM teme refinement

**Refaktor:** `src/ui/sastanci/pmTemeTab.js`

Dodaje se:
1. Sort po: `prioritet DESC, admin_rang ASC NULLS LAST, created_at DESC` (default + klikabilni header)
2. Per-row "📅 Stavi na sastanak..." → mini-modal select `zakazan` sastanaka po datumu → PATCH `pm_teme.sastanak_id`
3. Per-row "🔥 Hitno" / "✋ Skini hitnost" toggle → PATCH `pm_teme.hitno`
4. Admin rang inline input (već postoji logika, proverim da li je kompletna)
5. Empty state za "Moje teme"

---

## 5. Pitanja — ČEKA ODGOVOR PRE IMPLEMENTACIJE

### ❗ Pitanje #1 — BLOKIRAJUĆE: Status vrednosti u `sastanci.status`

Baza ima CHECK: `('planiran', 'u_toku', 'zavrsen', 'zakljucan')`.  
Brief (Faza B zadatak) koristi: `'zakazan'`, `'u_toku'`, `'zakljucan'`, `'arhiviran'`, `'otkazan'`.

**Neslaganje:**

| Brief vrednost | DB vrednost | Isto? |
|---|---|---|
| `zakazan` | `planiran` | Verovatno isto — ali ime se razlikuje |
| `u_toku` | `u_toku` | ✅ |
| `zakljucan` | `zakljucan` | ✅ |
| `arhiviran` | ❌ ne postoji | Nova vrednost? |
| `otkazan` | ❌ ne postoji | Nova vrednost? |
| `zavrsen` | postoji u DB | Nije u brifu — šta je to? |

**Konkretno pitanje:** Da li treba dodati `'arhiviran'` i `'otkazan'` u CHECK constraint (nova SQL migracija), ili koristiti isključivo postojeće vrednosti?

Ako koristimo **samo postojeće**:
- "Zakaži" = status `'planiran'` (kao sada)
- Nema "Arhiviraj" / "Otkaži" akcije u Fazi B
- Status machine: `planiran → u_toku → zakljucan`

Ako **dodamo nove**:
- Nova migracija `alter_sastanci_add_statuses.sql`
- Treba proveriti da li Faza 2 RLS dozvoljava pisanje `'arhiviran'`/`'otkazan'`

**Preporuka:** Koristiti samo postojeće u Fazi B (`planiran → u_toku → zakljucan`), bez novih statusa. Arhiviranje kao Faza C zajedno sa PDF-om.

---

### ❗ Pitanje #2 — Storage bucket naziv

Brief pominje kreiranje bucketa `'sastanci-presek'`, ali u bazi **već postoji** bucket `'sastanak-slike'` (iz `add_sastanci_module.sql`) sa ispravnim MIME tipovima i limitom 10 MB.

**Pitanje:** Da li koristimo `'sastanak-slike'` (postojeći) za slike u zapisniku, ili želiš **poseban** bucket `'sastanci-presek'`?

**Preporuka:** Koristiti `'sastanak-slike'` — nova SQL migracija nije potrebna.

---

### ❗ Pitanje #3 — Rich-text editor strategija

`DOMPurify` **nije** u `package.json` dependencies.

**Opcije:**
1. `npm install dompurify` + `@types/dompurify` (novo u deps — needs OK)
2. Minimalni whitelist sanitizer u custom helperfu (npr. `src/lib/htmlSanitize.js`) — dozvoljena lista tagova: `<b><i><u><br><p><ul><ol><li><a href>`, svi ostali se stripuju. Radi samo za ove tagove, bez WYSIWYG kompleksnosti.
3. Plain textarea (bez rich-text, samo plaintext `sadrzaj_text`) — `sadrzaj_html = null`

**Preporuka:** Opcija 2 — minimalni sanitizer bez nove npm zavisnosti, dovoljan za beleške i stavke zapisnika. Ako se u budućnosti pokaže nedovoljan, lako zameniti sa DOMPurify.

---

### ❗ Pitanje #4 — Relacija `sastanakModal.js` (540 linija) vs novi `sastanakDetalj/`

U `src/ui/sastanci/` već postoji `sastanakModal.js` (540 linija) koji se importuje iz `sastanciTab.js`. Ovaj modal je za **edit/pregled postojećeg sastanka u modal overlay-u**.

Brief traži `sastanakDetalj/index.js` kao **full-page ruta** (`/sastanci/<uuid>`), ne modal.

**Pitanje:** Da li:
- (a) Zadržati oba — modal ostaje za brzi edit, detalj ruta za kompletan rad (zapisnik, kanban, arhiva)?
- (b) Zameniti modal sa detalj rutom — klik na sastanak uvek vodi na `/sastanci/<uuid>`?

**Preporuka:** Opcija (b) — konzistentnije, ukida duplikaciju. Kada korisnik klikne na sastanak u listi, ide na detalj stranicu. "Brzi edit" naslova/datuma/mesta ostaje kao dugme unutar detalj headera.

---

### ❗ Pitanje #5 — "Zavrsen" status u DB

`sastanci.status` ima vrednost `'zavrsen'` u CHECK-u, ali nije u workflow brifu.

**Pitanje:** Šta je razlika između `'zavrsen'` i `'zakljucan'`? Da li:
- `zavrsen` = sastanak je fizički održan ali zapisnik nije formalizovan?
- `zakljucan` = zapisnik je potpisan/zaključan?

Ili je `zavrsen` legacy vrednost koja se više ne koristi?

**Preporuka:** Tretirati `'zavrsen'` kao "završen ali nezaključan" — između `u_toku` i `zakljucan`. Ako se ne koristi, prikazati kao `zakljucan` u UI.

---

## 6. SQL — nacrt (čeka odgovor na Pitanje #1 i #2)

**Ako §5 Pitanje #1 → koristimo samo postojeće statuse:**
- Nema SQL migracija.

**Ako §5 Pitanje #1 → dodajemo `'arhiviran'` i `'otkazan'`:**
- `sql/migrations/alter_sastanci_add_statuses.sql`:
  ```sql
  ALTER TABLE public.sastanci DROP CONSTRAINT IF EXISTS sastanci_status_check;
  ALTER TABLE public.sastanci ADD CONSTRAINT sastanci_status_check
    CHECK (status IN ('planiran','u_toku','zavrsen','zakljucan','arhiviran','otkazan'));
  ```

**Ako §5 Pitanje #2 → novi bucket:**
- `sql/migrations/add_sastanci_storage_buckets.sql` (po Faza B brifu)

**Ako koristimo postojeći `'sastanak-slike'`:**
- Nema SQL migracije (bucket postoji).

---

## 7. Redosled implementacije (po odobrenju plana)

```
B1a: Routing (appPaths.js + router.js) + state ključevi
B1b: src/services/sastanciDetalj.js
B1c: sastanakDetalj/index.js (shell + header + status machine)
B1d: pripremiTab.js
B1e: zapisnikTab.js + lib/htmlSanitize.js
B1f: akcijeTab.js
B1g: arhivaTab.js
B2:  akcioniPlanKanban.js + akcijaDetailModal.js + refactor akcioniPlanTab.js
B3:  refactor pmTemeTab.js
DOC: docs/Sastanci_modul.md ažuriranje
```

---

*Čeka odgovor na Pitanja #1–#5 pre početka implementacije.*

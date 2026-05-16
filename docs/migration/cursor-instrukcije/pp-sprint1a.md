# Cursor instrukcija — PP Sprint 1A: Timer cleanup + Promise timeout + 10K banner

> Verzija: 2026-05-16 · Sprint: PP Sprint 1A (quick wins) · Zavisi od: [Sprint 0 status](../pp-sprint0-status.md) · Audit ref: [Plan proizvodnje analiza](../../Plan_proizvodnje_modul_analiza.md)

---

## ⚠ Pre-flight nalazi (čitati pre Zadatka 0)

Posle Jarine revizije ove instrukcije, otkriveno je da kod već sadrži deo infrastrukture koju je instrukcija predlagala da napravimo. **Ne pravi ono što već postoji.**

### 1. `sbReq` već podržava count mode

[src/services/supabase.js:197-215](../../../src/services/supabase.js#L197) — wrapper `sbReqWithCount(path)` već:
- Šalje `Prefer: count=exact` header
- Parsira `Content-Range` (`0-49/1234` → `total: 1234`)
- Vraća `{ rows, total }`
- AbortError pravilno propagira

**Posledica za Zadatak 3 (M22):** ne diraj `src/services/supabase.js`. Samo importuj postojeći `sbReqWithCount` u `planProizvodnje.js` i koristi ga umesto trenutnog `sbReq` u `loadAllOpenOperations`.

### 2. Warning paleta već postoji u modulu

[src/styles/planProizvodnje.css:758-766](../../../src/styles/planProizvodnje.css#L758) — klasa `.pp-warning`:

```css
.pp-warning {
  color: #fcd34d;
  background: color-mix(in srgb, #eab308 14%, transparent);
  border: 1px solid color-mix(in srgb, #eab308 28%, transparent);
  border-radius: 8px;
  padding: 8px 10px;
  font-size: 12px;
}
```

**Modul je dark theme.** Originalno predlagana paleta `#fff8e1`/`#f59f00` je light-theme i vizuelno bi ispala iz teme.

**Posledica za Zadatak 3 (M22):** banner div koristi `class="pp-warning pp-truncation-banner"`. Dodatna `.pp-truncation-banner` klasa samo dodaje `display: flex; gap: 8px; margin: 0 0 12px;` (layout), ne menja paletu.

### 3. `_shared.js` ne postoji u modulu

Modul `src/ui/planProizvodnje/` nema shared helper fajl. Pattern je per-tab helper-i. Copy-paste `renderTruncationBanner` u `pregledTab.js` i `zauzetostTab.js` je prihvatljiv (DRY ne vredi promenu konvencije za jednu funkciju).

### 4. `loadAllOpenOperations` ima samo 2 caller-a

Grep `loadAllOpenOperations(` u celom repo-u — caller-i:
- `src/ui/planProizvodnje/pregledTab.js:131`
- `src/ui/planProizvodnje/zauzetostTab.js:251`

To su upravo dva fajla koje instrukcija već pokriva u Zadatku 3.2. **Breaking return shape je siguran** — nema skrivenih caller-a.

### 5. H14 retry race — token pattern obavezan

Originalna instrukcija koristi boolean `state.loadAborted = false; setTimeout(... = true ...)`. Ako korisnik klikne „Pokušaj ponovo" pre nego što prva `Promise.all` resolve-uje, oba in-flight load-a su istovremena i boolean ne razlikuje koji od njih sme da renderuje. **Token pattern je obavezan.** Vidi revidiranu skicu u Zadatku 2.

### 6. M16 mora pokriti i `loadTimeoutId` iz H14

Posle implementacije H14, `pregledTab.js` ima **dva** timera u state-u: `rnFilterTimer` i `loadTimeoutId`. `teardownPregledTab` mora da otkaže **oba**. Eksplicitno u Zadatku 1.

### 7. `count=planned` vs `exact` — odgovor

Postojeća implementacija koristi `count=exact`. Ne otvaraj to pitanje. `count=planned` na view-u sa LATERAL-om i 80 kolona daje neprecizne brojeve (planner ne razume složene join-ove). `exact` za 18K redova je pod 200ms — prihvatljivo.

---

## Cilj

Tri quick win izmene u modulu Planiranje proizvodnje koje rešavaju operativne rizike bez izmene poslovne logike:

- **M16**: `clearTimeout` u teardown funkcijama 4 taba — sprečava da debounce timer „okida" posle demount-a taba i poziva render funkcije na uništenom DOM-u.
- **H14**: timeout guard za `Promise.all` u `pregledTab.js` — ako jedan request visi, korisnik dobija toast i može da napusti tab, umesto da spinner stoji zauvek.
- **M22→H**: UI banner kad rezultat hit-uje 10K cap u `loadAllOpenOperations` — operater vidi da posmatra nekompletan set i može da filtrira pre nego što donese odluku. Trenutno u produkciji ima 18 299 otvorenih operacija → operater vidi 55% slike bez ikakvog upozorenja.

Sve tri izmene su strogo aditivne. Postojeća funkcionalnost mora da nastavi da radi neizmenjeno.

## Kontekst

Sprint 0 verifikacija završena ([pp-sprint0-status.md](../pp-sprint0-status.md)), sve DB pretpostavke potvrđene zelene. Frontend code-side audit potvrdio:
- 4 debounce timera u modulu (jedan po tabu), nijedan `clearTimeout` u teardown-u nije eksplicitno potvrđen
- `Promise.all` u `pregledTab.js:129-131` bez ikakvog timeout-a
- `loadAllOpenOperations` ima hard cap 10000 redova, produkcija ima 18 299

## Relevantni fajlovi koje treba pročitati pre rada

- `src/ui/planProizvodnje/poMasiniTab.js` — search za `rnFilterTimer` i `teardownPoMasiniTab`
- `src/ui/planProizvodnje/zauzetostTab.js` — debounce oko linije 222, teardown na kraju fajla
- `src/ui/planProizvodnje/pregledTab.js` — debounce oko linije 104, `Promise.all` oko linije 131, teardown na kraju fajla
- `src/ui/planProizvodnje/kooperacijaTab.js` — debounce oko linije 67, teardown na kraju fajla
- `src/services/planProizvodnje.js` — `loadAllOpenOperations` oko linije 380
- `src/services/supabase.js` — **SAMO ČITAJ**: `sbReqWithCount` linija 197–215. Ne menjaj.
- `src/styles/planProizvodnje.css` — `.pp-warning` linija 758
- `docs/Planiranje_proizvodnje_modul.md` — kanon modula
- `docs/migration/pp-sprint0-status.md` — verifikacija stanja
- `docs/migration/pp-sprint0-code-checks.md` — code inventar (event listeneri, timeri)

## Zadaci

### 0. Pripremna analiza (obavezno pre koda)

Pre nego što napišeš ijednu izmenu, pročitaj sledeće i dokumentuj u `docs/migration/pp-sprint1a-analysis.md`:

1. **Za M16**: za svaki od 4 taba, navedi:
   - tačan naziv state property-ja koji čuva timer ID (`state.rnFilterTimer` ili drugačije)
   - tačno ime teardown funkcije
   - liniju gde se trenutno `setTimeout` postavlja
   - liniju gde se trenutno timer ID nullify-uje (ako se nigde, zabeleži)

2. **Za H14**: u `pregledTab.js`:
   - tačan kod oko linije 131 (`Promise.all` poziv)
   - da li je rezultat dodeljen state-u ili lokalnoj promenljivoj
   - da li već postoji bilo kakav `try/catch` oko poziva
   - postoji li već `state.activeRequestId`, `state.loadToken` ili sličan obrazac koji bi mogao da se reuse-uje

3. **Za M22**: u `src/services/supabase.js`:
   - **SAMO POTVRDA**: `sbReqWithCount(path)` postoji na liniji 203, vraća `{ rows, total }`. NE menjaj `sbReq`.
   - Procitaj kako se `withCount: true` koristi (linija 255) — Cursor mora samo da importuje `sbReqWithCount` u `planProizvodnje.js`.

4. **Za M22**, dodatno: u `pregledTab.js` i `zauzetostTab.js` — sva mesta gde se zove `loadAllOpenOperations()` (već potvrđeno 2 mesta: pregledTab.js:131, zauzetostTab.js:251).

**STOP ovde.** Pre kreiranja koda, ovaj analizni dokument se commit-uje kao prvi commit u PR-u. Jara ga čita i daje zeleno svetlo pre nego što kreneš zadatke 1–3.

---

### 1. M16 — `clearTimeout` u 4 teardown-a (commit 2)

Cilj: u svakoj teardown funkciji, za svaki postojeći debounce timer, pozovi `clearTimeout` PRE nego što se state property nullify-uje ili se state objekt zameni.

Pattern (primeniti na sva 4 taba, sa imenima property-ja iz zadatka 0):

```js
export function teardownXxxTab(/* ... */) {
  // Otkaži pending debounce timer ako postoji
  if (state.rnFilterTimer) {
    clearTimeout(state.rnFilterTimer);
    state.rnFilterTimer = null;
  }
  // Za pregledTab.js DODATNO (iz Zadatka 2/H14):
  if (state.loadTimeoutId) {
    clearTimeout(state.loadTimeoutId);
    state.loadTimeoutId = null;
  }
  // ... ostatak postojeće teardown logike (ne diraj)
}
```

Pravila:
- Ako tab nema teardown funkciju — **stani i prijavi**, ne pravi novu (to je posebna odluka).
- Ako tab ima više različitih timera (npr. ESC modal timer, draggable retry timer), otkaži samo one koji su debounce za korisnički unos. Modal focus timer-e (kratki, ~50ms) ostavi — nisu izvor problema.
- Ne menjaj ponašanje debounce-a (delay vrednost ostaje ista).
- Ne dodaj nove state property-je osim ako analiza iz zadatka 0 pokaže da timer ID trenutno nije sačuvan nigde.
- **Specifično za `pregledTab.js`:** Zadatak 2 dodaje `state.loadTimeoutId`. M16 mora da pokrije i taj timer (vidi pattern iznad).

Commit poruka: `pp: clear pending debounce timers in tab teardown (M16)`

---

### 2. H14 — `Promise.all` timeout u `pregledTab.js` (commit 3)

Cilj: ako `Promise.all([loadMachines(), loadAllOpenOperations()])` ne završi za 15 sekundi, korisnik vidi toast greške i tab prikaže „Pokušaj ponovo" dugme umesto beskonačnog spinner-a.

**Važno**: ne dodajemo AbortController za sam HTTP zahtev (to ide u Sprint 3 / H18 kao globalna izmena u `sbReq`). Za ovaj quick win koristimo **token pattern** — timeout odbacuje UI rezultat, request završava u backgroundu ali se ignoriše.

Implementacija (revidirana skica sa token pattern-om umesto fragile boolean-a):

```js
const LOAD_TIMEOUT_MS = 15000;

async function loadAndRender(/* ... */) {
  // Otkaži prethodni timeout ako postoji (ručni refresh ili "Pokušaj ponovo")
  if (state.loadTimeoutId) {
    clearTimeout(state.loadTimeoutId);
    state.loadTimeoutId = null;
  }

  // Token: svaki novi load dobija novi broj. Stari in-flight load
  // koji se vrati posle ovoga vidi da myToken != state.loadToken i preskoči render.
  state.loadToken = (state.loadToken || 0) + 1;
  const myToken = state.loadToken;

  state.loadTimeoutId = setTimeout(() => {
    if (myToken !== state.loadToken) return; // novi load je već startovan
    state.loadTimeoutId = null;
    renderLoadTimeoutError(host);
  }, LOAD_TIMEOUT_MS);

  try {
    const [machines, ops] = await Promise.all([loadMachines(), loadAllOpenOperations()]);
    if (myToken !== state.loadToken) return; // teardown ili novi load, ignoriši
    clearTimeout(state.loadTimeoutId);
    state.loadTimeoutId = null;
    // ... postojeća render logika (sa ops.rows ako je M22 već applied)
  } catch (err) {
    if (myToken !== state.loadToken) return;
    clearTimeout(state.loadTimeoutId);
    state.loadTimeoutId = null;
    throw err; // postojeći error handling
  }
}

function renderLoadTimeoutError(host) {
  host.innerHTML = `
    <div class="pp-load-error pp-warning">
      <p>Učitavanje predugo traje. Server može da bude opterećen.</p>
      <button type="button" class="btn" data-action="retry-load">Pokušaj ponovo</button>
    </div>
  `;
  host.querySelector('[data-action=retry-load]')
      ?.addEventListener('click', () => loadAndRender(/* ... */));
  showToast?.('Učitavanje predugo traje.', 'error');
}
```

U `teardownPregledTab`: postavi `state.loadToken = (state.loadToken || 0) + 1` (invalidira sve in-flight token-e) i `clearTimeout(state.loadTimeoutId)`. Vidi Zadatak 1 za kombinovan teardown.

CSS: koristi postojeću `.pp-warning` klasu. Dodaj **samo** layout override ako je potreban:
```css
.pp-load-error {
  text-align: center;
  padding: 16px 12px;
}
.pp-load-error p {
  margin: 0 0 12px;
}
```

Pravila:
- Timeout je 15 sekundi. Ne menjaj na drugu vrednost bez Jarinog odobrenja.
- Toast preko `showToast` ako helper već postoji u modulu — ne uvozi novu biblioteku.
- „Pokušaj ponovo" mora ponovo pokrenuti istu funkciju (idempotentno).
- Ne menjaj `loadAllOpenOperations` ovde — to je Zadatak 3.
- **Token pattern obavezan** — boolean `loadAborted` je race-prone i instrukcija je revidirana.

Commit poruka: `pp: 15s timeout guard for Promise.all in pregledTab (H14)`

---

### 3. M22 — UI banner za 10K cap (commit 4)

Cilj: kada `loadAllOpenOperations` vrati tačno 10000 redova (ili kada server kaže da total prelazi limit), prikaži warning banner u Pregled i Zauzetost tabu.

Implementacija u tri koraka:

**3.1.** U `src/services/planProizvodnje.js`, refaktoriši `loadAllOpenOperations` da koristi POSTOJEĆI `sbReqWithCount`:

```js
import { sbReqWithCount } from '../services/supabase.js';

const ALL_OPS_LIMIT = 10000;

export async function loadAllOpenOperations() {
  const path = `v_production_operations_effective?...&limit=${ALL_OPS_LIMIT}`;
  // sbReqWithCount već postoji u supabase.js (linija 203), vraća { rows, total }
  const { rows, total } = await sbReqWithCount(path);

  // Defensive za grešku: ako rows null (fetch failed), null bocked
  const safeRows = Array.isArray(rows) ? rows : [];
  const safeTotal = Number.isFinite(total) ? total : safeRows.length;

  return {
    rows: safeRows,
    total: safeTotal,
    truncated: safeTotal > ALL_OPS_LIMIT,
    limit: ALL_OPS_LIMIT,
  };
}
```

**NE diraj `src/services/supabase.js`.** `sbReqWithCount` je već implementiran u toj infrastrukturi (pre-flight nalaz #1).

**3.2.** Update caller-a u `src/ui/planProizvodnje/pregledTab.js` (linija 131) i `src/ui/planProizvodnje/zauzetostTab.js` (linija 251):

```js
const [machines, result] = await Promise.all([
  loadMachines(),
  loadAllOpenOperations(), // sada vraća { rows, total, truncated, limit }
]);
if (result.truncated) {
  renderTruncationBanner(host, { shown: result.rows.length, total: result.total });
}
// dalje koristi result.rows umesto direktnog niza
```

`renderTruncationBanner` — copy-paste u oba taba (pre-flight nalaz #3 — `_shared.js` ne postoji):

```js
function renderTruncationBanner(host, { shown, total }) {
  const wrap = document.createElement('div');
  wrap.className = 'pp-warning pp-truncation-banner';
  wrap.innerHTML = `
    <span class="pp-truncation-icon" aria-hidden="true">⚠</span>
    <span>Prikazano prvih <strong>${shown.toLocaleString('sr-RS')}</strong>
    od <strong>${total.toLocaleString('sr-RS')}</strong> operacija.
    Filtriraj po RN ili odeljenju za precizniju sliku.</span>
  `;
  host.prepend(wrap);
}
```

**3.3.** CSS u `src/styles/planProizvodnje.css` — koristi postojeću `.pp-warning` paletu, dodaj samo layout (pre-flight nalaz #2):

```css
.pp-truncation-banner {
  display: flex;
  gap: 8px;
  align-items: center;
  margin: 0 0 12px;
}
.pp-truncation-icon {
  font-size: 16px;
}
```

NE pravi novu `#fff8e1` / `#f59f00` paletu — modul je dark theme i to bi ispalo iz vizuelne teme.

Pravila:
- `loadAllOpenOperations` mora ostati eksportovana sa istim imenom.
- Caller koji preuzima rezultat mora da koristi `.rows` (ne razbijati staru semantiku tihim trikom).
- Ako u modulu postoje JEDINIČNI TESTOVI za `loadAllOpenOperations` (npr. `tests/services/planProizvodnje.*.test.js`) — ažuriraj ih na novi return shape.
- Ne menjaj `loadOperationsForMachine` ni `loadOperationsForDept` (oni imaju druge limite i drugu semantiku).
- Banner se prikazuje SAMO ako `truncated === true`. U normalnom režimu (npr. 5000 ops u produkciji za 6 meseci) banner ne sme da treperi.
- **Caller-i su SAMO 2** (pre-flight #4): pregledTab.js:131, zauzetostTab.js:251. Nema drugih.

Commit poruka: `pp: warn user when loadAllOpenOperations truncates at 10K (M22)`

---

## Šta sme da menja

- `src/services/planProizvodnje.js` (samo `loadAllOpenOperations` + import za `sbReqWithCount`)
- `src/ui/planProizvodnje/poMasiniTab.js` (samo teardown)
- `src/ui/planProizvodnje/zauzetostTab.js` (teardown + caller za M22)
- `src/ui/planProizvodnje/pregledTab.js` (teardown + Promise.all + caller za M22)
- `src/ui/planProizvodnje/kooperacijaTab.js` (samo teardown)
- `src/styles/planProizvodnje.css` (dodavanje 2 layout-only CSS bloka, bez nove palete)
- `tests/services/planProizvodnje.*.test.js` (ako test postoji za `loadAllOpenOperations`)
- novi fajl `docs/migration/pp-sprint1a-analysis.md`

## Šta NE sme da menja

- `src/services/supabase.js` (**NE**: `sbReqWithCount` već postoji, ne diraj)
- `v_production_operations` ili bilo koju SQL šemu
- gate funkcije (`can_edit_plan_proizvodnje`, `can_force_plan_reassign`)
- bilo koji SECURITY DEFINER RPC
- bridge skriptu (`workers/loc-sync-mssql/scripts/backfill-production-cache.js`)
- `auto_sort_bucket`, `sortProductionOperations` helper, ni jedan drag-drop ili reassign kod
- `loadOperationsForMachine`, `loadOperationsForDept`
- behavior drag-drop-a (to je Sprint 1C / H13)
- `archived_at` kolone i njihove filter-e (status quo, vidi Sprint 0 odluku)
- `is_ready_for_processing` back-compat alias u SQL view-u (status quo do Sprinta 2)

## Očekivani output

PR sa 4 commit-a (jedan na vrhu — analiza, tri za pod-zadatke), grananog iz `main`:
1. `docs: pp sprint 1A pre-flight analysis`
2. `pp: clear pending debounce timers in tab teardown (M16)`
3. `pp: 15s timeout guard for Promise.all in pregledTab (H14)`
4. `pp: warn user when loadAllOpenOperations truncates at 10K (M22)`

PR description template:

```
## Sprint 1A — quick wins

- M16: clearTimeout u 4 tab teardown-a
- H14: 15s timeout za Promise.all u pregledTab (token pattern, ne boolean)
- M22→H: banner za 10K cap u loadAllOpenOperations (koristi postojeći sbReqWithCount)

Iz Sprint 0 nalaza — sve DB pretpostavke zelene, kod-strana menja se aditivno.

Pre-flight (jara): sbReqWithCount već postoji; .pp-warning već postoji; 2 callera.

### Verifikacija (ručno, na staging-u)
- [ ] M16: brzo prebacivanje između tabova posle kucanja u filter — bez JS error-a u konzoli
- [ ] H14: blokiraj mrežu (DevTools throttling Offline) → otvori Pregled tab → posle 15s vidim toast + "Pokušaj ponovo" dugme
- [ ] H14: klik "Pokušaj ponovo" sa već-pending zahtevom — samo jedan render na kraju (token pattern radi)
- [ ] M22: na produkcijskom snapshot-u (18.3K ops) banner se vidi; na sintetičkom < 10K skupu banner se NE vidi

### Rollback
Svaki commit je nezavisan. Ako bilo koji uzrokuje regresion — revert single commit, ostala dva ostaju.
```

## Acceptance kriterijumi

**M16**:
- u svakoj od 4 teardown funkcija postoji eksplicitan `clearTimeout` na svaki debounce timer
- `pregledTab.js` teardown otkazuje OBA timera (rnFilter + load)
- pending timer-i nisu vidljivi u Chrome DevTools Performance tab posle brzog tab switch-a (manualna provera, Jara)
- nijedna postojeća funkcionalnost (filter, sort, klik na red) nije promenjena

**H14**:
- DevTools Offline → tab spinner posle 15s prelazi u error stanje sa retry dugmetom
- klik na „Pokušaj ponovo" pokreće load ponovo
- normalan load (< 15s) ne pokazuje nikakvu razliku od trenutnog ponašanja
- teardown taba dok je load u toku ne uzrokuje JS error
- **race test:** klik „Pokušaj ponovo" pre nego što prva fetch resolve-uje → samo jedan render set kao rezultat (token diskvalifikuje stari)

**M22**:
- na produkciji (18 299 ops) banner se prikazuje u Pregled i Zauzetost tabu odmah po load-u
- na test setu < 10000 ops banner se ne prikazuje
- broj u banner-u je tačan (iz Content-Range, koji `sbReqWithCount` već parsira)
- klikabilan filter po RN i dalje radi normalno
- banner ne menja postojeće DOM strukture (samo prepend pre tabele)

## Rollback plan

Tri commit-a su nezavisna. Za svaki postoji jasan revert put:
- M16 revert: `git revert <hash>` — povratak na staro stanje (samo dodaje malo memory leak rizika)
- H14 revert: `git revert <hash>` — povratak na beskonačni spinner u worst case
- M22 revert: `git revert <hash>` + ručno proveri da `loadAllOpenOperations` caller-i očekuju niz, ne objekat (git revert će pokupiti sve jer su caller-i u istom commit-u)

Ako CSS izmene uzrokuju vizuelni problem — revert samo CSS hunk iz M22 commit-a, logika ostaje.

## Vremenska procena

- Zadatak 0 (analiza): 30 minuta
- M16: 30 minuta (4 fajla, ~5 min svaki + provera)
- H14: 60 minuta (token pattern + retry UI + teardown integracija)
- M22: 45 minuta (oduzeto 15 min jer `sbReqWithCount` već postoji)
- Manuelni smoke test: 30 minuta
- **Ukupno: ~3 sata jedan developer**

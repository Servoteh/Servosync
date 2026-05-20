# REVERSI — mobilni skener + ubrzanje zaduženja reznog alata

> Cursor instrukcija za doradu Reversi modula tako da magacioner i operater
> mogu **brzo i bez HID čitača** da skeniraju barkod sa pločice reznog alata
> i ID karticu operatera, i da kreiraju revers u 3 tapa.

---

## 1. Šta je problem (uočeno na terenu)

Kada se sa "Rezni alat" taba klikne **`Zaduženje (skener)`** otvara se modal
[`src/ui/reversi/cuttingToolScannerModal.js`](../src/ui/reversi/cuttingToolScannerModal.js)
čiji jedini ulaz je text input:

```
Skeniraj ili otkucaj kod… (Enter za potvrdu)
```

Taj input očekuje **HID skener** (USB ili BT koji se ponaša kao klavijatura
i šalje `Enter` na kraju). Na terenu, magacioner ima samo telefon — i nema
nijedno dugme koje pokreće kameru. Isti problem ima i **`Povraćaj (skener)`**.

Korisnička očekivanja (referenca: ekran *SERVOTEH MAGACIN* na mobilnom):

- velika dugmad (~84px visine), ikona + naslov + podnaslov,
- jedno **primary** CTA dugme koje odmah pokreće kameru,
- secondary CTA za karticu operatera i za mašinu (`ZADU-M-…`),
- HID input ostaje **kao fallback** unutar collapsed sekcije "Manuelni unos".

---

## 2. Šta već postoji (NE pisati ispočetka)

Sva infrastruktura je tu — treba je samo prikačiti na nova dugmad:

| Šta | Gde | Šta radi |
|---|---|---|
| Punokološni kamera skener | [`src/ui/reversi/scanOverlay.js`](../src/ui/reversi/scanOverlay.js) — `openReversiScanOverlay({ title, hint, acceptKinds, continuous, onResult })` | Sam razlikuje `ALAT-NNNNNN` (HAND), `RZN-NNNNNN` (CUTTING) i kraći alfanumerički kod kao `EMPLOYEE` card_barcode. Ima zoom, torch, tap-to-focus, vibraciju, kontinuirani režim sa chip listom. |
| Resolver barkoda | `resolveReversiBarcode(raw)` u istom fajlu | Vraća `{ kind, barcode, data }` — direktno upotrebljivo. |
| Service pozivi | [`src/services/reversiService.js`](../src/services/reversiService.js): `fetchCuttingToolByBarcode`, `fetchEmployeeByCardBarcode`, `fetchMachines`, `issueCuttingReversal`, `confirmCuttingReturn` | Backend deo radi. |
| Mobile-first CSS šablon | [`src/styles/mobile.css`](../src/styles/mobile.css) klase `.m-cta`, `.m-cta-primary`, `.m-cta-secondary`, `.m-cta-row` | Iste klase koje koristi `mobileHome.js` za krupna dugmad iz screenshot-a. |
| Quick Issue (skener-first) | [`src/ui/reversi/quickIssueModal.js`](../src/ui/reversi/quickIssueModal.js) — već ispravno koristi `openReversiScanOverlay` | Šablon za "kako se dugme prikači na kameru". |
| Quick Return | [`src/ui/reversi/quickReturnModal.js`](../src/ui/reversi/quickReturnModal.js) | Continuous scan loop — referenca za return tok. |

**Zaključak:** nedostaju samo 3 stvari — krupna dugmad u 2 modala
(`cuttingToolScannerModal.js`) i nekoliko CSS klasa za mobile layout.

---

## 3. Pregled tokova u modulu (kratko)

| Tok | Ulaz | Modal / overlay | Status |
|---|---|---|---|
| Zaduženje reznog alata (skener) | Tab "Rezni alat" → `Zaduženje (skener)` | `openCuttingToolIssueScannerModal` | **TREBA DORADA** — nema kamere |
| Quick Issue (mešovito) | Bilo gde → `Quick Issue` | `openQuickIssueModal` | OK — koristi kameru |
| Povraćaj reznog alata (skener) | Tab "Rezni alat" → `Povraćaj (skener)` | `openCuttingToolReturnScannerModal` | **TREBA DORADA** — nema kamere |
| Quick Return | "Moja zaduženja" → FAB `Skeniraj` | `openQuickReturnModal` | OK — koristi kameru |
| Klasično zaduženje (kompletan obrazac) | Tab "Zaduženja" → `Novo zaduženje` | `openIssueReversalModal` | OK — desktop tok |

---

## 4. Konkretne izmene (fajl po fajl)

### 4.1 `src/ui/reversi/cuttingToolScannerModal.js` — **issue skener**

**Lokacija u `paint()` funkciji, blok `body.innerHTML = ...`** — zameniti
postojeću `<div class="rev-scan-input-row">` sekciju **novim quick-action
blokom**, a stari text input premestiti u collapsed `<details>` ispod
postojeće sekcije "Manuelni izbor".

#### 4.1.1 Novi quick-action blok (na vrhu modala)

```js
<section class="rev-qa-block">
  <button type="button" class="rev-qa-cta rev-qa-cta--primary" id="revRznQaTool">
    <span class="rev-qa-ico" aria-hidden="true">📷</span>
    <span class="rev-qa-txt">
      <span class="rev-qa-title">SKENIRAJ ALAT</span>
      <span class="rev-qa-sub">Barkod sa pločice (RZN-…)</span>
    </span>
  </button>

  <div class="rev-qa-row">
    <button type="button" class="rev-qa-cta rev-qa-cta--secondary" id="revRznQaCard">
      <span class="rev-qa-ico" aria-hidden="true">🆔</span>
      <span class="rev-qa-txt">
        <span class="rev-qa-title">KARTICA OPERATERA</span>
        <span class="rev-qa-sub">${state.employee ? escHtml(state.employee.full_name) : 'Skeniraj ID'}</span>
      </span>
    </button>
    <button type="button" class="rev-qa-cta rev-qa-cta--secondary" id="revRznQaMachine">
      <span class="rev-qa-ico" aria-hidden="true">🏭</span>
      <span class="rev-qa-txt">
        <span class="rev-qa-title">MAŠINA</span>
        <span class="rev-qa-sub">${state.machine ? escHtml(state.machine.rj_code) : 'Skeniraj ZADU-M-…'}</span>
      </span>
    </button>
  </div>
</section>
```

#### 4.1.2 `bindEvents()` — dodati handlere

```js
import { openReversiScanOverlay } from './scanOverlay.js';

overlay.querySelector('#revRznQaTool')?.addEventListener('click', () => {
  openReversiScanOverlay({
    title: 'Skeniraj rezni alat',
    hint: 'Barkod RZN-… sa pločice. Skener ostaje otvoren za seriju.',
    acceptKinds: ['CUTTING'],
    continuous: true,
    onResult: async (parsed) => {
      if (!parsed.data?.id) { showToast('Alat nije u katalogu'); return; }
      addLineFromCatalog(parsed.data, 1);
      paint();
    },
  });
});

overlay.querySelector('#revRznQaCard')?.addEventListener('click', () => {
  openReversiScanOverlay({
    title: 'Skeniraj karticu operatera',
    hint: 'ID kartica zaposlenog',
    acceptKinds: ['EMPLOYEE'],
    continuous: false,
    onResult: async (parsed) => {
      const emp = parsed.data;
      if (!emp?.id) { showToast('Kartica nije prepoznata'); return; }
      state.employee = { id: emp.id, full_name: emp.full_name };
      paint();
    },
  });
});

overlay.querySelector('#revRznQaMachine')?.addEventListener('click', () => {
  openReversiScanOverlay({
    title: 'Skeniraj mašinu',
    hint: 'Nalepnica ZADU-M-… na mašini',
    acceptUnknown: true,
    continuous: false,
    onResult: async (parsed) => {
      // Reuse existing handleScannedInput parsing branch for ZADU-M-…
      handleScannedInput(parsed.barcode);
    },
  });
});
```

#### 4.1.3 HID input ostaje kao fallback

Premestiti postojeći `<input id="revRznScanIn">` blok u:

```js
<details class="rev-qa-manual">
  <summary>Manuelni / HID unos (USB skener, klavijatura)</summary>
  <!-- ovde ostaje postojeći input + .rev-scan-summary pills -->
</details>
```

Time se zadržava back-compat za korisnike sa USB skenerom, a UI više nije
zatrpan tehničkim detaljima.

#### 4.1.4 Veliko submit dugme

U `foot.innerHTML` zameniti postojeće sa:

```js
<button type="button" class="rev-btn" data-rev-close>Otkaži</button>
<button type="button" class="rev-btn rev-btn--primary rev-btn--lg rev-qa-submit"
        id="revRznScanSubmit" ${canSubmit() ? '' : 'disabled'}>
  ${state.pending ? 'Čuvam…' : `POTVRDI ZADUŽENJE (${state.lines.length})`}
</button>
```

---

### 4.2 `src/ui/reversi/cuttingToolScannerModal.js` — **return skener**

Funkcija `openCuttingToolReturnScannerModal()` — isti pattern:

**Pre liste stavki**, dodati jedno veliko CTA:

```js
<section class="rev-qa-block">
  <button type="button" class="rev-qa-cta rev-qa-cta--primary" id="revRznRetQa">
    <span class="rev-qa-ico" aria-hidden="true">📷</span>
    <span class="rev-qa-txt">
      <span class="rev-qa-title">SKENIRAJ ZA POVRAĆAJ</span>
      <span class="rev-qa-sub">RZN-… sa pločice — skener radi u seriji</span>
    </span>
  </button>
</section>
```

Handler:

```js
overlay.querySelector('#revRznRetQa')?.addEventListener('click', () => {
  openReversiScanOverlay({
    title: 'Skeniraj povraćaj',
    hint: 'RZN-… sa pločice — vraća se sa otvorenog reversa',
    acceptKinds: ['CUTTING'],
    continuous: true,
    onResult: async (parsed) => {
      await handleReturnScan(parsed.barcode);
    },
  });
});
```

Postojeći HID input ide u `<details>` fallback.

---

### 4.3 `src/styles/reversi.css` — novi quick-action stilovi

Dodati u sekciju gde se već definišu `.rev-modal--scanner` i `.rev-scan-grid`:

```css
/* Quick-action veliki CTA blok unutar scanner modala. Stilovi su sinhroni sa
   .m-cta familijom iz mobile.css, ali sa rev- prefiksom jer mogu da se
   pojave i izvan mobilnog shell-a (open in desktop modal). */
.rev-qa-block {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-bottom: 14px;
}

.rev-qa-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

@media (max-width: 480px) {
  .rev-qa-row { grid-template-columns: 1fr; }
}

.rev-qa-cta {
  display: flex;
  align-items: center;
  gap: 16px;
  min-height: 84px;
  padding: 18px 20px;
  border: 1px solid transparent;
  border-radius: 14px;
  font-family: inherit;
  color: #fff;
  cursor: pointer;
  text-align: left;
  transition: transform 80ms ease, box-shadow 120ms ease;
  -webkit-tap-highlight-color: transparent;
}
.rev-qa-cta:active { transform: scale(0.98); }
.rev-qa-cta:focus-visible { outline: 2px solid #93c5fd; outline-offset: 2px; }

.rev-qa-cta--primary {
  background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
  box-shadow: 0 4px 20px rgba(37, 99, 235, 0.35);
}
.rev-qa-cta--secondary {
  background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
  border-color: rgba(255, 255, 255, 0.12);
}

.rev-qa-ico { font-size: 30px; flex-shrink: 0; line-height: 1; }
.rev-qa-txt { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
.rev-qa-title { font-size: 16px; font-weight: 700; letter-spacing: 0.02em; }
.rev-qa-sub { font-size: 13px; font-weight: 400; opacity: 0.88; }

.rev-qa-manual { margin-top: 6px; }
.rev-qa-manual > summary {
  cursor: pointer;
  padding: 8px 10px;
  font-size: 13px;
  color: var(--rev-muted, #6b7b8e);
  border-radius: 8px;
  background: rgba(148, 163, 184, 0.08);
}
.rev-qa-manual[open] > summary { margin-bottom: 10px; }

.rev-btn--lg {
  min-height: 56px;
  padding: 14px 22px;
  font-size: 16px;
  font-weight: 700;
}
```

---

### 4.4 `src/ui/reversi/reznialat.js` — refraziranje teksta dugmadi

Trenutno: `📠 Zaduženje (skener)`, `↩ Povraćaj (skener)` — sugeriše HID.
Promeniti na:

```js
<button id="revRznScanIssue" class="rev-btn rev-btn--primary">
  <span class="rev-btn-ic" aria-hidden="true">📷</span>Zaduženje (kamera/skener)
</button>
<button id="revRznScanReturn" class="rev-btn rev-btn--outline-coral">
  <span class="rev-btn-ic" aria-hidden="true">📷</span>Povraćaj (kamera/skener)
</button>
```

Ovo je samo tekstualna izmena — funkcionalnost ostaje ista, ali korisnik
odmah razume da kamera radi.

---

### 4.5 (Opciono — preporučeno) Pre-fill operatera iz card_barcode

U `openCuttingToolIssueScannerModal()`, ako još nema `state.employee`,
posle prvog uspešnog **CUTTING** skena **automatski otvori karticu skener**:

```js
async function tryAddTool(barcode) {
  const r = await fetchCuttingToolByBarcode(barcode);
  if (!r.ok || !r.data?.id) { showToast(`Šifra nije pronađena: ${barcode}`); return; }
  addLineFromCatalog(r.data, 1);
  paint();
  if (!state.employee && state.lines.length === 1) {
    // first tool added — prompt for card right away
    setTimeout(() => overlay.querySelector('#revRznQaCard')?.click(), 250);
  }
}
```

Time je tok: tap "Skeniraj alat" → skenira RZN-… → modal sam pokreće
kameru za karticu → tap "Potvrdi". 3 tapa, ~5 sekundi.

---

## 5. Acceptance criteria (kako proveriti da je gotovo)

1. **Mobile (Chrome Android, telefon, portret):**
   - Otvori "Reversi" → tab "Rezni alat" → `Zaduženje (kamera/skener)`.
   - Modal pokazuje 3 velika dugmeta: **SKENIRAJ ALAT** (plavo, primary),
     **KARTICA OPERATERA**, **MAŠINA** (tamna, secondary).
   - Tap "SKENIRAJ ALAT" → puni ekran skener, kamera radi, vidiš laser i
     reticle. Skeniraj `RZN-000123` pločicu → vraća u modal, stavka je u listi.
   - Tap "KARTICA OPERATERA" → skener; skeniraj ID karticu → ime se
     pojavljuje kao podnaslov dugmeta.
   - Tap "MAŠINA" → skener; skeniraj `ZADU-M-…` → kod mašine pojavljuje
     se kao podnaslov.
   - **POTVRDI ZADUŽENJE** više nije sivo; tap → toast "✓ Zaduženje
     kreirano: REV-…".

2. **HID (USB skener) regresija:**
   - Isti modal, klikni "Manuelni / HID unos" → otvori se postojeći text
     input. Skeniraj USB skenerom → ENTER → ista logika (`handleScannedInput`)
     dodaje alat/mašinu/operatera. Postojeći USB tok ne sme da pukne.

3. **Povraćaj:**
   - Tab "Rezni alat" → `Povraćaj (kamera/skener)`.
   - Modal pokazuje veliko **SKENIRAJ ZA POVRAĆAJ**. Tap → continuous
     skener; skeniraj 2 različita RZN- → oba se pojavljuju u listi sa
     `remaining`/`return_qty`.
   - **POTVRDI POVRAĆAJ** → toast "✓ Povraćaj kreiran (N dokumenata)".

4. **Stari "Moja zaduženja" tab:**
   - FAB `Skeniraj` i dugme `Vrati alat (skener)` i dalje rade.
   - Sada nakon otvaranja modala "Vrati alat" odmah je dostupna kamera
     (preko novog dugmeta), ne samo HID input.

5. **Quick Issue regresija** — modal `openQuickIssueModal` se ne menja,
   mora i dalje da radi identično (već koristi `openReversiScanOverlay`).

6. **A11y:** sva nova dugmad imaju `aria-hidden="true"` na ikoni,
   `min-height` 84px, focus ring vidljiv (`:focus-visible`).

---

## 6. Šta NE diraj (van scope-a)

- `openIssueReversalModal` (klasičan desktop obrazac sa stavkama / kooperacijom).
- SQL / RPC pozive (`issueCuttingReversal`, `confirmCuttingReturn`).
- `scanOverlay.js` — kamera i decoder pipeline rade.
- Kataloški tab (`reznialat.js` deo iznad toolbara) — ostaje kao desktop UI.
- "Zaduženja" tab tabela — ne dira se.

---

## 7. Dodatni UX predlozi (za posle, NE u ovom PR-u)

Ovo su predlozi koji ubrzavaju rad ali su veći obim — otvoriti zasebne
zadatke ako se prihvate:

1. **Auto-detekt poslednje mašine za operatera** — pri skeniranju kartice,
   query `prijava_rada` poslednji red i pre-fill `state.machine`. Pattern
   već postoji u flow opisu `cuttingToolScannerModal.js` (vidi
   "default: poslednja mašina iz prijava_rada" u dokstringu).
2. **Audio feedback** — kratak "beep" posle uspešnog skena, "buzz" za
   nepoznat barkod. Vibracija već postoji (`navigator.vibrate?.(80)`).
3. **Offline queue za zaduženja** — postojeća
   [`src/services/offlineQueue.js`](../src/services/offlineQueue.js)
   već radi za premeštanja; isti pattern može da queue-uje
   `issueCuttingReversal` payloade.
4. **PWA "Add to home screen"** — `/m/reversi` ruta kao posebna
   mobile-only landing stranica (kao `/m`), sa istim CTA stilom iz
   `mobileHome.js`. Ovo je veći zahvat, posebna instrukcija.
5. **Skener nalepnice operatera na čelu/ruci** — Code128 kartice rade,
   ali QR (više bita) bi omogućio i dodatne metapodatke (npr. RFID
   fallback). Provera u `barcodeParse.js`.

---

## 8. Quick start za Cursor

1. Otvori
   [`src/ui/reversi/cuttingToolScannerModal.js`](../src/ui/reversi/cuttingToolScannerModal.js)
   — dodaj `import { openReversiScanOverlay } from './scanOverlay.js';`
2. U `openCuttingToolIssueScannerModal()`:
   - U `paint()`, na vrh `body.innerHTML` dodaj quick-action blok (4.1.1).
   - Postojeću `.rev-scan-input-row` i `.rev-scan-summary` umotaj u
     `<details class="rev-qa-manual">…</details>`.
   - U `bindEvents()`, dodaj 3 nova click handler-a (4.1.2).
   - Footer submit dugme dobija klase `rev-btn--lg rev-qa-submit` (4.1.4).
3. U `openCuttingToolReturnScannerModal()` — analogno: jedno veliko
   CTA + manual fallback (4.2).
4.  Dodaj CSS iz 4.3 u
   [`src/styles/reversi.css`](../src/styles/reversi.css).
5. U [`src/ui/reversi/reznialat.js`](../src/ui/reversi/reznialat.js)
   prepravi tekst dva dugmeta (4.4) — 2 reda.
6. (Opciono) Pre-fill card flow (4.5).
7. Pokreni `npm run dev`, testiraj kroz acceptance criteria iz sekcije 5
   na pravom telefonu (kamera ne radi u desktop Chrome bez HTTPS osim na
   `localhost`).
8. Pre PR-a: `npm run lint && npm test` — nije menjana logika, testovi
   moraju da prođu (postoje za `reversiCuttingImportHelpers`,
   `tspl2`, `revMapaCompute`).

Procena: **2–4h rada** uključujući manuelno testiranje na telefonu.

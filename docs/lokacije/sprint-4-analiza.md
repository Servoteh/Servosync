# Sprint LOC-Härd-4 — Korak 1 analiza

**Status:** OK za prelazak na Korak 2 (analiza je čisto frontend; nema otvorenih pitanja).
**Datum:** 2026-05-15
**Sprint dokument:** `HARDENING_SPRINTS.md` (Härd-4)

---

## 1. Document/window listeneri u `src/ui/lokacije/*`

| Fajl:linija | event | uklanja se? | komentar |
|---|---|---|---|
| modals.js:94 `bindEscClose` | keydown | ✅ kroz returnovani disposer | parno, svaki `openLocationModal/openQuickMove/openItemHistory` ga koristi sa `unbindEsc?.()` u close-u |
| modals.js:213-220 `openLocationModal` | (koristi bindEscClose) | ✅ ali samo ako `close()` bude pozvan | **H10:** ako `await fetchLocations()` baci exception (linija 226), `close()` se ne poziva, listener visi |
| scanModal.js:657 keydown onEsc | keydown | ✅ scanModal.js:637 u `close()` | parno |
| labelsPrint.js:37 keydown | keydown | ✅ labelsPrint.js:38 (returnovani disposer) | parno |
| lookupModals.js:46 keydown onKey | keydown | ✅ lookupModals.js:51 unutar handler-a samog | parno |
| **index.js:2376 mousedown** | mousedown | ❌ **H11** | nikad se ne uklanja |
| **index.js:2382 keydown** | keydown | ❌ **H11** | nikad se ne uklanja |
| **index.js:2389 resize** | resize | ❌ **H11** | nikad se ne uklanja |
| **index.js:2390 scroll** | scroll | ❌ **H11** | nikad se ne uklanja, čak je `passive:true` što ga čini još tišim |

`teardownLokacijeModule` (`index.js:2412-2420`) trenutno briše samo `mountRef`, `locPanelHost`, `historyUsersCache` i poziva `resetLabelsPrintPageState`. **Nijedan window/document listener iz `wireTabs` ne uklanja.** Pri svakom re-mount-u modula listeneri se dupliraju.

## 2. setTimeout / setInterval — 31 instanca

Tipovi:
- **Debounce timer-i** (`let t = null; clearTimeout(t); t = setTimeout(...)`) — index.js u `attachBrowseSearch`, `attachItemsSearch`, `attachHistoryFilters`, modals.js u `scheduleRefresh/TpList/Drawing`. **Svi imaju clearTimeout pre setovanja novog.** ✓
- **One-shot UI delay** (npr. fokus posle re-render-a) — `setTimeout(() => focus(), 50)` u scanModal. Ne zahteva cleanup.
- **CSV download cleanup** — `setTimeout(() => URL.revokeObjectURL(...), 100)` u index.js i csv.js. ✓
- **iOS visual viewport hack** — scanModal `requestAnimationFrame` + `setTimeout(180)`. Stop interval-a se cleanup-uje u `cleanupScan()`. ✓
- **androidChromeHintTimer** — `scanModal.js:728` setTimeout 8s. Cleanup u `clearAndroidChromeHintTimer()` koji se zove iz `handleDecodedBarcode`, `cancelLocationPick` i `cleanupScan`. ✓

**Nema curenja setTimeout-a** koje bi blokiralo GC.

## 3. Fetch / sbReq u event handler-ima bez AbortController-a

`AbortController` se **nigde** ne koristi u modulu Lokacije (0 matches). Postoji `signal:` parametar u `services/lokacije.js:fetchAllPlacements` i `fetchAllLocReportPartsByLocations` — prosleđuje se kroz `sbReq` (verovatno do fetch-a), ali **nijedan UI poziv ne prosleđuje signal**.

Konkretne lokacije bez timeout/abort:
- [predmetTab.js:286-290](../src/ui/lokacije/predmetTab.js#L286) — `Promise.all([fetchTpsForPredmet × 3])` bez abort (L21).
- [predmetTab.js:678](../src/ui/lokacije/predmetTab.js#L678) — CSV export loop koji može da curi posle close-a.
- [index.js:1230](../src/ui/lokacije/index.js#L1230) — dashboard `Promise.all` (6 paralelnih fetcheva) bez timeout-a; ako mreža visi, dashboard ostaje na loading-u.
- Items tab `fetchPlacements` u attachItemsSearch — debounced ali bez aborta starog request-a.

**Sprint preporuka (L21):** AbortController + 30s timeout u Predmet tabu. Ostali fetch-evi su out-of-scope za H-4 (pominju se u Härd-4 ali sprint detalji daju samo Predmet tab kao primer).

## 4. Status pojedinačnih nalaza

| Nalaz | Stanje | Akcija |
|---|---|---|
| **H9** `decodeBusy` flag | `try/finally` već postoji (scanModal.js:556-582). Rizik je da `setDecodeBusy` deluje na unmount-ovan DOM. | Dodaj `if (!overlay?.isConnected) return;` u handleDecodedBarcode posle `try`. |
| **H10** ESC listener leak | Listener se vezuje pre IIFE-a (modals.js:220). Ako `await fetchLocations()` baci, IIFE Promise rejecte-uje i `close()` se ne poziva. | Wrap async IIFE u `try/catch`; `close()` u catch grani. |
| **H11** wireTabs document listeneri | 4 listenera na document/window, 0 uklanja. | `const _lokDisposers = []` na modul-level. Svaki listener registruje disposer fn. `teardownLokacijeModule()` ih izvršava. |
| **M12** `nav.replaceWith(fresh)` | Click je delegiran na `container` koji se NE menja. `replaceWith` ne ruši delegaciju. Nema bug-a. | **Bez izmene** — verifikovano. |
| **M13** ERP lookup token race | Token se inkrementuje u `refreshItemState` (linija 1293) **pre awaita**. Debounce wrap (`scheduleRefresh`) clear-uje prethodni setTimeout pre setovanja novog, pa samo poslednji input pokreće fetch sa svežim token-om. **Nije race u praksi.** | **Bez izmene** — markiraj kao verifikovano. |
| **L21** AbortController u Predmet tab | `Promise.all` bez aborta. | Uvedi `AbortController` sa 30s timeout. **`sbReq` u `services/supabase.js` MORA da podržava `signal`** — proveriti pre izmene. |
| **M14** Batch queue LS perzistencija | Sprint kaže opciono, pita pre. | **Preskačemo** — namera je da batch queue bude volatilan (sprint dokument tako kaže). |

## 5. `sbReq` signal support — provera

Treba pogledati [src/services/supabase.js](../src/services/supabase.js) da li `sbReq` prima `signal` argument. Ako ne — refactor je veći nego što jedan sprint može.

**Provera odložena za Korak 2.** Ako `sbReq` ne podržava `signal`, mogućnost je:
- **A:** dodati podršku za `signal` u `sbReq` (mali refactor).
- **B:** koristiti `Promise.race([Promise.all(...), timeoutPromise])` — fetch se nastavlja u pozadini (curenje), ali UI dobija toast posle 30s.

Idemo sa **A** ako je `sbReq` čista fetch obrtka; **B** ako je kompleksniji wrapper.

## 6. Plan

### Korak 2 (sledeće, bez čekanja):
1. **H11** — `_lokDisposers` niz + cleanup u `teardownLokacijeModule` (najbolja vrednost po liniji koda).
2. **H10** — try/catch oko async IIFE u `openLocationModal`.
3. **H9** — `isConnected` check u `handleDecodedBarcode`.
4. **L21** — provera `sbReq` signal supporta, pa AbortController u predmetTab.
5. **M12, M13** — bez izmene, markiraj u MODUL_ANALIZA kao verifikovano.

Verifikacija: `npm test` (308/308), manual smoke da modul i dalje radi.

---

**STOP markeri nisu potrebni** — sprint pravila za Härd-4 ne zahtevaju potvrdu pre Koraka 2. Ako se ne slažeš sa odlukom da preskočimo M14 (LS perzistencija batch queue-a), reci pre nego što istekne ovaj sprint.

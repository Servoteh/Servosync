# PP Sprint 1A — pre-flight analiza

> Datum: 2026-05-16 · Status: završeno, kreirano pre koda · Zavisi od: [Sprint 1A cursor instrukcija](cursor-instrukcije/pp-sprint1a.md) i [Sprint 0 status](pp-sprint0-status.md)

Cilj: pre `git commit` na M16/H14/M22 dokumentovati tačne lokacije, postojeću infrastrukturu, i konkretne posledice (uključujući prioritetne korekcije gde se pokazuje da je posao već urađen).

---

## 1. M16 — `clearTimeout` u 4 teardown-a

### Krupna korekcija: **M16 je VEĆ PRIMENJEN.**

Sprint 0 audit ([pp-sprint0-code-checks.md](pp-sprint0-code-checks.md#4-settimeout--setinterval-u-modulu)) i Sprint 0 status fajl su pretpostavljali da `clearTimeout` u teardown-u nije eksplicitno potvrđen. Eksplicitan re-grep pokazuje suprotno — **sva 4 taba već imaju `clearTimeout` + `null` reset u `teardown` funkciji.**

| Tab | Teardown linija | `clearTimeout(rnFilterTimer)` | `state.rnFilterTimer = null` |
|---|---:|:-:|:-:|
| `poMasiniTab.js` | 155 (`teardownPoMasiniTab`) | ✅ 162 | ✅ 163 |
| `zauzetostTab.js` | 228 (`teardownZauzetostTab`) | ✅ 234 | ✅ 235 |
| `pregledTab.js` | 110 (`teardownPregledTab`) | ✅ 116 | ✅ 117 |
| `kooperacijaTab.js` | 73 (`teardownKooperacijaTab`) | ✅ 77 | ✅ 78 |

### Šta to znači za PR plan

- **M16 commit NE PRAVIMO** — nema šta da menjamo. Status quo je već čist.
- Sprint 0 nalaz „M16 — Pending setTimeout posle teardown-a" je **invalidan** kao bug; mora se ažurirati u Sprint 0 status fajlu.
- PR ima 3 commit-a umesto 4: `analysis` → `H14` → `M22`.

### Dodatni timer u `poMasiniTab.js:1615`

Pored `rnFilterTimer`, postoji još jedan `setTimeout` u `poMasiniTab.js:1615`:
```js
setTimeout(() => indicator.classList.remove('is-visible'), 1400);
```
Ovo je „Sačuvano" indikator timer — 1400ms, kratak, vizuelni feedback. Ne čuva se u state-u i ne otkazuje se u teardown-u. **Prihvatljiv kompromis** (audit kategorija: kao modal focus timer, niski rizik). Ostavlja se kao status quo.

---

## 2. H14 — `Promise.all` timeout u `pregledTab.js`

### Trenutni kod ([pregledTab.js:123-144](../../src/ui/planProizvodnje/pregledTab.js#L123))

```js
async function reload() {
  if (!state.host) return;
  state.loading = true;
  state.error = null;
  setRefreshSpinning(true);
  try {
    const [machines, rows] = await Promise.all([
      loadMachines(),
      loadAllOpenOperations(),
    ]);
    state.machinesMap = new Map((machines || []).map(m => [m.rj_code, m]));
    state.rows = rows || [];
    renderMatrix();
  } catch (e) {
    console.error('[pregled] reload failed', e);
    state.error = 'Greška pri učitavanju (' + (e?.message || e) + ')';
    renderMatrix();
  } finally {
    state.loading = false;
    setRefreshSpinning(false);
  }
}
```

### Nalazi
- `try/catch` postoji ✅ (postojeći error path se preusmerava na `renderMatrix()` sa `state.error`).
- Rezultat se dodeljuje state-u (`state.machinesMap`, `state.rows`).
- **Nema `AbortController` ni timeout-a** — ako `loadMachines` ili `loadAllOpenOperations` visi, `await Promise.all` čeka zauvek.
- `state.loading` postavlja `setRefreshSpinning(true)` ali ne menja main view-a.
- **Nema `state.activeRequestId` ni postojećeg token pattern-a.** Treba dodati.

### Implementacioni plan
Dodajem **token pattern** kao u revidiranoj Sprint 1A instrukciji. Token guard štiti i protiv:
- Tab teardown-a tokom in-flight request-a (teardown invalidira sve postojeće token-e).
- „Pokušaj ponovo" klika pre nego što prva fetch resolve-uje.
- Brze sekvence Osveži klikova.

State proširenje:
```js
const state = {
  // ... postojeće ...
  loadToken: 0,
  loadTimeoutId: null,
};
```

Timeout: 15s (instrukcija eksplicitno fiksira). Na timeout: prikazuje se `pp-load-error` div sa retry dugmetom + `showToast`.

`teardownPregledTab` dodatak: invalidira `loadToken` (`state.loadToken = (state.loadToken || 0) + 1`) i otkazuje `loadTimeoutId`. Postojeći `clearTimeout(state.rnFilterTimer)` ostaje.

### CSS
Postojeća `.pp-warning` klasa ([planProizvodnje.css:758](../../src/styles/planProizvodnje.css#L758)) je dark-theme amber. Reuse: `<div class="pp-load-error pp-warning">...</div>`. Layout-only dodatak za centriranje sadržaja:
```css
.pp-load-error { text-align: center; padding: 16px 12px; }
.pp-load-error p { margin: 0 0 12px; }
```

---

## 3. M22 — UI banner za 10K cap

### Trenutni kod ([planProizvodnje.js:380-421](../../src/services/planProizvodnje.js#L380))

```js
export async function loadAllOpenOperations() {
  if (!getIsOnline()) return [];
  const cols = [/* 21 kolona */].join(',');
  const params = new URLSearchParams();
  params.set('select', cols);
  // ... 5 filtera ...
  params.set('limit', '10000');

  const data = await sbReq(`v_production_operations_effective?${params.toString()}`);
  return sortProductionOperations(nonNullRows(data, 'v_production_operations_effective_all_open'));
}
```

Return shape: **Array** (rezultat `sortProductionOperations(...)`).

### Caller-i (potvrđeno grep-om — samo 2)
| Fajl | Linija | Kontekst |
|---|---:|---|
| [pregledTab.js](../../src/ui/planProizvodnje/pregledTab.js) | 131 | `Promise.all([loadMachines(), loadAllOpenOperations()])` |
| [zauzetostTab.js](../../src/ui/planProizvodnje/zauzetostTab.js) | 251 | isti pattern |

Oba destrukturiraju u promenljivu `rows` i koriste je kao niz.

### `sbReqWithCount` već postoji

Potvrđeno u [supabase.js:197-215](../../src/services/supabase.js#L197):
```js
export async function sbReqWithCount(path) {
  return sbReq(path, 'GET', null, { withCount: true });
}
```
- Šalje `Prefer: count=exact` (linija 256)
- Parsira `Content-Range` (linija 180-183, helper `parseContentRangeTotal` 207-215)
- Vraća `{ rows, total }` gde su oba ili oba `null` (kod fetch fail-a)

**Ne treba menjati `sbReq` niti dodavati novi `countMode` parametar.** Cursor instrukcija je pravilno reduktovana — koristim direktno postojeći wrapper.

### Refaktor plan

1. **`loadAllOpenOperations`** menja return na:
   ```js
   { rows: Array, total: number, truncated: boolean, limit: number }
   ```
   `total` dolazi iz `Content-Range`. Ako server vrati `null` total (npr. PostgREST greška), fallback: `total = rows.length`, `truncated = false`.

2. **Caller-i** mestima 131 i 251 menjaju destrukturiranje:
   ```js
   const [machines, opsResult] = await Promise.all([...]);
   state.rows = opsResult.rows || [];
   if (opsResult.truncated) renderTruncationBanner(state.host, { shown: ..., total: opsResult.total });
   ```

3. **Banner DOM** — copy-paste `renderTruncationBanner` u oba taba (modul nema `_shared.js` konvenciju). Banner ide `host.prepend(wrap)` da ne menja postojeću tablu.

4. **CSS** — reuse postojeće `.pp-warning` palete:
   ```css
   .pp-truncation-banner { display: flex; gap: 8px; align-items: center; margin: 0 0 12px; }
   .pp-truncation-icon { font-size: 16px; }
   ```

### Test impact

Grep `tests/**/planProizvodnje*.test.js`:
- `tests/services/planProizvodnjeCamReady.test.js`
- `tests/services/planProizvodnjeG2.test.js`
- `tests/services/planProizvodnjeG5.test.js`

**Nijedan test ne pokriva `loadAllOpenOperations`.** Nema test update-a potrebnih. Funkcionalna verifikacija mora biti manuelna (kao u Acceptance kriterijumima).

### Real-world impact

Sprint 0 SQL #11: **18 299 otvorenih operacija u produkciji** vs `limit=10000`. Banner će se odmah pojaviti u oba taba.

---

## 4. Sažeti plan PR-a

**3 commit-a** (originalno 4, M16 ispada):

| # | Commit | Fajlovi | Risk |
|---|---|---|---|
| 1 | `docs: pp sprint 1A pre-flight analysis` | `docs/migration/pp-sprint1a-analysis.md` (ovaj fajl) | 0 |
| 2 | `pp: 15s timeout guard for Promise.all in pregledTab (H14)` | `pregledTab.js`, `planProizvodnje.css` | Nizak — token pattern + reuse `.pp-warning` |
| 3 | `pp: warn user when loadAllOpenOperations truncates at 10K (M22)` | `planProizvodnje.js`, `pregledTab.js`, `zauzetostTab.js`, `planProizvodnje.css` | Srednji — `loadAllOpenOperations` return shape menja se sa Array na Object; samo 2 caller-a, oba pokrivena |

Ukupno realno vreme: ~2h (manje od originalne procene 3h jer M16 ispada).

---

## 5. Stvari koje NEĆE biti urađene u Sprint 1A

- M16 — već urađeno, ali Sprint 0 status fajl treba update da odražava verifikaciju (sledeća iteracija ili manuelni edit).
- H13 (event delegation) — Sprint 1C.
- H1 (G5 idempotency) — Sprint 1B.
- Bilo koji SQL change — Sprint 1A je pure frontend/service.

---

**Status:** ANALIZA ZAVRŠENA. Krećem sa H14 commit-om.

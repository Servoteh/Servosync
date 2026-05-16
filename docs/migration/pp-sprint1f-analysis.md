# PP Sprint 1F — pre-flight analiza (H28 + M20: Bridge health banner)

> Datum: 2026-05-16 · Sprint: 1F · Audit ref: H28 (bridge bez health-check) + M20 (bridge staleness nije vizuelno označen)

## Cilj

Dodati operativni banner u Plan proizvodnje modul koji upozorava operatera kada BigTehn cache nije svež. Trenutno modul tiho čita iz cache-a koji može biti star satima — operater donosi odluke (spremnost, status u radu) na zastarelim podacima bez ikakve indikacije.

H28 i M20 su iste suštine — H28 govori o nedostatku health-check pristupa, M20 o nedostatku UI banner-a. Rešavaju se zajedno.

## Postojeća infrastruktura

Lokacije modul je već implementirao zdravstveni banner u Härd-3 sprintu:
- [services/lokacije.js:844](../../src/services/lokacije.js#L844) — `fetchBridgeSyncStatus()` čita iz `bridge_sync_log` PostgREST tabele
- [ui/lokacije/index.js:229](../../src/ui/lokacije/index.js#L229) — `renderBridgeStaleBanner(statusList)` helper

`bridge_sync_log` je zajednička infrastruktura (svaki cache job upisuje finished_at + status posle završenog sync-a). PP modul može da je koristi bez DB izmena.

**Strategija reuse-a:** ne radim cross-module import iz `services/lokacije.js`. Umesto toga **paralelni helper u `services/planProizvodnje.js`** koji filtrira samo PP-relevantne sync job-ove. Dva razloga:
1. Različiti thresholds — Lokacije koristi 6h za RN (katalog), PP-u je 30 min već puno (real-time operativa).
2. Manje cross-module dependencies u service sloju.

## PP-relevantni sync job-ovi

Iz Lokacije banner-a (postojeća lista), PP zavisi od:
- `production_work_orders` — RN cache (`bigtehn_work_orders_cache`)
- `production_work_order_lines` — linije TP (`bigtehn_work_order_lines_cache`)
- `production_tech_routing` — prijave operatera (`bigtehn_tech_routing_cache`) — **kritično za G6 i PP-A readiness**

NE uključujem:
- `catalog_items` — predmet aktivacija, sporo se menja
- `production_bigtehn_drawings` — PDF crteži, ne blokira plan

## Threshold dizajn (drugačiji od Lokacije)

| Stanje | Threshold | Vizuel | Akcija |
|---|---:|---|---|
| Svež | < 30 min | Banner skriven | nema |
| Kašnjenje | 30 min – 2 h | Žuti `.pp-warning` banner sa ⚠ | informativno |
| Mrtav | > 2 h | Crveni banner sa 🔴 | „spremnost i status u radu možda nisu tačni" |

Razlog: bridge sinhronizuje svakih 15 min. 30 min praga znači **2 ciklusa propuštena** = nešto je zaista pogrešno. 2 h = bridge je sigurno offline ili u problemu.

**Ne blokiramo write akcije** (M20 je predlagao to za 2h prag). Razlog: REASSIGN/status/napomena ide u **overlay tabelu**, ne u BigTehn. Lokalne odluke šefa smene su validne bez obzira na bridge stanje. Banner samo upozorava da je **prikazani BigTehn deo** zastareo.

## Refresh strategija

Banner se učitava **jednom po mount-u modula** (`renderPlanProizvodnjeModule`). Tab switch trigger-uje re-render → banner se osvežava. Korisnik koji ostaje na istom tabu duže od sat vremena bez prebacivanja vidi old banner stanje — to je kompromis.

**Ne dodajem `setInterval`.** Razlozi:
- Memory leak risk (setInterval mora se očistiti u teardown-u, dodatni state).
- Bridge ima 15-min interval → koristnik koji vidi „nije svež 35 min" za 30 sek može da vidi „svež 5 min" bez akcije od strane korisnika. To nije bug, samo neažurirana info.
- Praktično: operater će sve vreme prebacivati tabove (Po mašini ↔ Zauzetost), pa će banner sigurno biti svež.

Ako se kasnije pokaže da je interval potreban, dodaje se kao Sprint 1F+1.

## Defensive handling

`fetchPpBridgeSyncStatus()` može da vrati `null`/`[]` ili da baci:
- Ako `bridge_sync_log` tabela ne postoji (npr. fresh env bez bridge-a)
- Ako RLS odbije (mada Lokacije kažu da je open authenticated)
- Ako network fail

U svim slučajevima: **banner ostaje skriven**, bez konzole error-a vidljivih korisniku. Tih fallback je kritičan jer ovo nije core feature.

## Implementacija

### `services/planProizvodnje.js`

```js
const PP_BRIDGE_JOBS = new Set([
  'production_work_orders',
  'production_work_order_lines',
  'production_tech_routing',
]);

const PP_BRIDGE_LABELS = {
  production_work_orders: 'RN',
  production_work_order_lines: 'Linije TP',
  production_tech_routing: 'Prijave operatera',
};

/**
 * H28/M20: vraća najnoviji finished_at po PP-relevantnom sync job-u.
 * Tih fallback ako tabela ne postoji ili PostgREST fail-uje.
 */
export async function fetchPpBridgeSyncStatus() {
  try {
    const rows = await sbReq(
      `bridge_sync_log?select=sync_job,finished_at,status&order=finished_at.desc&limit=200`,
    );
    if (!Array.isArray(rows)) return [];
    const seen = new Map();
    for (const r of rows) {
      if (!r || !PP_BRIDGE_JOBS.has(r.sync_job)) continue;
      if (!seen.has(r.sync_job)) {
        seen.set(r.sync_job, {
          sync_job: r.sync_job,
          last_finished: r.finished_at,
          status: r.status,
        });
      }
    }
    return Array.from(seen.values());
  } catch (_e) {
    return [];
  }
}

export { PP_BRIDGE_LABELS };
```

### `ui/planProizvodnje/index.js`

Shell HTML dobija novi `<div id="ppBridgeBanner">` između `</nav>` i `<main>`. Async helper:

```js
async function renderPpBridgeBanner(host) {
  if (!host) return;
  host.innerHTML = '';
  let status;
  try { status = await fetchPpBridgeSyncStatus(); }
  catch (_e) { return; }
  if (!status?.length) return;

  const now = Date.now();
  const WARN_MS     = 30 * 60 * 1000;
  const CRITICAL_MS =  2 * 60 * 60 * 1000;
  let worstAge = 0;
  const staleParts = [];

  for (const it of status) {
    const t = it.last_finished ? Date.parse(it.last_finished) : NaN;
    if (!Number.isFinite(t)) continue;
    const ageMs = now - t;
    if (ageMs <= WARN_MS) continue;
    worstAge = Math.max(worstAge, ageMs);
    const min = Math.round(ageMs / 60000);
    const hours = Math.round(ageMs / 3600000);
    const ageStr = min < 120 ? `${min} min` : `${hours} h`;
    const label = PP_BRIDGE_LABELS[it.sync_job] || it.sync_job;
    staleParts.push(`<strong>${escHtml(label)}</strong> · pre ${escHtml(ageStr)}`);
  }

  if (!staleParts.length) return;

  const isCritical = worstAge > CRITICAL_MS;
  const wrap = document.createElement('div');
  wrap.className = isCritical
    ? 'pp-warning pp-bridge-banner pp-bridge-critical'
    : 'pp-warning pp-bridge-banner';
  wrap.innerHTML = `
    <span class="pp-bridge-icon" aria-hidden="true">${isCritical ? '🔴' : '⚠'}</span>
    <span>
      <strong>Bridge sync ${isCritical ? 'NE RADI' : 'kasni'}:</strong>
      ${staleParts.join(' · ')}.
      ${isCritical
        ? 'Spremnost crteža i status u radu možda nisu tačni.'
        : 'Podaci možda nisu sveži.'}
    </span>
  `;
  host.appendChild(wrap);
}
```

Poziv: posle `mountEl.appendChild(container)` u `renderPlanProizvodnjeModule`:
```js
void renderPpBridgeBanner(container.querySelector('#ppBridgeBanner'));
```

Fire-and-forget — ne blokira render glavnog modula.

### CSS

```css
.pp-bridge-banner {
  display: flex;
  gap: 8px;
  align-items: center;
  margin: 8px 24px 0;
}
.pp-bridge-banner.pp-bridge-critical {
  color: #fca5a5;
  background: color-mix(in srgb, #dc2626 14%, transparent);
  border-color: color-mix(in srgb, #dc2626 32%, transparent);
}
.pp-bridge-icon {
  flex-shrink: 0;
  font-size: 14px;
}
```

`margin: 8px 24px 0` matches glavni `<main style="padding:24px...">` padding tako da banner deluje pravilno-poravnat.

## Acceptance kriterijumi

- Banner se ne pokazuje ako su svi PP sync job-ovi mlađi od 30 min.
- Banner se pokazuje žuto (sa ⚠) ako bar jedan job stariji od 30 min, mlađi od 2 h.
- Banner se pokazuje crveno (sa 🔴) ako bar jedan job stariji od 2 h.
- Ako `bridge_sync_log` ne postoji ili fetch fail-uje, banner ostaje skriven (bez konzole error-a vidljivih korisniku).
- Tab switch re-render-uje banner sa svežim podacima.

## Risk i rollback

- **Risk:** Nizak. Strogo aditivna izmena, fire-and-forget render, tih fallback.
- **Rollback:** `git revert` jednog commit-a. Banner nestaje, modul se ne menja drugačije.

## Vremenska procena

- Pre-flight: 30 min ✅
- Implementacija: 60 min
- Manuelni smoke test: 15 min (DevTools: izmeniti sat unazad da simuliraš stale cache)
- **Ukupno: ~1.5h**

## Stvari koje NEĆE biti u Sprint 1F

- Blokiranje write akcija na 2h prag (audit M20 sugestija, ali overlay je lokalan — write je validan bez bridge-a).
- Auto-refresh interval — kasnije ako bude potrebno.
- Health log za G6 RPC posebno (M29) — bridge skripta već propagira error.
- Detaljnije po-tabeli granularnost — trenutni 3 sync job-a su dovoljna pokrivenost.

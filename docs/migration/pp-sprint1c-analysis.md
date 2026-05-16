# PP Sprint 1C — pre-flight analiza (H13: event delegation u poMasiniTab)

> Datum: 2026-05-16 · Sprint: 1C · Audit ref: H13 u [Plan_proizvodnje_modul_analiza.md](../Plan_proizvodnje_modul_analiza.md)

## Cilj

Eliminisati ponavljano vezivanje 13+ listenera po redu na svakom `renderTable()` pozivu u `src/ui/planProizvodnje/poMasiniTab.js`. Refactor sa direktnih per-element `addEventListener` poziva na **event delegation** pattern — jedan listener po tipu događaja na stabilan `wrap` element, dispatcher na osnovu `data-action` atributa.

## Problem (audit H13)

Trenutno (`wireRows` na liniji 1256-1314): za svaku stavku u tabeli, na svakom `renderTable` izvršenju, kreira se 13 zasebnih event listener-a:
- 2× change (select-row, select-all-rows, toggle-cam-ready)
- 9× click (cycle-status, reassign-open, send-cooperation, toggle-urgent, toggle-pin, open-drawings, open-bigtehn-drawing, open-tech-procedure, why-bottleneck)
- 2× focus + blur (edit-note)
- 4× drag-drop event na `tbody` (dragstart, dragend, dragover, drop)

`renderTable` se izvršava:
- Na RN filter promenu (debounce 200ms) → potencijalno ~10×/min pri intenzivnom kucanju
- Posle svakog `loadOperationsForMachine` (~ručno Osveži)
- Posle svakog `loadOperationsForDept` (department prikaz)
- Posle svakog status/CAM/HITNO/pin akcionog toggle-a (state mutacija → renderTable)

**Skala:** mašina sa 100 ops × 13 listenera × 10 filter-otkucaja = **13 000 bind operacija u minutu** na slabijim mašinama. CPU cost je primetan na PC u proizvodnji (10-godišnja konfiguracija).

## Postojeća struktura — sve već ima `data-action`

Refactor je čist jer `rowHtml` u [poMasiniTab.js:1050-1206](../../src/ui/planProizvodnje/poMasiniTab.js#L1050) već dodaje `data-action="..."` atribute na svaki interaktivni element. Header isto (`data-action="select-all-rows"`). Drag-drop koristi `draggable="true"` + `data-key`.

Mapa `data-action` → handler:

| data-action | Element | Event | Handler funkcija | Linija |
|---|---|---|---|---|
| `select-row` | input checkbox | change | onToggleRowSelection | 1316 |
| `select-all-rows` | input checkbox | change | onToggleAllRowsSelection | 1324 |
| `cycle-status` | button | click | onCycleStatus | 1549 |
| `toggle-cam-ready` | input checkbox | change | onToggleCamReady | 1346 |
| `edit-note` | textarea | focus + blur | onSaveNote | 1587 |
| `reassign-open` | button | click | onReassign | 1621 |
| `send-cooperation` | button | click | onSendCooperation | 1370 |
| `toggle-urgent` | button | click | onToggleUrgent | 1400 |
| `toggle-pin` | button | click | onTogglePin | 1422 |
| `open-drawings` | button | click | onOpenDrawings | 1445 |
| `open-bigtehn-drawing` | button | click | onOpenBigtehnDrawing | 1480 |
| `open-tech-procedure` | button | click | onOpenTechProcedure | 1535 |
| `why-bottleneck` | button | click | onWhyBottleneck | 1521 |

## Tehnička pitanja

### 1. Gde bind-ovati delegated listenere?

**Opcija A:** `state.host` (top-level mount).
**Opcija B:** `#ppTableWrap` (`wrap` u `renderTable`).
**Opcija C:** WeakSet + bind po prvom render-u.

Odabrana: **opcija B sa `dataset.handlersAttached` flag-om**. Razlozi:
- `wrap` element je stabilan unutar jedne sesije (`renderTable` menja `wrap.innerHTML`, ne sam `wrap`).
- Bind-uje se jednom, naredni `wireRows()` pozivi su no-op (`if (wrap.dataset.handlersAttached === '1') return;`).
- Manji blast-radius od bind-a na `state.host` — drugi UI elementi u host-u sa istim `data-action` nazivima ne mešaju se.
- Ako `wrap` bude re-kreiran (fallback grana u `renderTable` koja pravi novi `#ppTableWrap` iz `#ppBody`), novi wrap nema flag → bind-uje se. ✅

### 2. Focus/blur za textarea note

`focus` i `blur` ne bubble-uju po default-u. **Rešenje:** `focusin` / `focusout` koji bubble-uju.

`originalVal` parametar za `onSaveNote(ta, originalVal)` se trenutno kapturira u closure-u na `focus`. Sa delegation-om, čitam ga iz `state.rows` u `focusout` handler-u:

```js
wrap.addEventListener('focusout', e => {
  const ta = e.target;
  if (!(ta instanceof HTMLTextAreaElement)) return;
  if (ta.dataset?.action !== 'edit-note') return;
  const tr = ta.closest('tr');
  const woId = Number(tr?.dataset.wo);
  const lineId = Number(tr?.dataset.line);
  const row = state.rows.find(r => r.work_order_id === woId && r.line_id === lineId);
  onSaveNote(ta, row?.shift_note || '');
});
```

`focusin` se ne mora bind-ovati — `originalVal` se izračuna lazy na blur-u iz aktuelnog state-a. Eliminisan je intermediate closure.

### 3. Drag-drop relocation

Trenutno na `tbody` (linija 1823-1900). `tbody` je deo `wrap.innerHTML` koji se zamenjuje pri svakom render-u → drag-drop listeneri se re-bind-uju.

**Rešenje:** Relocate dragstart/dragend/dragover/drop sa `tbody` na `wrap`. Selector `tr[draggable="true"]` u dragstart handler-u i dalje radi (svi drag eventi bubble-uju). Listeneri se bind-uju jednom (`wrap.dataset.dragdropAttached === '1'`).

`allowDragDrop` parametar iz `wireRows` postaje **rendering hint** (kontroliše `draggable="true"` u rowHtml), ne više bind-time decision. Drag-drop listeneri su uvek vezani; ako trenutni red nije draggable, `dragstart` handler vraća early (`tr` selector ne hvata).

### 4. Backward compat sa filter-aktivnim prikazom

Postojeća logika: kad je RN filter aktivan, drag-drop je onemogućen (`allowDragDrop: allowDragDrop && !filterActive` u liniji 977). To se postiže izostavljanjem `draggable="true"` u `rowHtml`. **Refactor ne menja to ponašanje** — listener će biti vezan, ali `dragstart` neće okidati jer redovi nisu draggable.

## Plan implementacije

### Commit 1: Pre-flight analiza (ovaj fajl)

### Commit 2: Refactor `wireRows` + `wireDragDrop` na delegation

Izmene u `src/ui/planProizvodnje/poMasiniTab.js`:

1. **`wireRows(wrap, { allowDragDrop })` postaje idempotentan.**
   - Provera `if (wrap.dataset.handlersAttached === '1') return;` na ulazu.
   - Postavlja `wrap.dataset.handlersAttached = '1'` pre bind-a.
   - Bind-uje 4 listenera: `click`, `change`, `focusout`, drag-drop ostaje u istoj funkciji.
   - Click dispatcher: `e.target.closest('[data-action]')` → switch po `dataset.action` → odgovarajući handler.
   - Change dispatcher: isti pattern za input checkbox-e.
   - Focusout dispatcher: handle samo `edit-note` textarea, čita `originalVal` iz `state.rows`.
   - `allowDragDrop` parametar zadržava se za buduće potrebe, ali ne kontroliše bind (drag listeneri uvek vezani).

2. **`wireDragDrop(wrap)` postaje idempotentan i bind-uje na `wrap`.**
   - Provera `if (wrap.dataset.dragdropAttached === '1') return;`.
   - 4 listenera (dragstart, dragend, dragover, drop) na `wrap` umesto na `tbody`.
   - `e.target.closest('tr[draggable="true"]')` za dragstart, `e.target.closest('tr')` za dragover/drop.
   - Postojeća logika unutar handler-a nedotaknuta.

### Vremenska procena

- Pre-flight analiza: 30 min ✅
- Refactor implementacija: 90 min (jedan veliki fajl, mnogo pažljivog editing-a)
- Manuelni smoke test: 30 min
- **Ukupno: ~2.5h**

## Acceptance kriterijumi

- Sve postojeće akcije (klik na status, CAM checkbox, napomena, REASSIGN, HITNO, pin, skice, BigTehn PDF, TP modal, Zašto modal, drag-drop reorder) rade identično kao pre.
- Posle 10× tab switch-a i filter promene, broj listenera na `wrap` elementu (DevTools → Inspect → "Event Listeners" tab) **ostaje konstantan** (~5: click, change, focusout, dragstart, dragend, dragover, drop = ~7).
- DevTools Performance snapshot tokom intenzivnog filter kucanja → ne pokazuje stotine `addEventListener` poziva.
- Drag-drop reorder radi unutar single-machine view-a; u "Sve" prikazu sa active filterom je onemogućen (kao i pre).
- Read-only korisnici (viewer/leadpm/hr) ne mogu da pokrenu write akcije — `disabled` atribut prosi sve (kao i pre).

## Rollback plan

Refactor je u jednom commit-u. `git revert <hash>` vraća staru implementaciju. Risk: srednji — `poMasiniTab.js` je 1954 linije, mnoge interakcije, manuelni test mora pokriti sve 13 akcija + drag-drop.

## Stvari koje NEĆE biti urađene u Sprint 1C

- H15 (drag-drop cleanup na tab switch) — biće rešen istom refactorom jer su listeneri vezani za `wrap` koji nestaje sa teardown-om.
- M17 (ESC key konkurentnost) — modal lifecycle je nepromenjen.
- M21 (PP-A perf test) — odvojen Sprint 1D.
- L23 (virtualizacija tabele) — kasnije.

## Sledeći koraci

1. Commit pre-flight analize.
2. Refactor implementacija.
3. Push.
4. Manuelni smoke test od strane Jare na staging/dev.
5. Posle validacije, krenuti sa Sprint 1D (M21 EXPLAIN ANALYZE).

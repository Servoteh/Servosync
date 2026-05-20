# REVERSI — "Unesi ime radnika" pored skeniranja kartice

> Follow-up na [CURSOR_REVERSI_MOBILNI_SKENER.md](./CURSOR_REVERSI_MOBILNI_SKENER.md).
> Cilj: kada radnik **nema karticu uz sebe**, magacioner može da ga izabere
> kucanjem imena umesto skeniranja ID-a. Ostaje isto — `state.employee = { id, full_name }`
> sa **stvarnim `id` iz baze** (ne free-text), tako da `issueCuttingReversal`
> RPC poziv radi identično.

---

## 1. UX odluka

Modal `openCuttingToolIssueScannerModal` ([src/ui/reversi/cuttingToolScannerModal.js](../src/ui/reversi/cuttingToolScannerModal.js))
trenutno ima 3 velika CTA dugmeta: **SKENIRAJ ALAT** / **KARTICA OPERATERA** / **MAŠINA**.

Dodaj **četvrti CTA** ispod prva tri kao `<details>` koji se širi inline —
ne otvara novi modal. Razlog: na mobilnom telefonu nema mesta za 4 ravnopravna
CTA u istom redu, a otvaranje novog modala preko postojećeg modala je naporno.

Layout posle izmene:

```
┌────────────────────────────────────────┐
│ 📷 SKENIRAJ ALAT                       │  ← primary, full width
└────────────────────────────────────────┘
┌──────────────────┬─────────────────────┐
│ 🆔 KARTICA OPER. │ 🏭 MAŠINA           │  ← secondary, 2 col
└──────────────────┴─────────────────────┘
┌────────────────────────────────────────┐
│ ✍ UNESI IME RADNIKA              ▼     │  ← novo, secondary, full width
└────────────────────────────────────────┘
  └── kad je otvoreno:
      ┌──────────────────────────────────┐
      │ [search input: Pretraga…]         │
      ├──────────────────────────────────┤
      │ ▸ Petar Petrović (Mašinska RJ)   │
      │ ▸ Marko Marković (Brusionica)    │
      │ ▸ … (max 8 redova, scroll)       │
      └──────────────────────────────────┘
```

**Zašto NE samo `<select>`:** u bazi ima 200+ zaposlenih, native mobile
`<select>` sa 200 opcija je nečitljiv. Search + lista sa max 8 rezultata
radi i u rukavicama.

**Zašto NE free-text bez `id`:** RPC `issueCuttingReversal` traži
`issued_to_employee_id` (UUID). Slobodan unos imena bez ID-a bi pukao na
backend-u. Ako radnik nije u bazi → mora ga prvo HR uvesti.

---

## 2. Konkretne izmene

### 2.1 [src/ui/reversi/cuttingToolScannerModal.js](../src/ui/reversi/cuttingToolScannerModal.js)

#### 2.1.1 Dodaj state polje

U `openCuttingToolIssueScannerModal()`, u `const state = { ... }` objekat:

```js
const state = {
  machine: null,
  employee: null,
  lines: [],
  machines: [],
  employees: [],
  expectedReturnDate: '',
  napomena: '',
  secondaryIds: [],
  pending: false,
  lastInput: '',
  empPickQuery: '',         // ← NOVO
  empPickRows: null,        // ← NOVO (null = koristi state.employees, array = filtered server result)
};
```

#### 2.1.2 Render — dodaj `<details>` posle `.rev-qa-row`

U `paint()`, unutar `<section class="rev-qa-block">`, **odmah posle**
`</div>` od `.rev-qa-row` (dakle ispod KARTICA + MAŠINA), pre `</section>`:

```js
<details class="rev-qa-pick" id="revRznQaEmpDetails" ${state.employee ? '' : ''}>
  <summary class="rev-qa-cta rev-qa-cta--secondary rev-qa-cta--pick">
    <span class="rev-qa-ico" aria-hidden="true">✍</span>
    <span class="rev-qa-txt">
      <span class="rev-qa-title">UNESI IME RADNIKA</span>
      <span class="rev-qa-sub">${state.employee ? escHtml(state.employee.full_name) : 'Bez kartice — pretraga po imenu'}</span>
    </span>
    <span class="rev-qa-pick-chevron" aria-hidden="true">▾</span>
  </summary>
  <div class="rev-qa-pick-body">
    <input type="search" id="revRznQaEmpSearch" class="rev-input" autocomplete="off"
           placeholder="Pretraga: ime, prezime…" value="${escHtml(state.empPickQuery)}"/>
    <ul class="rev-qa-emp-list" id="revRznQaEmpList"></ul>
  </div>
</details>
```

#### 2.1.3 Helper funkcija — popuni listu

Dodaj **van** `bindEvents()` ali unutar `openCuttingToolIssueScannerModal()`,
pored ostalih helper-a (`tryAddTool`, `addLineFromCatalog`):

```js
function paintEmpPickList(rows) {
  const ul = overlay.querySelector('#revRznQaEmpList');
  if (!ul) return;
  const list = Array.isArray(rows) ? rows : state.employees;
  const limited = list.slice(0, 8);
  if (limited.length === 0) {
    ul.innerHTML = '<li class="rev-qa-emp-empty">Nema rezultata</li>';
    return;
  }
  ul.innerHTML = limited
    .map(
      (e) => `<li>
        <button type="button" class="rev-qa-emp-row" data-rev-emp-pick="${escHtml(e.id)}">
          <strong>${escHtml(e.full_name)}</strong>
          ${e.department ? `<span class="rev-muted"> · ${escHtml(e.department)}</span>` : ''}
        </button>
      </li>`,
    )
    .join('');
  ul.querySelectorAll('[data-rev-emp-pick]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const eid = btn.getAttribute('data-rev-emp-pick');
      const emp = (Array.isArray(rows) ? rows : state.employees).find((e) => e.id === eid);
      if (!emp) return;
      state.employee = { id: emp.id, full_name: emp.full_name };
      const det = overlay.querySelector('#revRznQaEmpDetails');
      if (det) det.open = false;
      state.empPickQuery = '';
      state.empPickRows = null;
      paint();
      showToast(`Operater: ${emp.full_name}`);
    });
  });
}
```

#### 2.1.4 `bindEvents()` — handler za search input i details toggle

Na **kraj** `bindEvents()` funkcije (pre poslednje zatvarajuće zagrade `}`),
dodaj:

```js
const empDet = overlay.querySelector('#revRznQaEmpDetails');
const empSearch = overlay.querySelector('#revRznQaEmpSearch');

if (empDet) {
  empDet.addEventListener('toggle', () => {
    if (!empDet.open) return;
    paintEmpPickList(state.empPickRows);
    setTimeout(() => empSearch?.focus(), 50);
  });
}

if (empSearch) {
  empSearch.addEventListener('input', () => {
    const q = empSearch.value.trim();
    state.empPickQuery = q;
    clearTimeout(bindEvents._empDeb);
    bindEvents._empDeb = setTimeout(async () => {
      if (!q) {
        state.empPickRows = null;
        paintEmpPickList(state.employees);
        return;
      }
      const r = await fetchEmployeesAny(q);
      state.empPickRows = r.ok && Array.isArray(r.data) ? r.data : [];
      paintEmpPickList(state.empPickRows);
    }, 220);
  });
}
```

> **Napomena:** `fetchEmployeesAny` je već importovan na vrhu fajla. Server-side
> `ilike` search (vidi [src/services/reversiService.js:328-345](../src/services/reversiService.js#L328-L345))
> vraća do 200 zaposlenih, što je dovoljno za autocomplete bez paginacije.

#### 2.1.5 Postojeći `<details class="rev-scan-fallback">` "Manuelni izbor"

**Ostavi nepromenjen** — taj blok ima i `Dodatni operateri` multi-select
koji je potreban za drugu smenu, što novi CTA ne pokriva. Idealno je da i
"Operater" select tamo (`#revRznESel`) ostane kao "stari način" — magacioner
će ga prirodno koristiti samo ako quick-pick ne radi (npr. offline).

---

### 2.2 [src/styles/reversi.css](../src/styles/reversi.css)

Dodaj **odmah posle** `.rev-qa-cta--secondary` definicije (gde su sve nove
`.rev-qa-*` klase iz prethodnog PR-a):

```css
/* Manji CTA varijanta za "Unesi ime" — niži, sa chevronom umesto pune dvolinije */
.rev-qa-cta--pick {
  position: relative;
  padding-right: 44px; /* prostor za chevron */
}

.rev-qa-pick-chevron {
  position: absolute;
  right: 16px;
  top: 50%;
  transform: translateY(-50%);
  font-size: 18px;
  transition: transform 160ms ease;
  opacity: 0.7;
}

.rev-qa-pick[open] > .rev-qa-cta--pick .rev-qa-pick-chevron {
  transform: translateY(-50%) rotate(180deg);
}

.rev-qa-pick > summary {
  list-style: none;
}
.rev-qa-pick > summary::-webkit-details-marker { display: none; }
.rev-qa-pick > summary::marker { display: none; }

.rev-qa-pick-body {
  margin-top: 10px;
  padding: 12px;
  background: rgba(15, 23, 42, 0.5);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 12px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.rev-qa-emp-list {
  list-style: none;
  margin: 0;
  padding: 0;
  max-height: 320px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.rev-qa-emp-row {
  width: 100%;
  display: flex;
  align-items: baseline;
  gap: 6px;
  padding: 12px 14px;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid transparent;
  border-radius: 10px;
  color: inherit;
  font-family: inherit;
  font-size: 15px;
  text-align: left;
  cursor: pointer;
  min-height: 48px;          /* tap target */
  -webkit-tap-highlight-color: transparent;
}

.rev-qa-emp-row:hover,
.rev-qa-emp-row:focus-visible {
  background: rgba(37, 99, 235, 0.18);
  border-color: rgba(37, 99, 235, 0.4);
  outline: none;
}

.rev-qa-emp-row:active {
  transform: scale(0.99);
}

.rev-qa-emp-empty {
  padding: 14px;
  color: var(--rev-muted, #6b7b8e);
  font-style: italic;
  list-style: none;
}
```

---

## 3. Acceptance criteria

1. Otvori `Reversi → Rezni alat → Zaduženje (kamera/skener)`.
2. **Prvi prikaz:** ispod **KARTICA OPERATERA + MAŠINA** vidi se zatvoreni
   collapsible **✍ UNESI IME RADNIKA** sa podnaslovom *"Bez kartice — pretraga po imenu"*.
3. Tap na njega → expand-uje se, fokus odmah na search input, lista pokazuje
   prvih 8 zaposlenih po imenu (alfa).
4. Kucaj "pet" → posle ~220ms lista se filtrira na *"Petar Petrović…"* (server-side `ilike`).
5. Tap na red → details se zatvara, podnaslov dugmeta menja se u izabrano ime,
   submit dugme "POTVRDI ZADUŽENJE (N)" više nije disabled (ako su alat i
   mašina već postavljeni).
6. **Skener flow ostaje:** ako neko skenira karticu **posle** ručnog izbora,
   `state.employee` se prepisuje na skeniranog — to je OK (poslednja akcija pobedi).
7. **Reset:** klik na novi izbor radnika (drugo ime u listi) takođe prepisuje
   `state.employee`.
8. **HID fallback i dalje radi:** otvori "Manuelni / HID unos" → otkucaj
   `RZN-…` → ENTER → alat dodat.
9. **Regresija:** povraćaj modal (`openCuttingToolReturnScannerModal`) — NE
   diraj. Tamo nije bilo "kartice" jer se povraćaj radi za trenutno
   ulogovanog operatera (auth.user), pa "Unesi ime" tamo nema svrhu.

---

## 4. Šta NE diraj

- `openCuttingToolReturnScannerModal` (povraćaj) — bez izmena.
- `openQuickIssueModal` — koristi sopstveni search pattern, ne menjati ovde
  (zaseban follow-up).
- `state.secondaryIds` multi-select u postojećem "Manuelni izbor" details-u
  — i dalje radi kao do sada za drugu smenu.
- `issueCuttingReversal` RPC poziv — `payload.issued_to_employee_id`
  ostaje obavezan; pošto izbor radnika i kroz novi CTA puni stvarnim `id`-em,
  ništa se ne menja na backend strani.
- `state.secondaryIds` i `assignees` blok u `submit()` — nepromenjeno.

---

## 5. Quick start

1. U [src/ui/reversi/cuttingToolScannerModal.js](../src/ui/reversi/cuttingToolScannerModal.js):
   - dopuni `state` sa 2 nova polja (2.1.1),
   - umetni `<details>` blok u `paint()` (2.1.2),
   - dodaj `paintEmpPickList()` helper (2.1.3),
   - dopuni `bindEvents()` sa 2 nova listener-a (2.1.4).
2. U [src/styles/reversi.css](../src/styles/reversi.css) dodaj CSS iz 2.2.
3. `npm run dev` — test na telefonu kroz acceptance criteria.
4. `npm run lint && npm test` — postojeći testovi se ne diraju.

Procena: **45–90min rada**.

---

## 6. Opcioni follow-up (NE u ovom PR-u)

- **Quick Issue modal** ([src/ui/reversi/quickIssueModal.js](../src/ui/reversi/quickIssueModal.js))
  već ima `#revQiEmpSearch + #revQiEmpSel` search — ali u istom modalu se već
  pokazuje. Konzistentno bi bilo i tamo prebaciti na `rev-qa-*` stil. Zaseban PR.
- **Prikaz odeljenja** u podnaslovu CTA dugmeta nakon izbora (npr.
  *"Petar Petrović · Brusionica"*) — sitno, dodati `${emp.department}` u
  `state.employee` strukturu i u render.

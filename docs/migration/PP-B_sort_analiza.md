# PP-B: Analiza redosleda operacija po HITNO × spremnost

## 1. Gde i kako se trenutno sortira u tri taba

### `poMasiniTab.js`

- **`refreshOperationsForMachine`** (lista jedne mašine nakon RPC `plan_pp_open_ops_for_machine`): nakon merga rezultata poziva **`sortProductionOperations(merged)`** — do PP-B to je koristilo **`shift_sort_order` → `auto_sort_bucket` → rok …** (bez čvrstog urgencija/spremnosti na vrhu liste).
- **`refreshOperationsForDept`** (operations / Ostalo): podaci dolaze iz **`loadOperationsForDept`** u servisu, koji na kraju takođe zove **`sortProductionOperations`**.

Drag-and-drop (**`wireDragDrop`**) menjao je **`state.rows`** i **`reorderOverlays`** sa **`shift_sort_order = 1..n`** za ceo prikazan niz redova na mašini, bez blokade prelaska između grupa urgencije/spremnosti.

### `pregledTab.js`

- Lista operacija **nisu ravno prikazane** — koristi **`buildDeadlineMatrix(filteredRows)`** gde **`filteredRows = filterOperationsByRnOrDrawing(state.rows, …)`**.
- **`state.rows`** dolazi iz **`loadAllOpenOperations()`**, koji je u servisu već sorirao kao **`sortProductionOperations`** — redosled operacija direktno ne utiče na zbire u matrici (`Map`/`reduce` po mašini), ali da bi isti canon redosled važio „u celom modulu“ preporučuje se eksplicitni **`sortByUrgencyAndReady`** kada se operacije obrađuju pre agregacije (PP-B tako radi posle RN filtera).

### `zauzetostTab.js`

- Isti obrazac kao Pregled: **`summarizeByMachine(filterOperationsByRnOrDrawing(...))`**, **`loadAllOpenOperations`** već dolazi soriran iz servisa. PP-B dodaje eksplicitni **`sortByUrgencyAndReady`** posle RN filtera radi konzistentnosti.

---

## 2. Kako je modelovano „HITNO"

- **`local_status`** u overlay-u ima vrednosti **`waiting` / `in_progress` / `blocked`** (cikliranje u UI) — **nema `urgent`**.
- RN-nivo „HITNO” je **`is_urgent: boolean`** u API odgovoru (join na **`production_urgency_overrides`** iz view **`v_production_operations_effective`**). Postoji još **`urgency_reason`**.

**Zaključak za PP-B:** koristiti **`!!row.is_urgent`** (ne **`local_status`**) za urgenciju.

„Spremno” (**PP-A**): **`!!row.is_ready_for_machine`** (view kolona nad tech routing cache-om).

---

## 3. Predlog implementacije (`sortByUrgencyAndReady`)

- Jedno mesto u **`planProizvodnje.js`**: funkcija koja sortira tako da je primarni ključ
  **`bucket = (isUrgent ? 0 : 2) + (isReady ? 0 : 1)`** (vrednosti 0–3), rastuće **0→1→2→3**.
- Sekundarni (unutar bucketa): **`shift_sort_order` ASC (NULL kao ranije ostaje posle eksplicitnog broja u `cmpNullableAsc`)**, zatim **rok** ASC, **`work_order_id`**, **`prioritet_bigtehn`, RN**, **`line_id`, `operacija`** — stabilnost i lakše QA.
- **`sortProductionOperations`** ostaje kao pozivnica na istu funkciju (**backward-compat** naziv za postojeće import-e).

SQL **`auto_sort_bucket`** ostaje na redovima (za „Zašto?” modal ili buduće) ali **liste u Plan-u više ga ne koriste za redosled** radi izbegavanja duple logike koja **ne sledi PP-B segmente**.

---

## 4. Drag-drop između bucket-a — predlog ponašanja (implementacija PP-B)

- **Preferirano (uradjeno):** ako bi novim redosledom **`urgencyReadyBucket`** postao strogo padajući na granicama liste (**nije neopadan u smislu 0≤1≤2≤3**), **otpustiti drop** („snap-back"): ne menjati **`state.rows`**, ne pozivati **`reorderOverlays`**, prikazati kratku poruku (**toast**).

**Rationale:** Dozvoljavati premeštaj koji meša PP-B segmenti bi na sledećem **`sortByUrgencyAndReady`** ionako bio poništen ili bi zahtevao kompleksan zapis **`shift_sort_order`** po segmentima; blokada na ivici je najpredvidljivija za šemu.

Alternativa (nisu dizajnirane ovde): dozvoliti cross-bucket i odmah re-sortovati ceo niz tako da se drag ignoriše — zbunjujuće za operatera.

---

## 5. Vizuelni separator (opciono / odluka)

- **Za PP-B kod:** separator između bucket-a na listi (**tanak divider**) nije uveden — čeka eksplicitnu odluku proizvođača. Boje hitnog roka / postojeće badge-e nismo menjali (**ograničenje zadatka**).

---

## Referenca na zavisnosti

- **PP-A** mora uvesti **`is_ready_for_machine`** na view-u kako bi segment „spremno” bio ispravan pre primene PP-B u produkciji.

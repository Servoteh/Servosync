# PP-A — Manuelni test plan: `is_ready_for_machine`

**Preduslov:** Migracija `sql/migrations/fix_v_production_operations_ready.sql` je primenjena u Supabase; `NOTIFY pgrst, 'reload schema';` odrađen; aplikacija povučena sveže (hard refresh).

---

## 1. Prva operacija u TP — nije počela

**Postavka:** Za izabrani aktivni RN iz plana, u `bigtehn_work_order_lines_cache` tekuća linija ima **najmanji** `operacija` u skupu linija tog RN-a. U `bigtehn_tech_routing_cache` nema ili nema nezavršenih prijava sa **`operacija < tekuća.operacija`** (tj. za prvu TP stavku nema „ispod” koji blokira).

**Očekivanje:**

- Na SQL: `is_ready_for_machine = TRUE`.
- Na UI (Plan → Po mašini): kolona **Spremnost** prikazuje **Spremno** za tu operaciju (isti izvor kao i ranije vizuelno, drugaći podatak).

---

## 2. Druga operacija u TP — prva NIJE završena

**Postavka:** Isti `work_order_id`. Za tekući red `operacija = N2`. Postoji bar jedan red u `bigtehn_tech_routing_cache` sa `operacija = N1`, `N1 < N2`, i `is_completed = FALSE`.

**Očekivanje:**

- `is_ready_for_machine = FALSE`.
- UI: **Čeka prethodnu (op. …)** — tooltip i dalje mogu pokazati `previous_operation_operacija` iz starije heuristike (`prioritet` / `komada`); ako se broj razlikuje od stvarno blokirajućeg `operacija`, prijaviti kao UX follow-up.

---

## 3. Druga operacija u TP — prva je završena

**Postavka:** Za sve redove cache-a sa `operacija < N2`: nema **`is_completed = FALSE`** (dozvoljene su dorade kao posebni redovi — slučaj 4).

**Očekivanje:**

- `is_ready_for_machine = TRUE`.
- UI: **Spremno**.
- Tabovi **Zauzetost mašina** / **Pregled svih**: brojač „spremno“ uključuje tu operaciju ako je ostalo u istom skupu filtara (RN završen, overlay, aktivacija predmeta kao i dosad).

---

## 4. Redovi sa `dorada_operacije > 0`

**Stanje u šemi:** Kolona **`dorada_operacije`** je u `bigtehn_tech_routing_cache`; redovi dorade dele **`operacija`** sa osnovnom obradom ili su posebni unosi sync-a.

**Odluka za PP-A (implementirana logika):**

- **`dorada_operacije` se eksplicitno ne filtrira** u uslovu spremnosti. Ako dorada ima **`is_completed = FALSE`**, ostaje blokator isto kao i bilo koja druga prijava sa tim **`operacija`** kada je **`operacija < tekuće`**.

**Rationale:** Spremnost se definiše isključivo preko **`is_completed`** nad cache redovima koji su numerisani **`operacija`** u istom **`work_order_id`** lanu TP-a; dorada koja još nije zatvorena u BigTehn-u i dalje znači da korak za taj **`operacija`** nije tehnički gotov za sledeće mašinski numerisane korake.

**Test:** Za RN poznat po doradi, ručno potvrditi da se prikaz **Čeka**/ **Spremno** slaže sa očekivanim **`is_completed`** u cache-u za relevantne **`operacija`**.

---

## Završni check-list

- Jedan konkretan RN iz proizvodnje: uprošćena SQL selekcija kao u `docs/migration/PP-A_ready_analiza.md`.
- Poziv `plan_pp_open_ops_for_machine` i tab „Po mašini“ daju konzistentan JSON (polje `is_ready_for_machine`).

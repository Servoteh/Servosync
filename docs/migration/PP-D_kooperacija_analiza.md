# PP-D — Kooperacija po operaciji (TP red)

## Kako radi danas

- **`production_overlays`**: kolone `cooperation_status` (`none` / `external` / …), partner, datumi — **jedan red po `(work_order_id, line_id)`**, tj. po **liniji RN-a** (jedna planirana operacija u kešu).
- **Auto-kooperacija**: `production_auto_cooperation_groups` + join u view-u; **`is_cooperation_effective`** = auto **ILI** ručni status ≠ `none`.
- **Plan** (PostgREST + RPC `plan_pp_open_ops_for_machine`): filter **`is_cooperation_effective.eq.false`** — **cela linija** nestaje iz operativnih lista čim je bilo koji od signala aktivan.
- **`setCooperationManual`** u `planProizvodnje.js` upisuje **ceo overlay**; dugme **„→ Kooperacija”** u `poMasiniTab.js` posle uspeha **uklanja sve redove** sa tim `(work_order_id, line_id)` iz lokalnog `state.rows` (jedna operacija po redu u tabeli = jedna linija).

## Gubitak vidljivosti

- Da: ako je **ceo RN / linija** označena kooperacijom, **nema** u planu drugih operacija istog crteža koje bi ostale u Servotehu — jer je granularnost bila **linija**, ne **operacija u smislu TP reda** (mada `line_id` odgovara jednoj TP stavci, korisnik želi izbor **podskupa TP koraka koji dele isti RN** kroz više linija).

## Nova šema — `production_cooperation_ops`

- Tabela (**ime u migraciji: `production_cooperation_ops`**): `(work_order_id, line_id, operacija)` sa **`cleared_at` IS NULL** = aktivno slanje u kooperaciju za **tu** kombinaciju.
- Jedinstven aktivan koristi **`UNIQUE (work_order_id, line_id, operacija)`** + **`cleared_at`** za istoriju (re-otvaranje istog ključa ponovo aktivira isti red `UPDATE cleared_at = NULL`).
- RLS: isti obrasci kao **`production_overlays`** — `SELECT` za `authenticated`, pisanje pod **`can_edit_plan_proizvodnje()`** (admin / pm / menadžment).

## View logika (bez menjanja `production_overlays` kolona)

Helper funkcija **`public._pp_cooperation_excludes_from_plan(wo, line, op, is_cooperation_effective)`**:

- **`TRUE`** ako:
  - postoji aktivno (`cleared_at IS NULL`) red u **`production_cooperation_ops`** za taj `(work_order_id, line_id, operacija)`, **ili**
  - **legacy**: `is_cooperation_effective` i **nijedan** red u `production_cooperation_ops` za taj `(work_order_id, line_id)` (nema prelaska na granularni režim).

- **`FALSE`** inače (operacija ostaje u operativnom planu).

Pogledi:

- **`v_production_operations_operational_plan`** — `v_production_operations_effective` gde **NOT** `_pp_cooperation_excludes_from_plan(...)`.
- **`v_production_operations_cooperation`** — ista baza, gde **jeste** `_pp_cooperation_excludes_from_plan(...)` (lista za tab Kooperacija).

RPC **`plan_pp_open_ops_for_machine`** čita iz **`v_production_operations_operational_plan`** i **uklanja** stari filter `is_cooperation_effective IS FALSE`.

## Migracija sa starog modela

- **Opcija A (automatski):** za svaki overlay gde `cooperation_status <> 'none'`, INSERT u `production_cooperation_ops` za **sve** linije tog RN-a iz `bigtehn_work_order_lines_cache` — agresivno, može poslati previše u „kooperaciju”.
- **Opcija B (preporučeno u analizi):** **ne** auto-migrirati; korisnik koristi novi modal; legacy linije i dalje padaju pod drugi deo predikata (`is_cooperation_effective` bez redova u novoj tabeli) = ponašanje ostaje **cela linija skrivena** dok se ne unesu redovi u `production_cooperation_ops` (što uključuje „granularni režim” za taj `(wo, line)`).

## Pregled „u kooperaciji” / Vrati u plan

- Tab **Kooperacija** i dalje koristi isti UI; izvor podataka prelazi na **`v_production_operations_cooperation`**.
- Eksplicitno **„Vrati u plan”** po operaciji (UPDATE `cleared_at`) — **sledeći sprint** (nakon potvrde); trenutno **modal „Kooperacija”** na redu u planu upravlja čekiranjem operacija.

## Sort (PP-B)

- Ne menja se: isključene operacije ne ulaze u plan view pa ne učestvuju u sortu.

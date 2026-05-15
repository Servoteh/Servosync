# PP-A: Analiza prikaza „spremnosti” (ready) za mašinski red

## 1. Kako se trenutno računa „spremno”

### SQL — `public.v_production_operations_pre_g4` (izmene iz G2)

Čitav plan modul koji radi na produkcijskoj šemi koristi **lanac** `v_production_operations_pre_g4` → `v_production_operations` → `v_production_operations_effective`; spremnost se definiše u sloju koji je istorijski uveden kao G2 readiness.

Trenutno polje **`is_ready_for_processing`** nije vezano za `operacija < tekuće` iz `bigtehn_tech_routing_cache`.

Izvorna definicija (sada obično u **pre_g4**) koristi **`prev_block`** — lateral podupit koji bira jednu „prethodnu” liniju RN iz `bigtehn_work_order_lines_cache` tako što:

1. uzima sve linije istog RN-a čiji je **`l2.prioritet < l.prioritet`** (BigTehn polje **`prioritet`**, ne **`operacija`**),
2. među njima traži liniju koja je po agregatu `SUM(komada)` iz **`bigtehn_tech_routing_cache`** još uvek **`komada_done < wo.komada`** (koliko još nije urađeno na toj starijoj poziciji po prioritetu),

i uzima najnoviji takav blok (sort `prioritet DESC`).

Potom važi:

```text
is_ready_for_processing = (prev_block.operacija IS NULL)
```

Dakle „spremno” znači: **nema „bloker” linije u smislu prioriteta + nepotpune sume komada** — što **ne poklapa strogo** sa TP redosledom po **`operacija`** (TP redni broj). Ako `prioritet` ne prati TP red ili postoji nekonzistentno stanje, dobija se **„Spremno”** iako još postoji ranija **`operacija`** u kojoj u cache-u još ima nezavršenih (`is_completed = false`) prijava.

Konkretan fajl u repou sa ovom šemom je:

- `sql/migrations/add_production_g2_readiness_urgency.sql` — kolona `is_ready_for_processing`: linije oko **[128]** (izraz `(prev_block.operacija IS NULL)`), **`prev_any`/`prev_block`**: **[197–232]**.

Napomena: na bazi koja je na **pre_g4** putanji isti SELECT živi kao **`CREATE OR REPLACE VIEW public.v_production_operations_pre_g4`**, nastao rename iz G4 migracije; vidi `sql/migrations/add_production_g4_rework_scrap_cache.sql`.

### SQL — grupisanje liste

**`auto_sort_bucket`** u istoj view koristi **`prev_block.operacija IS NULL`** kao „prethodno završeno” za G2 prioritet liste — dakle isti pogrešan presjek kao gore (**[140–158]** u `add_production_g2_readiness_urgency.sql`).

### Servisni sloj

- `src/services/planProizvodnje.js` čita **`is_ready_for_machine`** iz **`v_production_operations_effective`**: `loadAllOpenOperations`, `summarizeByMachine`, `buildDeadlineMatrix`. Nema dodatnog proračuna spremnosti u JS-u (nakon PP-A).

### UI

- `src/ui/planProizvodnje/poMasiniTab.js` — kolona „Spremnost” koristi **`is_ready_for_machine`**.

- `src/ui/planProizvodnje/pregledTab.js` — preko **`buildDeadlineMatrix`** (`readyOps` ako je **`row.is_ready_for_machine`**).

- `src/ui/planProizvodnje/zauzetostTab.js` — isto preko **`summarizeByMachine`**.

## 2. Primer SQL-a za validaciju (ne izvršavati ovde — ručno posle merga)

Cilj: za jedan RN (`work_order_id`) uporediti **`operacija`** sa redosledom u cache-u — naći TP red gde manji **`operacija`** još ima **`is_completed = false`**.

```sql
-- ZAMENITI :wo_id konkretnim work_order_id (bigtehn_work_orders_cache.id) i opciono :broj_crteza za ljudski kontekst
SELECT
  v.rn_ident_broj,
  v.broj_crteza,
  v.operacija       AS tp_operacija,
  v.effective_machine_code,
  v.is_ready_for_machine,
  v.is_ready_for_processing,
  EXISTS (
    SELECT 1
    FROM public.bigtehn_tech_routing_cache tr
    WHERE tr.work_order_id = v.work_order_id
      AND tr.operacija < v.operacija
      AND tr.is_completed = FALSE
  ) AS has_incomplete_lower_operacija_route
FROM public.v_production_operations v
WHERE v.work_order_id = :wo_id
ORDER BY v.operacija;
```

Uz to, sirovi cache za isti RN:

```sql
SELECT operacija, machine_code, komada, is_completed, dorada_operacije
FROM public.bigtehn_tech_routing_cache
WHERE work_order_id = :wo_id
ORDER BY operacija, started_at;
```

### Kada je ishod pogrešan u staroj logici

- Postoji **`has_incomplete_lower_operacija_route = TRUE`**, dok je **`is_ready_for_processing`** (staro) još uvek **`TRUE`** zbog **`prioritet`** / **`prev_block`**.

---

## 3. Predlog ispravke (striktno TP po `operacija`)

**Definicija (kanon PP-A/B):**

- **`is_ready_for_machine = TRUE`** ako **ne postoji** nijedan red u **`bigtehn_tech_routing_cache`** takav da **`work_order_id` isti kao tekuće linije** i **`operacija < tekuće.operacija`** i **`is_completed = FALSE`**.

To je ravno špecifikaciji koraka 2 zahteva (blokuju samo eksplicitno nezavršene prijave sa manjim **`operacija`**).

Za **prethodnika po TP koji nema ni jednog reda u cache-u**: uslov **NOT EXISTS (... is_completed = FALSE)** ostaje **`TRUE`** (nema reda koji blokira); zato je u test planu i analizi naglašen slučaj „nije počela” kao granica.

Za **`auto_sort_bucket`**, da bi lista pratila istu ekonomiju kao „Spremnost”, zamena **`prev_block.operacija IS NULL`** pravom **`is_ready_for_machine`** (**lateral ili ista BOOLEAN izrada**).

Zadržati postojeće kolone **`previous_operation_*`** (prioritet/`komada` semantika) može ostaviti blagi nesklad sa tooltip tekstom dok se ne definiše odvojeno „blokirajuća `operacija` iz cache-a” — dokumentovano u test planu.

---

## 4. Plan migracije i regresije

### Migracija (draft u repou)

1. **`CREATE OR REPLACE VIEW public.v_production_operations_pre_g4`** sa:
   - novom kolonom **`is_ready_for_machine`** (i usklađenim **`is_ready_for_processing`** ako se oba drže identičnim),
   - ažuriranim **`auto_sort_bucket`** da koristi istu spremnost.

2. **`DROP VIEW public.v_production_operations_effective CASCADE;`**
3. **`DROP VIEW public.v_production_operations CASCADE;`**
4. Ponovo kreirati **`v_production_operations`** (G4 + `item_id` + `plan_rn_final_control_done` kao u poslednjoj produkcijskoj verziji, npr. `supabase/migrations/20260507100000__plan_final_qc_hide_fix_double_sum.sql`).
5. Ponovo kreirati **`v_production_operations_effective`**.
6. **`GRANT SELECT TO authenticated`**, **`REVOKE ... FROM anon`** kao u `revoke_anon_v_production_operations.sql` / sporednim migracijama.
7. Posle **CASCADE** proveriti da li je **`plan_pp_open_ops_for_machine`** ostao validan; u draft fajlu je uključeno ponovno **`CREATE OR REPLACE FUNCTION`** iz poslednje verzije (paginacija po RN).
8. **`NOTIFY pgrst, 'reload schema';`**

### Potencijalni regresivni efekti

| Oblast | Efekat |
|--------|--------|
| **Plan — Po mašini / Zauzetost / Pregled** | Broj „spremno” i redosled (`auto_sort_bucket`) mogu se promeniti — namerno, da prate TP + `is_completed`. |
| **Lokacije pregled** | Ako bilo gde čita **`v_production_operations`** i oslanja se na staru spremnost, ponašanje se menja; u ovom repou nije identifikovan drugi modul osim plana i deljenog TP modala (`loadFullTechProcedure` čita isti view). |
| **Nalepnice / izvozi** | Nisu dirani u ovom zadatku; ako koriste isti view u drugom repou, proveriti. |
| **Performanse** | **`NOT EXISTS`** po cache-u po redu — indeks **`(work_order_id, operacija)`** na **`bigtehn_tech_routing_cache`** (ako već postoji u šemi) smanjuje rizik; u suprotnom razmotriti indeks u posebnoj migraciji (van ovog drafta ako korisnik zabrani diranje sync-a). |

**Ograničenje zadatka:** SQL se **ne izvršava** u ovom agent run-u; validacija je u Supabase Studio posle merga (vidi korisničke instrukcije za PP-B).

---

## 5. Reference fajlova

| Fajl | Uloga |
|------|--------|
| `sql/migrations/add_v_production_operations.sql` | Rani view (bez G2 spremnosti) — referenca za join šemu |
| `sql/migrations/add_production_g2_readiness_urgency.sql` | G2 `prev_block` / `is_ready_for_processing` |
| `supabase/migrations/20260507100000__plan_final_qc_hide_fix_double_sum.sql` | Spoljašnji `v_production_operations` + effective |
| `sql/migrations/revoke_anon_v_production_operations.sql` | **REVOKE anon** obrasci |
| `src/services/planProizvodnje.js` | Čitanje polja za agregacije |
| `src/ui/planProizvodnje/poMasiniTab.js` | Prikaz „Spremnost” |

---

*Kraj analize PP-A (Korak 1). Izvršenje SQL u bazi sledi tek posle reviewer potvrde / merga.*

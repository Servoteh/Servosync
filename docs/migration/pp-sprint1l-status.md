# PP Sprint 1L — status posle dijagnostike

> Datum: 2026-05-17 · Sprint: 1L · Pre-flight: [pp-sprint1l-analysis.md](pp-sprint1l-analysis.md) · Prethodno: [pp-sprint1k-status.md](pp-sprint1k-status.md)

## Rezime u jednoj rečenici

Nijedna od tri pre-flight hipoteze (LATERAL nested indeks / plan cache / `predmet_aktivacija` indeks) nije sama po sebi krivac — pravi gap je između **direct view (6.5 s)** i **RPC funkcije (29 s)**, što ukazuje na **plpgsql per-function plan cache** koji `DISCARD PLANS` ne resetuje.

## Rezultati 5 dijagnostičkih upita

### #1 — Direct view EXPLAIN (`count(*)` na 8.4)

| Metrika | Vrednost |
|---|--:|
| Execution Time | **6 508 ms** |
| Rows (count) | 4 537 |
| Shared hits | 1 074 084 (≈8.4 GB) |
| Top join | `Merge Left Join wo × awo` (Index Scan, normalno) |
| Inner Index Scan (`bigtehn_wo_lines_wo_idx`) | 9 151 loops, 2 s |
| SubPlan 1 (`komada_done` SUM, filter `is_completed IS TRUE`) | 49 937 loops, 808 667 buffers |
| SubPlan 2 (analogno) | 5 771 loops, 119 144 buffers |

Bottleneck u direct view-u su dva SubPlan-a koji računaju `komada_done` po liniji (jednom za `tr` LATERAL, jednom za `fc`/`prev_block` LATERAL). Oba čitaju `bigtehn_tr_cache_wo_idx` sa `Filter: is_completed IS TRUE`.

### #2 — Indeksi na cache tabelama

Postoje svi potrebni:

- `bigtehn_work_order_lines_cache`:
  - `bigtehn_wo_lines_wo_idx (work_order_id)` ✓ (koristi se u planu)
  - `bigtehn_wo_lines_wo_op_idx (work_order_id, operacija)` ✓
  - `bigtehn_wo_lines_machine_idx (machine_code)` ✓
  - `bwolc_machine_code_work_order_id_idx (machine_code, work_order_id)` ✓
- `bigtehn_work_orders_cache`: PK + customer/ident/item/status indeksi ✓

Hipoteza A (indeks fali na lines cache) → **oborena**, indeksi su tu i koriste se.

### #3 — 1K partial indeks (`bigtehn_tr_cache_incomplete_wo_op_idx`)

| Metrika | Vrednost |
|---|--:|
| `idx_scan` | **0** |
| `idx_tup_read` | 0 |
| `idx_tup_fetch` | 0 |
| Veličina | 16 kB |

**Indeks se nikad ne koristi.** Razlog: postavljen je sa `WHERE is_completed = false` (računao sam na `_ready_chain` LATERAL koji baš to filtuje), ali planner u praksi koristi `bigtehn_tr_cache_wo_idx` (full) sa runtime filterom — verovatno zato što optimizator proceni da je full index dovoljno selektivan posle `work_order_id` lookup-a (9 incomplete redova ukupno u tabeli, pa Filter trivijalan).

**Akcija:** Sprint 1M će ovo dropovati. Korist nula, DML overhead minimalan ali ne nula.

### #4 — Plan cache test (`DISCARD PLANS` + RPC)

| Metrika | Vrednost |
|---|--:|
| Execution Time | **29 042 ms** (gore nego 1K baseline ~24.6 s) |
| Shared hits | 8 605 080 (≈67 GB — kao 1K) |
| Plan top | `Function Scan` (RPC wrapper) |

`DISCARD PLANS` nije pomogao. Hipoteza B (prepared statement plan cache) → **oborena**.

Ali — `DISCARD PLANS` čisti samo prepared-statement cache, **NE** i plpgsql per-function plan cache. Za to treba `DISCARD ALL` ili `pg_terminate_backend` (nova sesija), ili `ALTER FUNCTION ... SET plan_cache_mode = force_custom_plan`.

### #5 — `production.predmet_aktivacija` indeksi

- `predmet_aktivacija_pkey (predmet_item_id)` — unique PK ✓
- `predmet_aktivacija_je_aktivan_idx (je_aktivan)` — full, manje koristan
- `predmet_aktivacija_proj_mont_idx (je_projektovanje_montaza) WHERE TRUE` — partial za drugi use case

EXISTS lookup u `v_production_operations_effective` koristi PK (`predmet_item_id`). Hipoteza C → **oborena**.

## Gde dakle ide ~22 s razlike (direct = 6.5 s, RPC = 29 s)?

Funkcija `plan_pp_open_ops_for_machine` radi (u jsonb wrapper-u):

1. `SELECT e.* FROM v_production_operations_effective WHERE effective_machine_code = mc AND (6 dodatnih boolean filtera)`
2. `ROW_NUMBER() OVER (...)` po 4 polja
3. `GROUP BY work_order_id` da napravi RN-pagination
4. `jsonb_agg(to_jsonb(o) - '_sort_idx')`
5. Sve umotano u `RETURN ( WITH ... )` u plpgsql

Direct view radi samo `count(*)`. **Postgres može da odbije** sve LATERAL-e koje ne učestvuju u WHERE — naročito `prev_any`, `prev_block`, `drawings_count`, `g4`, **a možda i SubPlan-ove**. Kroz `SELECT e.*`, planner mora da emituje *sve* kolone, što reaktivira svih 5 LATERAL-a × ~5 000 outer redova → bukvalno više nego 4× rad direct count-a, što odgovara 6.5 s × ~4.5 ≈ ~29 s.

Drugim rečima: **glavni krivac je broj kolona u select listi**, ne plan cache. Plpgsql samo ne radi loše — radi tačno onoliko koliko `SELECT *` traži.

## Predlog za Sprint 1M (refaktor RPC selekcije, ne view-a)

Ne diramo view (rizik za druge konzumere). Umesto toga, u funkciji **rezerviraj kolone koje stvarno trebaju aplikaciji**:

```sql
-- u funkciji, umesto SELECT e.*:
SELECT
  e.line_id, e.work_order_id, e.operacija, e.effective_machine_code,
  e.original_machine_code, e.tpz_min, e.tk_min,
  e.rn_ident_broj, e.broj_crteza, e.naziv_dela, e.materijal, e.komada_total, e.rok_izrade,
  e.customer_name, e.customer_short,
  e.cam_ready, e.cam_ready_at,
  e.komada_done, e.is_done_in_bigtehn, e.last_finished_at,
  e.is_ready_for_machine,
  e.previous_operation_status, e.previous_operation_operacija, e.previous_operation_machine_code,
  e.is_urgent, e.urgency_reason,
  e.auto_sort_bucket, e.shift_sort_order, e.local_status, e.shift_note,
  e.is_rework, e.is_scrap, e.rework_pieces, e.scrap_pieces,
  e.cooperation_status, e.is_cooperation_effective, e.cooperation_source,
  e.has_bigtehn_drawing, e.drawings_count
  -- IZOSTAVLJENE (verovatno nepotrebne za listu): overlay_*, created_by, updated_by,
  -- materijal/dimenzija ako su pokrivene cache-om, ...
FROM public.v_production_operations_effective e
WHERE ...
```

Postgres-projection pruning kroz view neće reusable LATERAL-e ako se na njihove kolone *uopšte* referencira u izlazu — ali ono što sigurno možemo da odbacimo:

| Kolona | LATERAL | Da li se koristi u UI listi? |
|---|---|---|
| `prijava_count`, `real_seconds` | `tr` | možda u detalj-prikazu, ne u tabeli |
| `prev_block.*` | `prev_block` LATERAL × LATERAL | UI samo prikazuje status badge i operacija |
| `prev_any.*` | `prev_any` LATERAL × LATERAL | isto |
| `drawings_count` | `d` | da, treba u tabeli (gumb crteža) |
| `g4.rework_scrap_count` | `g4` | UI koristi is_rework/is_scrap (boolean), ne count |
| `fc.final_control_raw_sum` | `fc` | filter samo, ne emituje se |

Plan B (jeftiniji, manje obećavajući): **`ALTER FUNCTION ... SET plan_cache_mode = force_custom_plan`** — uglavnom pomaže kada parametar-tip filter selektivnost varira po pozivu (ovde varira po `mc`). Probaće se prvo jer je 1-liner.

## Akciona stavka pre 1M

1. **Drop 1K indeks** (idle, beskorisno):
   ```sql
   DROP INDEX CONCURRENTLY IF EXISTS public.bigtehn_tr_cache_incomplete_wo_op_idx;
   ```
2. **Test `plan_cache_mode = force_custom_plan`**:
   ```sql
   ALTER FUNCTION public.plan_pp_open_ops_for_machine(text,integer,integer)
     SET plan_cache_mode = force_custom_plan;
   DISCARD ALL; -- ili nova sesija
   EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM public.plan_pp_open_ops_for_machine('8.4', 100, 0);
   ```
   - Ako Execution Time padne ispod ~10 s → 1M se završava ovim 1-linerom + drop 1K.
   - Ako ostane ~29 s → idemo na refaktor selekcije iznad.
3. Ako ni jedno ne pomogne → 1M = direct view `SELECT only needed cols` (refaktor RPC tela).

## Vremenska procena 1M

- Drop 1K + ALTER FUNCTION test: 15 min
- Ako fail, refaktor SELECT liste u funkciji + EXPLAIN: 1h
- pgTAP regression test ako menjamo SELECT listu: 30 min
- **Ukupno: 15 min - 2h** zavisno od ishoda ALTER FUNCTION testa.

---

**Verzija:** 2026-05-17 · **Autor:** Sprint 1L dijagnoza · **Vlasnik:** team-erp.

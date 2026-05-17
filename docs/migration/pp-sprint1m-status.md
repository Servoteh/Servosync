# PP Sprint 1M — status (zatvaranje 1L+1M sprintova)

> Datum: 2026-05-17 · Sprint: 1M (a + c) · Prethodno: [pp-sprint1l-status.md](pp-sprint1l-status.md)

## Rezime u jednoj rečenici

Cilj **`plan_pp_open_ops_for_machine('8.4', 100, 0)` < 10 s** postignut: **10.3 s** posle eliminacije redundantnog `INNER JOIN v_active_bigtehn_work_orders` u `v_production_operations` view-u (1M-c). 1K i 1M-a (force_custom_plan) nisu bili dovoljni.

## Linija progresa

| Sprint | Promena | RPC Execution Time | Buffers (shared hit) |
|---|---|--:|--:|
| Baseline (pre 1K) | — | ~25 s | ~8.6 M (≈67 GB) |
| **1K** | `bigtehn_tr_cache_incomplete_wo_op_idx` (partial WHERE `is_completed=false`) | ~24.6 s | nepromenjeno |
| **1M-a** | DROP 1K idle indeksa + `ALTER FUNCTION SET plan_cache_mode=force_custom_plan` | ~29 s (čak gore zbog discard plans) | nepromenjeno |
| **1M-b** (ANALYZE) | `ANALYZE` na 7 cache tabela | ~22.8 s | nepromenjeno |
| **1M-c** | Eliminisan dupli `INNER JOIN v_active_bigtehn_work_orders` u `v_production_operations`; `item_id` vučen iz pre_g4 SELECT-a | **10.3 s** ✓ | **1.73 M** (≈13 GB) ✓ |

Direct SELECT (zaobilazi RPC, isti filteri): **4.1 s, 1.02 M buffers** posle 1M-c. Razlika RPC vs direct ~6 s je overhead plpgsql wrapper-a (CTE materijalizacija + `jsonb_agg(to_jsonb(o))` serijalizacija za 5117 redova).

## Šta je tačno bilo krivac

EXPLAIN planovi (Test A/D) su pokazali `Join Filter: (wo.id = wo_1.id)` sa **138 904 729 rows removed** — kartezijanski self-join između dva pojavljivanja `v_active_bigtehn_work_orders`. Trag u kodu (fix_v_production_operations_ready.sql:251-254):

```sql
-- pre 1M-c, v_production_operations je radio:
SELECT v.*, wo.item_id::integer AS item_id
FROM public.v_production_operations_pre_g4 v
INNER JOIN public.v_active_bigtehn_work_orders wo ON wo.id = v.work_order_id
```

Drugi JOIN je bio samo zato da bi se izvukao `wo.item_id`. Planner nije prepoznao da postoji već prvi `wo` u `pre_g4` (linija 142-144 istog fajla) → kartezijanski compare. Posle 1M-c:

1. `pre_g4` SELECT lista uključuje `wo.item_id::integer AS item_id` (linija 65 nove migracije)
2. `v_production_operations` direktno koristi `v.item_id`, bez sekundarnog JOIN-a (linija 261)

## Korelacija: koja hipoteza je bila tačna

| Hipoteza 1L | Status posle 1M-c |
|---|---|
| A — LATERAL indeks fali | **Oborena** (svi indeksi tu, koriste se) |
| B — plpgsql plan cache | **Oborena** (`force_custom_plan` nije pomogao) |
| C — `predmet_aktivacija` indeks fali | **Oborena** (PK pokriva EXISTS) |
| D — `SELECT e.*` reaktivira sve LATERAL-e | **Delimično** (~3.6 s razlike, ne glavna) |
| **(novo iz 1M-b dijagnoze) — kartezijanski self-join na `v_active_bigtehn_work_orders`** | **POTVRĐENA** |

Nova hipoteza nije bila u 1L pre-flight-u jer EXPLAIN-i su pokrivali samo gornji nivo plana. Tek puni `SELECT *` plan sa filterima (1M-b Test A) je otkrio kartezijanski.

## Sekundarne lekcije

1. **ANALYZE pomaže malo**. 7-tabelni ANALYZE batch spustio je RPC sa 29 s na 22.8 s — vredan ali ne dovoljan kad plan ima strukturni problem.
2. **`plan_cache_mode = force_custom_plan` je idle** za ovu funkciju. Ostavljen je (ne škodi), ali ne pomaže — generic plan i nije bio problem; problem je view definition.
3. **1K partial indeks (`is_completed = false`)** je promašen i drop-ovan u 1M-a. Hot path filtuje `is_completed IS TRUE`, ne `FALSE`.
4. **`DISCARD PLANS` ne čisti plpgsql per-function plan cache** — za to treba `DISCARD ALL` (ne radi u transakciji) ili nova sesija. Ali u našem slučaju ni jedno nije bilo potrebno jer plan cache nije bio krivac.

## Šta NIJE rađeno u 1M

- **Refaktor SELECT liste u RPC** (eksplicitne kolone umesto `e.*`). Eksplikacija: razlika count-vs-select je ~3.6 s, što je manje od 6 s overhead-a koje sad ima jsonb wrapper. Ne vredi sad — vredi tek ako idemo ispod 5 s u Sprint 1N.
- **Materijalizacija `fc.final_control_raw_sum`** (LATERAL koji još uvek ima SubPlan 1 + SubPlan 2 sa 49K + 5K loops). Vidi se u planu — ali sada ~3.5 s, ne 22 s. Vredi tek za Sprint 1N.
- **Eliminisanje `bd` LATERAL** (`bigtehn_drawings_cache` JOIN). UI ne koristi `has_bigtehn_drawing`/`bigtehn_drawing_*` direktno (vidi inventar u 1M-b), ali drop nije bezbedan bez double-check-a drugih konzumera (whyBottleneckModal, batch lookups).

## Sledeći koraci (opcioni Sprint 1N)

Targetiranje za **<5 s RPC**:

1. **Replace `jsonb_agg(to_jsonb(o))` sa eksplicitnom SELECT listom** u RPC-u. Pomaže serijalizaciju (~6 s wrapper overhead).
2. **Materijalizovan helper za `final_control_raw_sum`** sa REFRESH na bridge sync trigger.
3. **Eliminisanje `bd` LATERAL-a iz pre_g4** (zahteva audit svih konzumera).

Ako 10 s je prihvatljivo za UI — kraj. Inače 1N.

## Migracije primenjene (Sprint 1M)

1. `sql/migrations/add_production_perf_indexes.sql` (1K) — kreirao 1K indeks; **drop-ovan u 1M-a**
2. `sql/migrations/add_pp_open_ops_plan_cache_mode.sql` (1M-a) — drop 1K + plan_cache_mode
3. `sql/migrations/add_pp_view_eliminate_redundant_join.sql` (1M-c) — refaktor view-a

## Verifikacija u UI

Pre commit-a treba potvrditi (vlasništvo: Jara):
- [ ] Otvori PP modul → "Po mašini" tab → odaberi 8.4 → lista renderuje ispod 10 s
- [ ] Otvori "Zašto je ovo ovde?" modal na bilo kojem RN → svi badge-ovi i polja prikazani
- [ ] Sortiranje po Σ vremena footer-u radi
- [ ] HITNO flag radi (G2)
- [ ] CAM kockica klikabilna (G3)
- [ ] REASSIGN bulk operacija prolazi (G5)
- [ ] Kooperacija tab učitava (G7)
- [ ] item_id se i dalje vraća u response — proveri u console.log ili Network tab-u Supabase fetch-a

---

**Verzija:** 2026-05-17 · **Autor:** Sprint 1L+1M sinteza · **Vlasnik:** team-erp.

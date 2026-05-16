# PP Sprint 1K — pre-flight analiza (perf optimizacija PP-A NOT EXISTS)

> Datum: 2026-05-16 · Sprint: 1K · Pretvara M21 measurement (Sprint 1D) u akciju · [pp-sprint1d-status.md](pp-sprint1d-status.md)

## Cilj

Spustiti `plan_pp_open_ops_for_machine('8.4', 100, 0)` execution time sa **~25 s na < 1 s**. Bottleneck je PP-A `NOT EXISTS` provera u `_ready_chain` LATERAL — izvršava se za svaki red u view-u, što je do 4 543 puta za top mašinu.

## Strategija

Iz Sprint 1D nalaza:
- `bigtehn_tech_routing_cache` ima ~72 118 redova
- **9 redova ima `is_completed = FALSE`** (~0.012%)
- Postojeći indeks `bigtehn_tr_cache_wo_op_idx (work_order_id, operacija)` ne uključuje `is_completed`

PP-A `NOT EXISTS` upit:
```sql
NOT EXISTS (
  SELECT 1 FROM bigtehn_tech_routing_cache tr_rb
  WHERE tr_rb.work_order_id = <current>
    AND tr_rb.operacija < <current.operacija>
    AND tr_rb.is_completed IS FALSE
)
```

Sa trenutnim indeksom: Postgres mora da uradi index range scan po (work_order_id, operacija) → heap lookup za svaku kandidat-red → filter po `is_completed`. Za 4 543 ops × ~5 prosečnih kandidata = ~22 715 heap lookup-a, plus repeating LATERAL evaluation.

**Sa partial indeksom WHERE is_completed = FALSE:** Postgres odmah skenira samo ~9 redova kroz indeks, bez heap lookup-a. NOT EXISTS postaje skoro O(1).

## Plan migracije

### Opcija A — Partial indeks (preporučeno)

```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS bigtehn_tr_cache_incomplete_wo_op_idx
  ON public.bigtehn_tech_routing_cache (work_order_id, operacija)
  WHERE is_completed = false;
```

**Veličina:** ~9 reda × ~24 bytes = trivijalna (< 1 KB).
**Održavanje:** dodatni overhead na INSERT/UPDATE u bridge sync — zanemarljiv jer samo nezavršene operacije ulaze (a ima ih < 0.1%).

**Risk apply-a:** Nizak. `CONCURRENTLY` ne lock-uje tabelu, bridge sync radi normalno tokom create-a.

### Opcija B — Cover indeks (alternativa, NE preporučujem)

```sql
CREATE INDEX CONCURRENTLY bigtehn_tr_cache_wo_op_completed_idx
  ON public.bigtehn_tech_routing_cache (work_order_id, operacija)
  INCLUDE (is_completed);
```

Indeksira svih 72K redova. Veličina ~5-10 MB. Za naš slučaj **inferior** jer partial gađa upravo 9 redova koje treba.

### Odluka

**Idemo sa Opcijom A.** Partial indeks je drastično manji + brži za PP-A specifičan filter.

**Postoji li sukob sa drugim upitima?** Drugi upiti na cache (npr. `tr` LATERAL u istom view-u) traže SUM po `(work_order_id, operacija)` bez `is_completed` filter-a — koriste postojeći `bigtehn_tr_cache_wo_op_idx`. Partial indeks ne pravi konflikt, samo dodaje opciju za planner.

## Drugi LATERAL-i

`prev_any` i `prev_block` LATERAL-i u view-u rade subselect na `bigtehn_work_order_lines_cache` + nested LATERAL na cache. Trebalo bi proveriti:

```sql
SELECT indexname, indexdef FROM pg_indexes 
WHERE tablename = 'bigtehn_work_order_lines_cache';
```

Ako postoji `(work_order_id, prioritet)` ili `(work_order_id)` indeks → OK. Ako ne, dodati ga je sledeći korak.

**Strategija za Sprint 1K:** primeni samo partial indeks na `bigtehn_tech_routing_cache`, ponovi EXPLAIN ANALYZE, pa odluči da li je potreban indeks na lines cache (Sprint 1K+1 ako bude potreban).

## Verifikacija

Posle apply-a, ponovi:
```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM public.plan_pp_open_ops_for_machine('8.4'::text, 100, 0);
```

**Pragovi za odluku:**
- **< 1 s** → cilj postignut, Sprint 1K zatvoren.
- **1-5 s** → poboljšanje primetno, ali nije idealno. Razmotriti indeks na lines cache.
- **5-15 s** → marginalan benefit, problem nije u PP-A NOT EXISTS. Treba dublje istražiti druge LATERAL-e.
- **> 15 s** → partial indeks nije iskorišćen u planu. Treba EXPLAIN BEFORE i AFTER da poredimo.

## Risk i rollback

| Aspekt | Vrednost |
|---|---|
| Risk apply-a | Vrlo nizak (`CONCURRENTLY`, non-blocking) |
| Risk produkcijskog efekta | 0 — samo dodaje opciju za planner |
| Rollback | `DROP INDEX CONCURRENTLY IF EXISTS bigtehn_tr_cache_incomplete_wo_op_idx;` |

## CONCURRENTLY ograničenje

`CREATE INDEX CONCURRENTLY` **ne sme** da se izvršava unutar transakcije. To znači da migracija mora da bude pokrenuta van `BEGIN; ... COMMIT;` bloka u Supabase Studio (default SQL Editor način — bez explicit transakcije).

Ako Studio environment forsira transakciju (npr. migration framework), fallback je obični `CREATE INDEX` (sa kratkim lock-om na tabelu). Bridge sync se može zaustaviti par sekundi — prihvatljivo.

## Plan implementacije

**Commit 1:** ovaj fajl (pre-flight analiza)
**Commit 2:** `sql/migrations/add_production_perf_indexes.sql` — partial indeks draft

Posle apply-a, Jara:
1. Pokreće EXPLAIN ANALYZE iznova
2. Upiše novi Execution Time u pp-sprint1d-status.md (ili novi fajl pp-sprint1k-status.md)
3. Ako < 1s: Sprint 1K zatvoren ✅
4. Ako > 1s: razmotriti indeks na lines cache + ponoviti merenje

## Vremenska procena

- Pre-flight: 30 min ✅
- SQL migracija: 15 min
- Jara apply (CONCURRENTLY, non-blocking): par sekundi
- Ponovo EXPLAIN ANALYZE: 30 s
- **Ukupno: ~1h** (najbrži sprint do sad)

# PP Sprint 1D — pre-flight analiza (M21: EXPLAIN ANALYZE plan_pp_open_ops_for_machine)

> Datum: 2026-05-16 · Sprint: 1D · Audit ref: M21 u [Plan_proizvodnje_modul_analiza.md](../Plan_proizvodnje_modul_analiza.md)

## Cilj

Izmeriti realan query plan i execution time za `plan_pp_open_ops_for_machine` RPC na najopterećenijim mašinama iz produkcije. Rezultate koristiti za odluku da li Sprint 1E treba da pravi optimizacije (cover indeks, materialized view) ili je trenutno stanje dovoljno.

## Šta merimo

Iz Sprint 0 SQL #13: top 5 mašina po broju otvorenih operacija:

| Mašina | open_ops_count |
|---|---:|
| 8.4 | 4 543 |
| 8.3 | 3 263 |
| 8.2 | 2 041 |
| 1.10 | 1 100 |
| 5.3 | 838 |

`plan_pp_open_ops_for_machine` ima `SET statement_timeout TO '180s'`. Limit 100 RN po pozivu (paginacija). RPC u svom telu LATERAL-uje 4 subselect-a iz `v_production_operations_effective`:
- `_ready_chain`: PP-A `NOT EXISTS` provera na `bigtehn_tech_routing_cache (work_order_id, operacija, is_completed)`
- `tr`: SUM agregat (`komada_done`, `real_seconds`, `prijava_count`)
- `d`: `drawings_count` iz `production_drawings`
- `prev_any` + `prev_block`: max-by-prioritet linije za prethodne operacije

Indeks `bigtehn_tr_cache_wo_op_idx (work_order_id, operacija)` postoji (Sprint 0 SQL #6) ALI ne uključuje `is_completed` kao INCLUDE kolonu. To znači da PP-A `NOT EXISTS` mora da uradi **lookup u tabelu** (heap fetch) za svaki kandidat-red posle index scan-a. Ako tabela ima mnogo redova po `(work_order_id, operacija)` paru (npr. više prijava istog operatera), to dodaje I/O.

## Prag za odluku

- **Execution time < 1s** → Sprint 1E nije potreban. Status quo OK.
- **Execution time 1–5s** → ne hitno, ali kandidat za optimizaciju kad bude vremena.
- **Execution time > 5s** → Sprint 1E prioritet — operater čeka na realnom hardware-u (PC u proizvodnji).
- **Execution time > 60s** → kritično, prelazi UX prag tolerancije. Hitan fix.

## Potencijalne optimizacije (ako budu potrebne)

Po veličini napora, od jeftinijeg ka skupljem:

### A. Cover indeks `INCLUDE (is_completed)`

```sql
CREATE INDEX CONCURRENTLY bigtehn_tr_cache_wo_op_completed_idx
  ON public.bigtehn_tech_routing_cache (work_order_id, operacija)
  INCLUDE (is_completed);
```

Prednost: PP-A `NOT EXISTS` postaje **index-only scan** — bez heap lookup-a. Trošak: ~10-15% veći disk space, jedan dodatni indeks za održavanje na svakom INSERT/UPDATE/DELETE u tech routing cache-u (bridge sync). Risk: nizak (read-only path).

### B. Partial indeks `WHERE is_completed = false`

```sql
CREATE INDEX CONCURRENTLY bigtehn_tr_cache_incomplete_wo_op_idx
  ON public.bigtehn_tech_routing_cache (work_order_id, operacija)
  WHERE is_completed = false;
```

Prednost: indeks je manji jer indeksira samo nezavršene redove (verovatno < 30% tabele). `NOT EXISTS` upit po `is_completed IS FALSE` koristi ovaj indeks direktno. Trošak: slično cover indeksu, ali manji.

**Hibridni pristup:** A+B nije dupli trošak — Postgres planner bira optimalni. Ali u praksi jedan od dva je dovoljan.

### C. Smanjenje broja LATERAL subselect-a u view-u

Trenutno view ima 4 LATERAL. `prev_any` i `prev_block` su skupi jer rade scan svih linija RN-a + lateral subselect na cache. Možda mogu da se kombinuju u jedan upit ili materijalizuju.

Trošak: invazivna view promena, mora se testirati svaki UI prikaz.

### D. Materialized view za "hot" mašine

`CREATE MATERIALIZED VIEW mv_pp_open_ops` + REFRESH posle bridge sync-a. Frontend čita iz `mv_*` umesto direktnog view-a.

Trošak: kompleksniji deploy + invalidacija. Refresh latency. Verovatno overengineering.

## Plan Sprint 1D

### Commit 1: Pre-flight analiza (ovaj fajl)

### Commit 2: SQL alat za Jaru

Novi fajl `docs/migration/pp-sprint1d-checks.sql` — read-only EXPLAIN upiti koji se izvršavaju u Supabase SQL Editor:

1. EXPLAIN ANALYZE `plan_pp_open_ops_for_machine('8.4', 100, 0)` — najveća mašina
2. EXPLAIN ANALYZE `plan_pp_open_ops_for_machine('8.3', 100, 0)` — druga
3. EXPLAIN ANALYZE direktni SELECT iz `v_production_operations_effective WHERE effective_machine_code = '8.4'` — vidimo LATERAL plan
4. Pomoćni: nađi top RN na mašini 8.4 (za izolovani PP-A `NOT EXISTS` test)
5. Indeks usage stats — `pg_stat_user_indexes`
6. Tabela size + row count
7. (Ako > 5s) Skica `CREATE INDEX CONCURRENTLY` komande u komentaru

## Acceptance kriterijumi

- SQL fajl izvršen u Supabase Studio
- Rezultati zapisani u `pp-sprint1d-status.md` (ili appendovani u `pp-sprint0-status.md` — odluka Jare)
- Donesemo odluku za Sprint 1E na osnovu execution time-a

## Vremenska procena

- Pre-flight: 30 min ✅
- SQL fajl: 15 min
- Jara izvrši i upiše rezultate: 10-15 min
- Analiza + Sprint 1E odluka: 30 min
- **Ukupno: ~1.5h**

## Stvari koje NEĆE biti u Sprint 1D

- **NE pravimo indeks niti drugu optimizaciju.** Samo merimo.
- Ako rezultati pokažu > 5s, Sprint 1E će biti odvojen.
- Bez UI promena.
- Bez izmene postojećih RPC-a ili view-ova.

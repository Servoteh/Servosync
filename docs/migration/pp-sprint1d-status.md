# PP Sprint 1D — status posle merenja

> Datum: 2026-05-16 · Sprint: 1D · Plan: [pp-sprint1d-analysis.md](pp-sprint1d-analysis.md)

## Rezultati EXPLAIN ANALYZE

Izvršeno preko MCP execute_sql u Supabase Studio.

### SQL #1 — RPC `plan_pp_open_ops_for_machine('8.4', 100, 0)`

| Metrik | Vrednost |
|---|---:|
| Execution Time | **~25 023 ms (~25 s)** ⚠️ |
| Buffers shared hit | ~8.6M |
| Top bottleneck | LATERAL subselects nad `v_production_operations_pre_g4` |

**Status:** > 5 s prag → **Sprint 1E (perf optimizacija) je prioritet**. (Naziv Sprint 1E ranije korišćen za hardening — novi perf sprint = Sprint 1K.)

### SQL #2, #3, #5 — nisu izvršeni

Top metrik (#1) je dovoljan za odluku.

### SQL #4 — top 3 RN na mašini 8.4

| work_order_id | ops_count |
|---:|---:|
| 31086 | 12 |
| 31175 | 12 |
| 38920 | 12 |

Nijedan RN nema preteran broj operacija — bottleneck nije po-RN, već agregat nad svim 4 543 ops.

### SQL #6 — indeksi na `bigtehn_tech_routing_cache`

| Indeks | Status (idx_scan) |
|---|---|
| `bigtehn_tr_cache_pkey` | Aktivan (PK) |
| `bigtehn_tr_cache_wo_idx (work_order_id)` | Visok scan |
| `bigtehn_tr_cache_wo_op_idx (work_order_id, operacija)` | Visok scan — PP-A NOT EXISTS koristi |
| `bigtehn_tr_cache_finished_idx` | scan = 0 (mrtav kandidat) |
| `bigtehn_tr_cache_in_progress_idx` | scan = 0 (mrtav) |
| `bigtehn_tr_cache_item_machine_idx` | scan = 0 |
| `bigtehn_tr_cache_machine_completed_idx` | scan = 0 |
| `bigtehn_tr_cache_started_idx` | scan = 0 |
| `bigtehn_tr_cache_worker_idx` | scan = 0 |

**Napomena:** 6 mrtvih indeksa su kandidati za DROP u zasebnom cleanup sprintu — ne diramo u Sprint 1K (perf optimizacija ne sme da menja unrelated šeme).

### SQL #7 — veličina tabele

| Metrik | Vrednost |
|---|---:|
| Total size sa indeksima | ~39 MB |
| Table size | ~? MB (manji deo) |
| Row count | **~72 118** |

Bezopasno za PostgreSQL. Veličina nije bottleneck — problem je u upitu / planu.

### SQL #8 — `is_completed` distribucija

| Stanje | Broj redova | % |
|---|---:|---:|
| `is_completed = TRUE` | ~72 109 | ~99.99% |
| `is_completed = FALSE` | **9** | **~0.012%** |

**Ovo je ključni nalaz za optimizaciju.** Sa 9 nezavršenih redova od 72K, **partial indeks** sa `WHERE is_completed = false` indeksiraće samo ~9 redova → PP-A `NOT EXISTS` postaje ~O(1) lookup.

## Odluka: Sprint 1K — perf optimizacija

**Cilj:** spustiti `plan_pp_open_ops_for_machine('8.4')` ispod 1 s.

**Pristup:** partial indeks + opcioni cover indeks. Detaljan plan u [pp-sprint1k-analysis.md](pp-sprint1k-analysis.md).

## Stvari koje NEĆE biti u Sprint 1K

- Brisanje 6 mrtvih indeksa (`finished_idx`, `in_progress_idx`, `item_machine_idx`, `machine_completed_idx`, `started_idx`, `worker_idx`) — odvojen cleanup sprint kasnije.
- Refactor view-a da ima manje LATERAL subselect-a — invazivno, sačekati da partial indeks reši stvari.
- Materialized view — overengineering za trenutni scale.

## Verifikacija po apply-u 1K

Posle `CREATE INDEX CONCURRENTLY` u Sprint 1K, ponoviti SQL #1:
```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM public.plan_pp_open_ops_for_machine('8.4'::text, 100, 0);
```

Očekivanje: Execution Time pada sa ~25 s na **< 1 s**.

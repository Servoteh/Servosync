# PP Sprint 1K — status posle indeksa

> Datum: 2026-05-15 · Sprint: 1K · Analiza: [pp-sprint1k-analysis.md](pp-sprint1k-analysis.md) · Prethodno: [pp-sprint1d-status.md](pp-sprint1d-status.md)

## Primena indeksa

Jedna non-blocking komanda (van transakcijskog bloka, MCP `execute_sql`):

```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS bigtehn_tr_cache_incomplete_wo_op_idx
  ON public.bigtehn_tech_routing_cache (work_order_id, operacija)
  WHERE is_completed = false;
```

**Status:** uspešno kreiran.

## Ponovljeni EXPLAIN ANALYZE — SQL #1

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM public.plan_pp_open_ops_for_machine('8.4'::text, 100, 0);
```

| Metrik | Vrednost |
|---|--:|
| Execution Time | **24 604.809 ms (~24.6 s)** |
| Planning Time | 0.039 ms |
| Buffers (shared) | hit≈8.6M, read=1 |
| Vanjski plan | Function Scan na `plan_pp_open_ops_for_machine` |

## Zaključak Sprint 1K

Baseline (Sprint 1D) bio je ~25.0 s; posle partial indeksa merenje je **praktično isto** (~24.6 s). Cilj < 1 s **nije** postignut samim ovim indeksom — bottleneck ostaje unutar tela funkcije / LATERAL puteva (vidi 1D status), ne u spoljašnjem planu.

**Sledeći korak (van 1K):** refaktor unutrašnjeg upita, materijalizacija relevantnog skupa, ili druga promena plana koja štedi sken nad velikim view-om — ne samo još indeksa na `bigtehn_tech_routing_cache`.

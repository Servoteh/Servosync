# PP Sprint 1L — pre-flight (dublja perf dijagnoza posle 1K fail-a)

> Datum: 2026-05-16 · Sprint: 1L · Prethodno: [pp-sprint1k-status.md](pp-sprint1k-status.md) (cilj < 1 s nije postignut)

## Šta znamo

| Iz Sprint-a | Nalaz |
|---|---|
| 1D | Execution Time = ~25 s za `plan_pp_open_ops_for_machine('8.4', 100, 0)` |
| 1D #8 | 9 incomplete redova u cache-u (~0.012%) |
| 1K | Posle partial indeksa `(work_order_id, operacija) WHERE is_completed = false`: **i dalje ~24.6 s** |
| 1K plan | `Function Scan` (EXPLAIN vidi samo top-level node) |
| 1K buffers | Shared hit ≈ 8.6M = ~70 GB sa memorije čita |

Tabela `bigtehn_tech_routing_cache` je samo **39 MB**. Da bi se shared buffers hit popeo na 70 GB, neka operacija mora da pročita celu tabelu (ili veliki deo) **~1 800 puta**. To je signatura **nested-loop LATERAL korelacije** koja re-skanira po svakom outer redu.

## Hipoteze za bottleneck

### Hipoteza A — `prev_block` / `prev_any` LATERAL nested

Iz `fix_v_production_operations_ready.sql`, `prev_block` LATERAL u view-u:

```sql
LEFT JOIN LATERAL (
  SELECT l2.operacija, l2.machine_code, l2.prioritet,
         COALESCE(t2.komada_done, 0) AS komada_done
  FROM public.bigtehn_work_order_lines_cache l2
  LEFT JOIN LATERAL (
    SELECT SUM(t.komada) AS komada_done
    FROM public.bigtehn_tech_routing_cache t
    WHERE t.work_order_id = l2.work_order_id
      AND t.operacija     = l2.operacija
  ) t2 ON TRUE
  WHERE l2.work_order_id = l.work_order_id
    AND l2.prioritet < l.prioritet
    AND COALESCE(t2.komada_done, 0) < COALESCE(wo.komada, 0)
  ORDER BY l2.prioritet DESC, l2.operacija DESC
  LIMIT 1
) prev_block ON TRUE
```

Za svaki red u view-u:
1. Skenira `bigtehn_work_order_lines_cache` sa filter `(work_order_id, prioritet)`.
2. Za svaku tu liniju: nested LATERAL sa SUM agregatom nad cache (cela skupina prijava).
3. Sortira + LIMIT 1.

Ako `bigtehn_work_order_lines_cache` ima više linija po RN-u (običajno 5-15), to je 5-15 SUM agregata po outer redu. Outer redova ima 4 543 (za mašinu 8.4). Ukupno: ~50 000+ SUM agregata. Svaki SUM čita ~par stranica → milioni stranica.

**Najjača hipoteza.**

### Hipoteza B — funkcija plan cache (generic vs custom)

PostgreSQL plpgsql funkcije imaju cache plan. Kad je indeks dodat u 1K, **postojeća kompajlirana funkcija u plan cache-u i dalje koristi stari plan**. Treba `DISCARD PLANS;` ili sesija restart.

Brzo proverljivo: pokreći EXPLAIN direktno na inline view query (`SELECT * FROM v_production_operations_effective WHERE effective_machine_code = '8.4' LIMIT 100`) — to ne ide kroz funkciju, koristi sveži plan.

### Hipoteza C — `v_production_operations_effective` JOIN-ovi

View ima `EXISTS production.predmet_aktivacija` filter + `INNER JOIN v_active_bigtehn_work_orders`. Ako lifecycle `predmet_aktivacija` nema indeks na `predmet_item_id`, EXISTS pravi seq scan.

## Plan dijagnostike

### Korak 1 — Direct view EXPLAIN (Sprint 1D SQL #3 koji nije izvršen)

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT count(*) FROM public.v_production_operations_effective
WHERE effective_machine_code = '8.4';
```

Ovo pokazuje **pravi plan** — sve LATERAL-e razvuče. Tu vidimo `nested loop` ili `hash join` na svakom nodu sa actual time-om.

### Korak 2 — Provera indeksa na susednim tabelama

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('bigtehn_work_order_lines_cache', 'bigtehn_work_orders_cache');
```

Tražimo `(work_order_id, prioritet)` i `(work_order_id)` na lines cache.

### Korak 3 — Indeks usage stats (da li 1K indeks uopšte radi)

```sql
SELECT indexrelname, idx_scan, idx_tup_read, idx_tup_fetch,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE indexrelname = 'bigtehn_tr_cache_incomplete_wo_op_idx';
```

Ako `idx_scan = 0` → planner ne koristi 1K indeks. To znači H-B (plan cache) ili da partial indeks ne matchuje filter sintaksi.

### Korak 4 — Plan cache test

```sql
DISCARD PLANS;
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM public.plan_pp_open_ops_for_machine('8.4'::text, 100, 0);
```

Ako se Execution Time spušta posle `DISCARD PLANS;` → H-B potvrđen, treba `ALTER FUNCTION ... SET plan_cache_mode = force_custom_plan;`.

### Korak 5 — `predmet_aktivacija` indeks audit

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'production' AND tablename = 'predmet_aktivacija';
```

## Posledice po hipotezi

| Hipoteza potvrđena | Akcija |
|---|---|
| **A** (LATERAL nested) | Dodati indeks `(work_order_id, prioritet, operacija)` na `bigtehn_work_order_lines_cache` ako fali; refaktor view-a da kombinuje `prev_any`+`prev_block` u jedan LATERAL |
| **B** (plan cache) | `ALTER FUNCTION ... SET plan_cache_mode = force_custom_plan;` (jednostavno, ali možda nedovoljno) |
| **C** (predmet_aktivacija) | `CREATE INDEX ON production.predmet_aktivacija (predmet_item_id) WHERE je_aktivan = true;` |

## Šta NEĆE biti u Sprint 1L

- Bilo kakva izmena view-a ili RPC tela — Sprint 1L je samo **dijagnoza**.
- Brisanje 1K indeksa — ostavlja se za sada (možda će se koristiti posle plan cache reset-a).
- Materijalizovan view — too invazivan, čeka da dijagnoza pokaže potrebu.

## Plan implementacije

**Commit 1:** ovaj fajl (pre-flight)
**Commit 2:** `docs/migration/pp-sprint1l-checks.sql` — 5 dijagnostičkih upita za Jara

Posle Jarinog izvršavanja, ja sastavljam `pp-sprint1l-status.md` sa odlukom: Sprint 1M cilj (refaktor) ili Sprint 1L+ (manji indeks).

## Vremenska procena

- Pre-flight: 30 min ✅
- SQL alat: 20 min
- Jara izvrši 5 upita: 10 min
- Sinteza + odluka: 30 min
- **Ukupno: ~1.5h**

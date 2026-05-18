# Plan — ispravka vremena (P0/P1) — deploy 2026-05-20

Primeno na Supabase projekat preko MCP (`plan_fix_real_and_planned_seconds`, `plan_fix_real_views`, `plan_fix_real_views_wrap`).

Repozitorijumska migracija: `20260520120000__plan_fix_real_and_planned_seconds.sql`

## Šta menja

- `plan_tech_routing_real_seconds(work_order_id, operacija)` — `real_seconds` = zbir `(finished_at - started_at)`, ne `SUM(PrnTimer)`.
- `v_production_operations_pre_g4` koristi tu funkciju u LATERAL `tr`.
- Klijent: `plannedSeconds()` — preostala količina (`komada_total - komada_done`), TPZ samo dok nema urađenih komada.

## Smoke

```sql
SELECT rn_ident_broj, operacija, real_seconds
FROM v_production_operations_effective
WHERE rn_ident_broj = '9000/107' AND operacija = 10;
-- Očekivano: real_seconds ~ 2287206 (ne ~4780451)
```

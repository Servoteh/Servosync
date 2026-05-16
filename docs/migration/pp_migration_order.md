# Plan proizvodnje modul — redosled migracija (runbook)

Rešava nalaz **H27** iz [docs/Plan_proizvodnje_modul_analiza.md](../Plan_proizvodnje_modul_analiza.md): PP migracije imaju implicitne zavisnosti („Primeni nakon X") koje Supabase SQL Editor ne validira. Ako neko pokrene out-of-order, baza padne sa missing column/constraint ili sa missing cross-module function.

Ovaj fajl je istina za **redosled apply-a u Supabase produkciji**.

Analog za Lokacije modul: [loc_migration_order.md](loc_migration_order.md).

---

## Cross-module zavisnosti

PP migracije zovu funkcije definisane u drugim modulima. Pre prve PP migracije, OVE moraju da postoje:

| Funkcija | Definisana u | Status na produkciji (Sprint 0 SQL #4) |
|---|---|---|
| `public.current_user_email()` | `add_audit_log.sql` (kadrovska/share) | ✅ postoji |
| `public.current_user_is_admin()` | `add_audit_log.sql` ili sl. | ✅ postoji |
| `production._pracenje_line_is_final_control(...)` | Praćenje proizvodnje (`20260425124400__pracenje_proizvodnje_init.sql`) | ✅ postoji |

Ako bilo koja fali (npr. nova/dev baza pre Praćenja), PP migracije će padati. **Pre PP apply-a, primeni Praćenje proizvodnje modul.**

---

## Redosled apply-a (produkcija)

| # | Fajl | Zavisi od | Idempotentno | Rollback |
|---|---|---|---|---|
| 1 | `add_plan_proizvodnje.sql` | `current_user_email` cross-module | da (CREATE IF NOT EXISTS) | DROP TABLE production_overlays, production_drawings CASCADE |
| 2 | `add_plan_proizvodnje_menadzment_edit.sql` | (1) | da | restore can_edit_plan_proizvodnje bez 'menadzment' |
| 3 | `add_v_production_operations.sql` | (1) + bigtehn_*_cache | da | DROP VIEW v_production_operations |
| 4 | `revoke_anon_v_production_operations.sql` | (3) | da | GRANT SELECT ON v_production_operations TO anon |
| 5 | `add_production_active_work_orders.sql` | bigtehn_work_orders_cache | da | DROP TABLE production_active_work_orders |
| 6 | `update_v_production_operations_active_work_orders.sql` | (3) + (5) | da | restore prethodni view |
| 7 | `add_production_overlays_cam_ready.sql` | (1) + (6) | da | ALTER TABLE production_overlays DROP COLUMN cam_ready, cam_ready_at, cam_ready_by |
| 8 | `add_production_g2_readiness_urgency.sql` | (6) + (7) | da | DROP TABLE production_urgency_overrides; restore prethodni view bez is_urgent/auto_sort_bucket |
| 9 | `add_production_cooperation_g7.sql` | (8) + `current_user_is_admin` cross-module | da | DROP TABLE production_auto_cooperation_groups; ALTER TABLE production_overlays DROP COLUMN cooperation_* |
| 10 | `add_production_g5_reassign_rpc.sql` | (9) + `current_user_email` | da | DROP FUNCTION reassign_production_line, bulk_reassign_production_lines, can_force_plan_reassign, production_machine_group_slug; DROP TABLE production_reassign_audit |
| 11 | `add_production_g4_rework_scrap_cache.sql` | (9) + `production._pracenje_line_is_final_control` cross-module | da | DROP TABLE bigtehn_rework_scrap_cache; rename view nazad iz `_pre_g4` |
| 12 | `add_production_g6_auto_in_progress.sql` | (11) + service_role | da | DROP FUNCTION mark_in_progress_from_tech_routing |
| 13 | `supabase/migrations/20260506120000__plan_hide_rn_after_final_qc.sql` | (11) + `production._pracenje_line_is_final_control` | da | restore prethodni view bez `plan_rn_final_control_done` |
| 14 | `supabase/migrations/20260507100000__plan_final_qc_hide_fix_double_sum.sql` | (13) | da | restore (13) verziju |
| 15 | `supabase/migrations/20260506120000__plan_pp_open_ops_machine_wo_pagination.sql` | (14) | da | DROP FUNCTION plan_pp_open_ops_for_machine |
| 16 | `fix_v_production_operations_ready.sql` (PP-A) | (14) + (15) | da | restore G2 readiness logiku, restore plan_pp_open_ops_for_machine iz (15) |
| 17 | **`add_production_g5_idempotency.sql`** (Sprint 1B / H1) | (10) + (16) | da | DROP FUNCTION reassign_production_line(...,uuid); DROP FUNCTION bulk_reassign_production_lines(...,uuid); ALTER TABLE production_reassign_audit DROP COLUMN client_event_uuid |
| 18 | **`add_production_security_hardening.sql`** (Sprint 1E / L5+H5+H9) | (10) + drawings tabela | da | restore search_path = public; GRANT INSERT,UPDATE,DELETE ON production_reassign_audit TO authenticated; ALTER TABLE production_drawings DROP CONSTRAINT pd_storage_path_safe |
| 19 | **`add_production_overlays_history.sql`** (Sprint 1G / M11) | (1) + `current_user_email` | da | DROP TRIGGER po_audit_history; DROP FUNCTION production_overlays_audit_history; DROP TABLE production_overlays_history |
| 20 | **`add_production_orphaned_machine_cleanup.sql`** (Sprint 1H / H8) | (19) (radi i bez njega ali bolje sa) + **pg_cron** | da | `cron.unschedule('po_cleanup_orphaned_machines')`; DROP FUNCTION _po_cleanup_orphaned_machines_cron |

**Bold** = Sprint 1 hardening migracije iz 2026-05-16 sesije.

---

## Provera primenjenih migracija

Supabase nema kanonski „migration tracking" za inkrementalne apply-e. Verifikacija se radi pretragom postojanja konstrukti koje migracija donosi.

### Bazne tabele (1)
```sql
SELECT count(*) FROM information_schema.tables
WHERE table_schema='public' AND table_name IN ('production_overlays', 'production_drawings');
-- Treba: 2
```

### Gate proširena sa menadzment (2)
```sql
SELECT proname, prosrc FROM pg_proc WHERE proname='can_edit_plan_proizvodnje';
-- Telo treba da sadrži 'menadzment'
```

### Active RN filter (5+6)
```sql
SELECT count(*) FROM information_schema.tables
WHERE table_schema='public' AND table_name='production_active_work_orders';
-- Treba: 1
SELECT column_name FROM information_schema.columns
WHERE table_name='v_production_operations' AND column_name='is_mes_active';
-- Treba: 1 red
```

### G2/G3/G4/G5/G6/G7 (7-12)
```sql
SELECT proname FROM pg_proc WHERE proname IN (
  'reassign_production_line', 'bulk_reassign_production_lines',
  'mark_in_progress_from_tech_routing', 'can_force_plan_reassign',
  'production_machine_group_slug'
);
-- Treba: 5 redova
SELECT count(*) FROM information_schema.tables
WHERE table_schema='public' AND table_name IN (
  'production_urgency_overrides', 'production_auto_cooperation_groups',
  'production_reassign_audit', 'bigtehn_rework_scrap_cache'
);
-- Treba: 4
```

### KK + paginacija + PP-A (13-16)
```sql
SELECT column_name FROM information_schema.columns
WHERE table_name='v_production_operations'
  AND column_name IN ('plan_rn_final_control_done', 'is_ready_for_machine');
-- Treba: 2 reda
```

### Sprint 1 hardening (17-20)
```sql
-- H1 idempotency (17)
SELECT column_name FROM information_schema.columns
WHERE table_name='production_reassign_audit' AND column_name='client_event_uuid';
-- Treba: 1 red

-- L5/H5/H9 hardening (18)
SELECT proconfig FROM pg_proc WHERE proname='can_edit_plan_proizvodnje';
-- Treba: sadrži 'pg_temp'
SELECT conname FROM pg_constraint WHERE conname='pd_storage_path_safe';
-- Treba: 1 red

-- M11 history (19)
SELECT count(*) FROM information_schema.tables
WHERE table_schema='public' AND table_name='production_overlays_history';
-- Treba: 1
SELECT tgname FROM pg_trigger WHERE tgname='po_audit_history';
-- Treba: 1 red

-- H8 orphan cleanup (20)
SELECT jobname FROM cron.job WHERE jobname='po_cleanup_orphaned_machines';
-- Treba: 1 red (samo na PAID Supabase tier-u)
```

---

## CI redosled

Trenutno PP migracije **nisu** uključene u `sql/ci/migrations.txt` (CI je samo za Lokacije za sada). Ako se ikad doda CI za PP, redosled mora pratiti ovu tabelu **bez** koraka 20 (pg_cron migracija) — CI baza nema PAID tier-a.

---

## Out-of-order apply scenariji

Šta će se desiti ako neko pokrene migracije pogrešnim redom:

| Scenario | Posledica |
|---|---|
| Apply (11) pre (1) | `production._pracenje_line_is_final_control` ne postoji ili `production_overlays` ne postoji → ERROR |
| Apply (9) pre `current_user_is_admin` | `function current_user_is_admin() does not exist` |
| Apply (16) PP-A pre (15) paginacije | DROP CASCADE u (16) skida `plan_pp_open_ops_for_machine`, ali ga (16) ponovo kreira sa svojim potpisom — OK |
| Apply (17) H1 pre (10) | `production_reassign_audit` ne postoji → ERROR |
| Apply (19) M11 pre (1) | `production_overlays` ne postoji → ERROR |
| Apply (20) H8 pre (19) | Radi, ali cleanup promene se ne logiraju u history (acceptable trade-off) |

---

## Promene posle 2026-05-16 (Sprint 1)

| Sprint | Migracija | Audit ID | Apply status |
|---|---|---|---|
| 1B | `add_production_g5_idempotency.sql` | H1 | Čeka Jara |
| 1E | `add_production_security_hardening.sql` | L5+H5+H9 | Čeka Jara (pre-flight SELECT najpre) |
| 1G | `add_production_overlays_history.sql` | M11 | Čeka Jara |
| 1H | `add_production_orphaned_machine_cleanup.sql` | H8 | Čeka Jara (PAID tier) |

Preporučen redosled apply-a:
1. **1B** → 2. **1E** (pre-flight SELECT najpre) → 3. **1G** → 4. **1H**

---

**Verzija:** 2026-05-16 · **Autor:** Claude Opus 4.7 · **Audit ref:** H27.

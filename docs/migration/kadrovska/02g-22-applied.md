# Sprint 2.2 — RLS hardening primenjen

- **Datum:** 2026-05-17
- **Backup:** verifikovan pre apply-a (vidi `docs/migration/kadrovska/02c-extend-applied.md`)
- **Apply:** MCP `execute_sql` na projekat vezan za workspace (isti gde je extend primenjen)
- **Sanity check 1** (broj politika na ciljanim tabelama): 4 po tabeli × 6 tabela (`absences`, `work_hours`, `vacation_entitlements`, `contracts`, `employees`, `vacation_requests`) = **24**
- **Sanity check 2** (izrazi u `pg_policy`): write politike koriste **`current_user_is_admin()` OR `current_user_is_hr()` OR** scoped **`has_edit_role()` AND `current_user_manages_employee(...)`** (ili samo admin/HR za `employees_insert` / `employees_delete`)
- **Smoke test (browser):** admin, HR, menadžer (NULL scope) → bez 401/403 na opisanim scenarijima *(provera operatora)*
- **RBAC matrica:** `npm run gen:rbac-matrix` posle merge-a migracija u repou

## Specifičnosti odluka

- **employees_update:** koristi `current_user_manages_employee(id)` umesto novog `current_user_manages_department(department)`. Semantika ista; optimizacija u Sprint 4 polish backlog.
- **employees_insert** i **employees_delete:** striktno admin / HR (menadžer ne kreira niti briše zaposlene).
- **vr_insert:** očuvan self-submit (`submitted_by` = JWT email) + proširen za admin / HR / scoped menadžment.
- **employee_children:** **nije dirano** — ostaje strogo admin (PII).
- **vr_select** i **vr_update:** u **extend** migraciji (managed GO scope).
- **vr_delete:** **nije dirano** — Sprint 4 backlog.

## Sub_department scope refaktor — Sprint 4 / Faza 2 backlog

Pre 2.2, menadžeri sa `managed_departments` na nivou **pododeljenja** (npr. Nabavka, Bravarija) mogli su biti neusklađeni sa `employees.department` na nivou **sektora**. Pravi scope čeka refaktor helpera da koristi npr. `employees.sub_department_id` (ili mapiranje), ne samo `employees.department`.

## Operativno

- **24h watchful period:** izbegavati nove SQL promene narednih 24h ako je moguće; pri prijavi 401 prvo **`user_roles`**, **Network** ( koji zahtev ), ne rollback bez dijagnoze.
- **Druga Supabase instanca (npr. Luka):** ručno primeniti isti niz: `extend_kadr_managed_departments_scope.sql`, `harden_kadr_menadzment_write_scope.sql`, uz usklađen `managed_departments` (NULL za legacy pun scope ili realan test skup), inače lokalni testovi ne odražavaju produkciju.

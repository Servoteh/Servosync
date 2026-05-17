# `extend_kadr_managed_departments_scope` — evidencija primene

**Namena:** Za 6+ meseci — odgovor na „kada je ovo bilo na stagingu / ko je primenio”.

---

## Staging (Supabase SQL Editor)

| Polje | Vrednost |
|--------|----------|
| **Datum apply-a** | _YYYY-MM-DD — popuniti posle izvršenja_ |
| **Ko je radio** | _Ime — ručno (ovaj korak nije Cursor)_ |
| **MCP / URL projekta (provera okruženja)** | `https://fniruhsuotwsrjsbhrxd.supabase.co` — **morate sami potvrditi da je ovo staging**, ne prod. |

### Provere posle `Run` cele migracije `sql/migrations/extend_kadr_managed_departments_scope.sql`

| Provera | Status |
|---------|--------|
| **(a)** `pg_proc`: `current_user_managed_departments`, `current_user_manages_employee`, `current_user_can_manage_vacreq` — **3 reda** | ☐ |
| **(b)** Ulogovan kao menadžment korisnik: `SELECT public.current_user_managed_departments();` — niz ili `NULL` (legacy) | ☐ |
| **(c)** `current_user_manages_employee(...)` sa `employees.id` iz odeljenja iz scope-a — **true** | ☐ |

### Opciono (~10 min)

| Koridor | Status |
|--------|--------|
| `sql/tests/security_kadr_managed_departments_scope.sql` u SQL Editoru (ROLLBACK na kraju) | ☐ svi assertovi OK |

---

## Repo / CI

| Polje | Vrednost |
|--------|----------|
| **PR / MR koji dodaje red u `sql/ci/migrations.txt`** | _Link — umeti posle merge-a_ |
| **Napomena za redosled** | U CI listi: posle `enable_user_roles_rls_proper.sql` (jer extend koristi `current_user_is_admin()`), sledi `add_rbac_managed_departments.sql` → `add_kadr_vacation_requests.sql` → `extend_kadr_managed_departments_scope.sql`. |

---

## Posledica

Kada gore (a)–(c) na **stagingu** prođu, helpere ima baza — **Sprint 2.2 (RLS dalje)** može da se veže na iste funkcije.

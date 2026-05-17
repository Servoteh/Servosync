# Draft: managed_departments + GO scope (Sprint 1)

**Datum:** 2026-05-17  
**Migracija (draft):** `sql/migrations/extend_kadr_managed_departments_scope.sql`  
**Test (DRAFT):** `sql/tests/security_kadr_managed_departments_scope.sql`

---

## 1. `current_user_can_manage_vacreq()` — stara vs nova

### Stara definicija (iz `add_kadr_vacation_requests.sql`)

```sql
CREATE OR REPLACE FUNCTION current_user_can_manage_vacreq()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE lower(email) = lower(auth.jwt() ->> 'email')
      AND role IN ('admin', 'hr', 'menadzment', 'leadpm', 'pm')
      AND is_active = true
  )
$$;
```

### Nova definicija (isto ponašanje rezultata za 0-arg)

Telo je **funkcionalno isto** (isti `EXISTS` nad ulogama), uz dodato `SET search_path = public, pg_temp` i kvalifikovane šeme.

**Šta se menja u sistemu:** RLS na `vacation_requests` **više ne koristi** samo ovu funkciju za SELECT/UPDATE managerske grane. Umesto `current_user_can_manage_vacreq()` u tim politikama stoji **`current_user_manages_employee(employee_id)`**, koja:

- za **admin / hr / pm / leadpm** vraća `true` za svakog zaposlenog;
- za **menadzment**: `managed_departments IS NULL` ⇒ pun obim; inače `employees.department = ANY(managed_departments)`.

**Zašto nije „prošireno” u telu 0-arg funkcije:** bez `employee_id` PostgreSQL ne zna koji red `vacation_requests` se proverava u `USING` izrazu ako se poziva samo `...()`.

### Diff (zamišljen)

```diff
-AS $$
-  SELECT EXISTS (
-    SELECT 1 FROM user_roles
-    WHERE lower(email) = lower(auth.jwt() ->> 'email')
+AS $$
+  SELECT EXISTS (
+    SELECT 1 FROM public.user_roles AS ur
+    WHERE lower(ur.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
       AND role IN ('admin', 'hr', 'menadzment', 'leadpm', 'pm')
-      AND is_active = true
+      AND ur.is_active IS TRUE
   )
 $$;
```

+ Nova migracija dodaje `SECURITY DEFINER … SET search_path = public, pg_temp` i `COMMENT`.

---

## 2. `current_user_managed_departments()` — zamenjena stara verzija

Stara verzija u `add_rbac_managed_departments.sql` koristila je `ur.user_id = auth.uid()` (često neusklađeno sa šemom `user_roles` u repou).

Nova verzija: jedan red sa `role = 'menadzment'`, match na `lower(email)` iz JWT-a, vraća `managed_departments`.

---

## 3. `current_user_manages_employee(p_emp_id)` — napomena o `current_user_is_hr_or_admin()`

U specifikaciji je predložen `WHEN current_user_is_hr_or_admin() THEN true`. U bazi **`current_user_is_hr_or_admin()` uključuje i `menadzment`**, pa bi to poništilo department scope. Implementacija koristi **eksplicitno** grananje: `admin`, zatim `hr`, zatim `pm`/`leadpm`, zatim `menadzment` sa `managed_departments`. Funkcije `current_user_is_hr_or_admin` / `has_edit_role` **nisu menjane** (zahtev).

---

## 4. JS — `canManageEmployee()` u `src/state/auth.js`

Paritet sa `current_user_manages_employee`; koristi `getManagedDepartments()` (bez dupliranja pravila o nizu).

---

## 5. Sprint 2 — UI tačke za uvođenje `canManageEmployee`

Cilj: ne prikazivati dugmad Odobri/Odbij / ne koristiti optimistic UI kada RLS ionako odbija; sužiti liste gde je UX poželjan.

| Fajl | Predlog integracije |
|------|---------------------|
| `src/ui/kadrovska/vacationRequestsTab.js` | U `_renderRows`, umesto samo `canManageVacationRequests()` za akcije, zahtevati i `canManageEmployee(emp)` gde je `emp` red iz `kadrovskaState.employees` za `r.employeeId`. |
| `src/ui/kadrovska/index.js` | Opciono: background load badge / prefetch zahteve samo ako korisnik ima bar jedan „manage” slučaj — ili ostaviti load, ali badge tekst ako nema prava ni za jedan pending (Sprint 2 UX). |
| `src/ui/kadrovska/shared.js` | Samo ako se uvodiDisable taba „Zahtevi GO” za menadžment bez ikakvog scope reda — trenutno `canManageVacationRequests()` ostaje „šešir”; sužavanje je po redu u tabu. |
| `src/ui/mojProfil/index.js` | Opciono: poruka ako je menadžment scooped a bira zaposlenog van liste (edge); picker je već filtriran — paritet sa `canManageEmployee` za buduće polje bez picker-a. |

**Napomena:** `canManageVacationRequests()` i dalje odgovara „ulazi u modul / vidi tab”; stvarno odobrenje po redu — `canManageEmployee`.

---

## 6. Sledeći koraci (van ovog PR-a)

- Posle `CREATE POLICY`: pokrenuti `node scripts/generate-rbac-matrix.cjs --check` i uključiti migraciju u `sql/ci/migrations.txt`.
- Razmotriti da li `vr_delete` treba da koristi isti scope kao UPDATE (trenutno `current_user_is_hr_or_admin()` uključuje menadžment).

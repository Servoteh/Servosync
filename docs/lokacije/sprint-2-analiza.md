# Sprint LOC-Härd-2 — Korak 1 analiza

**Status:** STOP — sprint pravila kažu da Cursor pita pre migracije ako vrednosti `pododeljenje` ne odgovaraju draftu.
**Datum:** 2026-05-15
**Sprint dokument:** `HARDENING_SPRINTS.md` (Härd-2)

---

## 1. Postojeća definicija `loc_can_manage_locations()` i `loc_is_admin()`

Iz `sql/migrations/add_loc_module.sql` (originalna verzija) i `add_loc_menadzment_manage_locations.sql` (proširenje):

```sql
-- helper: kompletan spisak uloga iz user_roles za aktuelnog auth.jwt() korisnika
CREATE OR REPLACE FUNCTION public.loc_auth_roles()
RETURNS TEXT[]
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT coalesce(
    array_agg(DISTINCT lower(ur.role::text)) FILTER (WHERE ur.role IS NOT NULL),
    ARRAY[]::text[]
  )
  FROM public.user_roles ur
  WHERE ur.is_active = true
    AND lower(ur.email) = lower(coalesce(auth.jwt()->>'email', ''));
$$;

-- INSERT/UPDATE master lokacija
CREATE OR REPLACE FUNCTION public.loc_can_manage_locations()
RETURNS BOOLEAN ... AS $$
  SELECT public.loc_auth_roles() && ARRAY['admin','leadpm','pm','menadzment']::text[];
$$;

CREATE OR REPLACE FUNCTION public.loc_is_admin()
RETURNS BOOLEAN ... AS $$
  SELECT public.loc_auth_roles() && ARRAY['admin']::text[];
$$;
```

Identifikacija korisnika ide preko **email-a iz JWT-a** matchovanog na `user_roles.email` (lowercased), **NE** preko `auth.uid()`. Isti obrazac koriste `add_pb4_rls_and_agg.sql`, `add_menadzment_full_edit_kadrovska.sql`, `add_maintenance_module.sql:maint_is_erp_admin`.

## 2. Postojeće uloge u `user_roles.role`

CHECK constraint je više puta menjan; finalna vrednost iz `add_pm_teme_v2.sql` + `sql/ci/00_bootstrap.sql`:
- `admin`
- `leadpm`
- `pm`
- `user`
- `viewer`
- `hr`
- `menadzment`
- `magacioner` (samo u CI bootstrap-u; nije verifikovano u produkciji)

Sprint dokument je potvrdio listu **admin, leadpm, pm, menadzment** za Härd-2.

## 3. KRITIČNO OTKRIĆE — sprint draft predlaže shape koji NE postoji

Sprint draft v5 helper-a:
```sql
SELECT pododeljenje INTO v_pododeljenje
  FROM public.employees
 WHERE auth_user_id = v_uid
 LIMIT 1;
```

**Dva problema:**

### Problem A — `employees.auth_user_id` ne postoji
`grep -r 'auth_user_id' sql/migrations/` daje 0 matches. Mapping employee → auth user u celom kodbase-u ide preko `lower(email)`:

```sql
-- obrazac iz add_pb4_rls_and_agg.sql, add_menadzment_full_edit_kadrovska.sql:
DECLARE
  auth_email TEXT := lower(trim(coalesce(auth.jwt() ->> 'email', '')));
BEGIN
  ...
  WHERE lower(trim(ur.email)) = auth_email
  ...
```

Schema `employees`:
- `id UUID`, `full_name TEXT`, `department TEXT` (legacy), `department_id INTEGER → departments`, `sub_department_id INTEGER → sub_departments`, `position_id INTEGER → job_positions`, `email TEXT` (unique ako nije prazan), `is_active BOOLEAN`.
- **Nema `auth_user_id`.**

### Problem B — `pododeljenje` nije kolona, već JOIN na `sub_departments`
Sprint draft pretpostavlja `employees.pododeljenje TEXT` koje sadrži literalno `'Magacin'` ili `'Proizvodnja'`. Stvarno:

```sql
-- iz add_kadr_org_structure.sql:
INSERT INTO public.sub_departments (department_id, name, sort_order)
SELECT t.dept_id, t.name, t.so
FROM (VALUES
  -- 2 · Proizvodnja (top-level)
  (2, 'Rukovodstvo i tehnologija', 10),
  (2, 'Planiranje i priprema',     20),
  (2, 'Sečenje i rezanje',         30),
  (2, 'Bravarija i zavarivanje',   40),
  (2, 'Farbara',                   50),
  (2, 'Mašinska obrada',           60),
  -- 3 · Montaža
  (3, 'Mašinska montaža',          10),
  -- 8 · Infrastruktura, logistika i nabavka
  (8, 'Rukovodstvo infrastrukture', 10),
  (8, 'Nabavka',                    20),
  (8, 'Magacin i logistika',        30),
  (8, 'Objekti i bezbednost',       40),
  ...
)
```

**Nigde ne postoji `sub_departments.name = 'Magacin'` ni `'Proizvodnja'`** kao tačan string.

## 4. Stvarne kandidatske vrednosti

| Top-level `departments` (id, name) | Sva pododeljenja koja pripadaju |
|---|---|
| 1 — Menadžment | (bez sub) |
| 2 — **Proizvodnja** | Rukovodstvo i tehnologija; Planiranje i priprema; Sečenje i rezanje; Bravarija i zavarivanje; Farbara; Mašinska obrada |
| 3 — **Montaža** | Mašinska montaža |
| 4 — Automatika – Elektro | Rukovodstvo automatike; Elektro projektovanje; PLC programiranje i SCADA; Puštanje u rad; Elektro montaža |
| 5 — Inženjering i projektovanje | Rukovodstvo inženjeringa; Mašinsko projektovanje; Hidraulika i algoritmi |
| 6 — Projekti | PM tim |
| 7 — Prodaja i marketing | Prodaja; Ponude i tenderi; Marketing |
| 8 — **Infrastruktura, logistika i nabavka** | Rukovodstvo infrastrukture; Nabavka; **Magacin i logistika**; Objekti i bezbednost |
| 9 — Održavanje i servis | Održavanje opreme; Terenski servis; IT |
| 10 — Kvalitet | Kontrola kvaliteta |
| 11 — Finansije i administracija | Administracija; HR i organizacioni razvoj; Finansije i pravo |

---

## 5. Otvorena pitanja (čekam potvrdu pre Koraka 2)

### Q1. Koji ZAPOSLENI tačno smeju da pozivaju `loc_create_movement`?

Tri verovatne interpretacije „Magacin / Proizvodnja":

| Opcija | Pravilo | Posledica |
|---|---|---|
| **A** | `departments.id = 2` (Proizvodnja, sva pododeljenja) + `sub_departments.name = 'Magacin i logistika'` | Široko: ~svi proizvodni radnici + magacioneri. Operativci u Montaži (`departments.id = 3`) ostaju van. |
| **B** | `departments.id IN (2, 3)` (Proizvodnja + Montaža) + `sub_departments.name = 'Magacin i logistika'` | Najlogičnije za modul Lokacije: i monteri „uzimaju” delove sa polica i taj pokret se mora zapisati. |
| **C** | `departments.id IN (2, 3, 8)` (Proizvodnja + Montaža + cela Infrastruktura) | Najšire: i nabavka i objekti+bezbednost mogu da skeniraju. Verovatno preterano. |
| **D** | drugačija ručna lista (npr. samo specifične pozicije iz `job_positions`) | Cursor pita šta tačno. |

**Preporuka analize:** **B** — Proizvodnja (dept 2) + Montaža (dept 3) + sub_department „Magacin i logistika". Razlog: skeniranje na polici se dešava u tri sloja: magacioner premešta robu, proizvodnja zaduži za TP, monter premešti u sklop. Sva tri toka su legitimna.

### Q2. Mapping korisnika — email ili UID?

Predlažem da pratimo postojeći obrazac (svuda u kodbase-u): **email** iz JWT-a matchovan na `lower(employees.email)`. Tako helper postaje:

```sql
CREATE OR REPLACE FUNCTION public.loc_can_create_movement()
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email TEXT := lower(trim(coalesce(auth.jwt()->>'email', '')));
  v_roles TEXT[];
BEGIN
  IF auth.uid() IS NULL OR v_email = '' THEN
    RETURN false;
  END IF;

  -- (1) user_roles spisak (Härd-1 lista)
  v_roles := public.loc_auth_roles();   -- već postoji
  IF v_roles && ARRAY['admin','leadpm','pm','menadzment']::text[] THEN
    RETURN true;
  END IF;

  -- (2) employee match preko email-a → odeljenje/pododeljenje
  RETURN EXISTS (
    SELECT 1
      FROM public.employees e
      LEFT JOIN public.sub_departments sd ON sd.id = e.sub_department_id
     WHERE e.is_active
       AND lower(coalesce(e.email,'')) = v_email
       AND (
         e.department_id IN (2, 3)             -- Proizvodnja, Montaža (Opcija B)
         OR sd.name = 'Magacin i logistika'    -- magacioneri u Infrastrukturi
       )
  );
END;
$$;
```

### Q3. Da li `viewer` ili `magacioner` user_roles uloga ima neki uticaj?

Ako neko ima `user_roles.role = 'viewer'` i istovremeno je u Proizvodnji — Opcija B propušta (employee check pobeđuje). To je verovatno ispravno. Ako želiš da **explicit `viewer` role overrid-uje** (sprečava skeniranje), reci.

`magacioner` postoji u CI CHECK constraint-u — proveri da li je live u produkciji (Cursor nije pokrenuo upit na bazi, samo grep migracija). Ako jeste, treba ga dodati u listu `user_roles` granu (1) helper-a.

### Q4. CSV injection (L24) — gde tačno?

Postoji `tests/lib/csv.test.js` i `src/lib/csv.js`. CSV se generiše u 3 mesta u Lokacije modulu (`fetchAllPlacements` export, history export, report export) + više u Kadrovska. Predlažem da escape pattern (`=`, `+`, `-`, `@`, `\t`, `\r` prefiksuju sa `'`) bude **u `src/lib/csv.js`** (centralno) i pokrije se test slučajem. To je 1 fajl + 1 test fajl.

---

## 6. Sažetak — šta sledi posle potvrde

Posle odgovora na **Q1–Q3**, Korak 2 piše `sql/migrations/harden_loc_create_movement_v5_roles.sql`:
- Helper `loc_can_create_movement()` sa logikom iz Q1 (B preporuka) + obrascom mapiranja iz Q2 (email).
- Modifikacija RPC-a `loc_create_movement` v5: posle `auth.uid() IS NOT NULL` check, dodaje se `IF NOT public.loc_can_create_movement() THEN return not_authorized`.

Korak 3 (frontend):
- Mapping `not_authorized` → "Nemate dovoljno prava za premeštanje."

Korak 4 (pgTAP):
- `test_authz_admin_passes` (admin uloga, bez employee reda → prolazi)
- `test_authz_random_authenticated_blocked` (login bez ijedne uloge i bez employee reda → blocked)
- `test_authz_proizvodnja_employee_passes` (employee sa `department_id=2`, bez user_roles → prolazi)
- `test_authz_magacin_employee_passes` (employee sa `sub_departments.name='Magacin i logistika'` → prolazi)

Bonus L24:
- `src/lib/csv.js` escape; `tests/lib/csv.test.js` nova test grupa.

---

**STOP. Čekam odgovore na Q1–Q4.**

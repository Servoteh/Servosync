# PB Sprint 4 — Faza A (analiza)

## A1. `employees` — pododeljenje

- **Tačan naziv kolone za FK:** `sub_department_id` (INTEGER → `sub_departments(id)`), vidi `sql/migrations/add_kadr_org_structure.sql`.
- **Legacy tekst:** kolona `department` (TEXT) — payroll / prikaz; **ne koristi se** za pravilo „Rukovodstvo inženjeringa“ u PB4 SQL — koristi se **`sub_departments.name`** preko join-a.
- **Tačna vrednost u seed-u:** u `add_kadr_org_structure.sql` linija ~244: `name = 'Rukovodstvo inženjeringa'` (malo **i** u „inženjeringa“). U PB4 helper-u koristi se **`lower(trim(sd.name)) = lower(trim('Rukovodstvo inženjeringa'))`** radi otpornosti na razliku velikih/malih slova.

## A2. Mapiranje auth email → `employee_id`

- U projektu se svuda koristi **`auth.jwt() ->> 'email'`** (ne `auth.email()` u migracijama).
- Nema jedinstvene funkcije `employee_id_from_jwt` pre PB4 — dodaje se **`pb_current_employee_id()`** u `add_pb4_rls_and_agg.sql`.

## A3. `ganttTab.js` — listeneri

- **`renderGanttTab`** puni `root.innerHTML` pa dodaje **više** slušalaca unutar iste funkcije:
  - navigacija (`#pbGanttPrev` / Next / Today),
  - **`root.querySelectorAll('.pb-gantt-task-row .pb-gantt-name').forEach(td => addEventListener('click', ...))`**
  - **`root.querySelectorAll('.pb-gantt-bar').forEach(bar => addEventListener(...))`** za tooltip i klik.
- Pri svakom pozivu `renderGanttTab` (promena filtera / meseca) stari čvorovi se brišu — **slušalci na starom DOM-u nestaju**, ali ako bi se ikad dodalo na stabilni parent bez full replace, došlo bi do dupliranja. **Rešenje PB4:** delegacija na **`root`** (`click`, `mouseover`/`mouseout` ili `pointer*`) + **`data-task-id` na `.pb-gantt-bar`** da se ne traži task preko reda pri svakom handleru.

## A4. `izvestajiTab.js` — učitavanje i obračun

- **`getPbWorkReports`** se ne poziva direktno iz taba — koristi **`ctx.getWorkReports()`** iz `index.js`.
- **`index.js`** je učitavao **celu godinu** (`first`–`last` te godine, `limit: 8000`).
- Obračun (**`runSum`**) koristi **`filterWorkReportsByPeriod(ctx.getWorkReports(), ...)`** — klijentski filter nad tim nizom.

## A5. `user_roles` vs pododeljenje

- **`has_edit_role()`** u `add_menadzment_full_edit_kadrovska.sql` vraća TRUE za globalne uloge **`admin`, `hr`, `menadzment`, `pm`, `leadpm`** — **nema** posebne vrednosti `pb_editor` u `user_roles`.
- **„Rukovodstvo inženjeringa“** je **`sub_departments.name`**, **ne** rola u `user_roles`.
- Za „vidi sve izveštaje“ PB4 eksplicitno uključuje **`leadpm`, `pm`, `menadzment`** (globalno u `user_roles`) + **admin** + **JOIN** na `sub_departments` za **`Rukovodstvo inženjeringa`**. **`hr` nije u specifikaciji** — ne dobija automatski pregled svih `pb_work_reports` (samo ako je admin ili jedna od tri uloge / rukovodstvo pododeljenja).

## Zaključak za migraciju

- **`pb_can_edit_tasks()`** ostaje za **`pb_tasks`**; za **`pb_work_reports`** INSERT za „običnog“ inženjera koristi se **`pb_can_edit_tasks() AND employee_id = pb_current_employee_id()`** (paritet: samo krug koji već sme da uređuje PB + sopstveni redovi).
- **INSERT za široku grupu:** `pb_current_user_can_see_all_reports()` može unositi za bilo kog zaposlenog (menadžment unosi tuđe sate).

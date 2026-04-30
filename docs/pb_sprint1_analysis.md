# PB Sprint 1 — analiza (pre implementacije)

## A1. `employees`

- **Kolone (šema / `add_kadrovska_module.sql`):** `id`, `full_name`, `position`, `department`, `phone`, `email`, `hire_date`, `is_active`, `note`, `created_at`, `updated_at` (+ eventualno proširenja iz kasnijih migracija u produkciji).
- **Filteri:** `department` i `position` postoje — pogodni za buduće filtere u UI.
- **RLS (`employees_select`):** `TO authenticated` sa `USING (true)` — **svi autentifikovani** mogu da čitaju sve redove (ne samo „sebe”). Insert/update/delete ide preko `has_edit_role()`.

## A2. `projects`

- **Kolone (`docs/SUPABASE_PUBLIC_SCHEMA.md` / `sql/schema.sql`):** `id`, `project_code`, `project_name`, `projectm`, `project_deadline`, `pm_email`, `leadpm_email`, `reminder_enabled`, `status`, timestamps.
- **Aktivan projekat:** u kodu (`src/services/projekti.js`, `loadProjektiLite`) aktivni su svi osim arhiviranih: `status=neq.archived`. U šemi baseline je `CHECK (status IN ('active','completed','archived'))` — vrednost **`archived`** označava neaktivan za dropdown; **`completed`** ostaje vidljiv dok god nije arhiviran.
- **RLS:** u migracijama u repou nema eksplicitnog `CREATE POLICY` za `projects`; u produkciji može postojati politika iz spoljašnjeg skupa — za PB servis koristimo isti REST obrazac kao ostali moduli.

## A3. `user_roles` i `has_edit_role`

- **Uloge u šemi / constraint-u:** vidi `user_roles_role_allowed` kroz migracije (`admin`, `leadpm`, `pm`, `menadzment`, `hr`, `magacioner`, `cnc_operater`, `viewer`, …) — tačan skup zavisi od primenjenih migracija.
- **`has_edit_role()`** (`add_menadzment_full_edit_kadrovska.sql`): vraća true za globalne `admin`, `hr`, `menadzment`, `pm`, `leadpm` (+ per-project pm/leadpm).
- **`pb_editor`:** u zahtevu je spomenuta posebna rola; **`user_roles` CHECK u živoj šemi ne dozvoljava proizvoljnu novu vrednost bez ALTER CONSTRAINT-a**, a zadatak eksplicitno zabranjuje menjanje tabele `user_roles`. Zato **RLS za PB koristi `current_user_is_admin() OR has_edit_role()`** za INSERT/UPDATE na `pb_*` (inzinjerski krug već pokriven PM/LeadPM/Menadžment/HR/admin). Ako se u PB2 uvede `pb_editor`, potrebna je odvojena migracija koja proširuje CHECK i eventualno `effectiveRoleFromMatches` u FE.

## A4. Uzorci migracija

- **`updated_at`:** trigger `BEFORE UPDATE` na funkciju `update_updated_at()` (kadrovska migracija).
- **Audit:** `audit_row_change()` iz `add_audit_log.sql`; trigger `trg_audit_<table>` AFTER INSERT|UPDATE|DELETE.
- **SECURITY DEFINER:** uvek `SET search_path = public, pg_temp` (vidi `fix_user_roles_rls_recursion.sql`, `has_edit_role`).

## A5. `src/ui/router.js`

- Moduli su **pathname rute** (`/plan-montaze`, `/kadrovska`, …), ne hash — `pathnameToRoute` + `pathForModule` u `src/lib/appPaths.js`.
- Lista dozvoljenih modula u `MODULES`; navigacija sa hub kartica poziva `navigateToModule(moduleId)`.

## A6. `src/state/auth.js`

- Postoje `canEdit()`, `isAdmin()`, role iz `user_roles`.
- **Dodata:** `canAccessProjektniBiro()` — svi ulogovani osim „viewer“ u smislu role snapshota (koristi se ista lista kao za širi read pristup drugim modulima: admin, leadpm, pm, menadzment, hr, cnc_operater, magacioner; viewer zadržan kao read-only blokiran).
- **Dodata:** `canEditProjektniBiro()` — `has_edit_role` paritet: `canEdit()` ∪ HR (`canEditKadrovska` krug).

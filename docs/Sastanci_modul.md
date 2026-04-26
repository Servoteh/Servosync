# Sastanci — dokumentacija

Modul **Sastanci** upravlja operativnim sastancima (sedmični / projektni), **PM temama** (predlog, odobravanje, dodela), **akcionim planom** i **zapisnicima** (Faza B proširuje zapisnik i presek). Tehnička šema: [SUPABASE_PUBLIC_SCHEMA.md](./SUPABASE_PUBLIC_SCHEMA.md), RLS: [RBAC_MATRIX.md](./RBAC_MATRIX.md), `sql/migrations/add_sastanci_module.sql`, `harden_sastanci_rls_phase2.sql`, templati: `sql/migrations/add_sastanci_templates.sql` (kada se primeni).

Kod: `src/ui/sastanci/`, `src/services/sastanci.js`, `sastanciTemplates.js`, `src/state/sastanci.js`, `src/styles/sastanci.css`, REST: `sbReq()`.

Stack: **Vite + vanilla JS** (nema React-a), isti obrasac kao [Plan_montaze_modul.md](./Plan_montaze_modul.md) / [Kadrovska_modul.md](./Kadrovska_modul.md) — `kadrovska-header`, tab strip, `canEdit()`.

---

## Uloga modula

| | |
|---|---|
| **Svrha** | Redovna operativa: sastanci, dnevni red (PM teme), akcije sa rokovima, arhiva zaključanih. |
| **Korisnici** | Svi ulogovani: `canAccessSastanci()`. Pisanje: `canEditSastanci()` (admin, leadpm, pm, menadžment) — u UI često kroz `canEdit()`; HR i viewer read-only. |
| **Ulaz** | [moduleHub.js](../src/ui/hub/moduleHub.js) — kartica „Sastanci”. Ruta: History API, modul u `src/ui/router.js`. |
| **Auth** | [src/state/auth.js](../src/state/auth.js) — `getCurrentUser()`, `canEdit()`, `canAccessSastanci()`, `canEditSastanci()`, `canPrioritizeTeme()` (samo admin za „za razmatranje” / admin_rang). |

---

## Tabovi i fajlovi

Aktivni tab je u [state/sastanci.js](../src/state/sastanci.js) (`activeTab`), **bez** sessionStorage (za razliku od Kadrovske); korisničke preferencie za list/kalendar: `sessionStorage` ključ `sastanci:sastanci_view` (vidi [constants.js](../src/lib/constants.js) `SESSION_KEYS.SAST_SASTANCI_VIEW`).

| Tab (UI) | `activeTab` | Fajl |
|----------|----------------|------|
| Pregled | `dashboard` | [dashboardTab.js](../src/ui/sastanci/dashboardTab.js) — KPI, 3 widgeta (sledeći sastanak, moje akcije, moje teme), sekcije ispod. |
| Sastanci | `sastanci` | [sastanciTab.js](../src/ui/sastanci/sastanciTab.js) + [sastanciCalendar.js](../src/ui/sastanci/sastanciCalendar.js) — lista / kalendar, templati ([templatesModal.js](../src/ui/sastanci/templatesModal.js)). |
| PM teme | `pm-teme` | [pmTemeTab.js](../src/ui/sastanci/pmTemeTab.js) — sub-tabovi; nakon CTA sa Pregleda: `SAST_INTENT_PM_MOJE`. |
| Po projektu | `pregled-projekti` | [pregledPoProjektuTab.js](../src/ui/sastanci/pregledPoProjektuTab.js) |
| Akcioni plan | `akcioni-plan` | [akcioniPlanTab.js](../src/ui/sastanci/akcioniPlanTab.js) — filter „Samo moje” + `SAST_INTENT_AKCIJONI_MOJE` |
| Arhiva | `arhiva` | [arhivaTab.js](../src/ui/sastanci/arhivaTab.js) |

**Zajednički UI:** [index.js](../src/ui/sastanci/index.js) — root + **FAB** [quickAddTemaButton.js](../src/ui/sastanci/quickAddTemaButton.js) (nova PM tema). Modali: [sastanakModal.js](../src/ui/sastanci/sastanakModal.js), [createSastanakModal.js](../src/ui/sastanci/createSastanakModal.js), [fazaBPlaceholder.js](../src/ui/sastanci/fazaBPlaceholder.js) (meso za Fazu B: pun detalj sastanka).

---

## Servisi

| Servis | Uloga |
|--------|--------|
| [sastanci.js](../src/services/sastanci.js) | Sastanci CRUD, učesnici, `loadDashboardStats`, `loadNextPlaniranSastanak`, `loadUcesniciForMany` |
| [sastanciTemplates.js](../src/services/sastanciTemplates.js) | Templati + `nextOccurrence`, `instantiateTemplate` |
| [pmTeme.js](../src/services/pmTeme.js) | `loadPmTeme` (uklj. `excludeStatuses`) |
| [akcioniPlan.js](../src/services/akcioniPlan.js) | `v_akcioni_plan`, filter po `odgovoranEmail` |
| [projekti.js](../src/services/projekti.js) | `loadProjektiLite` za selecte |

Status vrednosti `sastanci.status` (baza / UI): `planiran`, `u_toku`, `zavrsen`, `zakljucan` — vidi [sastanci.js SASTANAK_STATUSI](../src/services/sastanci.js).

---

## Baza (Faza 1, Supabase)

- Postojeće tabele: `sastanci`, `sastanak_ucesnici`, `pm_teme`, `akcioni_plan`, `presek_*`, `sastanak_arhiva` (bez izmene u F.A).
- Nove (posle migracije): `sastanci_templates`, `sastanci_template_ucesnici` — nacrt u [add_sastanci_templates.sql](../sql/migrations/add_sastanci_templates.sql).

---

## Stilovi

[sastanci.css](../src/styles/sastanci.css) — prefiks `sast-*` / Faza A: `sast-fab`, `sast-kpi-compact`, `sastanak-status-*`, kalendar, widgeti Pregleda.

---

## Hub

Kartica u [moduleHub.js](../src/ui/hub/moduleHub.js) vodi u modul preko `onModuleSelect('sastanci')`.

---

## Konvencije

- UI strings: srpski. JS: `camelCase`, baza: `snake_case`.
- Email kao identitet korisnika (paritet `user_roles`).

---

## Istorija razvoja

### F.A — Quick wins (2026-04-26)

- Pregled: prazan hero + 3 widgeta, kompaktan KPI red; „Vidi sve” prebacuje na PM teme / Akcioni plan sa namenskim filterom (session).
- Sastanci tab: prekidač Lista / Kalendar (`sastanci:sastanci_view`), status pill-ovi po stvarnim DB ključevima, placeholder modal za Fazu B, templatе (nakon SQL migracije).
- Servis + UI templata, FAB za brzu temu, dokumentacija, `add_sastanci_templates.sql` (ručno u Supabase).

**Predlog commit poruke (za vlasnika):**  
`feat(sastanci): Faza A — Pregled widgeti, kalendar, templatе, FAB, SQL nacrt za šablone`

---

## Deploy SQL

1. Pregledati i pokrenuti [sql/migrations/add_sastanci_templates.sql](../sql/migrations/add_sastanci_templates.sql) u Supabase SQL Editoru.
2. Proveriti da su `update_updated_at()` i `has_edit_role()` prisutni (ranije migracije).

# Sastanci modul — Faza A (analiza + plan implementacije)

**Datum:** 2026-04-26

**Napomena:** Dokument fiksira odluke pre implementacije. Status sastanka u UI i CSS prate **stvarne ključeve iz baze** (`planiran`, `u_toku`, `zavrsen`, `zakljucan`).

---

## 1. Trenutno stanje (šta postoji)

- **Pregled** je u [src/ui/sastanci/dashboardTab.js](src/ui/sastanci/dashboardTab.js) (nema `pregledTab.js`).
- **Tabovi:** Pregled (`dashboard`), Sastanci, PM teme, Po projektu, Akcioni plan, Arhiva — vidi [src/ui/sastanci/index.js](src/ui/sastanci/index.js).
- **Servisi:** [src/services/sastanci.js](src/services/sastanci.js), [akcioniPlan.js](src/services/akcioniPlan.js), [pmTeme.js](src/services/pmTeme.js).
- **State:** [src/state/sastanci.js](src/state/sastanci.js) — `activeTab` u memoriji, keš projekata.
- **Uloge:** [src/state/auth.js](src/state/auth.js) — `canEdit()`, `getCurrentUser()`, `canAccessSastanci()`.
- **Baza:** `sastanci.status` ∈ `planiran` | `u_toku` | `zavrsen` | `zakljucan` — vidi [sql/migrations/add_sastanci_module.sql](sql/migrations/add_sastanci_module.sql).
- **RLS:** [sql/migrations/harden_sastanci_rls_phase2.sql](sql/migrations/harden_sastanci_rls_phase2.sql), [docs/RBAC_MATRIX.md](docs/RBAC_MATRIX.md).

Pregled nije prazan u kodu, ali bez podataka u bazi KPI i liste su prazni — Faza A dodaje empty state CTA, tri akciona widgeta, kompaktni KPI red, kalendar, templatе, globalni quick-add teme.

---

## 2. Šta Faza A dodaje (A1–A4)

| Tačka | Sadržaj | Fajlovi |
|--------|---------|--------|
| A1 | Empty state, widgeti: sledeći sastanak / moje akcije / moje teme, compact KPI, postojeće tri sekcije | [dashboardTab.js](src/ui/sastanci/dashboardTab.js), prošireni servisi |
| A2 | Lista ⟷ kalendar, sessionStorage `sastanci:sastanci_view`, pill statusa po DB, akcije + placeholder Faza B | [sastanciTab.js](src/ui/sastanci/sastanciTab.js), [sastanciCalendar.js](src/ui/sastanci/sastanciCalendar.js) |
| A3 | Templat i modal, servis, seed predlog "Nedeljni PM" | [templatesModal.js](src/ui/sastanci/templatesModal.js), [sastanciTemplates.js](src/services/sastanciTemplates.js) |
| A4 | FAB + modal nove teme | [quickAddTemaButton.js](src/ui/sastanci/quickAddTemaButton.js), [index.js](src/ui/sastanci/index.js) |

---

## 3. Šema baze — `sastanci_templates`

- Tabela `sastanci_templates` (kolone po specifikaciji zadatka).
- Pomoćna `sastanci_template_ucesnici` (template_id, email, label), PK (template_id, email).
- RLS: SELECT `authenticated`, INSERT/UPDATE/DELETE `has_edit_role()`.
- `updated_at` preko postojećeg `update_updated_at()`.

Nacrt migracije: [sql/migrations/add_sastanci_templates.sql](sql/migrations/add_sastanci_templates.sql) (pokreće vlasnik ručno u Supabase).

---

## 4. Otvorene odluke (kompromis u implementaciji)

- **KPI red:** pet postojećih metrika iz `loadDashboardStats` u jednom kompaktnom redu (korisnički spec pominjao 4+1; praktično svih 5).
- **„Moje teme“ u widgetu:** isključeni statusi `zatvoreno` i `odbijeno` ( `odlozeno` tretirano kao aktivno ).

---

## 5. Tok nakon ove faze

1. Review SQL nacrta → primena u Supabase.
2. Redovan rad kroz A1–A4 u repou (Vite, bez novih npm paketa).

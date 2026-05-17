# Kadrovska / „Moj profil” — audit menadžerskog scope-a (bez izmena koda)

**Datum:** 2026-05-17  
**Izvor:** statička analiza repoa (fajlovi navedeni u zadatku + `RBAC_MATRIX.md` + relevantne migracije).

---

## 1. Trenutno stanje

### 1.1 Helperi u `src/state/auth.js` (pattern: `canManage*`, `canApprove*`, `canSubmit*`, `canAccessOdsustva*`, `getManaged*`)

| Funkcija | Namena (kratko) | Role / logika |
|----------|-----------------|---------------|
| `canManageUsers()` | Podešavanja / korisnici | `admin` |
| `canManageReversi()` | Reversi modul | `admin`, `menadzment`, `pm`, `leadpm`, `magacioner` |
| `canManageVacationRequests()` | Odobri/odbij GO zahteve (UI + servis) | `admin`, `hr`, `menadzment`, `leadpm`, `pm` |
| `canSubmitVacationRequestForOthers()` | „Podnesi za ime drugog” (Moj profil) | iste kao `canManageVacationRequests()` |
| `canAccessOdsustvaPregled()` | Tab **Odsustva** u Kadrovskoj | `admin`, `hr`, `leadpm`, `pm`, `menadzment` |
| `canEditOdsustva()` | Komentar: Listing read-only za menadžment | `admin`, `hr`, `leadpm`, `pm` (**bez** `menadzment`) |
| `getManagedDepartments()` | Scope odeljenja iz memorije | `state.managedDepartments ?? null` |
| `setManagedDepartments(depts)` | Postavlja niz ili `null` | — |

**Napomena:** `canEditOdsustva()` **nije referenciran** nigde drugde u `src/` (pretraga po importu / pozivu); tab Odsustva — Listing koristi `canEditKadrovska()` za dugmad/CRUD gate.

**Ostali pomoćni auth helperi relevantni za Kadrovsku (bez gore prefiksa):**

- `canAccessKadrovska()` — ulaz u modul: `admin` \| `hr` \| `menadzment`
- `canEditKadrovska()` — širok CRUD u Kadrovskoj (zaposleni, absences servis, …): `admin`, `leadpm`, `pm`, `hr`, `menadzment`
- `canEditKadrovskaGrid()` — mesečni grid: isti skup
- `canAccessSalary()` — Zarade: samo `admin`
- `canViewEmployeePii()` — JMBG, deca, … UI: samo `admin`
- `isHrOrAdmin()` — traka notifikacija (širi od PII): `admin`, `hr`, `menadzment`
- `canEdit()` — Plan montaže + **contracts/workHours servisi** (vidi divergenciju): `admin`, `leadpm`, `pm`, `menadzment` (**bez** `hr`)

### 1.2 Helperi u `src/services/` (isti patterni)

| Fajl | Šta koristi |
|------|-------------|
| `userRoles.js` | `setManagedDepartments`; SELECT `managed_departments` iz `user_roles` |
| `vacationRequests.js` | `canManageVacationRequests()` za PATCH statusa |
| `users.js` | `canManageUsers()` |
| `employees.js`, `vacation.js`, `absences.js` | `canEditKadrovska()` |
| `contracts.js`, `workHours.js` | `canEdit()` (ne `canEditKadrovska()`) |

### 1.3 Gde se koristi `managed_departments` / „managed” scope

| Lokacija | Ponašanje |
|----------|-----------|
| `src/services/userRoles.js` | Učitava `managed_departments` sa `user_roles`; `loadAndApplyUserRole()` postavlja **`setManagedDepartments(primary?.managed_departments ?? null)`** gde je `primary` prvi red čija je `role` = efektivna rola |
| `src/state/auth.js` | Dokumentacija: `NULL` = neograničen pristup |
| `src/ui/mojProfil/index.js` | Jedini **potrošač** `getManagedDepartments()` u UI: filtrira listu za picker zaposlenog pri „podnesi za drugog” — **`managedDepts.includes(e.department)`** (string na `employees.department` / view) |
| `sql/migrations/add_rbac_managed_departments.sql` | Kolona `user_roles.managed_departments TEXT[]`; funkcija `current_user_managed_departments()` — **nema** upotrebe u drugim migracijama u repou (pretraga po `current_user_managed_departments`) |

**Nema** front filtriranja liste zaposlenih u Kadrovskoj tabovima po `getManagedDepartments()` (grid, zaposleni, GO, zahtevi, …).

### 1.4 RLS sažeto (`docs/RBAC_MATRIX.md` + izvorne migracije)

| Tabela | SELECT | INSERT/UPDATE/DELETE |
|--------|--------|----------------------|
| `employees` | **USING(true)** | `has_edit_role()` |
| `absences` | **USING(true)** | `has_edit_role()` |
| `vacation_entitlements` | **USING(true)** | `has_edit_role()` |
| `work_hours` | **USING(true)** | `has_edit_role()` |
| `contracts` | **USING(true)** | `has_edit_role()` |
| `salary_terms` | `current_user_is_admin()` | admin |
| `salary_payroll` | `current_user_is_admin()` | admin |
| `kadr_notification_log` | `current_user_is_hr_or_admin()` | ista logika (HR/admin/menadžment po migraciji menadžment pun kadrovski edit) |
| `vacation_requests` | sopstveni zahtev **ILI** `current_user_can_manage_vacreq()` | UPDATE: `current_user_can_manage_vacreq()`; DELETE: `current_user_is_hr_or_admin()` |

**USING(true)** znači: bilo koji `authenticated` vidi sve redove na SELECT; ograničenje je uglavnom u `v_employees_safe` (maskiranje PII), ne u RLS row filteru za cele tabele.

`has_edit_role()` / `current_user_can_manage_vacreq()`: vidi `add_menadzment_full_edit_kadrovska.sql`, `add_kadr_vacation_requests.sql`.

---

## 2. „Moj profil” — modul, fajlovi, scope pravilo

| Fajl | Uloga |
|------|--------|
| `src/ui/mojProfil/index.js` | Glavni UI; učitavanje; **jedini filter po `getManagedDepartments()`** za picker |
| `src/state/auth.js` | `canAccessSelfService()` ⇒ bilo koji ulogovan korisnik |
| `src/ui/router.js` | Ruta `self-service` / `canAccessSelfService()` pre render-a |
| `src/lib/appPaths.js` | Mapiranje putanje (npr. `/moj-profil`) |
| `src/ui/hub/moduleHub.js` | Link „Moj profil” |
| `src/lib/constants.js` | `SESSION_KEYS` za sub-tabove Moj profil |
| `src/services/vacationRequests.js` | `loadMyVacationRequestsFromDb`, `saveVacationRequestToDb`, … |

**Scope pravilo (trenutno):**

- **Podaci o sebi:** employee preko `v_employees_safe?email=eq.<jwt email>`; odsustva filtrirana na `employee_id === myEmployee.id`; zahtevi: merge sopstvenih + `loadVacationRequestsForEmployeeFromDb(myEmployee.id)`.
- **„Podnesi za drugog”:** vidljivo ako `canSubmitVacationRequestForOthers()`; lista zaposlenih iz celog `v_employees_safe` (aktivni), zatim **opciono** `list.filter(e => managedDepts.includes(e.department))` ako je `getManagedDepartments()` ne-prazan niz.
- **Komentar u kodu** (`mojProfil/index.js` ~L14) kaže „leadpm/pm” i „svog odeljenja ili svačije”; **kod ne razlikuje** rolu — filter se primenjuje za sve sa nenull `managed_departments`, uključujući `menadzment`/`hr`/`admin` ako im je polje popunjeno.

Ključne linije scope-a picker-a:

```213:222:src/ui/mojProfil/index.js
    if (canSubmitForOthers && allEmpData) {
      const managedDepts = getManagedDepartments();
      let list = allEmpData.map(mapDbEmployee);
      /* leadpm/pm: filtrirati samo odeljenja kojima upravljaju */
      if (managedDepts && managedDepts.length > 0) {
        list = list.filter(e => managedDepts.includes(e.department));
      }
```

---

## 3. UI tačke u Kadrovskoj — lista zaposlenih / odsustva / zahtevi

| Tab | koji tabla / lista | očekivana rola (ulaz) | Filter na frontu | Filter na bazi (RLS) |
|-----|-------------------|------------------------|------------------|----------------------|
| **Zaposleni** | `employees` → `v_employees_safe` | `canAccessKadrovska()` | pretraga, odeljenje, status (`employeesTab.js`) | SELECT svi; PII maska u view-u |
| **Odsustva — Pregled** | agregat absences + work_hours + … | `canAccessOdsustvaPregled()` | period, klijent-side pivot (`odsustvaPregledTab.js`) | čitanje punih tabela za učesnike |
| **Odsustva — Listing** | `absences` | isti ulaz u modul | filteri; **CRUD gate:** `canEditKadrovska()` | SELECT all rows |
| **Zahtevi GO** | `vacation_requests` | tab vidljiv ako `canManageVacationRequests()` | status, godina, ime (`vacationRequestsTab.js`); **nema** dept filtera | menadžer vidi **sve** zahteve ako `current_user_can_manage_vacreq()` |
| **Mesečni grid** | zaposleni + `work_hours` | `canAccessKadrovska()` | pretraga, **filter po odeljenju u toolbaru** (opciono, user-driven, ne „managed scope”) | SELECT all `work_hours` |
| **Sati** | `work_hours` | isti | filter zaposlenog/meseca | SELECT all |
| **Ugovori** | `contracts` | isti | filteri | SELECT all |
| **Zarade** | `salary_*` | samo `canAccessSalary()` (admin) | — | admin-only |
| **Notifikacije** | `kadr_notification_*` | UI blok ako **ne** `isHrOrAdmin()` | — | `current_user_is_hr_or_admin()` |
| **Izveštaji** | više izvora | tab uvek u stripu; pod-tabovi sa vlastitim gate-ovima (`canViewEmployeePii`, `isAdmin`, …) | filteri | zavisi od tabela; zarada pod-tab admin |

**Tab „Zahtevi GO” i akcije**

- Vidljivost taba: `kadrVisibleTabDefs()` → `requestsOnly` ⇒ `canManageVacationRequests()` u `shared.js`.
- Background učitavanje pending badge: `index.js` ako `canManageVacationRequests()` — `loadAllVacationRequestsFromDb()`.
- Dugmad Odobri/Odbij/Obriši: `vacationRequestsTab.js` — `canManageVacationRequests()`; servis PATCH zahteva isto.

---

## 4. Tačke divergencije UI vs RLS / dokumentacija

1. **`managed_departments`:** koristi se **samo** u Moj profil picker-u; RLS **ne** filtrira po odeljenju; `current_user_managed_departments()` u SQL **nije** povezana sa politikama u repou.
2. **Menadžment i širina podataka:** `canManageVacationRequests()` i `vacation_requests` RLS dozvoljavaju menadžmentu **pregled i UPDATE svih** zahteva (bez department predicate). UI takođe učitava **sve** zahteve (`loadAllVacationRequestsFromDb`).
3. **`canEditOdsustva()` vs stvarni Listing:** helper isključuje `menadzment`, ali Listing koristi `canEditKadrovska()` koja **uključuje** `menadzment` — usklađeno sa `has_edit_role()` u bazi posle `add_menadzment_full_edit_kadrovska.sql`.
4. **`docs/Kadrovska_modul.md` tabela za menadžment** (samo grid + odsustva read-only) — **zastarelo** u odnosu na `canEditKadrovska()` + migraciju menadžment pun edit.
5. **SELECT USING(true)** na `employees`, `absences`, `vacation_entitlements`, `work_hours`, `contracts`: UI može sakriti, API i dalje vraća sve redove za autentifikovanog korisnika.
6. **HR vs `canEdit()`:** `contracts.js` / `workHours.js` koriste `canEdit()` koja **isključuje** `hr`, dok RLS za te tabele dozvoljava `hr` preko `has_edit_role()` — sužen frontend za HR u odnosu na bazu.

---

## 5. OPEN QUESTIONS

1. **`user_roles.user_id` vs `current_user_managed_departments()`**  
   Migracija `add_rbac_managed_departments.sql` filtrira `WHERE ur.user_id = auth.uid()`. U `sql/schema.sql` tabela `user_roles` ima `email`, bez `user_id`. Potrebna verifikacija na živoj bazi da li kolona postoji (dodata van repoa) ili je funkcija nekonzistentna.

2. **Šta tačno stoji u `managed_departments` — `employees.department` tekst ili `departments.id`?**  
   Moj profil poredi sa **`e.department`** (string). Ako se u budućnosti koristi isključivo `department_id` / kanonski naziv iz `departments`, potrebna normalizacija.

3. **Više redova `user_roles` po korisniku**  
   `loadAndApplyUserRole` uzima **`managed_departments` samo iz „primary” reda** (prvi match efektivne role). Ako treba unija scope-a ili poseban red po projektu — nije definisano.

### Moguća rešenja za department-scoped menadžment (usklađivanje)

| Opcija | Opis | Prednosti | Mane |
|--------|------|-----------|------|
| **A — RLS + SQL helperi** | Proširiti `USING` na SELECT/UPDATE sa `employee_department_in_managed_scope(employee_id)` baziran na `current_user_managed_departments()` ili JOIN na `employees.department_id` | Jaka garancija na API nivou | Više SQL posla; mora pokriti sve tabele koje cure preko relacija |
| **B — RPC / view-ovi** | Umesto direktnog REST čitanja, `SECURITY DEFINER` liste sa filterom | Jedan kontrolni sloj | Održavanje RPC-eva; frontend refaktor |
| **C — Hibrid** | RLS za kritične tabele (`vacation_requests`, `absences`, `work_hours`); UI filter kao UX | Postepeni rollout | Dva mesta pravila ako RLS nije kompletna |

---

## 6. Lista promena (plan) da menadžment radi po skupu odeljenja

### 6.1 Novi / prošireni helperi (predlog imena)

**JavaScript (`auth.js` ili poseban modul):**

- `getKadrovskaRowScope()` — vraća `{ mode: 'all' \| 'departments', departmentIds?: UUID[], departmentNames?: string[] }`
- `employeeInKadrovskaScope(emp)` — jedna funkcija za tabele/redove
- `canManageVacationRequestRow(req, empRow)` — odobijanje samo ako zaposleni u scope-u
- `canEditKadrovskaForEmployee(emp)` — sužavanje CRUD dugmadi (opciono zasebno od čitanja)

**SQL:**

- Ispraviti / zameniti `current_user_managed_departments()` da radi preko **email-a ili `auth.uid()`** konzistentno sa `user_roles`
- `vacreq_row_manageable()` — `current_user_can_manage_vacreq() AND (scope check)`
- `employee_in_managed_departments(e.department_id, e.department)` — jedan predikat za reuse u politikama

### 6.2 Tabele za zaštitu RLS-om (prioritet)

1. `vacation_requests` (SELECT/UPDATE) — danas menadžment vidi sve  
2. `employees` (SELECT bar za ne-admin; ili striktniji read preko view-a)  
3. `absences`, `work_hours`, `contracts` — ako cilj je „vidi samo svoj tim”  
4. `vacation_entitlements` — danas SELECT za sve  
5. `kadr_notification_log` — ako menadžment ne sme videti HR queue za druge odeljenje (poslovno pravilo)

### 6.3 Tabovi / akcije za UI filter (uz RLS)

- `vacationRequestsTab.js` — lista, badge count, odobri/odbij  
- `shared.js` / `employeeOptionsHtml` — opciono sužiti default opcije za menadžera  
- `gridTab.js` — default department filter prema scope-u  
- `vacationTab.js`, `reportsTab.js`, `employeesTab.js` — isti helper za listu  
- **Moj profil** — već ima filter; uskladiti sa istom konvencijom (id vs naziv)

### 6.4 Predlog imena kolone / podataka (ako se proširuje model)

- `user_roles.managed_department_ids UUID[]` — kanonski, FK logika ka `departments.id`  
- ili zadržati `managed_departments TEXT[]` ali dokumentovati da mora biti **identičan string** `employees.department` / `department_name`  
- `user_roles.managed_sub_department_ids UUID[]` — ako scope treba finije od odeljenja

---

*Kraj audit dokumenta.*

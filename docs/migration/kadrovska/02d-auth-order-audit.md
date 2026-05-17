# Audit: redosled role vs `managed_departments` u callback-ima

**Datum:** 2026-05-17  
**Cilj:** Mesta gde se **u istom callback-u / istom sinhronom toku** kombinuju čitanje **uloge** (`state.role`, `getCurrentRole()`, role-helperi) i **managed scope-a** (`getManagedDepartments()`, ili `canManageEmployee()` koji interno koristi oba).  
**Bez izmena koda** — samo inventar.

---

## 1. Izvor istine za redosled pri login-u / refresh-u uloge

| Fajl | Ponašanje |
|------|-----------|
| `src/services/userRoles.js` — `loadAndApplyUserRole()` | Prvo `setManagedDepartments(...)`, zatim `setRole(...)`. |
| `src/state/auth.js` — `setManagedDepartments` / `setRole` | `notify()` (pa `onAuthChange`) ide **samo** iz `setRole`, ne iz `setManagedDepartments`. Slušaoci vide već usklađen par managed + role posle jednog `setRole`. |

Posledica: kod koji u **jednom** `onAuthChange` pozivu čita i rolu i managed nije ražen između dva notify-a, pod uslovom da se scope uvek puni kroz `loadAndApplyUserRole` (ili ekvivalent: managed pre role).

---

## 2. `onAuthChange` pretplate u `src/` (grep)

| Lokacija | Callback | Da li koristi **i** rolu **i** managed? |
|----------|----------|----------------------------------------|
| `src/ui/kadrovska/index.js` | `canManageVacationRequests()` → `refreshVacReqBadge()` | **Da.** Rola u `canManageVacationRequests`; `refreshVacReqBadge` → `_itemsInScope` → `getManagedDepartments()` + `canManageEmployee()` (uloga + managed za `menadzment`). |
| `src/ui/planMontaze/index.js` | `_renderShell()` | **Ne** — header koristi `getAuth().role`; nema `getManagedDepartments` u tom lancu. |
| `src/ui/podesavanja/index.js` | `_renderShell()` | **Ne** — `canAccessPodesavanja` / header su na `role`; nema managed. |
| `src/ui/sastanci/sastanakDetalj/zapisnikTab.js` | `refreshSaveBar()` | **Ne** — samo `getIsOnline()`. |

**Pozivi `loadAndApplyUserRole`:** `src/main.js`, `src/ui/router.js` (login / reset), `src/ui/modulePlaceholder.js` (probe) — nakon `await` ne nastavljaju isti callback direktno sa mešavinom role+managed u UI (samo routovanje / hub).

---

## 3. `getManagedDepartments` u `src/` (sve reference)

| Fajl | Kontekst |
|------|----------|
| `src/state/auth.js` | Definicija; `canManageEmployee()` — **jedan** helper koji u sebi čita i `state.role` i `getManagedDepartments()`. |
| `src/ui/kadrovska/vacationRequestsTab.js` | `_itemsInScope`, `_renderRows`, prazna stanja (poruke po `managed`); akcije kroz `canManageEmployee`. U istom render ciklusu takođe `getCurrentRole()`, `canManageVacationRequests()`. |
| `src/ui/mojProfil/index.js` | `_loadAndRender` — posle `canSubmitVacationRequestForOthers()` (rola) filtrira listu zaposlenih preko `getManagedDepartments()`. **Nema** `onAuthChange` u ovom modulu. |

---

## 4. `getCurrentRole` u `src/ui/` (grep)

- `src/ui/kadrovska/vacationRequestsTab.js` — uz managed scope u `_renderRows` i `_deleteRequest`.
- `src/ui/planProizvodnje/poMasiniTab.js` — samo rola, **bez** `getManagedDepartments`.

---

## 5. Zaključak

**Uglavnom svuda OK za `onAuthChange`:** jedina pretplata koja u istom handleru spaja rolu i managed scope je **`src/ui/kadrovska/index.js`** (badge GO zahteva); ona je u skladu sa redosledom u `loadAndApplyUserRole` i jednim `notify` posle `setRole`.

**Dodatna mesta koja treba pratiti pri budućim izmenama (isti render / isti korisnički tok, ne nužno `onAuthChange`):**

1. **`src/ui/kadrovska/vacationRequestsTab.js`** — `_renderRows`, `refreshVacReqBadge` → `_itemsInScope` (eksplicitno meša rolu i managed kroz helperе).  
2. **`src/ui/mojProfil/index.js`** — `_loadAndRender` (rola preko `canSubmitVacationRequestForOthers`, zatim `getManagedDepartments`); ako se ikada doda pretplata na auth bez ponovnog učitavanja, proveriti isti invariant.

Nije identifikovano drugo `onAuthChange` mesto koje čita `getManagedDepartments`.

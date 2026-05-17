# Plan: prebacivanje „Katalog mašina" iz Održavanja u Podešavanja

> Cilj: katalog mašina (`maint_machines`) postaje **matični podatak** u
> [/podesavanja](../../src/ui/podesavanja/), pošto isti red opisuje i mašinu
> za Održavanje i lokaciju (Loc modul). Modul Održavanje zadržava read-only
> pristup operativnim listama (assets / machine detalj), ali više ne nosi
> ulogu autoritativnog uređivača kataloga.
>
> Iz konteksta razgovora: „nova mašina će biti i u Lokacijama. U Fazi 2
> možemo da napravimo trigger koji to radi automatski."

---

## 0. Status implementacije (2026-05-17)

| Faza | Status | Šta obuhvata |
|---|---|---|
| **Faza 1 — UI selidba** | ✅ live | Novi tab „🛠 Mašine" u /podesavanja, wrapper [masineTab.js](../../src/ui/podesavanja/masineTab.js), dual-entry (Podešavanja + zadržan `/maintenance/catalog`). |
| **Faza 2 — auto-sync trigger** | ✅ apply-ovan u Supabase | Migracija [add_loc_machine_sync_trigger.sql](../../sql/migrations/add_loc_machine_sync_trigger.sql) primenjena; insert nove mašine u katalogu → automatski red u `loc_locations`. |

Otvorene tačke vidi u sekciji [10. Otvoreno / sledeći koraci](#10-otvoreno--slede%C4%87i-koraci).

---

## 1. Zatečeno stanje (audit, 2026-05-17)

### 1.1 UI (Održavanje)
- [src/ui/odrzavanjeMasina/maintCatalogTab.js](../../src/ui/odrzavanjeMasina/maintCatalogTab.js) — 1311 LOC.
  Izvozi:
  - `renderMaintCatalogPanel(host, ctx, state)` — glavni panel (spreadsheet edit,
    filter, sort, sticky dirty bar, audit history).
  - `openMaintMachineModal({ mode, existing, onSaved })` — modal za add/edit
    pojedinačne mašine (koristi se i iz detalja mašine na
    [index.js:1859](../../src/ui/odrzavanjeMasina/index.js#L1859)).
  - `openMaintMachinesImportDialog({ onImported })` — bulk uvoz iz
    `bigtehn_machines_cache`.
  - `openMaintMachineDeleteDialog(opts)` — hard delete modal.
  - `openMaintMachineDocsDialog(opts)` — wrapper oko `renderMaintFilesTab`.
  - `canManageMaintCatalog(prof)` / `canHardDeleteMaintMachine(prof)` —
    **autorizacioni helperi koje koriste i sibling paneli** (vidi 1.3).

- Trenutno se mount-uje preko URL ruta:
  - `/maintenance/catalog` ([index.js:1017](../../src/ui/odrzavanjeMasina/index.js#L1017))
  - `/maintenance/machines` u admin grani ([index.js:1042](../../src/ui/odrzavanjeMasina/index.js#L1042)),
    gde admin/chief dobija edit-katalog, operator → read-only operativnu listu.

### 1.2 Servisi (data layer)
[src/services/maintenance.js](../../src/services/maintenance.js) već sadrži
sve potrebne RPC/REST wrappere; **ne treba ih ni preimenovati ni seliti**
(maintenance modul i dalje konzumira iste pozive). Relevantne funkcije:

| Funkcija | Linija | Svrha |
|---|---|---|
| `fetchMaintMachines(opts)` | [830](../../src/services/maintenance.js#L830) | list (sa filterom archived/tracked) |
| `insertMaintMachine(payload)` | [933](../../src/services/maintenance.js#L933) | add manual |
| `patchMaintMachine(code, patch)` | [971](../../src/services/maintenance.js#L971) | inline edit |
| `archiveMaintMachine` / `restoreMaintMachine` | 985–994 | soft delete |
| `fetchMaintMachinesImportable` | [1005](../../src/services/maintenance.js#L1005) | preview za import iz BigTehn-a |
| `importMaintMachinesFromCache(codes)` | [1147](../../src/services/maintenance.js#L1147) | bulk insert |
| `renameMaintMachine(old, new)` | [1128](../../src/services/maintenance.js#L1128) | atomski rename `machine_code` |
| `deleteMaintMachineHard(code, reason)` | [1033](../../src/services/maintenance.js#L1033) | hard delete + audit |

### 1.3 Cross-modul zavisnosti `canManageMaintCatalog`
Helper se uvozi iz `maintCatalogTab.js` na **6 mesta** unutar `src/ui/odrzavanjeMasina/`:
- `maintAssetsPanel.js` (linije 7, 60, 160)
- `maintVehiclesPanel.js` (13, 115, 223)
- `maintItAssetsPanel.js` (13, 105, 218)
- `maintFacilitiesPanel.js` (13, 126, 238)
- `maintLocationsTab.js` (15, 25)
- `maintSettingsPanel.js` (13, 115)
- `index.js` (459, 1020, 1045, 1456, 1557)

> **Implikacija:** ne smemo da uklonimo izvoz `canManageMaintCatalog` iz
> Održavanja, ili moramo da pravimo refaktor svih konzumenata. Plan ispod
> bira opciju **A: helper ostaje u Održavanju, UI panel se seli**.

### 1.4 Baza (postoji, ne dirati u ovoj fazi)
- [sql/migrations/add_maint_machines_catalog.sql](../../sql/migrations/add_maint_machines_catalog.sql) —
  tabela, RLS, view `v_maint_machines_importable`.
- [sql/migrations/add_loc_machine_locations_from_maint.sql](../../sql/migrations/add_loc_machine_locations_from_maint.sql) —
  trenutno **jednokratan seed** iz `maint_machines` u `loc_locations`.
  Faza 2 = ovaj seed pretvoriti u kontinuirani trigger.

### 1.5 RLS politika (već sinhronizovana sa ERP rolama)
- `maint_machines_insert/update/delete` USING:
  `maint_is_erp_admin() OR maint_profile_role() IN ('chief','admin')`
- `maint_machines_select` USING: `maint_has_floor_read_access()` (širok krug).
- Zaključak: **selidba UI-ja u /podesavanja ne traži promenu RLS-a** — ERP
  admin/menadžment već imaju write pristup. Ono što treba dodati u
  `canAccessPodesavanja()` je vidljivost taba i za maint-chief-ove, ako
  želimo da im ostavi pristup samom katalogu (vidi 2.3).

---

## 2. Ciljno stanje (Faza 1 — selidba UI-ja)

### 2.1 Novi tab u Podešavanjima
- Dodaje se stavka u sidebar grupi **„Podaci"** u
  [src/ui/podesavanja/index.js](../../src/ui/podesavanja/index.js#L58-L65),
  pre `maint-profiles`:
  ```
  { id: 'masine', icon: '🛠', label: 'Mašine', adminOnly: false }
  ```
  `adminOnly: false` jer maint-chief takođe treba da uređuje katalog.
  Stvarna granularnost ide kroz `canManageMaintCatalog(prof)` (vidi 2.3).

- `TAB_SUBTITLES.masine = 'Podaci'`.
- `_activeTab === 'masine'` u `renderPodesavanjaModule` i `_wireSidebar`
  poziva `refreshMaintMachines()` + re-render.

### 2.2 Novi fajl: `src/ui/podesavanja/masineTab.js`
- **Tanki wrapper** oko postojećeg `renderMaintCatalogPanel`. Ne dupliramo
  logiku — re-export i delegacija.
- Skelet:
  ```js
  // src/ui/podesavanja/masineTab.js
  import {
    renderMaintCatalogPanel,
    canManageMaintCatalog,
  } from '../odrzavanjeMasina/maintCatalogTab.js';
  import { fetchMaintUserProfile } from '../../services/maintenance.js';

  let _prof = null;

  export async function refreshMaintMachinesTab() {
    _prof = await fetchMaintUserProfile().catch(() => null);
    return _prof;
  }

  export function renderMasineTab() {
    return `
      <div class="set-page-header">
        <div class="set-page-header-icon">🛠</div>
        <div>
          <h2 class="set-page-header-title">Mašine</h2>
          <p class="set-page-header-sub">
            Katalog mašina (matični podatak). Dodavanje, izmena, arhiviranje,
            uvoz iz BigTehn-a. Mašine iz ovog kataloga se prikazuju i u
            Lokacijama i Održavanju.
          </p>
        </div>
      </div>
      <div id="setMasineHost"></div>
    `;
  }

  export function wireMasineTab(root, opts = {}) {
    const host = root.querySelector('#setMasineHost');
    if (!host) return;
    renderMaintCatalogPanel(host, {
      prof: _prof,
      onNavigateToPath: opts.onNavigateToPath,
    });
  }
  ```
- Razlog za wrapper: zadržavamo jednu istinu (`maintCatalogTab.js`), a u
  /podesavanja stavljamo **page header** koji jasno govori da je ovo
  matični podatak (drugačiji jezik od onoga što imamo u Održavanju).

### 2.3 Permission gate
- Trenutno [src/state/auth.js → canAccessPodesavanja()](../../src/state/auth.js)
  vraća `true` samo za `admin` ili `menadzment` ERP role. **Maint chief
  trenutno nema pristup /podesavanja modulu.**
- Dve opcije:
  - **A.** Proširiti `canAccessPodesavanja()` da pusti i korisnike za koje
    `canManageMaintCatalog(prof)` vraća true (tj. ima maint profil
    chief/admin). Ovo zahteva da `canAccessPodesavanja()` postane async ili
    da fetch-uje profil unapred → komplikovano.
  - **B.** *(preporuka)* Ostaviti `canAccessPodesavanja()` na admin/menadžment,
    a maint-chief-u **zadržati postojeću rutu** `/maintenance/catalog`
    kao mount za isti `renderMaintCatalogPanel`. Tako:
    - ERP admin/menadžment → /podesavanja → Mašine (matični podatak).
    - Maint chief → /odrzavanje → meni „Katalog" (operativni ulaz).
    - **Ista komponenta, dva ulaza** — niko ne gubi pristup.

> **Odluka u planu:** opcija **B**. Faza 1 ne menja
> `canAccessPodesavanja()`. Maint chief vidi katalog kao i do sada, kroz
> Održavanje. ERP admin dobija drugu (kanonsku) tačku ulaska iz
> Podešavanja.

### 2.4 Što se NE menja u Fazi 1
- `maintCatalogTab.js` ostaje gde je. **Ne premeštamo ga fizički** —
  brisalo bi 6 sibling importova i lomilo `openMaintMachineModal` poziv iz
  `index.js:1859`.
- `canManageMaintCatalog` ostaje exportovan iz `maintCatalogTab.js` (ostali
  paneli ga zovu nepromenjeno).
- URL `/maintenance/catalog` ostaje da radi (back-compat za bookmarks).
  U Održavanju se **link na katalog povlači iz menija** (ali ruta ostaje
  za maint-chief-a i deep-link).

### 2.5 Naslov / formulacija
U Podešavanjima tab se zove **„Mašine"**, ne „Katalog mašina" — u kontekstu
matičnih podataka kraći naziv je čitljiviji (uporedi sa „Korisnici",
„Organizacija", „Matični podaci"). Page header objašnjava da je to katalog.

---

## 3. Konkretni koraci implementacije (Faza 1)

Svaka tačka je atomska, može se odvojeno commitovati.

1. **Dodaj sidebar entry**
   [src/ui/podesavanja/index.js](../../src/ui/podesavanja/index.js):
   - SIDEBAR_GROUPS „Podaci" → ubaci `{ id: 'masine', icon: '🛠',
     label: 'Mašine', adminOnly: false }` ispred `maint-profiles`.
   - `TAB_SUBTITLES.masine = 'Podaci'`.
   - `_visibleTabs()`/`_wireSidebar` već iteriraju listu, ne traže izmenu.

2. **Kreiraj `src/ui/podesavanja/masineTab.js`** (vidi skelet u 2.2).

3. **Wire-uj tab** u `index.js` Podešavanja:
   - import `refreshMaintMachinesTab`, `renderMasineTab`, `wireMasineTab`.
   - U `_panelHtml`: `if (tab === 'masine') return renderMasineTab();`
   - U `_wireTabBody`: `if (_activeTab === 'masine') wireMasineTab(_mountEl, ...)`.
   - U `renderPodesavanjaModule` + `_wireSidebar`: granom za `masine`
     pozovi `refreshMaintMachinesTab().then(_renderShell)`.

4. **Skloni „Katalog" stavku iz menija Održavanja** (opciono u istom commit-u
   ili posebnom):
   - U [src/ui/odrzavanjeMasina/index.js](../../src/ui/odrzavanjeMasina/index.js)
     skloni dugmad „⚙ Katalog mašina →" ([linije 676 i 1496](../../src/ui/odrzavanjeMasina/index.js#L676))
     **samo za ERP admin/menadžment**, ali ih ostavi za maint chief
     (deep-link na `/maintenance/catalog` ostaje).
   - Subnav check na liniji 292 (`assets` grupa) ostaje — operator i dalje
     ide kroz `assetsMachines`.

5. **Smoke test (manual u browseru):**
   - ERP admin → /podesavanja → klik „Mašine" → vidi katalog, doda mašinu,
     edituje, arhivira.
   - Menadžment role → vidi tab (već ima `adminOnly: false`).
   - Maint chief → /odrzavanje → „Katalog" (ako je zadržan) i dalje radi.
   - Operator → nema novi tab (Podešavanja mu je zaključano).
   - Kratak deep-link: `/maintenance/catalog` u browseru → i dalje radi.

6. **Nije potrebno:** nikakva SQL migracija u Fazi 1. RLS već dozvoljava
   admin/menadžmentu, koji su jedini novi korisnici ovog UI-ja.

7. **Naknadni cleanup (može i kasnije):** preimenovati
   [maintCatalogTab.js](../../src/ui/odrzavanjeMasina/maintCatalogTab.js) →
   `masineKatalogPanel.js` i preseliti u
   `src/ui/shared/` ili `src/ui/masine/`, pa popraviti svih 6 sibling
   importova. To je čisto refactor, ne menja UX. **Ne radimo u Fazi 1.**

---

## 4. Faza 2 — automatsko prebacivanje u Lokacije (trigger) ✅ NAPISANO

> Status: migracija napisana, **čeka apply u Supabase SQL Editoru**.
> Fajl: [sql/migrations/add_loc_machine_sync_trigger.sql](../../sql/migrations/add_loc_machine_sync_trigger.sql)

Postojeća migracija [add_loc_machine_locations_from_maint.sql](../../sql/migrations/add_loc_machine_locations_from_maint.sql)
je **jednokratan seed**. Kada admin sada doda novu mašinu u katalogu, ona
ne ulazi u `loc_locations` automatski.

### 4.1 Šta tačno automatizovati
Pri INSERT/UPDATE na `maint_machines`:
- INSERT (active, `tracked=TRUE`, `archived_at IS NULL`) →
  insert reda u `loc_locations` (type=`MACHINE`, parent = M.* hala po
  istom CASE mapping-u kao u seed-u).
- UPDATE → ako se promenio `name` ili `archived_at`, ažurirati
  `loc_locations.name` (i eventualno `is_active = false` kad je
  arhivirana).
- DELETE → ne brišemo iz `loc_locations` automatski, jer su istorijske
  prijave rada vezane za lokaciju; eventualno set `is_active = false`.

### 4.2 Plan migracije Fazu 2 (skica)
Fajl: `sql/migrations/add_loc_machine_sync_trigger.sql`
- Funkcija `public.maint_machines_sync_to_loc()` — STATEMENT/ROW trigger
  AFTER INSERT OR UPDATE, koja izvršava upsert u `loc_locations` po
  `location_code = NEW.machine_code`.
- Trigger `trg_maint_machines_loc_sync` na `public.maint_machines`.
- Backfill `INSERT … SELECT … ON CONFLICT DO UPDATE` za sve aktivne
  mašine koje nisu već u `loc_locations` (idempotentno, isto kao seed).
- Edge case: dept_code mapping — izdvojiti CASE iz seed-a u
  `public.maint_machine_dept_code(rj_code TEXT) RETURNS TEXT` funkciju i
  zvati je i iz seed-a i iz trigger-a (single source of truth).
- DOWN: `DROP TRIGGER`, `DROP FUNCTION`.

### 4.3 UI implikacija Fazu 2
- U Podešavanjima → Mašine, dodati napomenu uz „+ Dodaj mašinu":
  „Mašina će automatski biti dostupna i u Lokacijama."
- Nije potrebno menjati frontend kod — trigger radi tiho na DB nivou.

### 4.4 Otvorena pitanja za Fazu 2 (rešiti pre kodiranja)
- **Šta sa rename?** `renameMaintMachine` već radi atomski rename
  `machine_code` u svim maint_* tabelama. Da li trigger treba da prati i
  `loc_locations.location_code` rename? Verovatno da, ali je rizik za
  reference iz `production`/`pracenje` tabela. **Predlog:** dokumentovati
  da rename ne menja `loc_locations` automatski; admin mora ručno.
- **Šta sa `M.OST` fallback-om?** Ako admin doda mašinu sa šifrom koja
  ne matchuje nijedan prefiks, ide u Ostalo. UI bi mogao da prikaže
  upozorenje, ali to je polish.
- **Manual mašine (KOMP-01, HVAC-2):** trenutni CASE mapping očekuje
  šifre tipa „2.3" / „6.5". Manual mašine padaju u `M.OST`. To je OK kao
  default; admin može kasnije premestiti u tačnu halu kroz Loc UI.

---

## 5. Rizici i kontra-mere

| Rizik | Verovatnoća | Kontra-mera |
|---|---|---|
| Lomimo `openMaintMachineModal` iz detalja mašine | Niska — Faza 1 ne dira fajl | Smoke test: detail mašine → ✎ Uredi |
| Maint chief gubi pristup katalogu | Srednja, mitigovano | Opcija B u 2.3 — ostavlja `/maintenance/catalog` rutu |
| 6 sibling importa `canManageMaintCatalog` puca | Visoka ako brišemo fajl | Faza 1 ne briše; refactor je odvojen task |
| Dva ulaza zbune korisnika | Srednja | Page header u Podešavanjima jasno govori „matični podatak"; meni u Održavanju zove „Katalog" (operativni jezik) |
| Faza 2 trigger pravi duplikate na rename | Niska | Trigger upsert po `location_code`; rename = manual proces |

---

## 6. Definicija „gotovo" za Fazu 1

- [ ] Sidebar u /podesavanja prikazuje stavku „Mašine" za admin/menadžment.
- [ ] Klik na nju otvara isti spreadsheet katalog (add / edit / archive / import).
- [ ] Postojeća ruta `/maintenance/catalog` i dalje radi (back-compat).
- [ ] Smoke test sva četiri role-a (admin / menadžment / maint chief / operator).
- [ ] Nema novih SQL migracija, nema RLS izmena.

## 7. Definicija „gotovo" za Fazu 2 (zasebno)

- [x] Migracija napisana: [add_loc_machine_sync_trigger.sql](../../sql/migrations/add_loc_machine_sync_trigger.sql)
- [x] `add_loc_machine_sync_trigger.sql` primenjen u Supabase (2026-05-17).
- [ ] Test: insert nove mašine u Podešavanjima → red automatski iskoči u
  `loc_locations` (proveriti u SQL Editoru). _— ostaje korisnički smoke test._
- [ ] Arhiviranje mašine → `loc_locations.is_active = false`. _— smoke test._
- [x] Backfill je idempotentan (ponovno pokretanje ne pravi duplikate).

### 7.1 Apply uputstvo

U Supabase SQL Editor (production projekat), kao postgres/service_role:

```sql
-- Kopiraj ceo sadržaj fajla i klikni Run.
-- sql/migrations/add_loc_machine_sync_trigger.sql
```

Očekivani NOTICE output na kraju:
```
add_loc_machine_sync_trigger OK: loc MACHINE=<N>, aktivne u maint=<N>, nedostaju u loc=0, bez parent=0.
```

### 7.2 Smoke test posle apply-a

1. **INSERT test (kroz UI):**
   - /podesavanja → Mašine → „+ Dodaj mašinu" → unesi `TEST-001`, naziv „Test mašina".
   - Sačuvaj.
   - U SQL Editoru: `SELECT * FROM loc_locations WHERE location_code = 'TEST-001';`
   - Mora postojati red sa `location_type = 'MACHINE'`, `parent_id = M.OST` (jer „TEST-001" ne matchuje nijedan CASE prefiks).

2. **UPDATE name test:**
   - U katalogu promeni naziv „Test mašina" → „Test mašina v2", sačuvaj.
   - Pokreni isti SELECT — `name` mora biti ažuriran.

3. **ARCHIVE test:**
   - Klikni „Arhiv." u redu TEST-001.
   - U SQL Editoru: `SELECT is_active FROM loc_locations WHERE location_code = 'TEST-001';` → mora biti `false`.

4. **RESTORE test:**
   - U Podešavanjima → Mašine → filter „Sve" → klikni „Vrati".
   - `is_active` mora biti `true` opet.

5. **Cleanup test mašine:**
   - U katalogu klikni „🗑 Obriši" (hard delete) — `maint_machines` red i `loc_locations` red ostaju RAZDVOJENI:
     `maint_machines` se briše, `loc_locations.TEST-001` red **ostaje** (po dizajnu, čuvamo placement istoriju).
   - Ručno obrisati `loc_locations` red ako nije potreban:
     `DELETE FROM loc_locations WHERE location_code = 'TEST-001';` (radi samo ako nema placement-a).

---

## 8. Šta je tačno promenjeno (po fajlovima)

### Faza 1 — UI selidba
| Fajl | Promena |
|---|---|
| [src/ui/podesavanja/masineTab.js](../../src/ui/podesavanja/masineTab.js) | **Nov fajl.** Tanki wrapper koji prikazuje `renderMaintCatalogPanel` ispod page header-a „🛠 Mašine". |
| [src/ui/podesavanja/index.js](../../src/ui/podesavanja/index.js) | Dodat import iz `./masineTab.js`. Stavka `{ id: 'masine', icon: '🛠', label: 'Mašine' }` u sidebar grupi „Podaci". Wire u `renderPodesavanjaModule`, `_panelHtml`, `_wireSidebar`, `_wireTabBody`. `TAB_SUBTITLES.masine = 'Podaci'`. |
| [src/ui/odrzavanjeMasina/maintCatalogTab.js](../../src/ui/odrzavanjeMasina/maintCatalogTab.js) | **Nije diran.** I dalje izvozi `canManageMaintCatalog` koji koriste 6 sibling panela. |
| [src/ui/odrzavanjeMasina/index.js](../../src/ui/odrzavanjeMasina/index.js) | **Nije diran.** Ruta `/maintenance/catalog` i dugmad „⚙ Katalog mašina →" ostavljeni za maint chief-a (deep-link i menu u Održavanju i dalje rade). |

### Faza 2 — auto-sync trigger
| Fajl | Promena |
|---|---|
| [sql/migrations/add_loc_machine_sync_trigger.sql](../../sql/migrations/add_loc_machine_sync_trigger.sql) | **Nova migracija.** Helper `maint_machine_dept_code(TEXT)` + trigger fn `maint_machines_sync_to_loc()` (`SECURITY DEFINER`) + AFTER INSERT/UPDATE trigger + idempotentan backfill. Primena: kopiran u Supabase SQL Editor, prošao bez greške posle popravke `ON CONFLICT` targeta. |

---

## 9. Šta nije išlo glatko (lessons learned)

### 9.1 `ON CONFLICT (location_code)` pada na produkciji
- **Simptom:** prva apply iteracija pucala je sa `42P10: there is no unique or exclusion constraint matching the ON CONFLICT specification`.
- **Uzrok:** `loc_locations` ima **dva moguća unique indeksa** zavisno od toga koje `add_loc_step*` migracije su primenjene — originalni case-sensitive `loc_locations_code_uq` iz [add_loc_module.sql](../../sql/migrations/add_loc_module.sql) i case-insensitive `lower(location_code)` iz `add_loc_step2_ci_unique.sql`. Targeted `ON CONFLICT (location_code)` zahteva tačno tu kolonu kao unique constraint i ne tolerira `lower()` varijantu.
- **Fix:** zameniti svih 3 `ON CONFLICT (location_code) DO NOTHING` → `ON CONFLICT DO NOTHING` (bez targeta). To je isti pristup koji koristi i postojeći seed [add_loc_machine_locations_from_maint.sql](../../sql/migrations/add_loc_machine_locations_from_maint.sql). Dodata je i napomena u header migracije da budući autori ne ponove istu grešku.
- **Pouka za budućnost:** uvek `ON CONFLICT DO NOTHING` bez targeta kad pišeš migraciju nad `loc_locations.location_code`, dok god ne konsoliduješ koje `loc_step*` koraci su deo svake produkcione baze.

### 9.2 RLS na `loc_locations` blokira maint chief-a
- **Problem:** `loc_locations_insert/update` politika zahteva `loc_can_manage_locations()` (admin/leadpm/pm). Maint chief koji doda mašinu kroz `/maintenance/catalog` nema nijednu od te tri uloge → trigger bi tiho pao.
- **Rešenje:** trigger funkcija deklarisana kao `SECURITY DEFINER` — bypass-uje RLS. `auth.uid()` ostaje korisnikov (čita se iz JWT claim-a, ne iz `current_user`), pa audit log u [add_loc_locations_audit.sql](../../sql/migrations/add_loc_locations_audit.sql) i dalje pravilno upisuje actor.

### 9.3 `canAccessPodesavanja()` ne pušta maint chief-a u Podešavanja
- **Stanje:** maint chief koji se loguje vidi „🔒 Pristup zabranjen" na /podesavanja. To je **dizajn-izbor opcija B** iz sekcije 2.3 — ima paralelni ulaz kroz `/maintenance/catalog`.
- **Korisnik je u razgovoru rekao** da je OK da i šef održavanja dobije pristup Podešavanjima, ali zadržali smo dual-entry kao najlakšu opciju da ne lomimo postojeću role-only logiku auth-a. Otvoreno za reviziju (sekcija 10.1).

---

## 10. Otvoreno / sledeći koraci

### 10.1 _(opciono)_ Pristup maint chief-a u /podesavanja
Trenutno maint chief ima pristup kroz `/maintenance/catalog`. Ako želiš čistiji UX (jedna kanonska tačka), proširi [src/state/auth.js → canAccessPodesavanja()](../../src/state/auth.js) da pusti i `chief`/`admin` iz `maint_user_profiles`. Komplikacija: trenutno je sinhrona funkcija; profil bi se morao fetch-ovati ranije ili napraviti async grana. **Predlog:** ostaviti kako jeste dok ne stigne stvarna pritužba korisnika.

### 10.2 _(opciono)_ Konsolidacija dept-code CASE-a u seed-u
Postojeći seed [add_loc_machine_locations_from_maint.sql](../../sql/migrations/add_loc_machine_locations_from_maint.sql) i dalje ima **inline CASE** umesto da zove novu helper funkciju `maint_machine_dept_code()`. Ako se mapping ikad menja, treba ažurirati i seed i helper. Trenutno ovo nije problem (seed je jednokratan; helper je live), ali za novi env primena bi išla: helper → seed → trigger (redosled). **Preporučeni cleanup:** prepisati seed da pozove helper, kao i bilo koji future seed. Ne urgentno.

### 10.3 _(potreban)_ Korisnički smoke test
Smoke procedura iz sekcije 7.2 nije prošla kroz UI — samo SQL strana je verifikovana (sanity NOTICE iz migracije). Pre nego što proglasimo Faza 2 100% gotovom, treba:
- INSERT test mašine kroz UI → proveriti da li je iskočila u Lokacijama.
- Arhiv/restore → `is_active` toggle.
- Cleanup test mašine.

### 10.4 _(strateški)_ Rename mašine ne sinhronizuje Lokacije
`renameMaintMachine` RPC menja `machine_code` u svim `maint_*` tabelama, ali **NE** menja `loc_locations.location_code`. Trenutno admin mora ručno. Razlog je to što `loc_locations.location_code` referenciraju i `production` / `pracenje` tabele preko placement-a. Treba odlučiti:
- _(a)_ Proširiti `renameMaintMachine` da menja i `loc_locations.location_code` u istoj transakciji + svuda gde se referencira.
- _(b)_ Ostaviti kako jeste i jasno označiti u UI-ju (pop-up: „Lokacija se ne menja automatski — promeni je ručno").
- _(c)_ Sakriti dugme „Preimenuj" iz Podešavanja → Mašine (jer je rizično za sync) i ostaviti ga samo u Održavanju.

Ovo nije blocker za Faza 1/2 ali jeste design decision koji vredi razrešiti pre nego što neko renamuje produkcionu mašinu.

### 10.5 _(nice-to-have)_ Refactor: izvući katalog iz Održavanja
Sada [maintCatalogTab.js](../../src/ui/odrzavanjeMasina/maintCatalogTab.js) živi u `src/ui/odrzavanjeMasina/` iako je matični podatak. Razlog: brisanje fajla bi lomilo 6 sibling importova (`canManageMaintCatalog`). Cleanup put:
1. Premestiti `maintCatalogTab.js` → `src/ui/shared/masineKatalogPanel.js`.
2. Premestiti `canManageMaintCatalog` u `src/state/auth.js` ili novi `src/lib/maintPermissions.js`.
3. Update svih 7+ konzumenata.

Nije urgentno; čisti refactor, ne menja UX.

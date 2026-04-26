# Planiranje proizvodnje — dokumentacija

**Jedan aktuelni dokument za modul u repou.**  
Izvor zahteva (korisnički predlog sprintova): **`PLAN_PROIZVODNJE_DORADE_v1.2.md`** (lokalni fajl van repoa; ovde je **stvarno stanje** nakon implementacije G1–G7).

Izvor u kodu: `src/ui/planProizvodnje/`, `src/services/planProizvodnje.js`, `src/state/auth.js`, stilovi `src/styles/planProizvodnje.css`.  
Baza: migracije u `sql/migrations/` (ispod je spisak). Bridge punjenje: repo **`servoteh-bridge`** i skripta `scripts/backfill-production-cache.js` (i paralelno `workers/loc-sync-mssql` u monorepu).

**Povezano (ljudi / sektor, ne modul):** ko u Kadrovskoj/obračunu spada u **HAP Fluid** — vidi `docs/reports/hap_fluid_sektor_referenca.md`. (U planu, „HAP” radni nalozi i dalje prate `add_production_active_work_orders.sql`, nezavisno od te liste.)

---

## Uloga modula

**Operativni plan šinskog obrade:** prikaz otvorenih operacija iz BigTehn cache-a (radni nalozi, stavke, mašine), filtrirano na **aktivne RN-ove** (MES lista + pravila u Supabase), lokalno **raspoređivanje po mašini** (prioritet), **status** (waiting / in_progress / blocked; `completed` i završetak u BigTehn-u), kolona **„Napomena”** (u bazi i dalje `shift_note`), **REASSIGN**, **skice** (Storage), **kooperacija** (poseban tab + auto-grupe + ručni flag). Podaci iz overlay tabela **ne idu nazad u BigTehn** — BigTehn ostaje izvor istine za RN/tehnologiju; ovde se vodi operativni prikaz i lokalne odluke.

---

## Pristup i uloge

| Funkcija | Pravilo |
|----------|---------|
| Ulaz u modul | `canAccessPlanProizvodnje()` — **admin, leadpm, pm, menadzment, hr, viewer** (svi ulogovani sa tim ulogama u `user_roles`) |
| **Pun edit** (drag-drop, status, napomena, REASSIGN, crteži, HITNO, pin, kooperacija ručno, CAM, itd.) | `canEditPlanProizvodnje()` — **admin, pm, menadzment** |
| Read-only u UI | **leadpm, hr, viewer** — badge „read-only”, servisi na write vraćaju `null` pre upita; RLS na serveru i dalje štiti |

**Baza:** RLS na `production_overlays`, `production_drawings` i bucket `production-drawings` koristi **`public.can_edit_plan_proizvodnje()`** — mora uključivati iste uloge kao UI. Migracija: `add_plan_proizvodnje_menadzment_edit.sql`.

**Napomena:** U `user_roles`, efektivna rola mora ispravno da uključi `menadzment` (`effectiveRoleFromMatches` u `src/services/userRoles.js`).

---

## Tabovi (UI)

Modul: `sessionStorage` / hub modul **`plan-proizvodnje`**, `src/ui/planProizvodnje/index.js`.

| Tab | Svrha | Glavni fajl |
|-----|--------|-------------|
| **Po mašini** | Tabovi po **odeljenju** → lista mašina ili lista operacija; tabela: drag-drop, status, napomena, RN filter, CAM, spremnost, HITNO, pin, bulk REASSIGN, kooperacija „→ Kooperacija”, Σ planirano vreme, DORADA/SKART badge + filter | `poMasiniTab.js` |
| **Zauzetost mašina** | Zbirno po mašini; RN filter; agregati (uklj. G2/G3/G4 gde postoji) | `zauzetostTab.js` |
| **Pregled svih** | Matrica mašina × dani; RN filter; badge-i | `pregledTab.js` |
| **Kooperacija** | Operacije sa `is_cooperation_effective` (auto RJ grupe iz `production_auto_cooperation_groups` + ručni `cooperation_status`); pretraga RN/crtež; akcije po izvoru (auto vs manual) | `kooperacijaTab.js` |

Pomoćni moduli: **`departments.js`**, **`drawingManager.js`**, **`techProcedureModal.js`**.

### Tabovi „Po mašini" (v2)

Tabovi su u **2 reda**. Detalj: `src/ui/planProizvodnje/departments.js`.

**Red 1**: Sve · Glodanje · Struganje · Brušenje · Erodiranje · Ažistiranje  
**Red 2**: Sečenje i savijanje · Bravarsko · Farbanje i površinska zaštita · CAM programiranje · Ostalo

(Grupisanje mašina po `rj_code` / eksplicitne liste u `departments.js` — vidi fajl za produženu tabelu.)

Drag-drop (`shift_sort_order`) samo u single-machine kontekstu.

---

## Filter aktivacije predmeta

Operacije za plan se čitaju iz **`public.v_production_operations_effective`**: to je `v_production_operations` (otvoreni RN-ovi, BigTehn linije, overlay) **dodatno** filtrirano na predmete koji su u `production.predmet_aktivacija` sa `je_aktivan = true` — isključeni predmeti **ne** ulaze u prikaz, čak i sa aktivnim RN-ovima. Upravljanje: **Podešavanja → Podeš. predmeta** (admin + menadžment). U **Praćenju** lista aktivnih predmeta (`get_aktivni_predmeti()`) koristi **isti** kriterijum: samo `je_aktivan` (nije presek sa MES listom).

## Servisni sloj (`planProizvodnje.js`)

- **Čitanje:** `loadMachines()`, `loadOperationsForMachine`, `loadOperationsForDept`, `loadAllOpenOperations`, `listForCooperation`, `listAutoCooperationGroups` — iz `v_production_operations_effective` (operativni planovi isključuju efektivnu kooperaciju; vidi filter aktivacije iznad).
- **Pisanje overlay-a:** `upsertOverlay()`, `reorderOverlays()`.
- **G2:** `setUrgent()`, `clearUrgent()`, `pinToTop()`, `unpin()`, `sortProductionOperations()`.
- **G3:** `setCamReady()` (i srodno u UI).
- **G5:** `reassignLine()`, `bulkReassignLines()` → RPC `reassign_production_line` / `bulk_reassign_production_lines` (nema direktnog client UPSERT-a za dodelu mašine).
- **G7:** `setCooperationManual()`, `clearCooperationManual()`, itd.
- **G4/G6 (podaci):** nisu „servis pozivi” sami po sebi — zavise od cache-a i backfill/bridge; vidi ispod.
- **Crteži:** Storage + `production_drawings`.

Lokalni statusi: `LOCAL_STATUSES`, `STATUS_CYCLE_NEXT`.

---

## Sprint G1–G7 — šta je urađeno (realno stanje u repou)

Spec v1.2 deli zahteve u **G1–G7**; **G8** (HITNO u QBigTehn) je **otkazan** — hitnost je samo lokalno (G2).

| Sprint | Obuhvat u v1.2 | Urađeno u repou | Napomene / odstupanja |
|--------|----------------|-----------------|------------------------|
| **G1** | „Napomena” (ne „šefova”), RN/crtež filter, Σ planirano vreme | **Da** | Filter klijentski, `localStorage` po tabu. Footer ne uključuje redove gde je operacija završena u BigTehn-u (logika kao u helperu). |
| **G2** | Spremnost, lokalno HITNO, dvonivoski sort (pin bije auto), Pin/Otpinuj | **Da** | Tabela `production_urgency_overrides`; view `v_production_operations` sa `is_ready_for_processing`, `previous_operation_status`, `is_urgent`, `auto_sort_bucket`. Spremnost: agregat `komada_done` iz tech routinga vs plan RN (prethodne operacije po `prioritet`). |
| **G3** | CAM kockica | **Da** | Kolone `cam_ready*` u `production_overlays` + view. |
| **G4** | Faza A analiza, faza B badge/filter | **Da** | Faza A: `docs/migration/g4-skart-analiza.md`. Faza B: **nije** heuristika po `opis_rada` — uvedena **`bigtehn_rework_scrap_cache`** (redovi iz `tTehPostupak` gde je `IDVrstaKvaliteta` 1/2), view proširen (`is_rework`, `is_scrap`, količine). Zahtev u v1.2 koji pominje `ftDodatiPostupke...` rešen je pouzdanim kvalitet signalom, ne TVF pozivom u app-u. |
| **G5** | Bulk REASSIGN, ista grupa, admin force + audit | **Da** | RPC + `production_reassign_audit`. **Force:** u dogovoru sa korisnikom dozvoljeni **`admin` i `menadzment`** (u nekim nacrtima tekstualno samo admin — u kodu je `can_force_plan_reassign()`). |
| **G6** | Auto `in_progress` kad operater prijavi komade | **Da**, drugačiji detalj od G6 bloka u v1.2 | U spec-u je ponekad nacrtan RPC nad **`part_movements`**. U implementaciji: **`mark_in_progress_from_tech_routing()`** koristi **`bigtehn_tech_routing_cache`** (prijava `komada > 0`, spoj na plan linije po `(work_order_id, operacija)`), jer je to isti signal prijave operatera u praksi. Poziva se iz **backfill** posle `tech` sync-a (`servoteh-bridge` / `workers/loc-sync-mssql` skripta). Nije korišćen trigger na cache tabelama. `blocked` se ne menja. |
| **G7** | Kooperacija: auto-grupe + manual + tab, izuzimanje iz operativnog plana | **Da** (faza A+B) | `production_auto_cooperation_groups` (seed + admin RLS), proširenje `production_overlays` (`cooperation_*`), view polja `is_cooperation_effective` itd. **Podešavanja → UI sekcija** za održavanje auto-grupa iz v1.2 **nije** obavezno urađena — grupe se mogu održavati kroz **Supabase Table Editor** / SQL dok se ne doda ekran. |

---

## Baza podataka (ključni objekti)

### Tabele (izbor; pun spisak u migracijama)

- **`production_active_work_orders`**, view **`v_active_bigtehn_work_orders`** — koji RN su „aktivni” za MES/Plan; `v_production_operations` gleda samo te RN-ove.
- **`production_overlays`** — `shift_sort_order`, `local_status`, `shift_note`, `assigned_machine_code`, `cam_ready*`, `cooperation_*`, arhiva kada RN završi.
- **`production_urgency_overrides`** — G2 HITNO po RN-u.
- **`production_reassign_audit`** — G5 force razlozi.
- **`production_auto_cooperation_groups`** — G7 auto RJ grupe.
- **`bigtehn_rework_scrap_cache`** — G4 signali DORADA/SKART (ne direktan deo v1.2 minimalnog opisa, ali potrebno da badge bude pouzdan).
- **`production_drawings`** — skice.

### View

- **`v_production_operations`** — višestruki rewrite kroz migracije; uključuje aktivne RN, tech routing agregate, G2, G3, G4, G7; wrapper **`v_production_operations_pre_g4`** ostaje ispod ako je G4 view sloj ugradio dodatne kolone — proveri trenutnu definiciju u poslednjoj `add_production_g4_rework_scrap_cache` migraciji. Koristiti **`security_invoker = true`** gde je traženo (security advisor).

### Funkcije (izbor)

- `can_edit_plan_proizvodnje()`, `reassign_production_line`, `bulk_reassign_production_lines`, `production_machine_group_slug`, `can_force_plan_reassign`
- `mark_in_progress_from_tech_routing` (G6) — `GRANT` tipično **service_role**; poziv iz bridge backfill klijenta.

### Redosled tipičnih migracija (informativno; tačan zavisi od grane)

```text
add_plan_proizvodnje.sql
add_v_production_operations.sql
add_plan_proizvodnje_menadzment_edit.sql
add_production_active_work_orders.sql + update_v_production_operations_active_work_orders.sql
add_production_overlays_cam_ready.sql
add_production_g2_readiness_urgency.sql
add_production_cooperation_g7.sql
add_production_g5_reassign_rpc.sql
add_production_g4_rework_scrap_cache.sql   # uključuje proširenje v_production_operations za G4
add_production_g6_auto_in_progress.sql
fix_supabase_security_advisor_findings.sql   # ako je primenjena — views/functions hardening
```

---

## Stilovi i putanje

- **`src/styles/planProizvodnje.css`**
- Deep link: **`/plan-proizvodnje`** → `appPaths.js`

---

## Lokalni storage (UX)

- `plan-proizvodnje:last-machine`, `plan-proizvodnje:last-department`
- RN filter: `plan-proizvodnje:filter-rn:po-masini` (i slični za druge tabove)
- G2 filter dorade/skart: `plan-proizvodnje:filter-rework:po-masini` (kada je uključeno u UI)

---

## Bridge i ručni backfill

- Stalan sync: repozitorijum **`servoteh-bridge`** (Node scheduler, production svakih 15 min, itd.).
- Puno punjenje / nadoknada cache-a: `scripts/backfill-production-cache.js` — tabele uključuju **`rework-scrap`** (G4) i nakon **`tech`** poziv **`mark_in_progress_from_tech_routing`** (G6). Na VM-u bez git-a: kopirati ažuriran `backfill-production-cache.js` i pokretati `node scripts/...` (vidi `servoteh-bridge` README).

---

## Hub

`moduleHub.js` — kartica „Planiranje proizvodnje”.

---

## Konvencije

- Upisi u overlay i G2/G7 proveravaju **`canEditPlanProizvodnje()`** gde je primenjivo; REASSIGN i force idu kroz **RPC** na serveru.
- Uloge iz **`user_roles`**, ne iz JWT `app_metadata` za autorizaciju pisanja.

---

## Istorija razvoja (F.x + G sprintovi)

- **F.1–F.5** — osnovna šema, tabovi, skice, refactor odeljenja (vidi starije commit poruke i `index.js` ako postoji zastareo checklist).
- **G1** — UX: Napomena, filter RN, footer suma.
- **G2** — spremnost, lokalno HITNO, sort + pin.
- **G3** — CAM.
- **G4** — analiza + cache `bigtehn_rework_scrap_cache` + view + badge/filter.
- **G5** — bulk + guarded REASSIGN + force + audit.
- **G6** — auto in_progress preko tech routing + backfill/bridge.
- **G7** — kooperacija (lookup + overlay + tab).
- **G8** — nije implementiran (otkazano u v1.2).

**Napomena o zastarelom tekstu:** zaglavlje ili komentar u `index.js` može pominjati stari checklist — **ovaj fajl** je mera trenutnog obima modula.

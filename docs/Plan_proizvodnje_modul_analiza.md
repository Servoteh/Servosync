# Modul PLANIRANJE PROIZVODNJE — analiza za AI agenta (Claude / ChatGPT)

> Cilj ovog dokumenta: dati narednom AI agentu **kompletnu, samosadržajnu sliku modula** `src/ui/planProizvodnje/*` + `production_*` tabela + bridge dependency-ja, sa **kritičnim tačkama** koje moraju biti razmatrane pre svake izmene. Optimizovano za chat-context dump.
>
> Stack: vanilla JS (ES modules, bez frameworka), Supabase (PostgreSQL + PostgREST), SECURITY DEFINER RPC-i, view-ovi sa `security_invoker = true`. Bridge punjenje cache-a iz MSSQL-a (BigTehn) ide kroz `servoteh-bridge` Node scheduler (15 min) + ručni `workers/loc-sync-mssql/scripts/backfill-production-cache.js`.
>
> Autoritativan opis trenutnog stanja modula: [docs/Planiranje_proizvodnje_modul.md](Planiranje_proizvodnje_modul.md). Ovaj fajl je **reliability/security audit**, ne arhitekturalna referenca.

---

## 1. Brzi mentalni model

**Operativni plan šinske obrade.** Modul ne piše nazad u BigTehn (MSSQL je izvor istine za RN/tehnologiju). Sve „operativne odluke šefa smene" žive u **overlay tabelama** koje stoje pored BigTehn cache-a:

- `bigtehn_*_cache` (read-only, Bridge sync) = stvarno stanje iz proizvodnje (RN, linije TP-a, prijave operatera, dorada/skart).
- `production_overlays` + `production_urgency_overrides` + `production_auto_cooperation_groups` + `production_drawings` = lokalni sloj odluka (redosled, status, napomena, HITNO, CAM, kooperacija, skice).
- `v_production_operations` (i `_pre_g4`, `_effective`) = **denormalizovan join** svih ovih izvora; UI čita samo iz view-ova.

**Centralna invarijanta:** RN → linija TP (`bigtehn_work_order_lines_cache.id`) → operacija (`l.operacija`, redni broj u TP-u). Pun ključ overlay-a je `(work_order_id, line_id)` — jedan overlay po liniji RN-a.

**Spremnost crteža za mašinski red** (PP-A, kanon od 2026-05-15):
```
is_ready_for_machine = NOT EXISTS (
  bigtehn_tech_routing_cache WHERE work_order_id = tekuće
    AND operacija < tekuće.operacija
    AND is_completed = FALSE
)
```
Prva operacija u TP-u → uvek `TRUE`. Polje `is_ready_for_processing` postoji kao back-compat alias sa istom vrednošću. PP-A je tek mergovan; **stara G2 logika (`prev_block` po `prioritet`-u) je zamenjena** — proveri da je SQL migracija `fix_v_production_operations_ready.sql` izvršena u Supabase Studio pre nego što tumačiš ponašanje view-a.

**Sve write operacije** prolaze kroz RLS gate `public.can_edit_plan_proizvodnje()` (admin/pm/menadzment) ili kroz `SECURITY DEFINER` RPC-i koji rade dodatni `auth.uid()` + role check u telu. Read je otvoren za sve `authenticated` (`anon` je explicit REVOKE-ovan).

---

## 2. Mapa fajlova

### Frontend
| Fajl | Linije | Odgovornost |
|---|---:|---|
| [src/ui/planProizvodnje/index.js](../src/ui/planProizvodnje/index.js) | ~210 | Shell modula, 4 taba (Po mašini, Zauzetost, Pregled svih, Kooperacija), auth header, tab routing, sessionStorage za poslednji tab. |
| [src/ui/planProizvodnje/poMasiniTab.js](../src/ui/planProizvodnje/poMasiniTab.js) | ~1954 | **Najveći fajl modula.** Dept tabovi (Glodanje, Struganje, …), drill-down mašina, drag-drop reorder (`shift_sort_order`), status cycle, napomena, REASSIGN (single + bulk), CAM, pin, HITNO, skice, TP modal, „Zašto ovde?", paginacija po RN (100/strana). |
| [src/ui/planProizvodnje/zauzetostTab.js](../src/ui/planProizvodnje/zauzetostTab.js) | ~440 | Zbirno po mašini: count otvoreno/crteža/spremno/HITNO/CAM/reassigned + rok matrica; klik na red → jump u Po mašini. |
| [src/ui/planProizvodnje/pregledTab.js](../src/ui/planProizvodnje/pregledTab.js) | ~360 | Matrica mašine × 5 radnih dana sa brojem operacija po roku; RN filter. |
| [src/ui/planProizvodnje/kooperacijaTab.js](../src/ui/planProizvodnje/kooperacijaTab.js) | ~250 | Lista operacija sa `is_cooperation_effective = TRUE` (auto RJ grupe + manual overlay). Auto vs manual izvor, akcije: označi vraćeno, otkaži manual. |
| [src/ui/planProizvodnje/departments.js](../src/ui/planProizvodnje/departments.js) | ~200 | 11 odeljenja (2 reda chip-ova) → mapping `machinePrefixes`, `machineCodes`, `operationNamePatterns`. Helper `findDeptForMachineCode()`. |
| [src/ui/planProizvodnje/drawingManager.js](../src/ui/planProizvodnje/drawingManager.js) | ~350 | Modal za skice: upload (file + drag-drop), soft-delete, thumbnail signed URL, MIME/size validacija. |
| [src/ui/planProizvodnje/techProcedureModal.js](../src/ui/planProizvodnje/techProcedureModal.js) | ~450 | Read-only modal: kompletan TP za RN, sve prijave iz tech routing cache, PDF crteža iz Storage-a (signed URL u blob URL za iframe). |
| [src/ui/planProizvodnje/whyBottleneckModal.js](../src/ui/planProizvodnje/whyBottleneckModal.js) | ~300 | Read-only modal „Zašto ovde?" — interpretira `auto_sort_bucket`, `previous_operation_*`, `is_ready_for_machine`, `is_urgent`. |
| [src/services/planProizvodnje.js](../src/services/planProizvodnje.js) | ~1510 | PostgREST/RPC sloj — `loadMachines`, `loadOperationsForMachine` (RPC `plan_pp_open_ops_for_machine`), `loadAllOpenOperations` (limit 10K), `loadOperationsForDept` (limit 5K), `upsertOverlay`, `reorderOverlays`, `setCamReady`, `setUrgent`, `pinToTop`, `reassignLine` / `bulkReassignLines` (RPC), `uploadDrawing`, `loadFullTechProcedure`. Helper-i: `sortProductionOperations`, `summarizeByMachine`, `buildDeadlineMatrix`. |
| [src/state/auth.js](../src/state/auth.js) | ~346 | `canAccessPlanProizvodnje()`, `canEditPlanProizvodnje()`, `getIsOnline()`. |
| [src/styles/planProizvodnje.css](../src/styles/planProizvodnje.css) | — | Sav modul. |

### Migracije (redom — informativno; tačan zavisi od grane)

1. [add_plan_proizvodnje.sql](../sql/migrations/add_plan_proizvodnje.sql) — `production_overlays`, `production_drawings`, view v1, Storage bucket, RLS + `can_edit_plan_proizvodnje()`.
2. [add_plan_proizvodnje_menadzment_edit.sql](../sql/migrations/add_plan_proizvodnje_menadzment_edit.sql) — proširuje gate sa `menadzment`.
3. [add_v_production_operations.sql](../sql/migrations/add_v_production_operations.sql) — rani view bez aktivnih RN filtera.
4. [revoke_anon_v_production_operations.sql](../sql/migrations/revoke_anon_v_production_operations.sql) — security fix: REVOKE SELECT FROM anon.
5. [add_production_active_work_orders.sql](../sql/migrations/add_production_active_work_orders.sql) + [update_v_production_operations_active_work_orders.sql](../sql/migrations/update_v_production_operations_active_work_orders.sql) — MES filter; view sada gleda samo aktivne RN.
6. [add_production_overlays_cam_ready.sql](../sql/migrations/add_production_overlays_cam_ready.sql) — G3.
7. [add_production_g2_readiness_urgency.sql](../sql/migrations/add_production_g2_readiness_urgency.sql) — G2: `production_urgency_overrides`, `is_urgent`, `auto_sort_bucket` (1–8).
8. [add_production_cooperation_g7.sql](../sql/migrations/add_production_cooperation_g7.sql) — G7: `production_auto_cooperation_groups`, `cooperation_*` kolone u overlay-u.
9. [add_production_g5_reassign_rpc.sql](../sql/migrations/add_production_g5_reassign_rpc.sql) — G5: `reassign_production_line`, `bulk_reassign_production_lines`, `production_machine_group_slug`, `can_force_plan_reassign` + audit tabela.
10. [add_production_g4_rework_scrap_cache.sql](../sql/migrations/add_production_g4_rework_scrap_cache.sql) — G4: `bigtehn_rework_scrap_cache` + rename view u `v_production_operations_pre_g4`.
11. [add_production_g6_auto_in_progress.sql](../sql/migrations/add_production_g6_auto_in_progress.sql) — G6: `mark_in_progress_from_tech_routing()` (GRANT service_role).
12. [supabase/migrations/20260506120000__plan_hide_rn_after_final_qc.sql](../supabase/migrations/20260506120000__plan_hide_rn_after_final_qc.sql) + [20260507100000__plan_final_qc_hide_fix_double_sum.sql](../supabase/migrations/20260507100000__plan_final_qc_hide_fix_double_sum.sql) — 8.3: sakrij RN posle završne kontrole (KK ≥ količina, ≤ 1.5×).
13. [supabase/migrations/20260506120000__plan_pp_open_ops_machine_wo_pagination.sql](../supabase/migrations/20260506120000__plan_pp_open_ops_machine_wo_pagination.sql) — RPC paginacija po RN (100/strana, hard cap 250).
14. [fix_v_production_operations_ready.sql](../sql/migrations/fix_v_production_operations_ready.sql) — **PP-A (2026-05-15)**: strict readiness po TP `operacija` + cache. DROP/CREATE CASCADE svih view-ova + ponovna definicija `plan_pp_open_ops_for_machine`.

### External / bridge

- [workers/loc-sync-mssql/scripts/backfill-production-cache.js](../workers/loc-sync-mssql/scripts/backfill-production-cache.js) — Node skripta, čita iz MSSQL-a, upsertuje u `bigtehn_*_cache`, posle `tech` sync-a zove `rpc/mark_in_progress_from_tech_routing` sa SERVICE_ROLE_KEY.
- `servoteh-bridge` (poseban repo) — production scheduler, 15 min interval.

---

## 3. Šema baze — invarijante koje MORAJU da drže

```
production_overlays
  PK: id BIGSERIAL
  UNIQUE: (work_order_id, line_id)
  CHECK: local_status ∈ {waiting, in_progress, blocked, completed}
  CHECK: cooperation_status enum
  NEMA FK ka cache tabelama (jer se cache briše-i-puni)
  Soft archive: archived_at, archived_reason

production_drawings
  PK: id BIGSERIAL
  UNIQUE: storage_path
  Logički FK: (work_order_id, line_id) → ali bez DB constraint-a
  Soft delete: deleted_at, deleted_by

production_active_work_orders
  PK: work_order_id BIGINT (logički FK na bigtehn_work_orders_cache.id, bez constraint-a)
  Nema soft delete — istorija je u updated_at + reason

production_urgency_overrides
  PK: work_order_id (jedan red po RN)
  Soft archive: cleared_at, cleared_by
  RLS DELETE policy: USING (false) — write-only soft archive

production_reassign_audit
  PK: id BIGSERIAL
  Append-only — INSERT samo iz SECURITY DEFINER RPC
  RLS: SELECT samo za can_force_plan_reassign() korisnike
  ⚠ NEMA explicit REVOKE INSERT/UPDATE/DELETE FROM authenticated — RLS WITH CHECK(false) ali nije pattern

production_auto_cooperation_groups
  PK: rj_group_code TEXT
  Soft delete: removed_at, removed_by
  RLS: write samo za current_user_is_admin()

bigtehn_rework_scrap_cache
  PK: id BIGINT (preslikano iz BigTehn-a)
  CHECK: quality_type_id ∈ {1=DORADA, 2=SKART}
  RLS: SELECT za sve authenticated; nikakav write iz klijenta
```

### View

- **`v_production_operations`** — `security_invoker = true`, GRANT authenticated, REVOKE anon. Denormalizuje ~80 kolona iz 6+ tabela. Wrapper za `_pre_g4` + G4 agregat + `plan_rn_final_control_done`.
- **`v_production_operations_pre_g4`** — sve OSIM G4 agregata. PP-A je ovde dodao `is_ready_for_machine` + zadržao `is_ready_for_processing` kao identičnu vrednost.
- **`v_production_operations_effective`** — `v_production_operations` + `EXISTS production.predmet_aktivacija` (je_aktivan=TRUE) + `NOT plan_rn_final_control_done`.
- **`v_active_bigtehn_work_orders`** — `bigtehn_work_orders_cache` + `is_mes_active` flag iz `production_active_work_orders`.

Svi `security_invoker = true` — RLS se evaluira pod prikazivačem, ne pod ownerom view-a. ✅ Ispravan obrazac.

### RPC sažeto

| RPC | Sec | search_path | GRANT | Šta radi |
|---|---|---|---|---|
| `can_edit_plan_proizvodnje()` | DEFINER | `public` | authenticated | Boolean — pita `user_roles` za admin/pm/menadzment |
| `can_force_plan_reassign()` | DEFINER | `public` | authenticated | Boolean — admin/menadzment |
| `production_machine_group_slug(rj_code)` | IMMUTABLE | `public` | authenticated | Mapira RJ → slug (glodanje/struganje/…) |
| `reassign_production_line(...)` | **DEFINER** | `public, auth, pg_temp` | authenticated | Single REASSIGN. Validira gate + group match, force traži audit reason + admin/menadzment. UPSERT overlay + audit INSERT. |
| `bulk_reassign_production_lines(...)` | **DEFINER** | `public, auth, pg_temp` | authenticated | Petlja kroz JSONB array, zove `reassign_production_line` per stavku. |
| `mark_in_progress_from_tech_routing()` | **DEFINER** | `public, auth, pg_temp` | **service_role only** | Bridge: waiting → in_progress kad `komada > 0` u prijavi. Zove se iz backfill skripte. |
| `plan_pp_open_ops_for_machine(machine, limit, offset)` | INVOKER | `public` | authenticated | Paginacija po RN za Po mašini tab. Statement timeout 180s. |

### RLS sažeto

- `production_overlays`, `production_drawings`, `production_active_work_orders`: SELECT za sve authenticated; INSERT/UPDATE/DELETE pod `can_edit_plan_proizvodnje()`.
- `production_urgency_overrides`: SELECT/INSERT/UPDATE pod gate; **DELETE USING(false)** — koristi se soft archive (`cleared_at`).
- `production_reassign_audit`: SELECT samo za force-users; write blokiran kroz RLS.
- `production_auto_cooperation_groups`: SELECT za sve; write pod `current_user_is_admin()` (definisana van PP migracija — **proveri da postoji pre apply-a**).
- Storage bucket `production-drawings`: SELECT authenticated; INSERT/UPDATE/DELETE pod `can_edit_plan_proizvodnje()`.

---

## 4. KRITIČNE TAČKE — gledati pre svake izmene

Oznake: **H** = high (krši invariantu, gubi podatke, security gap), **M** = medium (UX problem, race u retkim slučajevima, performance), **L** = low (kozmetika, dokumentacija).

### 4.1 Concurrency / race conditions (DB)

**[H1] G5 RPC nema idempotency ključ.**
`reassign_production_line()` i `bulk_reassign_production_lines()` rade UPSERT u `production_overlays` i INSERT u `production_reassign_audit`. Ako klijent retry-uje (timeout, network drop, korisnik klikne dvaput), server primi DVA poziva — drugi izmeni `assigned_machine_code` ponovo na istu vrednost (idempotentno za state) ALI **audit log dobija duplikat reda sa force_reason-om**. Operativno: audit izvještaj prikazuje dva force-a za jedan stvarni event.
**Mitigation:** klijent generiše `client_event_uuid` (UUID v4) pre RPC-a; RPC prima `p_client_event_uuid uuid` parametar; `production_reassign_audit` dobija `UNIQUE (client_event_uuid)`; INSERT u audit je `ON CONFLICT DO NOTHING`.

**[H2] Optimistic drag-drop reorder bez OCC.**
[poMasiniTab.js:1858-1900](../src/ui/planProizvodnje/poMasiniTab.js#L1858) — `reorderOverlays()` šalje ceo niz `(work_order_id, line_id)` sa novim `shift_sort_order`. Ako dva šefa istovremeno reorder-uju različite operacije na istoj mašini, **drugi će prepisati prvog** bez ikakvog upozorenja. `production_overlays` nema `version`/`updated_at` OCC kolonu koja se koristi.
**Mitigation:** klijent šalje `expected_updated_at` po stavci; server poredi i odbija sa `409 Conflict` ako se razlikuje; UI prikazuje „Drugi korisnik je promenio raspored — osveži i pokušaj ponovo".

**[M3] G6 idempotency u bridge backfill-u.**
[add_production_g6_auto_in_progress.sql](../sql/migrations/add_production_g6_auto_in_progress.sql) — RPC se zove iz [backfill-production-cache.js](../workers/loc-sync-mssql/scripts/backfill-production-cache.js) **posle svakog tech sync-a**. RPC je idempotentan po definiciji (UPDATE `waiting → in_progress` i INSERT novih sa `ON CONFLICT DO NOTHING` — proveri da li je obrazac stvarno tako napisan). Ako jeste, OK. Ako nije, dupli pozivi mogu da prepišu `updated_by` na svaki batch.
**Verifikacija:** ručno pregledaj telo `mark_in_progress_from_tech_routing()` — da li `INSERT ... ON CONFLICT` postoji ili `IF NOT EXISTS` guard? Ako ne, dodaj `ON CONFLICT (work_order_id, line_id) DO NOTHING`.

**[M4] Cooperation flag race.**
Ako jedan operater označi liniju kao `cooperation_status='external_in_progress'` dok drugi pokušava REASSIGN iste linije, oba upita prolaze kroz različite kodne puteve (`upsertOverlay` direktan vs `reassign_production_line` RPC) — poslednji wins. Ne postoji explicit lock niti CHECK koji blokira REASSIGN dok je kooperacija aktivna.
**Mitigation:** u `reassign_production_line()` dodaj guard: `IF v_existing.cooperation_status NOT IN ('none','external_done') THEN RETURN error 'in_cooperation'`.

### 4.2 Permission / autorizacija

**[H5] `production_reassign_audit` write RLS nekonzistentna.**
Audit je dizajniran kao append-only iz SECURITY DEFINER RPC-a. SELECT je gated kroz `can_force_plan_reassign()`. Ali write side (INSERT/UPDATE/DELETE) zavisi od **default deny** RLS-a — nema **explicit** `WITH CHECK (false)` policy-ja. SECURITY DEFINER RPC bypassuje RLS, što je tačno za upis iz RPC-a, ali ako bilo ko ikad ostavi tabelu sa `ALTER TABLE ... DISABLE ROW LEVEL SECURITY` (npr. tokom debug-a) — write postaje slobodan.
**Mitigation:**
```sql
REVOKE INSERT, UPDATE, DELETE ON public.production_reassign_audit FROM authenticated, anon;
GRANT INSERT ON public.production_reassign_audit TO service_role;
```
ili eksplicitno `CREATE POLICY pra_no_client_write FOR ALL TO authenticated USING (false) WITH CHECK (false);`.

**[H6] Cross-module dependency može da slomi migraciju.**
`fix_v_production_operations_ready.sql` poziva `production._pracenje_line_is_final_control(...)`; `add_production_cooperation_g7.sql` poziva `public.current_user_is_admin()`. **Obe funkcije nisu definisane u PP migracijama** — dolaze iz Praćenja proizvodnje, odnosno iz drugog modula. Ako neko aplicira PP migracije na svežoj bazi pre Praćenja, migracija pada.
**Mitigation:** pre `CREATE OR REPLACE VIEW`, dodaj guard:
```sql
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='_pracenje_line_is_final_control'
    AND pronamespace::regnamespace::text='production')
  THEN RAISE EXCEPTION 'Pre PP migracija mora biti primenjen modul Praćenje proizvodnje'; END IF;
END $$;
```

**[M7] UI gate je samo flag, draggable atribut ostaje u DOM-u.**
[poMasiniTab.js:1047](../src/ui/planProizvodnje/poMasiniTab.js#L1047) — `draggable="true"` se postavlja na red samo ako `state.canEdit`, ALI ako se UI re-renderuje sa kompromitovanim state-om (npr. ručno postavi `canEdit=true` u DevTools), atribut prođe. RLS je krajnja barijera (server vraća 403), ali UI poruke o grešci ne objašnjavaju root cause. Operativno minimalan rizik (svaki ulogovani korisnik već ima pristup view-u i može da prouzrokuje 403). Ozbiljniji rizik bi bio kada bi se `reorderOverlays()` izgubio gate u `can_edit_plan_proizvodnje()` — što je RLS politika i radi server-side.
**Mitigation:** ostavi UI gate kao convenience, RLS server-side je pravi gate. Dodaj jasnu toast poruku kada server vrati 403 („Nemaš dozvolu za ovu akciju").

### 4.3 Data integrity

**[H8] `assigned_machine_code` nema FK ni validation trigger.**
[add_plan_proizvodnje.sql](../sql/migrations/add_plan_proizvodnje.sql) — kolona je `TEXT`, validacija je opisno „proveri u app sloju". Bridge sync briše i puni `bigtehn_machines_cache` — ako MSSQL ukloni mašinu, overlay-i sa tom mašinom postaju **orphan**. View `v_production_operations` LEFT JOIN-uje machine cache, pa orphan red se prikazuje sa NULL grupom — ne pada, ali izveštaji su pogrešni.
**Mitigation:** periodic cleanup job (`pg_cron`):
```sql
SELECT cron.schedule('po_orphaned_machine_cleanup', '0 2 * * *', $$
  UPDATE production_overlays SET assigned_machine_code = NULL, updated_by = 'system:cleanup'
  WHERE assigned_machine_code IS NOT NULL AND archived_at IS NULL
    AND NOT EXISTS (SELECT 1 FROM bigtehn_machines_cache m
                    WHERE m.rj_code = production_overlays.assigned_machine_code);
$$);
```

**[H9] `production_drawings.storage_path` bez path-traversal zaštite.**
Kolona je `TEXT UNIQUE`. App sloj konstruisana kao `production-drawings/<wo>/<line>/<filename>`. Ako klijent (ili maliciozni POST) pošalje `storage_path='production-drawings/../../foo/bar.pdf'`, **postoji potencijal za remapiranje** unutar Storage bucket-a (Supabase storage RLS gleda bucket_id, ali path se koristi za listing). Trenutno nema DB CHECK koji bi to blokirao.
**Mitigation:**
```sql
ALTER TABLE production_drawings ADD CONSTRAINT pd_path_safe
  CHECK (storage_path ~ '^production-drawings/\d+/\d+/[A-Za-z0-9._\-]+$'
         AND storage_path NOT LIKE '%..%' AND storage_path NOT LIKE '%//%');
```

**[M10] `shift_sort_order` može da bude null ili duplikat.**
`reorderOverlays` postavlja `shift_sort_order = niz_index` za sve stavke u listi. Ako dva istovremena reorder-a pošalju iste indekse (vidi H2), polje nema UNIQUE constraint — postoje duplikati. UI sort je `ASC NULLS LAST`, pa duplikati postaju nedeterministički sortirani među sobom.
**Mitigation:** umesto absolute index-a koristi fractional indexing (npr. „lexorank") ili dodaj `UNIQUE (assigned_machine_code, shift_sort_order) WHERE archived_at IS NULL` — ali to traži dodatnu logiku za free-slot pretragu.

**[M11] Nema audit trail za sensitive state transitions na `production_overlays`.**
Promene `local_status` (npr. blocked → in_progress), CAM flag toggle, kooperacija manual toggle — sve ide kroz `upsertOverlay` bez ikakvog history reda. Postoji samo `updated_at` + `updated_by`. Forenzika („ko je skinuo HITNO, kada, zašto") nemoguća.
**Mitigation:** add `production_overlays_history` table + AFTER UPDATE trigger koji upisuje diff. Skala: ~50 promena dnevno × 365 dana = 18K redova/god — bezopasno.

**[M12] Mrtve kolone `archived_at` / `archived_reason` nemaju enforcement.**
`production_overlays.archived_at` postoji da označi overlay-e za RN-ove koji su zatvoreni. Ko ga postavlja? Trenutno nigde u kodu nije pronađen INSERT/UPDATE koji to radi. View `v_production_operations` filtrira po `archived_at IS NULL` u nekim slojevima (npr. `plan_pp_open_ops_for_machine`), ali ostali read-evi to ne rade.
**Verifikacija:** grep `archived_at` u services + workers — da li bridge backfill ikad postavlja `archived_at` posle završetka RN-a? Ako ne, kolona je mrtva.

### 4.4 Frontend race conditions

**[H13] Event listener memory leak na re-render tabele.**
[poMasiniTab.js:1256-1314](../src/ui/planProizvodnje/poMasiniTab.js#L1256) — `wireRows(wrap)` direktno radi `forEach(input => input.addEventListener(...))` za ~12 tipova event-a. Funkcija se zove iz `renderTable()` [linija 868-984](../src/ui/planProizvodnje/poMasiniTab.js#L868) koji je pozvan na:
- RN filter promenu (debounce 200ms) — [linija 723-730](../src/ui/planProizvodnje/poMasiniTab.js#L723)
- Posle svakog `loadOperationsForMachine` — [linija 780](../src/ui/planProizvodnje/poMasiniTab.js#L780)
- Posle svakog `loadOperationsForDept` — [linija 815](../src/ui/planProizvodnje/poMasiniTab.js#L815)

Pošto `renderTable` radi `wrap.innerHTML = ...` (zamenjuje sav HTML), stari elementi postaju unreachable i GC-ovi ih čiste — listeneri vezani na *stare* element nodes nestaju zajedno sa njima. **Ali ako bilo koji listener drži referencu na vanjski scope (closure)**, GC ne može da očisti dok je `wrap` live. Praktično: ovo nije strogi leak, ali **CPU cost** od ~12 × N redova × ~10 filter promena u minutu = par hiljada bind-ova/min na slabijim mašinama.
**Mitigation:** event delegation — jedan listener na `wrap` koji koristi `e.target.closest('[data-action=...]')`. Jednom postavljen, preživljava sve re-render-e jer `wrap` ostaje isti element.

**[H14] Promise.all bez timeout / AbortController.**
[pregledTab.js:129-131](../src/ui/planProizvodnje/pregledTab.js#L129) — `Promise.all([loadMachines(), loadAllOpenOperations()])` bez timeout-a. Ako jedan request visi (slaba mreža, server overload), spinner se vrti zauvek, tab se ne može napustiti bez F5.
**Mitigation:** wrap u `Promise.race([..., timeout(15000)])`; ili bolje — globalni `AbortController` po tabu koji se abortuje u `teardown`.

**[H15] Drag-drop handler-i ne čiste se na tab switch.**
[poMasiniTab.js:1823-1900](../src/ui/planProizvodnje/poMasiniTab.js#L1823) — `wireDragDrop(wrap)` veže `dragstart/dragend/dragover/drop` na `tbody`. Pošto se tbody zamenjuje na svakom `renderTable`, listeneri se ne ponavljaju (jer je novi element), ali ako u `teardownPoMasiniTab` nije eksplicitno otkazan **trenutni** dragstart u toku, drop može da završi u već-uništenom tabu i da pošalje `reorderOverlays` sa zastarelim `state.rows`.
**Mitigation:** u `teardownPoMasiniTab` postaviti `state.dragRowKey = null` i `state.host = null` pre demount-a; svaki listener handler proverava `if (!state.host) return;` na ulazu.

**[M16] Pending setTimeout posle teardown-a.**
[poMasiniTab.js:725-729](../src/ui/planProizvodnje/poMasiniTab.js#L725) — `setTimeout(renderTable, 200)` se ne otkazuje u `teardownPoMasiniTab`, makar `state.rnFilterTimer` se reset-uje. Pending timer u browser-u i dalje postoji.
**Mitigation:** u `teardown` pozovi `clearTimeout(state.rnFilterTimer)` PRE postavljanja na null. Isto za sve tabove sa debounce-om (`zauzetostTab.js:218`, `pregledTab.js:100`, `kooperacijaTab.js:63`).

**[M17] ESC key listener konkurentnost tokom tab switch-a.**
Ako je TP modal otvoren i korisnik klikne tab-button, `teardownActiveTab` zatvara modal što removeListener-uje ESC handler, ali u istom mikrotask-u korisnik može pritisnuti ESC i pogoditi stari handler (DOM event listenerов redosled garantuje sync removal, ali ako je modal close async — npr. `await fetch()` u close handleru — postoji prozor). Praktično: retko, low impact (najgori scenario: dupli close).

### 4.5 Offline / mreža

**[M18] `sbReq` nema HTTP timeout.**
Svi PostgREST pozivi koriste browser default fetch timeout (effectively beskonačno). Na lošoj mreži korisnik može videti spinner 30+ s.
**Mitigation:** `AbortController` u `services/supabase.js` sa 15s default-om; explicit `timeout: 60_000` za bulk operacije.

**[M19] Nema retry logike.**
Ako `sbReq` vrati `null` (network fail / 5xx), klijent prikaže toast i čeka korisnika da klikne „Osveži". Za ne-write akcije (read) automatski retry sa exp. backoff bi smanjio frustraciju. Za write — ne smemo retry bez idempotency ključa (vidi H1).

**[M20] Bridge staleness nije vizuelno označen u PP modulu.**
Lokacije modul ima `renderBridgeStaleBanner` koji upozorava ako su BigTehn cache stariji od 6h/36h/7d. PP modul tu funkciju ne zove — operater može da vidi „spremnost" / „status" iz cache-a koji je star 5 sati i da donese pogrešnu odluku.
**Mitigation:** dodaj banner u `index.js` header (pored read-only badge-a) koji čita `bridge_sync_log.last_run_at` i prikazuje minute since last sync. Threshold 30 min = upozorenje, 2 h = blokiraj write akcije.

### 4.6 Performance

**[M21] `plan_pp_open_ops_for_machine` 180s timeout — nije testirano sa 5K+ ops.**
[fix_v_production_operations_ready.sql:336](../sql/migrations/fix_v_production_operations_ready.sql#L336) — `SET statement_timeout TO '180s'`. View ima LATERAL subselect-e na cache tabele po redu. Bez indeksa `(work_order_id, operacija)` na `bigtehn_tech_routing_cache` PP-A `NOT EXISTS` proverava može da bude `O(N²)`.
**Verifikacija:**
```sql
SELECT indexname FROM pg_indexes WHERE tablename = 'bigtehn_tech_routing_cache';
-- Treba: idx (work_order_id, operacija, is_completed)
```
Ako ne postoji, dodaj.

**[M22] `loadAllOpenOperations` hard cap 10K redova bez paginacije.**
[planProizvodnje.js:417](../src/services/planProizvodnje.js#L417) — `limit: 10000`. Pregled tab i Zauzetost tab oba zovu tu funkciju. Ako proizvodnja ima 12K otvorenih operacija, tab tiho prekida na 10K. Korisnik ne zna.
**Mitigation:** prikaži warning u UI „Prikazano prvih 10K — neke operacije nisu uračunate".

**[L23] Tabela renderuje ceo set bez virtualizacije.**
Ako mašina ima 1000+ otvorenih operacija, DOM od 1000 redova je usporava staromodne mašine. Trenutno paginacija po RN (100/strana) drži ovo pod kontrolom, ali ako se „Sve" prikaz koristi za sve mašine, brojevi mogu da skoče.

### 4.7 Sigurnost / XSS

**[L24] `escHtml` konzistentno korišćen.**
Spot check svih `innerHTML =` mesta u modulu: `index.js:85-122`, `poMasiniTab.js:344-356, 948-980`, `drawingManager.js:177-214`, `techProcedureModal.js:73-126, 181`, error box-ovi — svi koriste `escHtml` za korisnički unos. Nije pronađen `insertAdjacentHTML`. Status: **OK**.

**[L25] PDF iframe blob URL.**
`techProcedureModal.js` učitava potpisan URL iz Storage-a, fetch-uje ga, pravi blob i prosleđuje iframe-u kao `src`. Blob URL se revoke-uje u `close()`. Da li je proverena MIME tip vrednost na klijentu pre nego što se servira kao PDF? Ako se servira non-PDF blob (npr. HTML sa skriptom), iframe će ga pokrenuti.
**Verifikacija:** ručno proveri `loadFullTechProcedure` / signed URL flow — da li je `Content-Type` validiran? Ako ne, ograniči `accept` na `application/pdf`.

**[L26] `JSON.parse(localStorage...)` bez whitelist polja.**
[zauzetostTab.js:166](../src/ui/planProizvodnje/zauzetostTab.js#L166) — `JSON.parse(localStorage.getItem(STORAGE_KEY_SORT) || '{}')`. Iako `JSON.parse` ne dozvoljava prototype pollution direktno, vrednosti idu u state bez tipovne provere. Maliciozni storage može da zarobi UI u beskonačnoj petlji ako se vrednosti koriste kao sort key bez whitelist-a.
**Mitigation:** whitelist `sortKey` i `sortDir` na ulazu.

### 4.8 Operacioni / out-of-band

**[H27] Migracije se ručno aplikuju — nema enforcement redosleda.**
PP repo (`sql/migrations/*.sql`) i Supabase grana (`supabase/migrations/*.sql`) imaju različite konvencije. Jara ručno izvršava preko Supabase Studio. Bez dependency matrix-a ili `SELECT pg_advisory_lock(...)` guarda, redosled nije garantovan.
**Mitigation:** dodaj `docs/migrations/README.md` sa dependency grafom (npr. iz output-a DB audit-a u prethodnoj sekciji). Svaka migracija na vrhu ima `-- Requires: <list of migrations or functions>`.

**[H28] Bridge worker bez health-check pristupa za PP.**
G6 `mark_in_progress_from_tech_routing` se poziva iz `backfill-production-cache.js`. Ako worker padne, status overlay-a ostane na `waiting` iako operater radi. UI nema indikaciju.
**Mitigation:** tabela `bridge_sync_log` (ako postoji za Lokacije) treba da prima i PP eventove; PP modul header treba da pokaže „Bridge: last run X min ago" sa crveno ako > 30 min.

**[M29] DEAD letter za G6.**
Šta ako `mark_in_progress_from_tech_routing` baci exception (npr. constraint violation, statement timeout)? Bridge skripta loguje i nastavlja — ali nigde nije logovano koji prijava nije obrađena. Sledeći ciklus će probati ponovo, ali ako je sistemska greška, samo se ponavlja.
**Mitigation:** dodaj `production_g6_sync_log` (run_id, started_at, finished_at, updated_count, inserted_count, error_message). Admin UI tabela.

**[M30] G6 RPC nije idempotentan po jedinstvenom događaju.**
Ako se `mark_in_progress_from_tech_routing` poziva sa istom tech routing skenom dvaput, UPDATE i INSERT su idempotentni (state je krajnji), ALI `updated_by = 'system:bridge:g6'` se prepiše čak i ako vrednost nije promenjena, što „truje" forenziku („zadnji put je system menjao, a u stvari je korisnik postavio").
**Mitigation:** u `mark_in_progress_from_tech_routing` ne diraj `updated_by` ako je vrednost ista. Ili: dodaj `auto_set_at` kolonu odvojeno od `updated_at`, tako da forenzika može da razlikuje user vs system change.

### 4.9 UX / poslovni rizici

**[M31] Kooperacija UI za auto-grupe ne postoji.**
G7 doc kaže: „Podešavanja → UI sekcija za održavanje auto-grupa nije obavezno urađena — grupe se mogu održavati kroz Supabase Table Editor / SQL." To znači da non-admin korisnik koji bi želeo da privremeno isključi „bravarsko" iz auto-kooperacije ne može.
**Mitigation:** kratak admin UI ekran u modulu Podešavanja (CRUD nad `production_auto_cooperation_groups`).

**[M32] „Sakrij RN posle završne kontrole" (KK) logika je heuristika.**
[supabase/migrations/20260507100000__plan_final_qc_hide_fix_double_sum.sql](../supabase/migrations/20260507100000__plan_final_qc_hide_fix_double_sum.sql) — `plan_rn_final_control_done = (sum_KK >= komada_total AND <= komada_total * 1.5)`. Gornja granica `× 1.5` je hack protiv duplih prijava. Ako operater duplo prijavi (npr. 200% količine), RN je „done" i nestaje iz plana — što može zatamniti grešku prijave. Ovo je kompromis koji bi trebalo dokumentovati u UI tooltip-u.

**[L33] „HITNO" prelazi između operacija jednog RN-a propagira samo kroz sort, ne kroz vizuelni indikator.**
Ako šef označi RN kao HITNO, sve operacije tog RN-a dobijaju `is_urgent=TRUE` (preko `production_urgency_overrides.work_order_id`). Sort radi, ali u Pregled tabu (matrica) nema badge-a koji bi pokazao „ovaj kvadratić je HITNO".

---

## 5. Bezbedne izmene — gde lako možeš da slomiš stvari

| Akcija | Rizik | Kako proveriti |
|---|---|---|
| Promena `v_production_operations` ili `_pre_g4` strukture | Sav UI čita iz njih + RPC `plan_pp_open_ops_for_machine`. Migracija mora DROP/CREATE CASCADE i ponovo definisati zavisne funkcije. | Pre apply-a: `\d+ v_production_operations` u Supabase Studio. Posle: smoke test sva 4 taba + WhyBottleneckModal + tech procedure modal. |
| Promena `production_overlays` UNIQUE ključa | Sav write (UPSERT u `upsertOverlay`, RPC reassign). | Grep `(work_order_id, line_id)` u svim migracijama i services-u. |
| Brisanje stare kolone `is_ready_for_processing` | Iako je back-compat alias, nije znano koje vanjske skripte (npr. backfill, reporting) čitaju ovo polje. | Grep `is_ready_for_processing` u celom repo-u + workers/ + `servoteh-bridge` (van repo-a). |
| Promena gate funkcije `can_edit_plan_proizvodnje()` | Sav RLS write + storage bucket. | `SELECT proname, prosrc FROM pg_proc WHERE proname='can_edit_plan_proizvodnje';` Test sa svakom ulogom (admin/pm/menadzment/leadpm/viewer/hr). |
| Promena bridge backfill skripte za G6 | Auto-status za stotine RN-ova istovremeno. | Dry-run sa `RETURNING` u test env-u; proveri da je `updated_count` razuman (< 100 za jedan ciklus). |
| Promena `auto_sort_bucket` izraza | Sort u 3 taba + WhyBottleneckModal opis. | Posle change-a: test 8 bucket-a (urgent×ready×status varijante) u prikazu. |
| Promena `sortProductionOperations` JS helper-a | Sva 3 taba koja ga zovu. | Unit test sa fixture-ima (već postoje `tests/services/planProizvodnje*.test.js`). |

---

## 6. Reliability checklist pre produkcije / kritičnih izmena

### Mora (H) — pre nego što PP modul ide u širu produkciju
- [ ] **Idempotency za G5 REASSIGN** — `client_event_uuid` u payload-u + UNIQUE na audit tabeli.
- [ ] **OCC za drag-drop** — `expected_updated_at` per stavku u `reorderOverlays`; server odbija sa 409.
- [ ] **Cross-module dependency guard** u PP migracijama (`production._pracenje_line_is_final_control`, `current_user_is_admin`).
- [ ] **`production_drawings.storage_path` CHECK constraint** (path traversal).
- [ ] **Explicit REVOKE INSERT/UPDATE/DELETE** na `production_reassign_audit` od `authenticated`.
- [ ] **Bridge health banner** u PP header-u (last sync time, threshold 30 min / 2 h).
- [ ] **Cleanup job** za orphaned `assigned_machine_code`.
- [ ] **Event listener cleanup u `poMasiniTab.js`** — event delegation pattern ili eksplicit `removeEventListener` u `teardown`.
- [ ] **HTTP timeout u `sbReq`** (15s default + AbortController per tab).
- [ ] **`Promise.all` u `pregledTab.js` sa timeout-om**.

### Trebalo bi (M)
- [ ] Audit log tabela `production_overlays_history` + AFTER UPDATE trigger.
- [ ] Periodic verify `bigtehn_tech_routing_cache` indeks `(work_order_id, operacija, is_completed)` — performanse PP-A `NOT EXISTS`.
- [ ] G6 sync log tabela + admin UI vidljivost.
- [ ] G6 RPC: ne dirаj `updated_by` ako je vrednost ista (forenzika).
- [ ] UI banner za 10K cap u `loadAllOpenOperations`.
- [ ] Whitelist `sortKey` i `sortDir` na `JSON.parse(localStorage)`.
- [ ] Admin UI za `production_auto_cooperation_groups` CRUD.
- [ ] Trigger ili explicit pravilo: REASSIGN blokiran dok je cooperation_status aktivan.
- [ ] `archived_at` flow — proveri da li se postavlja iz bridge-a kad RN završi; ako ne, ili implementuj ili obriši kolonu.

### Lepo bi bilo (L)
- [ ] HITNO badge u Pregled tab matrici.
- [ ] Vizuelni indikator u tooltip-u za KK heuristic granicu (1.0×–1.5×).
- [ ] Virtualizacija tabele za > 500 redova.
- [ ] Test suite za concurrent reorder + reassign.
- [ ] `current_user_is_admin()` dokumentacija u CLAUDE.md ili dependency matrix-u.

---

## 7. Glosar / pojmovi koji često zbunjuju agenta

| Termin | Značenje |
|---|---|
| RN | Radni nalog (BigTehn `bigtehn_work_orders_cache`). |
| Linija RN-a | Jedna stavka TP-a iz `bigtehn_work_order_lines_cache` — ima `operacija` (redni broj u TP-u). |
| Overlay | Red u `production_overlays` — lokalna odluka šefa smene za jednu (RN, linija) kombinaciju. |
| Spremnost / ready | `is_ready_for_machine` u view-u: TRUE ako sve operacije sa manjim `operacija` su `is_completed` u tech routing cache-u. |
| HITNO | `production_urgency_overrides` per RN. Propagira na sve linije RN-a kroz `is_urgent`. |
| CAM | `production_overlays.cam_ready` — flag „program za mašinu je gotov, može da se pusti". |
| Auto kooperacija | RJ grupa u `production_auto_cooperation_groups` → sve operacije te grupe se automatski tretiraju kao kooperacija. |
| Manual kooperacija | `production_overlays.cooperation_status ≠ 'none'` — per linija. |
| `is_cooperation_effective` | Auto OR manual — view kolona za filter. |
| REASSIGN | Promena `production_overlays.assigned_machine_code` — operacija premestena sa originalne mašine. |
| Force REASSIGN | REASSIGN izvan iste mašinske grupe — traži admin/menadzment + audit reason. |
| `auto_sort_bucket` | Broj 1–8 (1 = najprioritetnije: hitno+spremno+in_progress, 7 = blokirano). View kolona, koristi je `sortProductionOperations`. |
| `plan_rn_final_control_done` | Heuristic: KK pokriva ceo lot (>=komada_total i <= 1.5×). Posle ovog flag-a RN izlazi iz plana. |
| Bridge | `servoteh-bridge` (Node scheduler, 15 min) + `workers/loc-sync-mssql/scripts/backfill-production-cache.js` — sinhronizuje `bigtehn_*_cache` iz MSSQL-a. |
| BigTehn | QMegaTeh (legacy MSSQL aplikacija) — izvor istine za RN i tehnologiju. PP ne piše nazad. |
| MES aktivni RN | `production_active_work_orders.is_active = TRUE` — ručna whitelist + automatika. Inactive RN se ne prikazuju. |

---

## 8. Šta ovaj dokument NE pokriva

- `servoteh-bridge` (poseban repo) — Node scheduler, MSSQL connector, error handling van repo-a.
- `bigtehn_*_cache` šeme — pogledaj [docs/migration/04-qbigtehn-schema-inventory.md](migration/04-qbigtehn-schema-inventory.md) i [docs/migration/QBigTehn_MSSQL_full_ssms_export_2026-04-10.README.md](migration/QBigTehn_MSSQL_full_ssms_export_2026-04-10.README.md).
- Praćenje proizvodnje (`production.*` schema) — odvojen modul; PP zavisi od `production._pracenje_line_is_final_control()` i `production.predmet_aktivacija`.
- Storage bucket `production-drawings` RLS detalji — videti [add_plan_proizvodnje.sql](../sql/migrations/add_plan_proizvodnje.sql) sekciju Storage policies.
- `lib/dom.js` (`escHtml`, `showToast`) — globalni helper-i deljeni sa Lokacije modulom.
- PDM modul i veza sa crtežima (`bigtehn_drawings_cache`, `pdm.*`) — videti [docs/migration/07-pdm_pregled_crteza_veze_i_prenos.md](migration/07-pdm_pregled_crteza_veze_i_prenos.md).
- Predmet aktivacija RLS i UI — videti [docs/migration/07-predmet-aktivacija.md](migration/07-predmet-aktivacija.md).

---

## 9. Citati linija za AI agenta

Kada agent radi izmene, navedi konkretne lokacije:

**Frontend:**
- [poMasiniTab.js: drag-drop wireup](../src/ui/planProizvodnje/poMasiniTab.js#L1823)
- [poMasiniTab.js: wireRows event binding](../src/ui/planProizvodnje/poMasiniTab.js#L1256)
- [poMasiniTab.js: RN filter debounce](../src/ui/planProizvodnje/poMasiniTab.js#L720)
- [poMasiniTab.js: renderTable](../src/ui/planProizvodnje/poMasiniTab.js#L868)
- [pregledTab.js: Promise.all bez timeout](../src/ui/planProizvodnje/pregledTab.js#L129)
- [planProizvodnje.js: loadOperationsForMachine paginacija](../src/services/planProizvodnje.js#L177)
- [planProizvodnje.js: loadAllOpenOperations 10K cap](../src/services/planProizvodnje.js#L417)
- [index.js: tab routing + teardown](../src/ui/planProizvodnje/index.js#L127)

**DB / SQL:**
- [PP-A: strict readiness SQL](../sql/migrations/fix_v_production_operations_ready.sql)
- [PP-A: plan_pp_open_ops_for_machine timeout](../sql/migrations/fix_v_production_operations_ready.sql#L336)
- [G5: reassign_production_line RPC](../sql/migrations/add_production_g5_reassign_rpc.sql)
- [G6: mark_in_progress_from_tech_routing](../sql/migrations/add_production_g6_auto_in_progress.sql)
- [G2: production_urgency_overrides + auto_sort_bucket](../sql/migrations/add_production_g2_readiness_urgency.sql)
- [G7: production_auto_cooperation_groups](../sql/migrations/add_production_cooperation_g7.sql)
- [G4: bigtehn_rework_scrap_cache + pre_g4 rename](../sql/migrations/add_production_g4_rework_scrap_cache.sql)
- [Final QC hide + double sum fix](../supabase/migrations/20260507100000__plan_final_qc_hide_fix_double_sum.sql)
- [Anon revoke fix](../sql/migrations/revoke_anon_v_production_operations.sql)

**Bridge:**
- [workers/loc-sync-mssql/scripts/backfill-production-cache.js](../workers/loc-sync-mssql/scripts/backfill-production-cache.js) — search za `mark_in_progress_from_tech_routing`

---

## 10. Pitanja za sledeću sesiju (kandidati za sprint plan)

1. **Šta posle PP-A?** PP-A je doteruje samo readiness logiku. Da li je već validiran nad konkretnim RN-om iz proizvodnje? Ako jeste, sledeći prioritet je **H1 (idempotency G5)** ili **H13 (event listener cleanup)** — predloži korisniku da bira.
2. **Bridge health banner** — zahteva odluku gde se loguje (postoji `bridge_sync_log` za Lokacije; treba li PP da deli istu tabelu ili da ima svoju)?
3. **Audit log za overlay** — pre nego što se napravi, definiši šta tačno čuvamo (sve change-eve ili samo `local_status`, `assigned_machine_code`, `cam_ready`).
4. **Admin UI za auto-kooperaciju** — koliko često se grupe menjaju? Ako 1× mesečno, Table Editor je dovoljan; ako češće, UI ima vrednost.
5. **`archived_at` flow** — proveri sa Jarom: ko/šta postavlja `archived_at`? Ako mrtva kolona, obriši; ako se podrazumeva bridge da je postavlja, treba implementirati.

---

**Verzija:** 2026-05-15 · **Autor:** sistemski tim inženjera (Claude Opus 4.7, 1M context) · **Status:** za internu reliability/security review · **Sledeća revizija:** posle apply-a PP-A SQL migracije + 1 nedelja u produkciji.

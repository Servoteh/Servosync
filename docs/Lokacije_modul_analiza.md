# Modul LOKACIJE delova — analiza za AI agenta (Claude / ChatGPT)

> Cilj ovog dokumenta: dati narednom AI agentu **kompletnu, samosadržajnu sliku modula** `src/ui/lokacije/*` + `loc_*` tabela, sa **kritičnim tačkama** koje moraju biti razmatrane pre svake izmene. Optimizovano za chat-context dump.
>
> Stack: vanilla JS (ES modules, bez frameworka), Supabase (PostgreSQL + PostgREST), Capacitor (Android/iOS), ZXing za barkod, JsBarcode + QRCode za štampu, TSC ML340P preko TSPL2.

---

## 1. Brzi mentalni model

**HALA → POLICA**
- `HALA` = veći prostor (WAREHOUSE, PRODUCTION, ASSEMBLY, FIELD, TEMP). Mora biti `parent_id IS NULL` (root).
- `POLICA` = konkretno mesto (SHELF, RACK, BIN). Mora imati halu kao roditelja.
- Hijerarhija je strogo dvonivovska po **poslovnoj klasifikaciji**, iako enum `loc_type_enum` dopušta i druge tipove (npr. PROJECT, SERVICE, SCRAPPED, OTHER).
- Trigger `loc_locations_enforce_business_hierarchy` forsira pravila pri INSERT/UPDATE.

**Bucket "stanje po stavci" je trojka**: `(item_ref_table, item_ref_id, order_no, location_id)` sa `quantity NUMERIC(12,3)`.
- `order_no` = broj predmeta / RN-nalog (npr. `9000`). Komadi iz različitih naloga **NE smeju se mešati**.
- `item_ref_table` = obično `'bigtehn_rn'`, `item_ref_id` = broj TP.
- `drawing_no` = broj crteža (first-class kolona od v4).

**Sve premeštanje IDE samo kroz RPC** `public.loc_create_movement(payload jsonb)` (SECURITY DEFINER). Tabela `loc_location_movements` nema INSERT RLS policy — direktan INSERT iz klijenta je nemoguć. Trigger `loc_after_movement_insert` AFTER INSERT radi UPSERT na `loc_item_placements` (TO += qty, FROM -= qty ili DELETE).

---

## 2. Mapa fajlova

### Frontend
| Fajl | Veličina | Odgovornost |
|---|---|---|
| [src/ui/lokacije/index.js](../src/ui/lokacije/index.js) | 2389 | Shell, tab routing (`dashboard`/`predmet`/`browse`/`items`/`report`/`labels`/`definitions`/`history`/`sync`), KPI dashboard, browse tree/table, items pretraga, report tab, history, CSV export. |
| [src/ui/lokacije/modals.js](../src/ui/lokacije/modals.js) | 1457 | CRUD master lokacija (nova HALA / nova POLICA, bulk generator A1–A30, edit), `openQuickMoveModal` (brzo premeštanje bez kamere), `openItemHistoryModal`. |
| [src/ui/lokacije/scanModal.js](../src/ui/lokacije/scanModal.js) | 2285 | **Full-screen mobilni barkod skener.** ZXing kamera, parsing RNZ (`order/tp`), parsing kompozitnog barkoda police (`LP:uuid:uuid` ili `HALA-POLICA`), iOS visual viewport fix, offline queue. |
| [src/ui/lokacije/predmetTab.js](../src/ui/lokacije/predmetTab.js) | 820 | Pregled svih TP-ova izabranog predmeta sa statusom lokacije; CSV/PDF export; štampa lista. |
| [src/ui/lokacije/labelsPrint.js](../src/ui/lokacije/labelsPrint.js) | 882 | Štampa nalepnica POLICE i TP — JsBarcode/QRCode → `window.print` ili POST na TSC proxy (TSPL2). |
| [src/ui/lokacije/labelsPrintPage.js](../src/ui/lokacije/labelsPrintPage.js) | 727 | Batch režim: multi-select TP-ova kroz više predmeta, in-memory queue, jedan otisak. |
| [src/ui/lokacije/lookupModals.js](../src/ui/lokacije/lookupModals.js) | 228 | Read-only modali za pretragu BigTehn RN-ova i predmeta iz cache-a. |
| [src/services/lokacije.js](../src/services/lokacije.js) | 843 | Sav PostgREST/RPC sloj — `fetchPlacements`, `fetchAllPlacements` (50K hard cap), `fetchMovementsHistory`, `fetchLocReportPartsByLocations`, `fetchTpsForPredmet`, `locCreateMovement`, `searchBigtehnItems` (+ poseban customer lookup), `fetchBridgeSyncStatus`. |
| [src/state/lokacije.js](../src/state/lokacije.js) | 367 | In-memory UI state + LS perzistencija. Striktne whitelist validacije (tab id, UUID regex, page sizes, sort kolone, movement types, order_no shape). |
| [src/lib/lokacijeFilters.js](../src/lib/lokacijeFilters.js) | 92 | Pure helperi — `filterLocationsHierarchical` (čuva pretke match-ova), `placementMatches`. |
| [src/lib/lokacijeTypes.js](../src/lib/lokacijeTypes.js) | 59 | Klasifikacija HALA / POLICA / OSTALO; `canBeShelfParent`. |
| [src/lib/lokacijeSort.js](../src/lib/lokacijeSort.js) | 16 | Natural sort po `location_code`. |
| [src/styles/lokacije.css](../src/styles/lokacije.css) | 869 | Sav modul. |

### Migracije (redom primene)
1. `add_loc_module_step1_tables.sql` — bootstrap tabele bez triggera (fallback ako step2+ pada).
2. `add_loc_module.sql` — enums, tabele, triggeri, RLS, **RPC v1** `loc_create_movement`.
3. `add_loc_step2_ci_unique.sql` — case-insensitive unique na `location_code`.
4. `add_loc_step3_cleanup.sql` — admin RPC `loc_purge_synced_events`.
5. `add_loc_step4_pgcron.sql` — dnevni pg_cron job 03:15 UTC, retencija 90 dana.
6. `add_loc_step5_sync_rpcs.sql` — worker RPC-ovi: `loc_claim_sync_events` (FOR UPDATE SKIP LOCKED), `loc_mark_sync_synced`, `loc_mark_sync_failed` (exp. backoff, DEAD_LETTER posle 10 pokušaja).
7. `add_loc_v2_quantity.sql` — `quantity NUMERIC(12,3)`, unique → `(item, id, location)`, trigger radi aritmetiku, RPC validira kapacitet.
8. `add_loc_v3_order_scope.sql` — `order_no` dimenzija, unique → `(item, id, order_no, location)`.
9. `add_loc_v4_drawing_no.sql` — `drawing_no` first-class kolona, backfill iz `note ~ 'Crte[žz]:([^\s|]+)'`, trigger izvlači iz note ako klijent ne pošalje.
10. `add_loc_menadzment_manage_locations.sql` — uloga `menadzment` ulazi u `loc_can_manage_locations()` (zajedno sa admin/leadpm/pm).
11. `add_loc_report_by_locations_rpc.sql` + `add_loc_report_v2_bigtehn_columns.sql` + `add_loc_report_ident_broj_variant_match.sql` — RPC `loc_report_parts_by_locations`, koji joinuje `loc_item_placements` × `bigtehn_work_orders_cache` × `bigtehn_customers_cache` × `projects` sa „opuštenim sufiks” match-om za varijante ident_broja (`9400` vs `9400-2`).
12. `add_loc_tps_for_predmet_rpc.sql` → v2 → v3 — RPC za Predmet tab: MES aktivni RN filter, prefix match na tp_no/drawing_no, `has_pdf` polje.
13. `add_loc_locations_audit.sql` — generički audit trigger + SECURITY DEFINER RPC `loc_locations_audit`.
14. `add_loc_location_hierarchy_rules.sql` — view `loc_location_hierarchy_issues` (dijagnostika) + trigger koji forsira pravila HALA→POLICA.
15. `loc_location_code_scope_unique_strip_prefix.sql` — **promena uniqueness**: globalni `lower(location_code)` UQ → scoped `(COALESCE(parent_id, sentinel), lower(location_code))`. Police mogu imati istu šifru u različitim halama.
16. `add_loc_view_hale_i_police_list.sql` — view za listing.
17. `add_loc_report_ident_broj_variant_match.sql` — najnovija (untracked u git status), preciznija varijanta matching-a za ident_broj.

### Workers / external
- `workers/loc-sync-mssql/` — Node worker koji konzumira `loc_sync_outbound_events`, poziva MSSQL `sp_ApplyLocationEvent`. **Bez ovog worker-a sync queue raste; pg_cron purguje samo SYNCED stavke.**
- BRIDGE sync job (15 min) puni `bigtehn_*_cache`. Banner `renderBridgeStaleBanner` upozorava ako su starije od 6h (RN) / 36h (predmeti) / 7d (PDF crteži).

---

## 3. Šema baze — invarijante koje MORAJU da drže

```
loc_locations
  PK: id UUID
  UNIQUE: (COALESCE(parent_id, '00000000-0000-0000-0000-000000000000'), lower(location_code))
  CHECK: parent_id IS NULL OR parent_id <> id
  FK: parent_id → loc_locations(id) ON DELETE RESTRICT
  BEFORE INSERT/UPDATE trigger: ciklus check (CTE do 200 nivoa), path_cached/depth recompute
  AFTER UPDATE trigger: rekurzivno ažurira potomke kad se promeni parent ili name
  Business hierarchy trigger: HALA mora biti root; POLICA mora imati HALU za roditelja

loc_item_placements (trenutno stanje)
  PK: id UUID
  UNIQUE: (item_ref_table, item_ref_id, order_no, location_id)
  CHECK: quantity > 0
  CHECK: char_length(order_no) <= 40, char_length(drawing_no) <= 40
  FK: location_id → loc_locations(id) ON DELETE RESTRICT  (lokacija sa placement-om ne može da se obriše)

loc_location_movements (append-only istorija)
  Bez UPDATE/DELETE iz klijenta. INSERT samo kroz SECURITY DEFINER RPC.
  AFTER INSERT trigger: UPSERT u placements (TO += qty, FROM -= qty ili DELETE), INSERT u sync queue

loc_sync_outbound_events (queue ka MSSQL workeru)
  Worker pravi FOR UPDATE SKIP LOCKED claim, exp. backoff 2..360min, DEAD_LETTER posle 10 attempts.
  pg_cron purga SYNCED stavke starije od 90 dana.
```

### RLS sažeto
- `loc_locations`: SELECT za sve `authenticated`; INSERT/UPDATE samo ako `loc_can_manage_locations()` (admin/leadpm/pm/menadzment).
- `loc_item_placements`: SELECT za sve `authenticated`. Sav INSERT/UPDATE ide kroz trigger pod SECURITY DEFINER.
- `loc_location_movements`: SELECT za sve `authenticated`. **Nema INSERT policy** — samo RPC.
- `loc_sync_outbound_events`: SELECT samo za admin (`loc_is_admin()`).

### Ključni RPC-ovi
| RPC | Sec | Ko zove | Šta vraća |
|---|---|---|---|
| `loc_create_movement(payload jsonb)` | DEFINER | `authenticated` | `{ok, id}` ili `{ok:false, error: '...', detail?}`. Greške: `not_authenticated`, `missing_fields`, `bad_quantity`, `bad_order_no`, `bad_drawing_no`, `bad_to_location`, `already_placed`, `no_current_placement`, `from_ambiguous`, `from_has_no_placement`, `insufficient_quantity` (sa `available`/`requested`), `exception` (sa `detail`). |
| `loc_report_parts_by_locations(...)` | INVOKER | `authenticated` | `{total, rows}`. Sortovi whitelisted; sve filter parametri ILIKE-bezbedni. |
| `loc_tps_for_predmet(...)` | INVOKER | `authenticated` | `{total, rows}`. Filter MES-aktivni RN, prefix match. |
| `loc_locations_audit(p_limit)` | DEFINER | `authenticated` | Audit log redovi samo za `loc_locations`. |
| `loc_order_no_in_active_proj_mont(p_order_no)` | DEFINER | `authenticated` | boolean — koristi se kao soft upozorenje pre INITIAL_PLACEMENT-a. |
| `loc_claim_sync_events`, `loc_mark_sync_synced`, `loc_mark_sync_failed` | DEFINER | `service_role` samo | Worker API. |
| `_loc_purge_synced_events_cron` | DEFINER | pg_cron only | Retencija. |

---

## 4. KRITIČNE TAČKE — gledati pre svake izmene

### 4.1 Concurrency / race conditions (DB)

**[H1] ✅ REŠENO (Härd-1, 2026-05-15, `harden_loc_create_movement_v5.sql`)** — Advisory `pg_advisory_xact_lock` na hash(item_table, item_id, order_no) pre svake validacije serijalizuje paralelne pozive nad istim bucketom.

`loc_create_movement` ne uzima FOR UPDATE lock na placement pre validacije kapaciteta.
Pseudocode:
```
v_avail = SELECT quantity FROM loc_item_placements WHERE (item, id, order, from_loc)
IF v_qty > v_avail RETURN insufficient_quantity
INSERT INTO loc_location_movements (...)  -- trigger pravi UPDATE qty
```
Dva paralelna RPC poziva sa istim FROM-om i `v_qty = v_avail` mogu obojica proći check. Trigger pravi UPSERT pa će drugi pasti na `CHECK(quantity > 0)` ili `RAISE EXCEPTION` iz trigera (`missing placement on from_location`). To se hvata u `EXCEPTION WHEN others THEN ...` i vraća kao `{ok:false, error:'exception', detail:...}` — UI prikazuje generičku poruku, korisnik ne razume zašto.
**Mitigation:** `SELECT ... FOR UPDATE` na placement red pre validacije, ili premestiti kapacitet check u trigger uz SAVEPOINT.

**[H2] ✅ REŠENO opcijom B (Härd-1, 2026-05-15)** — `already_placed` check je uklonjen; trigger UPSERT sabira količinu na istu (item, order, location). Race postaje semantički ispravan — dva paralelna INITIAL-a sa istim bucketom akumuliraju komada. Advisory lock iz H1 je defense-in-depth.

INITIAL_PLACEMENT race — dvostruko zaduženje.
`v_existing_any = EXISTS (...)` nije unutar lock-a. Dva paralelna INITIAL_PLACEMENT-a za isti `(item, order_no)` na istu policu prolaze check, oba ulaze u INSERT, trigger radi UPSERT `ON CONFLICT (item, id, order_no, location_id) DO UPDATE SET quantity = old.qty + EXCLUDED.qty`. Rezultat: umesto `already_placed` greške, **količine se saberu**. Operativno: dva skenera istovremeno snimaju isti TP i komada postanu duplo.
**Mitigation:** Advisory lock na hash(item_table, item_id, order_no) za vreme RPC poziva, ili `SELECT ... FOR UPDATE` na bilo kojem placement-u tog para.

**[M3] Trigger SECURITY DEFINER pravi sync_outbound_events bez idempotency-a.**
Ako se klijentu ponovi `locCreateMovement` (npr. offline queue retry posle pada mreže gde je server zapravo upisao), pravi se **drugi** movement i drugi sync event. MSSQL strana će izvršiti `sp_ApplyLocationEvent` dvaput.
**Mitigation:** Klijent generiše UUID `event_uuid` pre RPC-a i šalje ga u `payload.idempotency_key`; RPC odbija duplikate. Ili: MSSQL strana drži tabelu primljenih event UUID-a.

### 4.2 Permission gap

**[H4] `loc_create_movement` je GRANT EXECUTE TO authenticated.**
Bilo koji ulogovani korisnik (čak i bez bilo koje uloge u `user_roles`) može da izvrši premeštanje. Provera u RPC-u je samo `auth.uid() IS NOT NULL`. Trenutno `canEdit()` u JS proverava ulogu pre nego što prikaže dugmad, ali to je samo UI gate — direktan POST `/rest/v1/rpc/loc_create_movement` zaobilazi UI.
**Mitigation:** Dodati u RPC `IF NOT (loc_auth_roles() && ARRAY['admin','leadpm','pm','menadzment','viewer']) THEN RETURN not_authorized` (sa eksplicitnom listom uloga koje smeju da skeniraju). Trenutno svako sa Supabase nalogom može da pokvari stanje.

**[M5] ✅ REŠENO (Härd-1, 2026-05-15)** — RPC sada rekurzivnim CTE prolazi `parent_id` chain odredišne lokacije; ako bilo koji predak (do dubine 200, defense protiv pokvarene hijerarhije) ima `is_active=false`, vraća `{ok:false, error:'parent_inactive'}`. UI prikazuje: "Hala (ili neki nadređeni prostor) je deaktivirana — premeštanje nije moguće."

Premeštanje na deaktiviranu HALU.
RPC validira samo `v_to.is_active`. Ako je hala deaktivirana (`is_active=false`), a polica u njoj je ostala aktivna, premeštanje prolazi. Logički nedoslednо — operater može zatrpavati „mrtvu” halu.

### 4.3 Data integrity / parsing

**[M6] `drawing_no` se izvlači regex-om iz `note`.**
Trigger v4: `substring(NEW.note FROM 'Crte[žz]:([^\s|]+)')`. Ako korisnik upiše ručnu napomenu „Vidimo se Crtež: 5678 u petak", regex izvuče `5678` i upiše u placement.drawing_no. Korupcija podatka.
**Mitigation:** Strožiji regex (samo na početku reda) ili napustiti regex fallback sad kad je drawing_no first-class.

**[M7] Trigger ne enforce-uje da `NEW.drawing_no` ostane vezan za `(item, order)`.**
Dva movement-a sa istim (item, order, location) ali različitim `drawing_no` rezultiraju da poslednji „wins”. Nije provera — placement.drawing_no je „poslednji upisan”, pa istorija može da divergira od reportinga.

**[M8] `loc_report_parts_by_locations` opušteni varijant match.**
Migracija `add_loc_report_ident_broj_variant_match.sql` matchuje `order_no=9400, item_ref_id=415` ↔ `bigtehn_work_orders_cache.ident_broj=9400-2/415` (sufiks varijanta). Match prolazi SAMO ako tačno jedan kandidat postoji. Ako je u kešu BigTehn-a `9400-2/415` i `9400-3/415` istovremeno, NIJEDAN se ne matchuje i red u report-u nema BigTehn meta — UI prikazuje „—" za naziv dela / kupca, mada lokacija postoji.

### 4.4 Frontend race conditions

**[H9] `decodeBusy` flag u scanModal.**
[src/ui/lokacije/scanModal.js:544-580](../src/ui/lokacije/scanModal.js#L544) — sprečava double-decode dok je form modal mid-await. `try/finally` resetuje, ali ako modal bude zatvoren između `setTimeout` re-init-a, listener može da pokuša da postavi flag na obrisanom DOM elementu.

**[H10] ESC key listener leak u `openLocationModal`.**
[src/ui/lokacije/modals.js:196-214](../src/ui/lokacije/modals.js#L196) — listener se vezuje pre `await fetchLocations()`. Ako fetch baci exception, modal se ne otvori a `unbindEsc` ostaje `null` → listener zaglavljen na document-u.

**[H11] `wireTabs` document listeneri nikad se ne uklanjaju.**
[src/ui/lokacije/index.js:2321-2335](../src/ui/lokacije/index.js#L2321) — `mousedown`/`keydown`/`resize`/`scroll` na document/window. `teardownLokacijeModule()` ih NE čisti. Pri SPA re-mount-u modula listeneri se dupliraju.

**[M12] Tab strip se re-render-uje na svakoj promeni taba.**
[index.js:2285-2298](../src/ui/lokacije/index.js#L2285) — `nav.replaceWith(fresh)` briše DOM. Pošto je click delegiran na `container`, funkcionalno radi; ali ako bilo koji feature kasnije veže listener direktno na `.loc-tab`, biće tihо otkačen.

**[M13] ERP lookup token race u modals.js `openQuickMoveModal`.**
[modals.js:1141, 1222-1232](../src/ui/lokacije/modals.js#L1141) — `lookupToken` se inkrementuje POSLE debounce-a. Brzo pucanje order+TP polja može vratiti stari rezultat ako je novi debounce kasnije scheduledован. Idealno: token++ pre debounce.

**[M14] In-memory queue za batch štampu se briše na reload.**
[labelsPrintPage.js:49-58](../src/ui/lokacije/labelsPrintPage.js#L49) — namerno bez LS perzistencije. Ako korisnik slučajno refresha pre nego štampu pošalje, gubi listu. Nije bug po spec-u, ali UX rizik.

### 4.5 Offline / mrežni padovi

**[H15] ✅ REŠENO (Härd-1, 2026-05-15)** — Klijent generiše `client_event_uuid` (UUID v4) u `services/lokacije.js:locCreateMovement` ili `services/offlineQueue.js:enqueueMovement` pre prvog poziva. Migracija dodaje partial UNIQUE indeks `uq_loc_movements_client_event_uuid` na `loc_location_movements`. RPC vraća `{ok:true, idempotent:true, id:<existing>}` za poznat UUID — retry je bezbedan. UUID je **opcioni** (Q1=A iz sprint analize): drugi moduli (Reversi, Štampa nalepnica) i dalje rade bez izmena jer RPC sam generiše ako payload ne nosi UUID.

Offline queue može pravi duplikate.
[src/ui/lokacije/scanModal.js:1945-1978](../src/ui/lokacije/scanModal.js#L1945) i pendant u modals.js — ako `locCreateMovement` server-side prođe, ali response ne stigne (timeout, network drop), klijent zaključi „fail" i `enqueueMovement()` ga ponovo. Worker će drugi put pokušati isti payload bez idempotency ključa. Komentari u kodu eksplicitno priznaju mogućnost.
**Mitigation:** Klijent generiše UUID v4 i šalje kao `payload.client_event_uuid`. RPC drži tabelu primljenih UUID-a ili koristi `INSERT ... ON CONFLICT (client_event_uuid) DO NOTHING`.

**[M16] `navigator.onLine` false negative na slaboj WiFi.**
Klijent može da odluči da je online, posle pokušaja koji visi 30s ode u timeout. Hard timeout u `sbReq` (videti `services/supabase.js`) nije dokumentovan u modulu Lokacije.

**[M17] BRIDGE cache zastareo a korisnik svejedno snima.**
Banner postoji, ali ne blokira flow. Snimanje crteža koga nema u kešu može da rezultira `bad_quantity` / `from_has_no_placement` u downstream-u jer placement.drawing_no ne match-uje report.

### 4.6 Performance

**[M18] `fetchLocations()` učitava SVE lokacije svaki put.**
Bez pagination, bez cache-a. Pri 5–10K polica (10 hala × 1000 polica je realan plan; vidi `HALA 3 shelves E1-E100` migraciju u git status), svaki `refreshLocPanel` povlači ceo set. Browser će uspešno renderovati tabelu (virtualization nigde), ali mreža će biti sporadično skupa.
**Mitigation:** Klijentski cache sa ETag-om / `If-Modified-Since` (PostgREST podržava), ili lazy-load po hali.

**[M19] Export hard cap 50,000 redova.**
[services/lokacije.js:108, 367, 542](../src/services/lokacije.js#L108) — `HARD_CAP = 50_000` u tri funkcije. Realan modul za 1–2 godine može preći taj broj. Truncated alert se prikaže, ali fajl je nepotpun.

**[M20] `loc_report_parts_by_locations` joinuje 5 tabela + LATERAL subselect.**
Pri 100K placement-a + 50K BigTehn RN-ova upit može da bude spor (>5s). Bez analizovanog plana, idx-i nisu garancija. LATERAL sa UNION ALL po `match_rank` skenira `bigtehn_work_orders_cache` dvaput.

**[L21] Predmet tab šalje 3 paralelna RPC poziva.**
[predmetTab.js:285-288](../src/ui/lokacije/predmetTab.js#L285) — count(with) + count(without) + page rows. Promise.all bez timeout-a. Ako server visi, ekran ostaje na loading-u beskonačno.

### 4.7 Sigurnost / XSS

**[L22] `escHtml` konzistentno korišćen.** Sve render funkcije u svim fajlovima koriste `escHtml()` iz `lib/dom.js`. Spot check nije našao raw `innerHTML` sa korisničkim input-om.

**[L23] Smart quotes u Edit-u.** Iz memorije: Edit tool ranije ubacivao curly quotes u JS template literale što kvari HTML atribute. Aktuelno stanje: pažljivo proveriti diff svake izmene `*.js` u Lokacije modulu.

**[L24] CSV injection.**
`rowsToCsv` u `lib/csv.js` (nije pregledan ovde, ali pretpostavlja se da escape-uje navodnike). Ako neko unese `note` koji počinje sa `=cmd|...`, Excel može da pokrene formulu. Provera vredi.

**[L25] localStorage `loc_drawing_cache_v1` deljen između scan i modal flow-a.**
Bez cross-tab sync. Manje važno jer su podaci ne-osetljivi.

### 4.8 Operacioni / out-of-band

**[H26] pg_cron retencija pretpostavlja PAID Supabase tier.**
Komentari u `add_loc_step4_pgcron.sql` priznaju da CREATE EXTENSION za pg_cron zahteva odgovarajuće privilegije. Na dev/lokal `loc_sync_outbound_events` raste bez ograničenja.

**[H27] DEAD_LETTER stavke nisu vidljive operativnom korisniku.**
Posle 10 neuspeha sync event ide u DEAD_LETTER. Samo admin vidi `loc_sync_outbound_events` (RLS). Ne postoji UI alert „X događaja čeka ručnu intervenciju”. Premeštanje je primljeno u Supabase, ali MSSQL strana zauvek ne zna.

**[M28] Nema worker health-check-a.**
`fetchBridgeSyncStatus()` čita `bridge_sync_log` za BigTehn cache, ali NEMA pandant za `loc-sync-mssql` worker. Ako worker padne, sync queue se gomila tiho.

**[M29] `approved_by` / `approved_at` su mrtve kolone.**
[add_loc_module.sql:108-109](../sql/migrations/add_loc_module.sql#L108) — kolone postoje, nikad se ne setuju. Bilo je verovatno predviđeno za odobravanje pokreta. Ako se u budućnosti dodaje workflow odobravanja, treba paziti da postojeća istorija ima `approved_*` NULL.

**[M30] Migracioni redosled nije auto-enforce-an.**
Komentari govore „Primeni NAKON xyz”. Supabase SQL editor ne validira. Ako neko pokrene v4 pre v3, pada na missing constraint.

### 4.9 UX / poslovni rizici

**[M31] Customer/predmet/projekat dolaze iz cache-a, ne real-time.**
Ako je predmet zatvoren u BigTehn-u poslednjih sat vremena, korisnik ga i dalje vidi (catalog_items sync je 36h prag pre staleness banner-a). Premeštanje za zatvoren predmet ne treba blokirati (operativno može da bude legitimno), ali UI bi mogao da označi.

**[M32] `is_mes_active` filter u Predmet tabu skriva RN-ove koji nisu na MES listi.**
Ako MES lista nije ažurirana, operater ne vidi nove RN-ove iako su u BigTehn-u. Tom prilikom pretraga preko `searchBigtehnWorkOrders` daje samo MES-aktivne (`v_active_bigtehn_work_orders`); generička `searchBigtehnWorkOrdersForItem` ide preko view-a sa MES kolonom ali bez filtera.

**[M33] Bulk kreiranje polica nije atomarno.**
[modals.js:436-483](../src/ui/lokacije/modals.js#L436) — loop `for n in from..to` zove `createLocation` pojedinačno. Ako se 7. polica srušila zbog duplikata, prvih 6 ostaju kreirane, korisnik vidi „Kreirano 6, neuspešno 24”. Toast obavestava, ali nema rollback-a.

**[L34] „Praktične" greške RPC-a koje se vraćaju kao `exception`.**
Sve neoznačene greške (npr. `CHECK(quantity > 0)`) padaju u `WHEN others` i prikazuju se generično. Operater nema info o root cause-u.

---

## 5. Bezbedne izmene — gde lako možeš da slomiš stvari

| Akcija | Rizik | Kako proveriti |
|---|---|---|
| Promena `loc_after_movement_insert` trigger-a | Sve premeštanje. Test: napraviti INITIAL → TRANSFER → još jedan TRANSFER → REMOVAL u istom (item, order) i proveriti placements aritmetiku. | SQL test sa pg_isolation_test ili integration test. |
| Dodavanje nove kolone u placements | Mora se proveriti svaki RPC koji vraća placement (report, items, predmet). | Grep `loc_item_placements?select=*` — vraća sve kolone. PostgREST-ov `select=*` automatski povlači nove. |
| Promena `loc_create_movement` payload schema | scanModal, modals (quickMove), batch flow. Sva 3 mesta zovu sa različitim payload oblicima. | Grep `locCreateMovement(` i `rpc/loc_create_movement`. |
| Promena `escHtml` ponašanja u `lib/dom.js` | Sva 11K linija UI render. | Test sa `<script>alert(1)</script>` u location_code, name, notes. |
| Promena natural sort-a | Browse table, hall dropdown, location options u report. | Vizuelni test sa A1, A2, A10, A100. |
| Promena state validacije | LS perzistencija. Stara LS vrednost može biti pogrešna pa whitelist treba da je apsorbuje. | Test: setItem-uj korumpiranu vrednost i proveri da `loadLokacijeTabFromStorage` ne pukne. |

---

## 6. Reliability checklist pre produkcije / kritičnih izmena

- [ ] **Idempotency**: dodati `client_event_uuid` u `loc_create_movement` payload, dedup u RPC-u (offline queue retry safe).
- [ ] **Advisory lock** ili `SELECT ... FOR UPDATE` u RPC-u pre validacije kapaciteta i `v_existing_any`.
- [ ] **Permission**: ograničiti `loc_create_movement` na konkretne uloge u RPC-u (ne samo `authenticated`).
- [ ] **DEAD_LETTER monitor**: dodati admin notification (slack/email) kad event ide u DEAD_LETTER.
- [ ] **Hala-deaktivacija**: rekurzivna provera predaka u RPC `loc_create_movement`.
- [ ] **`drawing_no` regex** u trigger-u — strožije ili eliminisati (svi noviji klijenti šalju eksplicitno).
- [ ] **Document listener cleanup** u `teardownLokacijeModule` (`mousedown`, `keydown`, `resize`, `scroll`).
- [ ] **ESC listener leak fix** u `openLocationModal` (`try/finally` oko `fetchLocations`).
- [ ] **CSV injection** test za `note` koji počinje sa `=`, `+`, `-`, `@`.
- [ ] **Sync worker health endpoint** — banner ako worker ne radi.
- [ ] **`loc_report_parts_by_locations` EXPLAIN ANALYZE** na ciljnoj zapremini (100K+ placements).
- [ ] **AbortController** na export i predmet tab fetch-evima.
- [ ] **Tests**: izolacioni test za concurrent INITIAL_PLACEMENT, concurrent TRANSFER, hala deactivacija.

---

## 7. Glosar / pojmovi koji često zbunjuju agenta

| Termin | Značenje |
|---|---|
| HALA | Root lokacija (`parent_id IS NULL`), tipa WAREHOUSE/PRODUCTION/ASSEMBLY/FIELD/TEMP. |
| POLICA | Lokacija unutar hale, tipa SHELF/RACK/BIN. |
| Predmet | BigTehn entitet (`bigtehn_items_cache`), broj predmeta = `broj_predmeta` (npr. `9400`). |
| Nalog / RN | Radni nalog. `order_no` u placement-u je `split_part(ident_broj, '/', 1)` BigTehn ident-a. Operativno = broj predmeta. |
| TP | Tehnološki postupak. `item_ref_id` = `split_part(ident_broj, '/', 2)`. Npr. `9400/755` → predmet 9400, TP 755. |
| Crtež | `drawing_no` / `broj_crteza`. Različito od TP. |
| RNZ barkod | Format `BROJ_NALOGA|BROJ_TP` na BigTehn nalepnici (npr. `7351\|1088`). |
| LP barkod | Format `LP:UUID_HALE:UUID_POLICE` na servoteh nalepnici police. |
| Placement | Trenutno stanje stavke na lokaciji. Jedan red po `(item, order, location)` bucketu. |
| Movement | Append-only istorijski događaj. INSERT samo kroz RPC. |
| Bucket | `(item_ref_table, item_ref_id, order_no)` — sve police gde je „taj komad iz tog naloga”. |

---

## 8. Šta ovaj dokument NE pokriva

- `workers/loc-sync-mssql/` — Node worker logika i MSSQL `sp_ApplyLocationEvent`.
- BRIDGE (MSSQL → Supabase cache sync) — to je `src/services/bridge.js` / odvojeni worker.
- `bigtehn_*_cache` šeme — pogledaj `docs/migration/04-qbigtehn-schema-inventory.md`.
- TSPL2 generator — `src/lib/tspl2.js` i `src/lib/labels/*`.
- Mobilni `/m/lookup` ekran — odvojen view, deli neke services helper-e.
- Storage RLS za PDF crteže — `src/services/drawings.js`.

---

## 9. Citati linija za AI agenta

Kada agent radi izmene, navedi konkretne lokacije:
- [Migracija v4 (drawing_no)](../sql/migrations/add_loc_v4_drawing_no.sql)
- [RPC loc_create_movement najnovija verzija](../sql/migrations/add_loc_v4_drawing_no.sql#L209)
- [RPC loc_report_parts_by_locations (varijant match)](../sql/migrations/add_loc_report_ident_broj_variant_match.sql)
- [RPC loc_tps_for_predmet v3](../sql/migrations/add_loc_tps_for_predmet_rpc_v3.sql)
- [Hijerarhija pravila trigger](../sql/migrations/add_loc_location_hierarchy_rules.sql)
- [Worker sync RPC-ovi](../sql/migrations/add_loc_step5_sync_rpcs.sql)
- [scanModal: decodeBusy + iOS hack](../src/ui/lokacije/scanModal.js#L420)
- [modals: bulk shelf generator](../src/ui/lokacije/modals.js#L349)
- [services: PostgREST helperi](../src/services/lokacije.js)
- [index.js: tab routing + listener leak rizik](../src/ui/lokacije/index.js#L2217)

---

**Verzija:** 2026-05-15 · **Autor:** automatska analiza (Claude Opus 4.7, 1M context) · **Status:** za internu reliability review.

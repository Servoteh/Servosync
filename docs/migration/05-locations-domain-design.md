# 05 — Locations / Inventory domain design (Faza 2)

> **Status:** skeleton v0.1
> **Datum:** 2026-05-15
> **Cilj:** definisati Postgres `inventory` šemu za Fazu 2 zasnovanu na obrascima iz modula Lokacije (Faza 1).
> **Vlasnik:** team-erp (predlog autora: Jara).
>
> **Ovo NIJE migracioni script.** Ovo je predlog arhitekture. Konkretne migracije se pišu tek posle PR review-a ovog dokumenta.

---

## 0. Kontekst

Modul Lokacije u Fazi 1 (`src/ui/lokacije`, `loc_*` tabele, `workers/loc-sync-mssql`) je tokom 2026-Q1/Q2 prošao kroz 4 hardening sprinta:

| Sprint | Commit | Šta donosi |
|---|---|---|
| Härd-1 | `33c6d7b` | Idempotency UUID + advisory lock + INITIAL akumulacija (opcija B) + parent_inactive |
| Härd-2 | `620e6ca` | Autorizacija `loc_can_create_movement` + CSV injection escape |
| Härd-3 | `3e4ca5b` | Worker heartbeat + DEAD_LETTER digest + UI banner + migration runbook |
| Härd-4 | `37454aa` | Document listener cleanup + try/catch u modalu + AbortController + `decodeBusy` isConnected check |

Ovi obrasci su sažeti u [04-qbigtehn-schema-inventory.md §5b](04-qbigtehn-schema-inventory.md#5b-lokacije-modul--validan-obrazac-za-fazu-2-inventory-domen).

**Faza 2 cilj:** premestiti kanonski izvor istine za inventory iz MSSQL-a (`QBigTehn` šema) u Postgres `inventory.*` šemu. Lokacije modul je polazna tačka — njegov DB model + RPC API postaju jezgro `inventory` domena.

---

## 1. Šema predloga

### 1.1 Tabele (kanonske)

```
inventory.locations               -- iz loc_locations (rename + scoped namespace)
inventory.location_movements      -- iz loc_location_movements
inventory.item_placements         -- iz loc_item_placements
inventory.sync_outbound_events    -- iz loc_sync_outbound_events
inventory.sync_worker_heartbeat   -- iz loc_sync_worker_heartbeat (Härd-3)
inventory.sync_alerts_outbox      -- iz loc_sync_alerts_outbox (Härd-3)

-- novo u Fazi 2:
inventory.legacy_id_map           -- staging: legacy_bigtehn_idrn → inventory.* PK
inventory.audit_log               -- domen-lokalan audit (ako odvojeno od public.audit_log)
```

Migration namespace (`public.loc_*` → `inventory.*`) dolazi kroz **rename-in-place** uz aliase / view-ove za backwards compat tokom kohabitacijskog perioda. Detalj: vidi §4.

### 1.2 Ključne kolone (mapping iz Faze 1)

`inventory.item_placements` zadržava trojku `(item_ref_table, item_ref_id, order_no)` jer to dolazi iz BigTehn ident_broj-a (`9400/755`). U Fazi 2 to postaje `(sku_id BIGINT, order_id BIGINT)` kad `sku` i `production.work_orders` postoje kao kanonski entiteti — sa staging mapping slojem (`inventory.legacy_id_map`) za prelaz.

Dodatne kolone:
- `cost_center_id` — za finansijsku alokaciju (BigTehn ima ovo razdvojeno po RJ).
- `reservation_state` — `available | reserved | committed | scrapped` (postojeći `placement_status` se mapira).

### 1.3 Hijerarhija lokacija

Zadržati postojeću dvonivovsku **HALA → POLICA** strukturu sa `loc_locations_guard_and_path` i `loc_locations_enforce_business_hierarchy` trigger-ima. Dodaci:
- Treći nivo `SUB-POLICA` (opcioni) za detaljniji regal/red/polica drilldown. Trigger forsira: HALA → POLICA → opcioni BIN.
- `location_capacity_kg`, `location_capacity_m3` numeričke kolone (placeholder za fizičke limite).

### 1.4 RPC API

| RPC (Faza 2) | Iz Faze 1 | Promene |
|---|---|---|
| `inventory.create_movement(payload jsonb)` | `loc_create_movement` v5+roles | Zadržava: idempotency UUID, advisory lock, parent_inactive, constraint_violation. Dodaje: `cost_center_id` u payload-u; `reservation_state` enum support. |
| `inventory.report_by_location(filters jsonb)` | `loc_report_parts_by_locations` | Refaktor join-ova: umesto BigTehn cache, direktan join na `production.work_orders` (kad postane kanonski). |
| `inventory.health_summary()` | `loc_sync_health_summary` | Isti shape; novi `sync_target` ('mssql' | 'native') flag za prelazni period. |
| `inventory.can_create_movement()` | `loc_can_create_movement` | Email → `auth.users` mapping. Faza 2 cilj: napraviti `employees.auth_user_id` FK i preći na UID-based check. Tokom prelaza oba puta. |
| Worker API (`claim_sync_events`, `mark_*`) | `loc_claim_sync_events` itd. | Isti. Brišu se kad MSSQL ode u arhivu. |

### 1.5 Outbox i sync — fade-out plan

Outbox + worker pattern (`loc_sync_outbound_events` + `loc-sync-mssql`) je **transient**. Logika:
- Faza 2a (kohabitacija sa BigTehn-om): outbox aktivan, Lokacije/Inventory pišu u Postgres a worker sinhronizuje u MSSQL `QBigTehn`.
- Faza 2b (MSSQL u arhivi): outbox postaje read-only za audit, worker se gasi, `target_procedure='dbo.sp_ApplyLocationEvent'` ostaje istorijski podatak.
- Faza 3 (pun cut-over): outbox tabela se rename-uje u `inventory.legacy_sync_audit`, DEAD_LETTER stavke postaju trag istorijskih problema.

---

## 2. Pattern check-lista (Härd-1..Härd-4 obrasci)

Svaka tabela / RPC u `inventory.*` namespace-u mora da prati:

- [ ] **Idempotency**: `client_event_uuid` u movements; partial UNIQUE indeks; RPC vraća `idempotent:true` na replay.
- [ ] **Advisory lock**: na bucket level pre validacije kapaciteta.
- [ ] **Auth**: email-based + role check (admin/leadpm/pm/menadzment + employees u relevantnim odeljenjima). Glavnoj write RPC ide `IF NOT can_X() THEN not_authorized`.
- [ ] **Hierarchy guard**: trigger sprečava cikluse, recompute path_cached, business hierarchy enforce.
- [ ] **RLS**: SELECT za authenticated, INSERT/UPDATE samo kroz SECURITY DEFINER RPC. **Nema INSERT policy na write tabelama.**
- [ ] **Constraint violation handling**: eksplicitno `WHEN unique_violation` / `WHEN check_violation` u RPC-u; vraća `constraint_violation` sa detaljem.
- [ ] **Soft delete / archive**: `is_active BOOLEAN` umesto DELETE; rekurzivna provera predaka u RPC-u.
- [ ] **Audit log**: trigger u `audit_log` ili lokalni `inventory.audit_log`; admin-only RPC za čitanje.
- [ ] **Migration runbook**: `XX_inventory_migration_order.md` sa rollback skriptama.

---

## 3. UI obrasci (Faza 2)

Frontend za inventory u Fazi 2 zadržava obrazce iz `src/ui/lokacije/*`:

- **`teardownModule` + disposers niz** za sve document/window listenere.
- **`try/catch` oko async IIFE u modalima** sa garantovanim `close()` u catch grani.
- **`AbortController` + 30s timeout** za sve `Promise.all` koji čekaju mrežu.
- **`escHtml`/`toCsvField` injection escape** za sve user-facing render-e i CSV export-e.
- **`isConnected` check pre svake DOM operacije u async callback-ima** (npr. iz kamere/scanner-a).
- **In-memory state vs LS perzistencija** — eksplicitan izbor po komponenti; UI state (filteri, paginacija) u LS sa whitelist validacijama, ali offline queue u LS sa idempotency UUID-om.

---

## 4. Migracioni plan (transient)

### Faza 2a — kohabitacija

1. Kreiraj `inventory` šemu i tabele kopiranjem `loc_*` definicija (CREATE OR REPLACE VIEW za backwards compat).
2. Klijenti i dalje koriste `public.loc_*` view-ove kao alias.
3. Worker i dalje sinhronizuje sa MSSQL-om.
4. Nove RPC-ove u `inventory.*` namespace; stari `public.loc_*` ostaju do brisanja.

### Faza 2b — cut-over MSSQL

1. BigTehn cache (`bigtehn_*_cache`) postaje archive-only — staging za poslednji read.
2. RPC `loc_report_parts_by_locations` se refaktoriše da joinuje `production.work_orders` umesto `bigtehn_work_orders_cache`.
3. Worker `loc-sync-mssql` se gasi; outbox tabela ostaje za audit.

### Faza 3 — namespace flip

1. `public.loc_*` view-ovi se brišu.
2. UI/services se updejtuju da koriste `inventory.*` direktno.
3. Worker fajlovi se brišu iz repo-a; runbook updejtuje istorijski citat.

---

## 5. Ograničenja / otvorena pitanja

- **`employees.auth_user_id`** ne postoji. Faza 2 treba da odluči: dodati to polje (sa migracijom iz email-a) ili nastaviti sa email-mapping-om. Email-mapping radi ali znači da promena email-a (zaposleni → udaja) razbija role check dok se `user_roles.email` ne updejtuje.
- **`order_no` semantika**: u Lokacije modulu = broj predmeta iz BigTehn ident_broj-a. U Fazi 2 može da postane FK na `production.work_orders.id`, ali tada gubimo „bez naloga" bucket (`order_no = ''` u Härd-1). Treba odluka: ostaje TEXT sa konvencijom, ili FK sa nullable + business rule.
- **`item_ref_table` polimorfizam**: trenutno može biti `'bigtehn_rn'`, `'rev_tools'`, itd. Faza 2 može da konsoliduje u `sku_id BIGINT` sa enum-om tipa SKU, ali to je veliki refactor (Reversi i drugi konzumeri).
- **`drawing_no` regex backfill**: legacy trigger iz Härd-1/v4 izvlači `drawing_no` iz `note` regex-om. Faza 2 može da eliminiše regex jednom kad svi klijenti pošalju drawing_no eksplicitno. Treba inventura legacy redova pre brisanja.
- **DEAD_LETTER permanentno čuvanje**: 90-dnevni purge iz `add_loc_step4_pgcron.sql` briše SYNCED stavke, ne DEAD_LETTER. Treba odluka kako se DEAD_LETTER arhiviraju.

---

## 6. Reference

- [Lokacije analiza modula (Härd-1..H-4 ✅)](../Lokacije_modul_analiza.md)
- [Migration runbook (Faza 1)](loc_migration_order.md)
- [QBigTehn schema inventory §5b](04-qbigtehn-schema-inventory.md#5b-lokacije-modul--validan-obrazac-za-fazu-2-inventory-domen)
- Sprint analize: [sprint-1](../lokacije/sprint-1-analiza.md), [sprint-2](../lokacije/sprint-2-analiza.md), [sprint-3](../lokacije/sprint-3-analiza.md), [sprint-4](../lokacije/sprint-4-analiza.md)

---

**Sledeći korak:** PR review ovog skeleton-a od strane team-erp-a. Posle prihvatanja:
1. Detaljan ER dijagram `inventory.*` šeme.
2. Prvi `inventory_schema_baseline.sql` u `sql/migrations/` (samo CREATE TABLE + RLS, bez podataka).
3. `inventory_migration_order.md` runbook po obrascu Faze 1.

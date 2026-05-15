# Sprint LOC-Härd-1 — Korak 1 analiza

**Status:** faktografski izveštaj pre pisanja koda. **NE krećemo dalje bez potvrde.**
**Datum:** 2026-05-15
**Sprint dokument:** `HARDENING_SPRINTS.md` (Härd-1)

---

## 1. Inventar poziva `locCreateMovement`

Stvarno stanje: **6 call-sajt-ova** (sprint dokument navodi 3). Šira slika je važna jer migracija menja RPC potpis i `client_event_uuid` mora doći sa SVAKOG mesta.

| # | Fajl | Linija | Kontekst | Payload (ključna polja) |
|---|---|---|---|---|
| 1 | `src/services/lokacije.js` | 461 | **Definicija** wrapper-a `locCreateMovement(payload)`. Šalje `{ payload }` (jedini parametar, wrapper objekat) preko `sbReq('rpc/loc_create_movement', 'POST', { payload })`. | — |
| 2 | `src/services/offlineQueue.js` | 162 | Auto-flush retry. **Šalje TAČAN payload iz LS reda** (`entry.payload`). Idempotency UUID koji se ubaci u payload pre `enqueueMovement` automatski opstaje kroz retry. | sačuvan payload kakav je |
| 3 | `src/services/reversiService.js` | 398 | `initialPlacementForTool`. **DRUGI MODUL (Reversi)**. | `{ item_ref_table: 'rev_tools', item_ref_id: <numerički>, movement_type: 'INITIAL_PLACEMENT', to_location_id, ... }` — `item_ref_table` ≠ `'bigtehn_rn'`. |
| 4 | `src/ui/lokacije/modals.js` | 1508 | `openQuickMoveModal` (manual unos, bez kamere). | `{ item_ref_table, item_ref_id, order_no, drawing_no?, to_location_id, from_location_id?, movement_type, quantity, note? }` |
| 5 | `src/ui/lokacije/scanModal.js` | 2018 | Glavni scan flow (single skener). Pre poziva proverava `navigator.onLine` i `enqueueMovement` na L2003. Na exception (L2022) takođe `enqueueMovement`. | isti shape kao #4, plus `movement_type: 'INITIAL_PLACEMENT' \| 'TRANSFER'` |
| 6 | `src/ui/mobile/mobileBatch.js` | 374, 379 | Batch slanje skeniranih redova. **Linija 379 je auto-fallback**: ako prvi poziv (`INITIAL_PLACEMENT`) vrati `already_placed`, drugi poziv šalje isto sa `movement_type: 'TRANSFER'`. | isti shape |
| 7 | `src/ui/stampaNalepnica/index.js` | 954, 992 | **DRUGI MODUL (Štampa nalepnica).** Dve instance — provera + kreiranje. | `{ item_ref_table: 'bigtehn_rn', item_ref_id: tpPart, ... }` |

**Bitno za sprint plan:**
- Sprint dokument je naveo `labelsPrintPage.js` kao treću UI lokaciju — **u stvari tu nema poziva** (`grep locCreateMovement` u tom fajlu → 0). Batch štampa NE pravi pokrete.
- Reversi (`reversiService.js`) i `stampaNalepnica/index.js` su **drugi moduli**. Sprint pravila eksplicitno zabranjuju izmene drugih modula. Posledica: u Koraku 2 i 3 mora se odlučiti — ili `client_event_uuid` ostaje **opcioni parametar** (RPC ga generiše ako nedostaje), ili se i ti pozivi pateju kao "neophodni minimum" jer dele isti RPC.
- `mobileBatch.js:377-381` ima fallback put kroz `already_placed`. Opcija B ukida tu grešku za INITIAL_PLACEMENT → fallback postaje **dead code** (nikad se neće okinuti). Treba ga ili ukloniti, ili ostaviti ali zabeležiti kao dead path.

## 2. Pseudocode trenutne v4 RPC logike `loc_create_movement`

```
1.  v_uid = auth.uid()
2.  IF v_uid IS NULL → {ok:false, error:'not_authenticated'}
3.  Parse payload polja: item_ref_table, item_ref_id (TEXT, ne bigint!),
       order_no (default ''), drawing_no (default ''),
       movement_type, quantity (default 1), to_location_id, from_location_id
4.  IF v_qty IS NULL OR <= 0 → bad_quantity
5.  IF char_length(order_no) > 40 → bad_order_no
6.  IF char_length(drawing_no) > 40 → bad_drawing_no
7.  IF item_table/id/to/mtype missing → missing_fields
8.  IF NOT EXISTS(loc_locations WHERE id=v_to AND is_active) → bad_to_location
9.  v_existing_any = EXISTS(placements za (item_table, item_id, order_no))
10. SWITCH movement_type:
      INITIAL_PLACEMENT:
         IF v_existing_any → already_placed
         v_from = NULL
      INVENTORY_ADJUSTMENT:
         v_from = NULL
      ostali (TRANSFER, REMOVAL, SCRAP, ...):
         IF v_from IS NULL:
            v_cnt = COUNT(placements za (item, id, order))
            IF 0 → no_current_placement
            IF > 1 → from_ambiguous
            v_from = (taj jedini)
         v_avail = quantity iz placement na v_from
         IF v_avail IS NULL → from_has_no_placement
         IF v_qty > v_avail → insufficient_quantity (sa available/requested)
11. INSERT INTO loc_location_movements (...) RETURNING id
    → trigger loc_after_movement_insert (v4) radi UPSERT placements + insert sync queue
12. RETURN {ok:true, id}
13. EXCEPTION WHEN others → {ok:false, error:'exception', detail:SQLERRM}
```

**Tačan potpis koji sprint mora da zadrži:**
`public.loc_create_movement(payload jsonb) RETURNS jsonb` sa wrapperom `{ payload: { ... } }` na klijent strani (NE `p_payload` kao u draftu sprinta — postojeći wrapper koristi ime `payload`).

## 3. Postojeća unique / CHECK ograničenja

### `loc_item_placements`
- **UNIQUE** `loc_item_placements_item_order_loc_uq` na `(item_ref_table, item_ref_id, order_no, location_id)` (v3 migracija; v1 i v2 nazivi `loc_item_placements_item_uq` / `loc_item_placements_item_loc_uq` su drop-ovani).
- **CHECK** `loc_item_placements_qty_pos_chk` na `quantity > 0` (v2).
- **CHECK** `loc_item_placements_order_no_len_chk` na `char_length(order_no) <= 40` (v3).
- **CHECK** `loc_item_placements_drawing_no_len_chk` na `char_length(drawing_no) <= 40` (v4).
- FK `location_id → loc_locations(id) ON DELETE RESTRICT`.

### `loc_location_movements`
- **CHECK** `loc_location_movements_qty_pos_chk` na `quantity > 0` (v2).
- **CHECK** `loc_location_movements_order_no_len_chk` na `char_length(order_no) <= 40` (v3).
- **CHECK** `loc_location_movements_drawing_no_len_chk` na `char_length(drawing_no) <= 40` (v4).
- Partial indeksi: `loc_location_movements_order_no_idx`, `loc_location_movements_drawing_no_idx`, `loc_mov_item_idx`, `loc_mov_to_idx`, `loc_mov_sync_pending_idx`.
- FK `to_location_id → loc_locations(id) ON DELETE RESTRICT`, `moved_by → auth.users(id) ON DELETE RESTRICT`.
- **NEMA INSERT RLS policy** — INSERT samo kroz SECURITY DEFINER RPC.

### Grep verifikacija imena indeksa
`grep -r 'uq_loc_movements'` → 0 matches. Predloženo ime `uq_loc_movements_client_event_uuid` slobodno.

## 4. Spisak grešaka koje trenutni RPC vraća (sa primerima UI poruka)

| `error` | Šta znači | Postojeće UI poruke (manje-više) |
|---|---|---|
| `not_authenticated` | `auth.uid() IS NULL` | "Niste prijavljeni." (scanModal `errMsg`) |
| `missing_fields` | obavezno polje nedostaje | "Nedostaju polja u zahtevu." |
| `bad_quantity` | qty <= 0 ili NULL | "Količina nije validna." |
| `bad_order_no` | length > 40 | "Broj naloga je predugačak." |
| `bad_drawing_no` | length > 40 | "Broj crteža je predugačak." |
| `bad_to_location` | TO ne postoji ili nije aktivna | "Odredište nije važeća polica." |
| `already_placed` | `v_existing_any` na INITIAL | **UKIDA SE u Härd-1 (opcija B).** Trenutna poruka: "Već postoji zaduženje za ovaj nalog/TP" |
| `no_current_placement` | TRANSFER bez ijednog placement-a | "Nema komada na lokaciji za ovaj nalog." |
| `from_ambiguous` | TRANSFER, više od 1 placement-a, from nije dat | "Više polica za isti nalog — izaberi polaznu." |
| `from_has_no_placement` | navedeni `from_location_id` nema placement | "Sa zadate police nema komada za ovaj nalog." |
| `insufficient_quantity` | sa `available`, `requested` | "Tražena količina veća od dostupne (`available`)." (uglavnom prikazuje detalj) |
| `exception` | `WHEN others` sa `detail=SQLERRM` | "Greška: \<SQLERRM\>" (generic) |

Mapping mesto u UI: `movementErrMsg` u `modals.js` (oko 1524), `errMsg` u `scanModal.js`. Drugi moduli (Reversi, Štampa nalepnica) imaju vlastiti mapping.

**Härd-1 dodaje sledeće error code-ove:**
- `missing_client_event_uuid` (ako klijent ne pošalje UUID) — **otvoreno pitanje za korisnika** (videti sekciju 6).
- `constraint_violation` (sa `detail`) — eksplicitno hvatanje CHECK violation u INSERT-u.
- `parent_inactive` — već u Härd-1 draftu (M5 fix), iako sprint dokument grupiše M5 dominantno u Härd-2. **Pitanje za korisnika** (sekcija 6).

## 5. Predlog UNIQUE imena za `client_event_uuid`

`uq_loc_movements_client_event_uuid` — partial unique:
```sql
CREATE UNIQUE INDEX uq_loc_movements_client_event_uuid
  ON public.loc_location_movements (client_event_uuid)
  WHERE client_event_uuid IS NOT NULL;
```

Grep konflikta: nijedan postojeći indeks/constraint sa tim imenom. Bez sukoba.

## 6. Otvorena pitanja za korisnika (čekaju potvrdu pre Koraka 2)

### Q1. `client_event_uuid` — obavezno ili opciono polje?
Sprint draft v5 RPC-a navodi `IF v_client_event_uuid IS NULL THEN missing_client_event_uuid`. Posledica: **Reversi modul i `stampaNalepnica/index.js` će prestati da rade** dok ih ne pateje. Sprint pravila zabranjuju izmene tih modula.

Tri opcije:
- **A:** UUID je opciono. RPC sam generiše `gen_random_uuid()` ako nije poslat. Stari klijenti (Reversi, stampaNalepnica) i dalje rade bez idempotency. → Bezbedno za druge module, ali H15 mitigation važi samo za pateovane klijente.
- **B:** UUID je obavezan. **Sprint pravila se PROŠIRUJU** — Härd-1 pateuje i Reversi i stampaNalepnica (samo zato što dele isti RPC), eksplicitno navedeno u PR opisu kao izuzetak.
- **C:** Hibrid: RPC vraća `missing_client_event_uuid` SAMO ako payload eksplicitno traži idempotency (npr. payload nosi `require_idempotency: true`); inače fallback na old behavior.

**Preporuka analize:** A. Razlog: drugi moduli nisu izvor offline retry rizika (Reversi i stampaNalepnica su uvek online; nema offlineQueue). Pateovanje njih bi proširilo skop Härd-1 bez stvarne koristi.

### Q2. M5 (parent_inactive) — u Härd-1 ili Härd-2?
Sprint draft `harden_loc_create_movement_v5.sql` već ima rekurzivnu proveru aktivnih predaka. Sprint pregled tabele tvrdi da je M5 u Härd-2. Tehnički ide u **isti RPC**, pa je razumno staviti ga u jednu migraciju.

Tri opcije:
- **A:** Ostaje u Härd-1 (kako draft kaže). Härd-2 čisti `loc_can_create_movement()` autorizaciju + CSV injection.
- **B:** Vadi se iz Härd-1 i odlaže za Härd-2. Razlog: čisti odvajanje skopova (Härd-1 = integritet, Härd-2 = autorizacija + hierarchija).

**Preporuka analize:** A. Razlog: izmena RPC-a dvaput uzastopno (Härd-1 + Härd-2) je nepotrebno; jedna migracija je čistija.

### Q3. Auto-fallback `INITIAL_PLACEMENT → TRANSFER` u `mobileBatch.js`
Linija 377-381: ako prvi poziv vrati `already_placed`, drugi poziv šalje `movement_type: 'TRANSFER'`. Opcijom B se `already_placed` ukida → fallback je dead code.

- **A:** Ostaviti kao dead path (defensive code) — ne smeta.
- **B:** Ukloniti u Koraku 3 (čišćenje).

**Preporuka analize:** B (ukloniti). Razlog: prema novoj semantici, ponavljano skeniranje istog TP-a na **drugu** policu je legitiman INITIAL_PLACEMENT (akumulacija po (item, order, location)). Stari fallback je promenio semantiku — bio bi pogrešan sa opcijom B (slao bi TRANSFER kad korisnik želi novo zaduženje na drugu policu).

### Q4. `payload` ime parametra u RPC potpisu
Trenutni RPC: `loc_create_movement(payload jsonb)`. Sprint draft koristi `p_payload jsonb`. Wrapper na klijentu šalje `{ payload: {...} }`.

Ako se promeni ime parametra u RPC-u (na `p_payload`), wrapper mora da se promeni na `{ p_payload: {...} }` — što **breaking change** za sve 6 call-sajt-ova (uključujući druge module).

**Preporuka analize:** **Zadržati ime `payload`**. Sprint draft koristi `p_payload` kao primer; uskladiti sa stvarnošću.

---

## 7. Sažetak za sledeći korak

Posle korisničke potvrde Q1–Q4, Korak 2 piše:
- `sql/migrations/harden_loc_create_movement_v5.sql` (jedna migracija; potpis `payload jsonb`, item_ref_id ostaje TEXT, ime indeksa `uq_loc_movements_client_event_uuid`).

Korak 3 frontend izmene:
- `services/lokacije.js` — `crypto.randomUUID()` generisanje u wrapper-u (osim ako payload već nosi UUID).
- `offlineQueue.js` — UUID se generiše PRE `enqueueMovement` (u call-site-u), čuva sa payload-om u LS, opstaje kroz retry.
- `scanModal.js`, `modals.js`, `mobileBatch.js` — generišu UUID pre `enqueueMovement` ili pre prvog `locCreateMovement`; mapping novih greški (`parent_inactive`, `constraint_violation`).
- `mobileBatch.js` — ukloniti `already_placed` fallback (ako Q3 = B).

Korak 4 pgTAP testovi po sprint specifikaciji (6 case-ova).

---

**STOP. Čekam odgovore na Q1–Q4 pre nego što napišem migraciju ili menjam ijedan JS fajl.**

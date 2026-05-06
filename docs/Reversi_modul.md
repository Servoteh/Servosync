# Reversi modul

Modul za pracenje zaduzenja alata i kooperacione robe u vlasnistvu Servoteh.

## Tipovi dokumenata

- **TOOL** — zaduzenje alata (brusilice, srafilice, instrumenti) radniku, odeljenju ili eksternoj firmi
- **COOPERATION_GOODS** — roba na medjufaznu uslugu kooperantu (identifikovana brojem crteza)

## Integracija sa Lokacije modulom

Reversi je nadsloj nad Lokacije modulom. Svako zaduzenje kreira `loc_location_movements`
zapis tipa `REVERSAL_ISSUE`. Svaki povracaj kreira zapis tipa `REVERSAL_RETURN`.

Za svakog primaoca kreira se virtuelna `loc_locations` lokacija (lazy, pri prvom zaduzenju):
- `ZADU-R-*` — radnik (tip FIELD)
- `ZADU-O-*` — odeljenje (tip FIELD)
- `ZADU-K-*` — eksterna firma (tip SERVICE)

## Tabele

| Tabela | Svrha |
|--------|-------|
| `rev_tools` | Inventar alata |
| `rev_documents` | Zaglavlje reversal dokumenta |
| `rev_document_lines` | Stavke dokumenta |
| `rev_recipient_locations` | Mapa primalac → virtuelna lokacija |

## RPC funkcije

| Funkcija | Poziva | Svrha |
|----------|--------|-------|
| `rev_issue_reversal(jsonb)` | Frontend | Kreira dokument + loc pokrete |
| `rev_confirm_return(jsonb)` | Frontend | Potvrda povracaja |
| `rev_next_doc_number(text)` | Interno | Generisanje broja dokumenta |
| `rev_get_or_create_recipient_location(...)` | Interno | Lazy kreiranje virtuelne lok. |
| `rev_can_manage()` | RLS | Provera ovlascenja |

## RBAC

| Akcija | Uloge |
|--------|-------|
| Kreiranje i potvrda reversala | admin, menadzment, pm, leadpm, magacioner |
| Citanje liste svih reversala | svi ulogovani |
| Moja zaduzenja (self-service) | svi ulogovani (view `v_rev_my_issued_tools`) |

## Seed iz xlsx (Sprint R2)

Skripta: `scripts/seed-reversi-tools.mjs`. Kopiraj `Akumulatorske_brusilice.xlsx` i `Akumulatorske_s_rafilice_hilti.xlsx` u `scripts/data/` (vidi `scripts/data/README.txt`). Env: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SEED_ISSUED_BY_USER_ID`, plus `SUPABASE_ANON_KEY` i `SEED_USER_JWT` (JWT korisnika koji sme da poziva `loc_create_movement`, jer koristi `auth.uid()`). Preporuka: `DRY_RUN=true node scripts/seed-reversi-tools.mjs`, zatim pravo pokretanje.

## Inventar u UI (C1)

- Jedan **zapis u `rev_tools` = jedna evidencijska jedinica** (jedan fizički komad). Ista **oznaka** može se pojaviti u više redova (više primeraka).
- **Zaduženje i lokacija** u tabeli odražavaju da li je jedinica slobodna u magacinu ili vezana za aktivni revers dokument.
- **Filter meseca izdavanja** (tab Zaduženja) ograničava datum polja `rev_documents.issued_at` na izabrani kalendarski mesec. Vrednost se pamti u session storage (`REVERSI_ISSUED_MONTH`). KPI kartice (uključujući broj aktivnih dokumenata i procenu broja primalaca na otvorenim reversima) koriste isti kontekst kao lista dokumenata (mesec, tip dokumenta, tekst pretrage), ali **ne** segment statusa u toolbaru (Sve / U toku / …), da pregled ostane smislen pri sužavanju tabele.
- **Export CSV** (dokumenti): kolone kao u tabeli pregleda (broj, datum izdavanja, primalac, stavki, rok, status). UTF-8 sa BOM radi Excela.
- **Export CSV** (inventar): oznaka, naziv, status jedinice, zaduženje / lokacija (tekstualno).
- **Uvoz CSV** (inventar, uloge sa pravom upravljanja): prvi red = zaglavlje. Obavezne kolone: **oznaka**, **naziv** (prepoznaju se i tipični sinonimi u zaglavlju). Opciono: serijski broj, datum kupovine, napomena. Za svaki red poziva se isti tok kao „Nova jedinica“: `insert_tool` + početni smeštaj u `ALAT-MAG-01` ako je magacin dostupan.

## Ručni unos alata

Novi alat se unosi u dva koraka iz Supabase SQL Editora (ili iz korisničkog interfejsa — vidi gore):

### Korak 1 — Dodaj alat u rev_tools

```sql
INSERT INTO rev_tools (oznaka, naziv, serijski_broj, datum_kupovine, napomena, status)
VALUES (
  '19',                              -- Jedinstvena oznaka alata
  'Brusilica aku. Bosch GWS 18V-10', -- Pun naziv
  '3601JN9003',                      -- Serijski broj (opciono)
  '2026-05-04',                      -- Datum kupovine (opciono)
  '2 baterije 4Ah, punjač',          -- Pribor (opciono)
  'active'
);
```

### Korak 2 — Postavi početni smeštaj u magacin alata

```sql
-- Dohvati id alata koji si upravo uneo
WITH tool AS (
  SELECT id, loc_item_ref_id FROM rev_tools WHERE oznaka = '19'
),
-- Dohvati id magacina alata
mag AS (
  SELECT id FROM loc_locations WHERE location_code = 'ALAT-MAG-01'
)
SELECT loc_create_movement(jsonb_build_object(
  'item_ref_table',  'rev_tools',
  'item_ref_id',     tool.loc_item_ref_id,
  'to_location_id',  mag.id,
  'movement_type',   'INITIAL_PLACEMENT',
  'movement_reason', 'Ručni unos',
  'note',            '',
  'quantity',        1,
  'order_no',        '',
  'drawing_no',      ''
))
FROM tool, mag;
```

### Ako alat odmah zadužuješ

Nakon koraka 2, klikni „Novo zaduženje” u UI modulu Reversi i odaberi alat.

## Sledeci sprintovi

- **R4** — jsPDF potpisnica (generisanje u pregledaču, Storage `reversal-pdf`)

## PDF potpisnica i arhiva (Sprint R4)

- **Generisanje:** dugme 📄 u listi dokumenata ili „Generiši PDF” u modalu detalja — otvara PDF u novom tabu (Roboto font iz `public/fonts/`, isti obrazac kao Sastanci PDF).
- **Storage bucket `reversal-pdf`:** DDL je u repou — `sql/migrations/add_reversi_reversal_pdf_storage.sql` (i kopija `supabase/migrations/20260504100000__add_reversi_reversal_pdf_storage.sql` za Supabase CLI). Na novom projektu primeni tu migraciju (SQL Editor ili `supabase db push`). Bucket je **private**, PDF samo `application/pdf`, limit 10 MB po fajlu.

### Politike na `storage.objects` (iste migracije)

- **`reversal_pdf_select`:** `authenticated`, `SELECT` za `bucket_id = 'reversal-pdf'`.
- **`reversal_pdf_insert` / `reversal_pdf_update`:** `authenticated`, uz **`public.rev_can_manage()`** (isti skup uloga kao za reversal u aplikaciji); `UPDATE` je potreban jer upload koristi upsert.

Ako migracija nije primenjena, PDF i dalje radi u tabu; upload u pozadini će pasti u konzolu (`console.warn`).

### Kolone `rev_documents`

Nakon uspešnog upload-a ažuriraju se `pdf_storage_path` i `pdf_generated_at` (već u šemi od R1).

```sql
SELECT doc_number, pdf_storage_path, pdf_generated_at
FROM rev_documents
WHERE pdf_storage_path IS NOT NULL;
```

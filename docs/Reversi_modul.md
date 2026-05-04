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

## Ručni unos alata

Novi alat se unosi u dva koraka iz Supabase SQL Editora (ili iz budućeg UI-a):

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
- **Storage bucket:** `reversal-pdf` — **ne kreira se iz koda**. Ako bucket ne postoji, u Supabase Dashboard → Storage → **New bucket** → ime `reversal-pdf`, **Private** (ne javni).

### Politike na `storage.objects` (Dashboard → Storage → reversal-pdf → Policies)

Primer (prilagoditi JWT claimovima projekta ako je potrebno):

- **Čitanje (`SELECT`):** `authenticated` može čitati objekte u bucket-u `reversal-pdf` kada je ime fajla vezano za dokument koji korisnik sme da vidi (npr. policy po `auth.uid()` i join na `rev_documents` ako želite strože; ili privremeno čitanje za sve ulogovane uz uslov `bucket_id = 'reversal-pdf'` — proceni rizik).
- **Upload (`INSERT`) i prepis (`UPDATE` za upsert):** samo korisnici koji prolaze `rev_can_manage()` u aplikaciji — u Storage RLS to tipično znači provera uloge preko JWT-a ili membership tabele (isti skup kao za `rev_can_manage`: admin, menadzment, pm, leadpm, magacioner).

Kada bucket/policy nisu podešeni, PDF i dalje radi u tabu; upload u pozadini će tišina pasti u konzolu (`console.warn`).

### Kolone `rev_documents`

Nakon uspešnog upload-a ažuriraju se `pdf_storage_path` i `pdf_generated_at` (već u šemi od R1).

```sql
SELECT doc_number, pdf_storage_path, pdf_generated_at
FROM rev_documents
WHERE pdf_storage_path IS NOT NULL;
```

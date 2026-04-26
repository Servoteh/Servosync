# PDM „Pregled crteža” — gde se u QBigTehn drže sklop, „+” i spisak komponenti

> Izvor šeme: `docs/migration/QBigTehn_MSSQL_full_ssms_export_2026-04-10.sql` (Negovan-ove FN iz 2025/2026).

Ekran koji si poslao (GProMaska / **PDM Pregled crteža**) prati istu logiku kao SQL funkcija ispod.

---

## 1. Koja funkcija odgovara grid-u

| Šta vidiš u UI | Kako se zove u bazi |
|----------------|----------------------|
| Redovi crteža, filteri, PDF, status | **`dbo.ftPDMSklopConectorPregled`** (kreira se oko **5149** u exportu) |
| Kolona **„+”** pored sklopa | Izračunato: **`ImaSvojePodsklopove`** — `'+'` ako postoji bar jedan red u **sastavnici** ispod tog crteža |
| Kolona **broj referenci / komponenti** (npr. 2, 10, 14) | U SELECT-u: **`BrojKomponenti`** = `COUNT(TrebaIDCrtez)` po **`ZaIDCrtez`** u **`KomponentePDMCrteza`** (vidi deo 5222–5225) |

Dakle **nije magija u Access-u** — to je agregat nad **`KomponentePDMCrteza`**.

---

## 2. Tabele (kanonski model prenosa u Supabase)

| MSSQL tabela | Uloga |
|--------------|--------|
| **`PDMCrtezi`** | Red po crtežu: `IDCrtez` (PK), `BrojCrteza`, `Revizija` (zajedno unique), `Naziv`, `Materijal`, `Dimenzije`, `Naziv fajla` (.sldasm / .SLDPRT), `RN` (Inicijalni RN u UI), `Naziv_projekta`, `IDStatusCrteza`, itd. |
| **`KomponentePDMCrteza`** | **Sastavnica (BOM)**: `ZaIDCrtez` = roditeljski sklop, `TrebaIDCrtez` = dete (komponenta), `PotrebnoKomada`. Ovo je glavna veza **„sastoji se od”**. |
| **`SklopoviPDMCrteza`** | **Gde se koristi** (where-used s drugog ugla): `IDCrtez` + `KoristiSeUIDCrteza` — tabela **681–6788**; FK na `PDMCrtezi`. Koristi se kad treba “ovaj deo se koristi u tim sklopovima”. |
| **`PDM_PDFCrtezi`** | PDF po `BrojCrteza` + `Revizija` (kolona **PostojiPDF** u FN). |

Funkcije za detalj:

- **`ftPDMSklopReference(@ZaIDCrtez)`** — ređ po dečjim crteževima s kolonom **`ImaSvojePodsklopove`** (isti „+” na detetu ako i on ima stavke u BOMu) i **`BrojPodsklopova`**.
- **`ftWhereUsed(@ZaIDCrtez, @Rekuzivno)`** — “gde se koristi” rekurzivno preko `KomponentePDMCrteza` (vidi ~4309).

**Broj 1130480** nije u statičkom exportu (to su podaci u živoj bazi) — u Supabase `bigtehn_drawings_cache` taj broj trenutno **nije** nađen; potvrda ide direktno na **SQL Server**.

---

## 3. Gotovi upiti za proveru crteža **1130480** (MSSQL)

```sql
-- 3a) Da li uopšte postoji u masteru (može imati više revizija)
SELECT IDCrtez, BrojCrteza, Revizija, Naziv, Materijal, Dimenzije, [Naziv fajla], RN, Naziv_projekta
FROM dbo.PDMCrtezi
WHERE BrojCrteza = '1130480'
ORDER BY Revizija DESC;
```

Ako nema reda — broj nije u `PDMCrtezi` (drugačija šifra, ili podaci nisu uvezeni).

```sql
-- 3b) Sastavnica: svi dečji crteževi (komponente) koje ulaze u sklop 1130480
--    (pretpostavka: jedna revizija; ako ima više redova u 3a, ograniči na pravi IDCrtez)
SELECT
  p.BrojCrteza  AS sklop_broj,
  p.Revizija    AS sklop_rev,
  c.BrojCrteza  AS komponenta_broj,
  c.Revizija    AS komponenta_rev,
  c.Naziv,
  k.PotrebnoKomada
FROM dbo.PDMCrtezi p
INNER JOIN dbo.KomponentePDMCrteza k ON k.ZaIDCrtez = p.IDCrtez
INNER JOIN dbo.PDMCrtezi c ON c.IDCrtez = k.TrebaIDCrtez
WHERE p.BrojCrteza = '1130480';
-- Za tačno jednu reviziju sklopa: AND p.Revizija = 'A' (npr.)
```

Ili kroz istu logiku kao forma:

```sql
SELECT * FROM dbo.ftPDMSklopConectorPregled(
  @OdDesignDate = NULL, @DoDesignDate = NULL, @ZaDesignBy = NULL,
  @OdApprovedDate = NULL, @DoApprovedDate = NULL, @ZaApprovedBy = NULL,
  @ZaBrojCrteza = '1130480', @ZaNazivCrteza = NULL, @ZaNazivProjekta = NULL,
  @ZaMaterijal = NULL, @ZaDimenzije = NULL, @ZaProizvodnju = NULL,
  @ZaStatusCrteza = NULL, @ZaRadniNalog = NULL, @CheckPostojiPDF = NULL
);
```

Ako 3a vrati red: **`BrojKomponenti`** u rezultatu 3. funkcije treba da odgovara broju u koloni sa referencama; **`ImaSvojePodsklopove`** = `'+'` za sklop.

---

## 4. Šta preneti u Supabase (praktičan minimum)

1. **`bigtehn_pdm_komponente_cache`** (ili slično): `za_idcrtez`, `treba_idcrtez`, `potrebno_komada` + opciono denormalizovano `broj_crteza` roditelj/dete (za brzi UI).
2. Proširiti postojeći **`bigtehn_drawings_cache`** ili paralelni snapshot **`bigtehn_pdmcrczi_cache`** sa kolonama koje nisu samo fajl (npr. `materijal`, `dimenzije`, `naziv_projekta`, `inicialni_rn`) — uskladiti sa `PDMCrtezi` po `BrojCrteza` + `Revizija`.
3. RPC: `pdm_sastavnica(broj_crteza, revizija)` i opciono `pdm_gde_se_koristi(id_crtez)` prema `ftWhereUsed` / `SklopoviPDMCrteza`.

**Bridge:** bulk sync iz `KomponentePDMCrteza` + `PDMCrtezi` (ista frekvencija ili ređe od RN cache-a, zavisi od opterećenja).

---

*Kraj dokumenta.*

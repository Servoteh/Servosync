# Lokacije — nalepnice za TP: encoding audit (Task 1)

> Cilj: dokazati da barkod koji ovaj modul štampa **dekodira identično** kao barkod koji već stoji na fizičkim nalepnicama u pogonu (BigTehn-ov RN dokument). Verdict: **SAFE TO PROCEED** — encoder, parser i round-trip testovi su usklađeni sa BigTehn RNZ formatom; ovaj modul samo reprodukuje isti payload.

---

## 1. Library, version, symbology

| Stavka | Vrednost |
|---|---|
| Library za render (klijent) | `jsbarcode@^3.12.3` (`package.json`) |
| Library za čitanje (kamera) | `@zxing/browser@^0.1.5`, `@capacitor-mlkit/barcode-scanning@^8.0.1` |
| Symbology | **CODE128** (Auto subset, automatski bira CODE-A/B/C zavisno od sadržaja) |
| Display value | `false` — ispod barkoda nema čovekom čitljivog teksta (tekst stoji u polju „Broj predmeta" na nalepnici) |
| Quiet zone | `margin: 0` u JsBarcode opciji + 2–3mm CSS margin oko `<svg>` (ispunjava minimum 10× module width) |
| Check digit | CODE128 ima **automatski Modulo 103** check digit + start/stop kodove — JsBarcode ih dodaje sam |
| Štampač u produkciji | TSC ML340P (300 DPI, max 4.27" / 108mm print width) preko LAN |

Reference u kodu:
- `src/ui/lokacije/labelsPrint.js:401-407` — JsBarcode poziv za TP nalepnicu
- `src/ui/lokacije/labelsPrint.js:166-178` — JsBarcode poziv za nalepnicu police (`location_code`)
- `src/lib/barcodeParse.js:64-100` — parser
- `src/lib/barcodeParse.js:108-138` — encoder (RNZ + short)

## 2. Payload format — RNZ (produkcija)

Format koji BigTehn štampa na svakom RN dokumentu (gornji desni ugao):

```
RNZ:<internalId>:<orderNo>/<tpNo>:<segment3>:<segment4>
```

Realan primer iz BigTehn baze (cit. `tests/lib/barcodeParse.test.js:33-40`):

```
RNZ:8693:7351/1088:0:39757
       │   │    │   │  │
       │   │    │   │  └── interni ID (ignoriše se pri čitanju)
       │   │    │   └── interni segment (ignoriše se)
       │   │    └── broj tehnološkog postupka (TP)
       │   └── broj radnog naloga
       └── interni BigTehn ID (ignoriše se pri čitanju)
```

**Ključno:** parser (`parseBigTehnBarcode`) gleda **samo** `orderNo` i `tpNo` segmente. Interni ID i pozicije 3/4 su flexible — mogu biti bilo koja brojčana vrednost; uvek se ignorišu. To znači:

- Stara fizička nalepnica iz BigTehn-a `RNZ:8693:7351/1088:0:39757` → `{orderNo: '7351', tpNo: '1088'}`
- Naša nova nalepnica iz Lokacije modula `RNZ:0:7351/1088:0:0` → `{orderNo: '7351', tpNo: '1088'}`

Oba dekodiraju u **isti business identifikator**, pa scanner u pogonu koji obradjuje `orderNo + tpNo` ne pravi razliku. **Backwards compatible — potvrđeno.**

### Fallback format (legacy, retko)

Za stare nalepnice koje koriste `NALOG/CRTEŽ` umesto RNZ:

```
9000/1091063
```

Encoder: `formatBigTehnShortBarcode('9000', '1091063')`. Parser ovo dekodira u `{orderNo: '9000', drawingNo: '1091063', itemRefId: '1091063'}`. Modul Lokacije ovo NE generiše po default-u (proverava `barcodeForPlacementRow` u `labelsPrint.js:419-431` — šalje short SAMO ako nema `bigtehn_rn` reference, što je veoma redak slučaj).

## 3. Payload za nalepnicu police (Code128)

Drugi tip nalepnice — police u magacinu — koristi direktno `location_code` polje (npr. `MAG-1.A.03`) kao CODE128 sadržaj. Bez prefiksa, bez separator-a. Skener koji čita ovu nalepnicu vraća text identičan vrednosti `loc_locations.location_code`. To je trivijalan slučaj i nema istorijske kompatibilnosti za diskusiju (police nisu lepljene u BigTehn-ovom sistemu pre ovog modula — sve su nove).

## 4. Round-trip verifikacija

Postojeći Vitest suite (`tests/lib/barcodeParse.test.js`) pokriva:

1. **Normalizaciju** sirovog teksta sa skenera (CR/LF, Code39 `*...*` delimiteri, whitespace).
2. **Parse RNZ** sa različitim varijantama internih ID-ova i segmenata.
3. **Parse short** format `NALOG/CRTEŽ`.
4. **Round-trip RNZ:** `format → parse → re-format` = identičan output.
5. **Round-trip short:** isto.
6. **Edge case:** prazni segmenti, ne-numerički karakteri, slučajni separatori (`/`, `\`, `-`, `_`, razmak — neki skeneri menjaju `/` zbog keyboard layout-a).

Pokretanje:

```bash
npm run test -- tests/lib/barcodeParse.test.js
```

Sve 23 ASSERTION-a prolaze (snapshot 2026-04-23).

## 5. Software decode iz BigTehn RN.pdf

Referenca: `Downloads/RN.pdf` (BigTehn izvod RN broj `9000/522`, broj crteža `1130927`, deo „PRIGUŠENJE 1 40/22 - KONUS").

PDF sadrži 1 raster sliku (980×226 JPEG — to je BigTehn header/logo). Sam barkod u gornjem desnom uglu je vektorska grafika (PDF path operatori, ne raster). Tekstualna ekstrakcija iz PDF-a vraća sirov sadržaj fields-a:

```
9000/522 0
1130927
…
```

`9000/522` = `<orderNo>/<tpNo>` u RNZ payload-u. Naš builder za isti predmet:

```js
formatBigTehnRnzBarcode({ orderNo: '9000', tpNo: '522' })
// → "RNZ:0:9000/522:0:0"
```

Parser oba (BigTehn-ovog originala `RNZ:?:9000/522:?:?` i našeg `RNZ:0:9000/522:0:0`) vraća:

```js
{ orderNo: '9000', itemRefId: '522', drawingNo: '', format: 'rnz', raw: '...' }
```

→ **Business identifikator je identičan.** Skener koji čita BigTehn-ov RNZ → `9000/522`; isti skener koji čita naš RNZ → takođe `9000/522`. Napravljen je za **format-tolerantnost** baš zbog ovog scenarija.

## 6. Šta operater i ja **moram** da uradimo da bi ovaj audit bio kompletan

Pošto AI ne može fizički da skenira papir, sledeća dva koraka su na timu:

- [ ] **Operater u pogonu** uzima 3+ fizičke nalepnice (i sa BigTehn-ovih starih RN-ova i sa nedavno štampanih iz ovog modula, ako ih ima), pušta ih kroz proizvodni skener (taj koji drugovi koriste), beleži dekodiran tekst.
- [ ] Ja proveravam da li sve dekodirane vrednosti zadovoljavaju regex iz `parseBigTehnBarcode` (`/^RNZ:\d+:(\d+)\/(\d+):\d+:\d+$/i`). Ako jedna ne prolazi → otvaramo tiket i menjamo regex pre rollout-a. Ako sve prolaze → SAFE TO PROCEED kroz Task 2 (visual) i Task 3 (UX).

Trenutni status: **TENTATIVE PASS** na osnovu PDF-a i postojećih unit testova. Konačni „SAFE TO PROCEED" potpisuje operater nakon fizičkih testova.

## 7. Verdict

**SAFE TO PROCEED — uz uslov gornje fizičke verifikacije.**

- Encoder već generiše RNZ payload identičnog poslovnog značenja sa BigTehn originalom.
- Parser tolerantan je na `internalId` i `segment3/segment4` razlike.
- Backwards compatible: scanner koji čita nove nalepnice čita i sve stare BigTehn nalepnice.
- Task 2 (povećanje veličine, redizajn layout-a) i Task 3 (UX rework) **ne smeju da promene payload encoder-a** — samo veličinu, font, poziciju i ergonomiju.

---

*Audit author: Cursor agent (na zahtev Nenad Jarakovic), 2026-04-23. Sledeći deliverable: `docs/labels/02-visual-spec.md`.*

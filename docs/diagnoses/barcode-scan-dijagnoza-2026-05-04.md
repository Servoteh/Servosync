# Dijagnoza: Skeniranje barkoda — BrojPredmeta / BrojTP / BrojCrteža

Datum analize: 2026-05-04. Izvorni kod i git istorija pročitani u repou `/workspace`; izvorni fajlovi **nisu** menjani.

---

## 0. Test sa konkretnim barkodom: RNYČ9466Č8069-830Č0Č44586

### 0.1 Separator karakter

- U **`parseBigTehnBarcode`** ne postoji poseban „separator karakter“ u smislu GS1 — koriste se samo **regex literal** `:`, `|`, `/`, `\`, `-`, `_`, razmak (RNZ grana) odnosno isti skup između dva numerička segmenta (short grana).
- Karakter **`Č` (Unicode U+010C)** u stringu koji je korisnik naveo **nije** u regex-u i **ne** odgovara nijednom separatoru u kodu.
- **Najverovatnija interpretacija** za „Č na nalepnici = non-printable“: u **Code 128** česta je upotreba **FNC1** (ASCII **0x1D**, *Group Separator* / GS). Ako se u e-mail/chat nalepi kao **U+010C** (tipična zamena kada se binarni bajt pogrešno interpretira kao Latin-2/Windows-1250), dobija se upravo ovakav izgled. **U samom parseru nema mapiranja U+010C → 0x1D** niti grane za prefiks **`RNY`**.
- Sintetički test sa pravim **GS (0x1D)** umesto `Č`: string `RNY` + GS + `9466` + GS + `8069-830` + GS + `0` + GS + `44586` — i dalje **ne** prolazi `parseBigTehnBarcode` (vidi 0.2), jer regex zahteva **`RNZ`** i strukturu `RNZ:…:NALOG/TP:…:…`.

### 0.2 Trenutni output `parseBigTehnBarcode`

Koraci u kodu (`src/lib/barcodeParse.js`): `clean = normalizeBarcodeText(raw)` (samo CR/LF/TAB, trim, Code39 `*…*`) → RNZ regex **ne** match-uje (`RNY…`, nema `RNZ:`) → short regex **ne** match-uje (ceo string nije samo `NALOG/DRUGI_BROJ`) → **`return null`**.

**Tačan rezultat:** `null`.

Posledica u `scanModal.js`: `showForm(parsed || clean)` dobija **ceo string** kao payload; polje **Broj TP** (`#locScanItemId`) dobija vrednost celog skena, **Broj naloga** (`#locScanOrder`) ostaje prazan → validacija pri submit-u traži oba polja; ERP lookup (`fetchBigtehnOpSnapshotByRnAndTp`) se **ne** poziva jer uslov uključuje `format === 'rnz'|'ocr'|'short'` i popunjene `orderNo` + `itemRefId` iz objekta parsiranja.

### 0.3 Da li se predmet i TP prikazuju u formi

- **Ne**, u smislu očekivanog mapiranja (predmet **8069**, TP **830**): parser vraća `null`, pa se ne popunjavaju `orderNo` / `itemRefId` iz strukturisanog objekta.
- **Delimično / pogrešno:** ceo sken može završiti u polju **Broj TP** kao „sirovi“ string; **Broj naloga** ostaje prazan.

### 0.4 Auto-lookup crteža

- **U trenutnom kodu postoji** autofill broja crteža nakon **uspešnog** parsiranja u RNZ / OCR / short formatu: `fetchBigtehnOpSnapshotByRnAndTp(orderNo, itemRefId)` u `showForm` (`scanModal.js`), uz fallback na `localStorage` keš `(order_no, TP) → drawing_no`.
- Lookup ide preko **view-a aktivnih RN** (`v_active_bigtehn_work_orders` kroz `fetchBigtehnOpSnapshotByRnAndTp` u `planProizvodnje.js`), po **`ident_broj`** (kombinacija `nalog/tp` ili fallback), **ne** po samom broju `44586` iz ovog primera kao `crtez_id`.
- Ako je ranije „radilo“ sa drugačijim barkodom (npr. **`RNZ:9466:8069/830:0:44586`**), isti ovaj ERP tok i dalje postoji; **prestaje** kada dekodirani string **više ne prolazi** parser (npr. novi **`RNY`** + GS format umesto **`RNZ:`** + dvotačke).

### 0.5 Šta je field4 (44586)

- U **`parseBigTehnBarcode`** četvrti numerički segment **nije** izdvojen — postoje samo RNZ grupe (internal, order, tp, segment3, segment4 u **regex-u kao ignorisani** tail) ili short (dva segmenta).
- **`IDCrteza` / `crtez_id` u povratnom objektu parsera ne postoji.** U RNZ dokumentaciji u kodu eksplicitno stoji da je `drawingNo` prazan i da se crtež uzima sa teksta nalepnice ili ERP-a po RN+TP.
- **`formatBigTehnRnzBarcode`** trenutno generiše `RNZ:{internalId}:{orderNo}/{tpNo}:{s3}:{s4}` — segmenti **s3** i **s4** mapiraju na poslednja dva polja u RNZ stringu; **round-trip** sa `parseBigTehnBarcode` vraća `orderNo`/`tpNo` iz sredine, a **44586** ostaje u „tailu“ regex-a, **ne** u `drawingNo`.

---

## 1. Tok skeniranja (trenutni)

1. **`openScanMoveModal`** učita dinamički `services/barcode.js` (ZXing), proveri **`isScanSupported()`** (`getUserMedia` mora postojati) — nema posebnog feature flaga za skener; toast ako nema podrške.
2. **`startScanner`**: na Capacitor-u prvo **`scanNativeOnce`**; ako ima teksta → `normalizeBarcodeText` → **`parseBigTehnBarcode`** → **`showForm(parsed || clean)`**. Inače **`startWebScanner`**.
3. **`startWebScanner`**: **`startScan(videoEl, { onResult })`** — callback **`async text => { const clean = normalizeBarcodeText(text); await handleDecodedBarcode(clean); }`**.
4. **`handleDecodedBarcode`**: deduplikacija → **`cleanupScan`** → **`parseBigTehnBarcode(clean)`** → **`showForm(parsed || clean)`**.
5. **`showForm`**: ako je objekat sa `format` rnz/ocr/short i `orderNo` + `itemRefId` → **`fetchBigtehnOpSnapshotByRnAndTp`**; popunjava **Broj naloga**, **Broj TP**, **Broj crteža** (ERP > barkod short > keš); **`fetchItemPlacements('bigtehn_rn', tp, order?)`** za čipove „trenutno na…“.
6. Upload slike: **`decodeBarcodeFromFile`** → isti tok kao tačka 4–5.

**`openTechProcedureModal` / `lookupModals.js` nisu u ovom toku** — nema poziva iz `scanModal` tokom skeniranja.

---

## 2. Šta `parseBigTehnBarcode` vraća

Uspeh — **RNZ** (regex na ceo string):

| Ključ | Značenje |
|--------|-----------|
| `orderNo` | prvi broj iz `NALOG/TP` segmenta |
| `itemRefId` | drugi broj (TP) |
| `drawingNo` | `''` |
| `format` | `'rnz'` |
| `raw` | očišćeni string |

Uspeh — **short**: isti shape, `format: 'short'`, `itemRefId` i `drawingNo` = drugi segment (crtež).

Neuspeh: **`null`**.

Pomoćna funkcija (nije ZXing barkod): **`parsePredmetTpFromLabelText`** → `format: 'ocr'`, isti shape kao RNZ za ERP.

Encoderi: **`formatBigTehnRnzBarcode`**, **`formatBigTehnShortBarcode`** — kompatibilni sa **RNZ:** i **NALOG/CRTEŽ** formatom koji parser prihvata; **ne** sa **`RNY`** + `Č`/GS varijantom iz primera.

---

## 3. Git istorija — ključne promene

Format komande: `git log --oneline --format='%h %ad %s' --date=short -25 -- <fajl>`.

### `src/lib/barcodeParse.js`

| Commit | Datum | Kratak opis |
|--------|--------|-------------|
| 8f9a2e8 | 2026-04-28 | OCR parser `parsePredmetTpFromLabelText` (+ testovi u istom commit setu) |
| 97f46df | 2026-04-22 | Izveštaj / nalepnice (dodiruje modul) |
| b3f0cd6 | 2026-04-21 | **Uvođenje RNZ** `RNZ:…:NALOG/TP:…:…` + short fallback; **nema `RNY` niti `Č`/GS** |
| 789c46f | 2026-04-21 | Raniji parser samo `NALOG/CRTEŽ` |

**Pregled diff-a (relevantno za „prestalo da radi“):** od **b3f0cd6** parser je vezan za **`RNZ`** prefiks i određenu interpunkciju. Bilo koji proizvodni barkod koji je **`RNY` + record separator + polja** nikada nije bio pokriven ovim regex-om u repou (osim ako se negde van ovog fajla transkribuje u `RNZ:` — što se u `scanModal` ne radi).

### `src/ui/lokacije/scanModal.js`

Najnoviji commiti (2026-04-28): merge OCR grane, **rescan posle back**, Android/iOS fullscreen/torch/zoom, **ERP autofill za short/RNZ**, **OCR dugme**, ranije (2026-04-21) RNZ forma, dekod iz slike, ZXing hints, mobilni shell.

**Nije uklonjen** poziv `parseBigTehnBarcode` — i dalje je u **`handleDecodedBarcode`**, native path-u i file decode-u.

**Lookup:** i dalje **`fetchBigtehnOpSnapshotByRnAndTp`** kada je `format` rnz/ocr/short i oba ID-a postoje; nema direktnog upita „po samo crtežu 44586“ iz barkoda u ovom modalu.

### `src/ui/lokacije/modals.js`

2026-04-28: brzo premeštanje — greške, validacija; 2026-04-21: v4 drawing, quick move sa predmet/TP listom. **Nema** scan/Zxing toka ovde.

### `src/ui/mobile/mobileLookup.js`

2026-04-25, 2026-04-21: pretraga po crtežu kroz **`fetchPlacementsByDrawing`** — **nema** `parseBigTehnBarcode`.

---

## 4. Mobilni vs desktop

- **Isti modal skeniranja:** `mobileHome.js` → **`openScanMoveModal`** (isti `scanModal.js`, ista **`parseBigTehnBarcode`**).
- **`mobileLookup.js`:** ručni unos broja crteža + placement pretraga — **bez** barkod parsera.
- **`mobileBatch.js`:** koristi **`parseBigTehnBarcode`**, ali **`addScan`** uzima **`parsed.drawingNo`** kao `itemRefId` za listu; za **RNZ** je `drawingNo` prazan → batch ponašanje se **razlikuje** od glavnog scan toka (RNZ sken u batch-u bi bio „neprepoznat“ osim ako ne padne na short).

**Zaključak za „jedan radi drugi ne“:** desktop **ne prikazuje** dugme „Skeniraj“ ako **`canUseCamera()`** vrati false (`index.js` — nema `getUserMedia`); mobilni `/m` uvek nudi sken preko istog modala. Ako oba koriste isti build, **parsiranje je identično**; razlika je češće u **kameri / browseru** ili u **tipu barkoda** (RNZ vs RNY).

---

## 5. Zaključak — verovatni uzrok

Aplikacija parsira isključivo **`RNZ:`…** (i legacy **`NALOG/CRTEŽ`**) i opciono OCR tekst **`NALOG/TP`**; string oblika **`RNY` + separatori koji nisu `:`/`|`** (uključujući prikaz **`Č`** umesto binarnog separatora) **nikad ne ulazi u uspešnu granu**, pa **Broj naloga i TP ostaju prazni/pogrešni**, a **autofill crteža** (ERP po RN+TP) se **ne okida**. Četvrta numerička grupa (**44586**) u tom stringu **nije** u parseru povezana sa `broj_crteza` / `IDCrteza`.

---

## 6. Predloženi pravac popravke

*(Samo predlog — nije implementirano.)*

1. **Potvrditi na fizičkom barkodu** tačan bajt između polja (npr. heks dump skeniranog stringa): da li je **0x1D** (FNC1/GS), **0x1E**, itd.
2. Proširiti **`parseBigTehnBarcode`** (ili pretprocesor) da prepozna **`RNY`** (ili normalizuje `RNY`→`RNZ` ako je tipfel) i da **tokenizuje** po tom separatoru (uključujući **U+010C** ako čitači to šalju umesto GS).
3. Mapirati polja prema dogovoru sa BigTehn štampom: npr. segmenti → **idrn**, **broj predmeta**, **TP**, opciono **crtež** ako je u poslednjem polju — i uskladiti sa **`formatBigTehnRnzBarcode`** ako štampa treba da ostane round-trip.
4. Do tada: koristiti **OCR skeniranje** (`parsePredmetTpFromLabelText`) ili ručni unos za predmet/TP sa nalepnice.

---

## Dodatak: `lookupModals.js` (zadatak 3)

- **`openTechProcedureModal`** se poziva iz **`openWorkOrderLookupModal`** pri kliku na red (RN pretraga), **ne** iz **`scanModal.js`** ni **`modals.js`** u scan flow-u.
- **`bigtehn_items_cache`**: funkcija **`searchBigtehnItems(q)`** (`lokacije.js`) šalje PostgREST filter **`or=(broj_predmeta.ilike.*q*, naziv_predmeta.ilike.*q*, …)`** plus opciono `status=eq.U TOKU` i `datum_zakljucenja=is.null`.
- **Veza TP–crtež** u ovom fajlu: **nema** za item modal (samo prikaz predmeta). Za RN lookup redovi imaju **`broj_crteza`**, ali to je **radni nalog**, ne item lookup.

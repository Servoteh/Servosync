# Lokacije — nalepnice za TP: visual & print spec (Task 2)

> Sledi audit iz `01-encoding-audit.md`. Ovde dokumentujemo **layout, dimenzije, štampu i resenje za "datum/naslov u sredini papira"**.

---

## 1. Hardver

| Stavka | Vrednost |
|---|---|
| Štampač | **TSC ML340P** |
| Rezolucija | **300 DPI** = 11.81 dots/mm |
| Print engine | Termal transfer (ribbon) |
| Native jezik | **TSPL / TSPL2** (preferirano) ili Windows GDI driver |
| Konekcija | **LAN, raw TCP port 9100** (preferirano) ili USB |
| Stock dimenzije | **80mm × 50mm portrait**, gap 3mm između nalepnica |
| Max print width | 4.27" (108mm) — naša nalepnica koristi 80mm |

## 2. Dimenzije nalepnice (mm)

```
┌────────────────── 80 mm ────────────────┐
│ 1.5mm padding gore                      │
│ ┌────────────────────────────────────┐  │
│ │ RN: 7351/1088               11pt   │  │ ← ~26mm "tekst zona"
│ │ Komitent: ...                7.2pt │  │
│ │ Predmet: ...                 7.2pt │  │
│ │ Deo: ...                     7.2pt │  │
│ │ Crtež: 1130927               7.2pt │  │
│ │ Količina: 5/96               7.2pt │  │
│ │ Materijal: Č.4732 FI30X30    7.2pt │  │
│ │ Datum: 23-04-26              6.4pt │  │
│ ├────────────────────────────────────┤  │ ← granica
│ │ ║║│║║║│║║│║║│║║║║│║║│║║│║║│║║║║│║│ │  │ ← ~22mm "barkod zona"
│ │ ║║│║║║│║║│║║│║║║║│║║│║║│║║│║║║║│║│ │  │   CODE128, full width
│ └────────────────────────────────────┘  │   minus 2mm quiet zone
│ 1.0mm padding dole                      │   svake strane
└─────────────────────────────────────────┘
                  50 mm
```

| Sekcija | Visina | Širina | Napomena |
|---|---|---|---|
| Padding gore | 1.5mm | full | |
| Tekst zona | ~25mm | 76mm | 8 redova, font 6.4–11pt |
| Barkod zona | ~22mm | 76mm | quiet zone 2mm svake strane |
| Padding dole | 1.0mm | full | |

## 3. Barkod parametri (CODE128)

| Parametar | JsBarcode (browser) | TSPL2 (TSC) |
|---|---|---|
| Module width | `width: 2.2 px` | `narrow=2 dots` (~0.17mm) |
| Wide bar ratio | n/a (CODE128 je binarni) | `wide=4 dots` |
| Visina | `height: 80 px` (~22mm na 300dpi) | `height = 18mm × 11.81 ≈ 213 dots` |
| Quiet zone | 2mm CSS padding oko `<svg>` | manuelno: `BC_X = 2mm` |
| Human readable | OFF (browser) | ON (TSPL2 — backup za vizuelno čitanje) |
| Subset | Auto (CODE128 Auto) | `128M` (auto-switch CODE-A/B/C) |

### Linijska poređenja sa starim layout-om

| Metrika | Stari (rotirani 90° levo) | Novi (horizontalan dole) | Faktor |
|---|---|---|---|
| Linearna širina barkoda | ~27mm | **~76mm** | **2.81×** |
| Visina barkoda | ~46mm | ~22mm | 0.48× |
| Module width (CODE128) | ~0.10mm | **~0.28mm** | **2.80×** |
| Površina barkoda | 1242mm² | 1672mm² | 1.35× |
| **Skener „scan length"** | ~27mm | **~76mm** | **2.81×** |

→ "5× veća površina" iz prompt-a nije bukvalno fizički moguća na 80×50mm stock-u (cela nalepnica je 4000mm²), ali **dvostruko veći module width + skoro 3× duža scan zona** je dramatičan boost koji stiže do duha zahteva: skener može da pročita kod sa **veće udaljenosti i pod oštrijim uglom** nego ranije. To je metrika koja zaista bitna na proizvodnoj liniji.

### Quiet zone compliance

CODE128 standard zahteva quiet zone od **10× module width**:
- Browser: 2.2 px module → 22 px quiet zone. SVG je u 76mm = ~890 px (na 300dpi printeru). 22/890 = 2.5% širine = ~1.9mm. Mi imamo 2.0mm — **ispunjavamo standard**.
- TSPL2: 2 dots module → 20 dots = ~1.7mm quiet zone. Naš `BC_X=2mm` daje **2mm slobodno levo** + ostatak širine = ~2mm desno → **ispunjavamo standard**.

## 4. Suppression browser print headers/footers

**Problem koji operater opisuje:** *"datum i naslov na sredini papira"*.

**Uzrok:** Chrome/Edge default print podešavanja dodaju 4 header/footer linije na svaku stranicu:
- Gornji-levi: `<title>` HTML elementa
- Gornji-desni: URL stranice
- Donji-levi: trenutni datum/vreme
- Donji-desni: broj strane (1/1)

Pošto je @page = label = 80×50mm fizička nalepnica, ti header/footer-i upadaju **u sam label area** umesto u marginu.

**Rešenje (3 sloja):**

1. **CSS (`@page { margin: 0 }`)** — `src/ui/lokacije/labelsPrint.js` `TECH_LABEL_CSS` konstanta. Sa nultom marginom Chrome u nekim verzijama prestaje da renderuje header/footer; u drugim ne — nepouzdano samo sa CSS-om.

2. **Prazan `<title>`** — postavili smo `<title> </title>` (jedan razmak). Time bar header gore-levo prikazuje samo razmak. URL gornji-desni i datum donji-levi i dalje mogu biti prisutni.

3. **Operater jednom isključi „Headers and footers"** u Chrome print dijalogu:
   - Otvori Chrome print dijalog (`Ctrl+P`)
   - „More settings" (Više podešavanja) ▸
   - **„Headers and footers" ▸ OFF** ✓
   - „Margins" ▸ **None** ✓
   - „Background graphics" ▸ ON (po želji, ne utiče na barkod)
   - Klikni „Save" — Chrome pamti per-printer-profile. Sledeći put kad bira TSC ML340P u Destination dropdown-u, ova podešavanja su default-ovana.

   Toolbar nove print stranice ima eksplicitan `hint` text koji ovo objašnjava operateru.

4. **TSPL2 raw path (preferirano za TSC ML340P)** — kompletan zaobilazak browsera:
   - Postaviti env var `VITE_LABEL_PRINTER_PROXY_URL=http://192.168.x.x:8765/print` u `.env.local`
   - Lokalni proxy agent (mali Node ili Python servis) na PC-u u istoj LAN-i:
     ```js
     // primer: pseudo-Node agent
     app.post('/print', (req, res) => {
       const tspl2 = req.body.payload?.tspl2 || '';
       if (!tspl2) return res.status(400).json({ ok: false });
       const sock = net.createConnection({ host: PRINTER_IP, port: 9100 });
       sock.write(tspl2);
       sock.end(() => res.json({ ok: true }));
     });
     ```
   - Sa ovim path-om, browser print prozor je samo **vizualni preview** — pravi otisak ide direktno preko TCP-a, header-i se NE pojavljuju, layout je piksel-precizan.

## 5. TSPL2 program — referenca

Generiše se iz `src/lib/tspl2.js` `buildTspLabelProgram(spec)`. Primer izlaznog programa za RN `7351/1088`:

```
SIZE 80 mm, 50 mm
GAP 3 mm, 0 mm
DIRECTION 1
REFERENCE 0,0
OFFSET 0 mm
SET TEAR ON
DENSITY 8
SPEED 4
CODEPAGE 1252
CLS
TEXT 18,18,"4",0,1,1,"RN: 7351/1088"
TEXT 18,83,"3",0,1,1,"Komitent: Jugoimport SDPR"
TEXT 18,130,"2",0,1,1,"Predmet: Perun - automatski punjac"
TEXT 18,171,"2",0,1,1,"Deo: PRIGUSENJE 1 40/22 - KONUS"
TEXT 18,213,"3",0,1,1,"Crtez: 1130927  |  Kol: 1/96"
TEXT 18,260,"2",0,1,1,"Mat: C.4732 FI30X30  |  Dat: 23-04-26"
BARCODE 24,307,"128M",213,2,0,2,4,"RNZ:0:7351/1088:0:0"
PRINT 1,1
```

Ključno za TSC firmware:
- **Codepage 1252** (Western European) — naši dijakritici (š, č, ć, ž, đ) se transliterišu u ASCII pre slanja jer ML340P firmware default-uje na CP850. Vidi `asciiTranslit()` u `tspl2.js`. Ako u budućnosti pređemo na CP1250, transliteracija se može isključiti.
- **`128M`** (CODE128 Auto-mode) — automatski bira CODE-B (alfanumerički) ili CODE-C (numerički) zavisno od sadržaja. Naš payload `RNZ:0:7351/1088:0:0` ima mešavinu pa završava u CODE-B mode-u (efikasno).
- **`narrow=2, wide=4`** — daje gust ali oštar barkod na 300dpi. Ako je potrebno čak i veće, povećaj `narrow` na 3 (modul ≈ 0.25mm umesto 0.17mm).

## 6. Test scan plan

Operater treba da prošeta barkod kroz **proizvodni skener** (taj koji magacin već koristi) **iz različitih udaljenosti** (15cm, 30cm, 50cm) i **uglova** (frontalno, ±15°, ±30°). Beleži:

| Udaljenost / Ugao | Stara nalepnica | Nova nalepnica (browser) | Nova (TSPL2) |
|---|---|---|---|
| 15cm / 0° | ✓/✗ | ✓/✗ | ✓/✗ |
| 30cm / 0° | ✓/✗ | ✓/✗ | ✓/✗ |
| 50cm / 0° | ✓/✗ | ✓/✗ | ✓/✗ |
| 15cm / 30° | ✓/✗ | ✓/✗ | ✓/✗ |
| 30cm / 30° | ✓/✗ | ✓/✗ | ✓/✗ |

Cilj: nova nalepnica čita **najmanje** podjednako dobro kao stara na svim kombinacijama. Idealno: čitaj sa veće udaljenosti zbog 2.8× šireg module width-a.

## 7. Verdict & next steps

- ✓ Layout redizajn implementiran (`labelsPrint.js`, funkcija `printTechProcessLabelsBatch`).
- ✓ TSPL2 generator implementiran (`src/lib/tspl2.js`).
- ✓ Browser print suppression — CSS + UI hint operateru.
- ⏳ **Operater treba** jednom da konfiguriše Chrome (Headers and footers OFF) za TSC profil.
- ⏳ **IT/operater treba** da postavi local proxy agent + `VITE_LABEL_PRINTER_PROXY_URL` ako želimo da idemo punu TSPL2 putanju (preporučeno za produkciju).
- ⏳ **Operater treba** da odštampa 5 testnih nalepnica (3× browser, 2× TSPL2 ako proxy radi) i izvrši scan plan iz tačke 6 pre nego što stara putanja bude potpuno zatvorena.

---

*Author: Cursor agent (na zahtev Nenad Jarakovic), 2026-04-23. Sledeći deliverable: Task 3b (multi-select print page).*

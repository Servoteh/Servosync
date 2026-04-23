# Lokacije — nalepnice za TP: visual & print spec (Task 2)

> Sledi audit iz `01-encoding-audit.md`. Ovde dokumentujemo **layout, dimenzije, štampu i razlog zašto NE šaljemo SIZE komandu štampaču**.

---

## 1. Hardver i printer-side konfiguracija

| Stavka | Vrednost |
|---|---|
| Štampač | **TSC ML340P** |
| Firmware | A2.15 EZD (vidi web admin: `http://192.168.70.20`) |
| Rezolucija | **300 DPI** = 11.81 dots/mm |
| Print engine | **Direct-Thermal** (NEMA ribbon — termo papir) |
| Native jezik | **TSPL / TSPL2** (preferirano) ili Windows GDI driver |
| Konekcija | **LAN, raw TCP port 9100** (preferirano) ili USB |
| **Paper Width (configured)** | **80.34 mm** |
| **Paper Height (configured)** | **40.30 mm** |
| Gap Size (configured) | 3.05 mm |
| Sensor Type | Continuous (gap) |

> **Konfiguracija je urađena jednom kroz TSC web admin** (http://192.168.70.20 ▸ Configuration ▸ Media). **NE smemo** da je menjamo iz klijenta.

## 2. Zašto NE šaljemo `SIZE` / `GAP` / `DENSITY` komande

Operater je javio: *„kada saljem print, ovo na slici dva mu je poslato kao izmena sa stampaca... Da ne saljemo izmene formata stampacu jer ga blokiramo, mora da ostane tako."*

Šta se događalo: prethodna verzija TSPL2 generatora je u svaki print job slala:

```
SIZE 80 mm, 50 mm
GAP 3 mm, 0 mm
DIRECTION 1
DENSITY 8
SPEED 4
CODEPAGE 1252
SET TEAR ON
```

TSC ML340P **prihvata** ove komande, ali ih ne ignoriše — on PIŠE preko trenutne web-admin konfiguracije. Pošto je prethodna verzija slala POGREŠNU visinu (50mm umesto 40.30mm), štampač je ulazio u kalibracioni loop kad ne može da nađe gap na očekivanoj poziciji → blocked stanje, traži manuelni reset.

**Pravilo (encode-only mode):**

Iz klijenta šaljemo SAMO komande koje crtaju sadržaj:

| Komanda | Funkcija | Bezbedno? |
|---|---|---|
| `CLS` | Briše print buffer pre crtanja | ✓ (ne menja konfiguraciju) |
| `TEXT x,y,...` | Crta tekst u tekućoj orijentaciji | ✓ |
| `BARCODE x,y,...` | Crta barkod | ✓ |
| `PRINT n,m` | Šalje buffer štampaču | ✓ |
| ~~`SIZE`~~ | ~~Postavlja paper size~~ | ✗ **ZABRANJENO** |
| ~~`GAP`~~ | ~~Postavlja gap između nalepnica~~ | ✗ **ZABRANJENO** |
| ~~`DENSITY`~~ | ~~Print density~~ | ✗ **ZABRANJENO** |
| ~~`SPEED`~~ | ~~Print speed~~ | ✗ **ZABRANJENO** |
| ~~`CODEPAGE`~~ | ~~Encoding~~ | ✗ **ZABRANJENO** |
| ~~`DIRECTION`~~ | ~~Orientation~~ | ✗ **ZABRANJENO** |
| ~~`REFERENCE`~~ | ~~Origin offset~~ | ✗ **ZABRANJENO** |
| ~~`SET TEAR`~~ | ~~Tear-off mode~~ | ✗ **ZABRANJENO** |

Generator (`src/lib/tspl2.js`) ovo enforce-uje; testovi (`tests/lib/tspl2.test.js`) verifikuju da NIJEDNA "format change" komanda nije prisutna u izlazu.

**Kada se promeni format nalepnice u pogonu** (npr. nova rolna 100×60mm) — operater ide u TSC web admin i menja Paper Width / Height → klik Set. Klijentski kod NE intervenira.

## 3. Dimenzije nalepnice (mm)

```
┌──────────────────── 80 mm ────────────────────┐
│ 1mm padding gore                              │
│                                               │
│ 7351/1088              Jugoimport SDPR        │ y=1.0mm,  red 1: RN | Komitent
│ Perun – automatski punjac                     │ y=5.5mm,  red 2: Naziv predmeta
│ PRIGUSENJE 1 40/22 - KONUS                    │ y=8.5mm,  red 3: Naziv dela
│ Crtez: 1130927         C.4732 FI30X30         │ y=11.5mm, red 4: Crtez | Materijal
│ Kol: 1/96              23-04-26               │ y=14.5mm, red 5: Kolicina | Datum
│                                               │
│ ║║│║║║│║║│║║│║║║║│║║│║║│║║│║║║║│║║│║║│║║│║║│ │ y=17.0mm, h=20mm
│ ║║│║║║│║║│║║│║║║║│║║│║║│║║│║║║║│║║│║║│║║│║║│ │ CODE128 full-width
│                                               │
└───────────────────────────────────────────────┘
                  40.3 mm
```

| Sekcija | y (mm) | h (mm) | Font (TSPL2) | CSS font-size |
|---|---|---|---|---|
| Padding gore | 0 | 1.0 | – | – |
| Red 1: RN | 1.0 | 4.0 | "4" (24×32 dots) — naglašen | 11pt bold |
| Red 1: Komitent | 2.0 | 3.0 | "2" (12×20 dots) | 7pt |
| Red 2: Naziv predmeta | 5.5 | 2.5 | "2" | 7pt |
| Red 3: Naziv dela | 8.5 | 2.5 | "2" | 7pt |
| Red 4: Crtez/Materijal | 11.5 | 2.5 | "2" | 7pt |
| Red 5: Količina/Datum | 14.5 | 2.5 | "2" | 7pt |
| Barkod | 17.0 | 20.0 | – (CODE128 128M) | – |
| Padding dole | 37.0 | 3.3 | – | – |

Total korišćena visina: 37mm; rezerva: 3.3mm (za toleranciju štampe i gap-detekciju).

## 4. Barkod parametri (CODE128)

| Parametar | JsBarcode (browser) | TSPL2 (TSC) |
|---|---|---|
| Module width | `width: 2.2 px` | `narrow=2 dots` (~0.17mm) |
| Wide bar ratio | n/a (CODE128 binary) | `wide=4 dots` |
| Visina | `height: 80 px` (CSS scale-uje na ~20mm) | `height = 20mm × 11.81 ≈ 236 dots` |
| Quiet zone | 2mm CSS padding oko `<svg>` | manuelno: `BC_X = 2mm` |
| Human readable | OFF | OFF (RN je već u Redu 1) |
| Subset | Auto (CODE128 Auto) | `128M` (auto-switch CODE-A/B/C) |
| Rotation | 0 (horizontalno) | 0 |

**Quiet zone compliance:** CODE128 standard zahteva 10× module width. Sa narrow=2 dots → 20 dots = ~1.7mm minimum quiet zone. Mi imamo 2mm svake strane → **PASS**.

## 5. Suppression browser print headers/footers

Problem: Chrome/Edge default print podešavanja dodaju `<title>` + URL + datum + page-num na svaku stranicu. Pošto je `@page = label = 80×40mm`, ti header-i upadaju u sam label area.

Rešenje (3 sloja):

1. **CSS** — `@page { size: 80mm 40mm; margin: 0 }` u `TECH_LABEL_CSS` (`src/ui/lokacije/labelsPrint.js`). Sa nultom marginom Chrome u nekim verzijama izostavlja header/footer; nepouzdano samo sa CSS-om.
2. **Prazan `<title>`** — postavili smo `<title> </title>` (jedan razmak) u open-uvon prozoru.
3. **Operater jednom isključi „Headers and footers" u Chrome print dijalogu:**
   - Otvori Chrome print dijalog (`Ctrl+P`)
   - „More settings" ▸
   - **„Headers and footers" ▸ OFF** ✓
   - „Margins" ▸ **None** ✓
   - „Background graphics" ▸ ON (po želji)
   - Klikni „Save as default" — Chrome pamti per-printer-profile

Toolbar nove print stranice ima eksplicitan hint operateru.

4. **TSPL2 raw path (preferirano za TSC ML340P)** — kompletan zaobilazak browsera. Postavi `VITE_LABEL_PRINTER_PROXY_URL` u `.env.local` na endpoint lokalnog proxy agenta koji prima JSON i piše `payload.tspl2` direktno na TCP `192.168.70.20:9100`. Sa ovim path-om, browser print prozor je samo vizualni preview — pravi otisak ide raw, headeri se NE pojavljuju.

Pseudo-Node primer agenta:

```js
import express from 'express';
import net from 'net';
const app = express();
app.use(express.json({ limit: '256kb' }));
app.post('/print', (req, res) => {
  const tspl2 = req.body?.payload?.tspl2 || '';
  if (!tspl2) return res.status(400).json({ ok: false, error: 'missing tspl2' });
  const sock = net.createConnection({ host: '192.168.70.20', port: 9100 });
  sock.on('connect', () => sock.end(tspl2));
  sock.on('error', e => res.status(502).json({ ok: false, error: String(e) }));
  sock.on('close', () => res.json({ ok: true, bytes: tspl2.length }));
});
app.listen(8765, () => console.log('TSPL2 proxy on :8765'));
```

## 6. TSPL2 program — referenca

Generiše se iz `src/lib/tspl2.js` `buildTspLabelProgram(spec)`. Primer izlaznog programa za RN `7351/1088`:

```
CLS
TEXT 18,12,"4",0,1,1,"7351/1088"
TEXT 496,24,"2",0,1,1,"Jugoimport SDPR"
TEXT 18,65,"2",0,1,1,"Perun - automatski punjac"
TEXT 18,100,"2",0,1,1,"PRIGUSENJE 1 40/22 - KONUS"
TEXT 18,136,"2",0,1,1,"Crtez: 1130927"
TEXT 496,136,"2",0,1,1,"C.4732 FI30X30"
TEXT 18,171,"2",0,1,1,"Kol: 1/96"
TEXT 496,171,"2",0,1,1,"23-04-26"
BARCODE 24,201,"128M",236,0,0,2,4,"RNZ:0:7351/1088:0:0"
PRINT 1,1
```

Napomene:
- **Bez `CODEPAGE`** — Naši dijakritici (š, č, ć, ž, đ) se transliterišu u ASCII pre slanja (vidi `asciiTranslit()`). Štampač koristi ono što je već konfigurisano u admin-u; mi ne intervenišemo.
- **`128M`** (CODE128 Auto-mode) — automatski bira CODE-B/C zavisno od sadržaja.
- **`narrow=2, wide=4`** — gust ali oštar barkod na 300dpi. Ako bude potreba za većom vidljivošću sa daljine, povećati `narrow` na 3.

## 7. Test scan plan

Operater treba da prošeta barkod kroz proizvodni skener iz različitih udaljenosti i uglova. Beleži (✓/✗):

| Udaljenost / Ugao | Stara nalepnica | Nova (browser) | Nova (TSPL2) |
|---|---|---|---|
| 15cm / 0° | ✓/✗ | ✓/✗ | ✓/✗ |
| 30cm / 0° | ✓/✗ | ✓/✗ | ✓/✗ |
| 50cm / 0° | ✓/✗ | ✓/✗ | ✓/✗ |
| 15cm / 30° | ✓/✗ | ✓/✗ | ✓/✗ |
| 30cm / 30° | ✓/✗ | ✓/✗ | ✓/✗ |

Cilj: nova nalepnica čita najmanje podjednako dobro kao stara.

## 8. Verdict & next steps

- ✓ Layout redizajn za **80×40mm** stock implementiran (`labelsPrint.js`, funkcija `printTechProcessLabelsBatch` + `buildTechLabelHtmlBlock`).
- ✓ TSPL2 generator u **encode-only mode** (`src/lib/tspl2.js`) — **NE šalje SIZE/GAP/DENSITY**.
- ✓ Browser print suppression — CSS + UI hint operateru.
- ⏳ **Operater treba** jednom da konfiguriše Chrome (Headers and footers OFF) za TSC profil.
- ⏳ **IT/operater treba** da postavi local proxy agent + `VITE_LABEL_PRINTER_PROXY_URL` ako želimo punu TSPL2 putanju (preporučeno za produkciju).
- ⏳ **Operater treba** da odštampa 5 testnih nalepnica (3× browser, 2× TSPL2 ako proxy radi) i izvrši scan plan iz tačke 7.

---

*Author: Cursor agent (na zahtev Nenad Jarakovic), 2026-04-23. Revizija nakon utvrđivanja stvarnih dimenzija stock-a (80.34×40.30mm) i printer-side config constraint-a.*

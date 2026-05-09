


# Cursor Instrukcija — Modul REVERSI (Alati i oprema)

Jedna instrukcija koja pokriva ceo Reversi modul, sa fokusom na 2 ključna taba: **Magacin** i **Rezni alat**.

---

## 1. Globalni kontekst modula

**Reversi** = sistem za zaduženja alata i opreme. Modul ima 5 glavnih tabova:

| Tab | Sadržaj |
|---|---|
| Moja zaduženja | Lista alata koje je trenutni korisnik zadužio |
| **Magacin** | Jedinstveni pregled svih artikala (ručni + rezni) u magacinu |
| Zaduženja | Aktivni reversi (ko je šta zadužio) |
| Inventar alata i opreme | Lista ručnog alata i opreme (1 komad = 1 stavka) |
| **Rezni alat** | Katalog šifri reznog alata (1 šifra → količina po lokaciji) |

### TopNav (standard za ceo modul)
```tsx
<TopNav title="Reversi" subtitle="Alati i oprema" icon={RotateCcw} />
```

### Glavni tabovi (`ReversiTabs`)
- 5 tabova → horizontalni tabovi sa coral underline
- Svaki tab: ikona + label + brojač (npr. "Magacin 247")
- Active: `border-b-2 border-primary text-primary`

### Layout pravilo
- `<main className="flex-1 px-6 py-5 space-y-4">` — **NEMA `max-w`**
- Sav sadržaj se prostire čitavom širinom ekrana (od ćoška do ćoška, samo 24px paddinga sa strana)

---

## 2. Tab MAGACIN

### Cilj
Jedinstveni pregled svih artikala u magacinu — i ručni alat (1 komad = 1 red, slobodan u magacinu) i rezni alat (suma po WAREHOUSE lokacijama).

### Struktura
```
PageHeader (Package ikona, "Magacin", opis)
└── Stats (4 kartice): Ukupno | Ručni | Rezni | Nisko stanje (crveni tone)
└── Toolbar: search + Grupa segmented (Sve/Ručni/Rezni) + ☑ Nulta stanja + Excel + + Novi artikal
└── Table (8 kolona)
```

### Kolone tabele
| # | Kolona | Širina | Format |
|---|---|---|---|
| 1 | Kataloški broj | 128px | mono bold + barkod ispod (mono mali sivi) |
| 2 | Naziv | flex | regular |
| 3 | Grupa | 112px | badge "Ručni" (plav, Wrench) / "Rezni" (lila, Scissors) |
| 4 | Lokacija | 160px | mono pill `WH-A-03-12` (samo za rezni; ručni = `—`) |
| 5 | Količina | 128px right | bold, sa jm + `min. X` ispod, obojena |
| 6 | Status | 128px | pill: Na stanju (zel) / Nisko stanje (žut) / Nema (crv) |
| 7 | Ažurirano | 128px | dd.mm.yyyy. |
| 8 | Akcije | 96px right | Eye + Pencil |

### Logika statusa količine
```ts
if (kolicina === 0) → "Nema" (crveno, text-red-600)
else if (kolicina < minKolicina) → "Nisko stanje" (žuto, text-amber-600)
else → "Na stanju" (zeleno, text-gray-900)
```

### Komponente
- `components/MagacinStats.tsx` — 4 stat kartice
- `components/MagacinToolbar.tsx` — search + segmented filter + checkbox + akcije
- `components/MagacinTable.tsx` — full-width tabela sa filter logikom

---

## 3. Tab REZNI ALAT

### Cilj
Katalog šifri reznog alata. Jedna **šifra** (npr. `RZN-000123 — Glodalo D12 HSS`) može imati količinu na više lokacija: u magacinu + na više mašina (kroz aktivne reverse). Tab pokazuje agregirano stanje po šifri.

### Struktura
```
PageHeader (Scissors ikona, "Rezni alat", opis)
└── Sub-tabs: [Katalog] | Po mašinama | Po zaposlenima  ← coral underline, manji nivo
└── Stats (5 kartica): Ukupno šifri | Aktivne (zel) | Na mašinama | U magacinu | Niska zaliha (crv)
└── Toolbar (2 reda):
    Red 1 (filteri): search + Klasa select + Mašina select + Status select
    Red 2 (akcije): [Štampa odabranih] | Zaduženje (skener) [primary] + Povraćaj (skener) | Excel + Nova šifra [primary]
└── Table (9 kolona, sa checkbox za bulk select)
```

### Sub-tabs `ReversiSubTabs`
- 3 stavke: Katalog / Po mašinama / Po zaposlenima
- Coral underline, **manji font** (`text-sm`) i tanji padding od glavnih tabova — vizuelna hijerarhija
- Klasa: `border-b-2`, active = coral; nije zaseban container, samo gornja granica

### Kolone tabele (Katalog)
| # | Kolona | Širina | Format |
|---|---|---|---|
| 1 | ☑ checkbox | 40px | za bulk Štampa odabranih |
| 2 | Oznaka | 160px | mono bold `RZN-000123` + barkod ispod |
| 3 | Naziv | flex | regular |
| 4 | Klasa | 112px | obojen badge: Glodalo (lila), Burgija (plav), Pločica (žut), Urezivač (teal), Razvrtač (roze) |
| 5 | U magacinu | 112px right | broj + `kom` |
| 6 | Na mašinama | 128px right | broj + `(N)` brojač lokacija + chevron za expand |
| 7 | Ukupno | 96px right | bold, obojena prema zalihama (crv/žut/crn) + `min. X` ispod |
| 8 | Status | 112px | pill: Aktivna (zel) / Povučena (siv) |
| 9 | Akcije | 128px right | Printer + Eye + Pencil |

### Expandable red — "Raspored po mašinama"
Klikom na broj "Na mašinama" otvara se podred sa pillovima:
```
[CNC-01  2 kom] [CNC-03  1 kom]
```

### Skener akcije (ključno!)
- **Zaduženje (skener)**: PRIMARY coral button — otvara modal sa skeniranjem barkoda za izdavanje
- **Povraćaj (skener)**: secondary white outline — otvara modal sa skeniranjem za vraćanje
- **Štampa odabranih**: bulk akcija, disabled dok nije izabran ni jedan red, prikazuje brojač (`Štampa odabranih  3`)

### Komponente
- `components/ReversiSubTabs.tsx` — 3 podtaba sa coral underline
- `components/RezniAlatStats.tsx` — 5 stat kartica
- `components/RezniAlatToolbar.tsx` — 2-redni toolbar (filteri + akcije)
- `components/RezniAlatTable.tsx` — tabela sa checkbox-bulk-select i expandable redom

---

## 4. Zajednička dizajn pravila

1. **Status pill format** — uvek isti pattern: dot + label, rounded-md, border, pastel pozadina
   - Zeleno (success): `bg-green-50 text-green-700 border-green-200`
   - Žuto (warning): `bg-amber-50 text-amber-700 border-amber-200`
   - Crveno (danger): `bg-red-50 text-red-700 border-red-200`
   - Sivo (neutral): `bg-gray-100 text-gray-600 border-gray-200`

2. **Klasa/grupa badges** — pastel tonovi po kategoriji, border + text isti hue
   - Glodalo lila, Burgija plav, Pločica žut, Urezivač teal, Razvrtač roze
   - Ručni alat plav, Rezni alat lila

3. **Brojevi i količine** — desno poravnati, bold, sa jm sitnim sivim fontom
   - Crveno za 0, žuto za ispod min., crno za normalno

4. **Mono font** za sve identifikatore: kataloški broj, oznaka, barkod, lokacija (`WH-A-03-12`)

5. **Hover stanje reda** — `hover:bg-primary-light/30`
6. **Selected red** — `bg-primary-light/40` (kad je checkbox aktivan)
7. **Zebra striping** — `even:bg-gray-50/40`

8. **Excel button** uvek zelena outline (`bg-green-50 border-green-200 text-green-700`)
9. **Primary akcije** uvek coral (`bg-primary text-white`)
10. **Skener akcije** — primary coral za zaduženje, secondary za povraćaj

---

## 5. Šta NE raditi (anti-patterns)

- ❌ Ne stavljaj `max-w` na `<main>` — sve tabele moraju biti edge-to-edge
- ❌ Ne koristi plavu boju za active tab — uvek coral (`#E25B45`)
- ❌ Ne mešaj filtere i akcije u istu liniju kad imaš 4+ akcija — koristi 2 reda u toolbar-u
- ❌ Ne pravi sub-tabove istom veličinom kao glavne tabove — moraju biti vizuelno manji nivo
- ❌ Ne sakrivaj brojač "Na mašinama" iza tooltip-a — koristi expand red sa pillovima
- ❌ Ne prikazuj samo količinu — uvek dodaj kontekst (jm, min., status)
- ❌ Ne ostavljaj prazan state bez CTA — uvek "+ Dodaj prvu šifru" / "Nema rezultata, izmenite filter"

---

## 6. Acceptance kriterijumi

### Magacin
- [ ] Sadržaj edge-to-edge (samo `px-6`)
- [ ] 4 stat kartice (Ukupno / Ručni / Rezni / Nisko stanje crvena)
- [ ] Toolbar u jednoj liniji: search + segmented filter + checkbox + Excel + Nova
- [ ] Tabela 8 kolona, količina obojena prema status logici
- [ ] Grupa badges razlikuju ručni/rezni
- [ ] Lokacija samo za rezni alat

### Rezni alat
- [ ] Sub-tabs (Katalog/Po mašinama/Po zaposlenima) sa coral underline
- [ ] 5 stat kartica
- [ ] Toolbar 2 reda: filteri zasebno od akcija
- [ ] Skener akcije (Zaduženje primary coral, Povraćaj secondary)
- [ ] Bulk select sa "Štampa odabranih" + brojač
- [ ] Tabela 9 kolona, klasa badges obojeni
- [ ] Expandable red sa rasporedom po mašinama
- [ ] Status: Aktivna (zelena) / Povučena (siva)
- [ ] Ukupno = magacin + sume po mašinama, obojeno prema min. količini

### Globalno
- [ ] TopNav koristi reusable komponentu sa props (`title`, `subtitle`, `icon`)
- [ ] Glavni tabovi i sub-tabovi konzistentni sa app-wide pravilom navigacije
- [ ] Sve identifikatore (oznaka, barkod, lokacija) u mono fontu
- [ ] Pastel boje za badge kategorije



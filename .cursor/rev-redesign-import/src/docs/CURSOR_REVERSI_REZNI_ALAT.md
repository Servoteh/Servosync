


# Cursor Instrukcija — REVERSI / REZNI ALAT (predlog dizajna + dorada da funkcioniše)

> **Napomena**: Ovaj dokument predstavlja **moj predlog dizajna i strukture** za tab "Rezni alat" u Reversi modulu. Tvoj zadatak je da ga **implementiraš u produkcijskoj aplikaciji** (Supabase + React + TS), doradiš nedostajuće delove i povežeš sa stvarnim podacima tako da sve funkcionalno radi.

---

## 1. Predlog strukture taba

Glavni tab **Rezni alat** ima 3 sub-taba (sub-navigacija unutar taba):

| Sub-tab | Sadržaj | Status |
|---|---|---|
| **Katalog** | Lista svih šifri reznog alata sa agregiranim stanjem | ✅ Detaljno specificirano (sekcija 2) |
| **Po mašinama** | Pivot pregled: šifre × mašine, količine u ćelijama | ⚙️ Potrebna implementacija |
| **Po zaposlenima** | Ko trenutno drži koje šifre (kroz aktivne reverse) | ⚙️ Potrebna implementacija |

Sub-tabovi koriste coral underline pattern, manji su nivo od glavnih Reversi tabova.

---

## 2. Sub-tab KATALOG — predlog kolona

Tabela sa sledećim kolonama (ovo je predlog koji treba implementirati):

| # | Kolona | Tip | Izvor podatka | Format / Logika |
|---|---|---|---|---|
| 1 | ☑ Checkbox | bool (UI state) | client | Bulk select za "Štampa odabranih" |
| 2 | **Oznaka** | string | `rezni_alat.oznaka` | Mono bold, npr. `RZN-000123` |
|   | Barkod | string | `rezni_alat.barkod` | Ispod oznake, mono mali sivi |
| 3 | **Naziv** | string | `rezni_alat.naziv` | Pun naziv artikla |
| 4 | **Klasa** | enum | `rezni_alat.klasa` | Badge sa bojom: Glodalo (lila), Burgija (plav), Pločica (žut), Urezivač (teal), Razvrtač (roze) |
| 5 | **U magacinu** | int | `rezni_alat_lokacije WHERE tip='WAREHOUSE'` SUM | Količina slobodna u magacinu |
| 6 | **Na mašinama** | int + breakdown | `revers_stavke WHERE status='aktivan'` GROUP BY mašini | Suma + brojač lokacija + expand za detalje |
| 7 | **Ukupno** | int (computed) | `U magacinu + Na mašinama` | Bold, obojen prema `min_kolicina` |
| 8 | **Status** | enum | `rezni_alat.status` | Pill: Aktivna (zel) / Povučena (siv) |
| 9 | **Akcije** | — | — | Štampa nalepnice + Pregled + Izmena |

### Logika boje za "Ukupno"
```ts
if (ukupno === 0) → text-red-600 (nema)
else if (ukupno < min_kolicina) → text-amber-600 (nisko)
else → text-gray-900 (ok)
```

### Expandable red — "Raspored po mašinama"
Klikom na vrednost u koloni "Na mašinama" otvara se podred:
```
[CNC-01  2 kom] [CNC-03  1 kom] [Strug-01  4 kom]
```
Svaki pill je klikabilan i vodi na detalje reversa za tu mašinu (opciono u v2).

---

## 3. Predlog filtera i akcija (toolbar)

### Red 1 — Filteri
- **Pretraga** (po: oznaci, nazivu, klasi, barkodu) — debounced 250ms
- **Klasa** select (sve klase iz enum-a + "Sve")
- **Mašina** select (lista iz `masine` tabele + "Sve mašine")
- **Status** select (Aktivne [default] / Povučene / Sve)

### Red 2 — Akcije
- **Štampa odabranih** (sekundarni button, disabled dok nema selekcije, prikaz brojača)
- **Zaduženje (skener)** — primary coral, otvara modal za skeniranje
- **Povraćaj (skener)** — sekundarni outline, otvara modal za skeniranje
- Desno: **Excel** (zelena outline) + **Nova šifra** (primary coral)

---

## 4. Šta TREBA DA URADIŠ — implementacija da funkcioniše

### 4.1 Data model (Supabase)

Proveri/dodaj sledeće tabele:

```sql
-- Šifre reznog alata
create table rezni_alat (
  id uuid primary key default gen_random_uuid(),
  oznaka text unique not null,           -- npr. RZN-000123
  barkod text,
  naziv text not null,
  klasa text not null check (klasa in ('Glodalo','Burgija','Pločica','Urezivač','Razvrtač')),
  min_kolicina int default 0,
  status text default 'aktivna' check (status in ('aktivna','povučena')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Stanje po lokacijama (WAREHOUSE = magacin, MASINA = na mašini)
create table rezni_alat_lokacije (
  id uuid primary key default gen_random_uuid(),
  rezni_alat_id uuid references rezni_alat(id) on delete cascade,
  tip text not null check (tip in ('WAREHOUSE','MASINA')),
  masina_id uuid references masine(id),  -- null kad je tip=WAREHOUSE
  kolicina int not null default 0,
  unique (rezni_alat_id, tip, masina_id)
);
```

> Ako tabele već postoje pod drugim imenima, mapiraj ih i prijavi razlike.

### 4.2 Query za listu kataloga

```ts
// supabase query
const { data } = await supabase
  .from('rezni_alat')
  .select(`
    id, oznaka, barkod, naziv, klasa, min_kolicina, status,
    lokacije:rezni_alat_lokacije(tip, masina_id, kolicina, masina:masine(oznaka))
  `)
  .order('oznaka')

// agregacija u JS:
const rows = data.map(r => {
  const uMagacinu = r.lokacije
    .filter(l => l.tip === 'WAREHOUSE')
    .reduce((s, l) => s + l.kolicina, 0)
  const naMasinama = r.lokacije
    .filter(l => l.tip === 'MASINA' && l.kolicina > 0)
    .map(l => ({ masina: l.masina.oznaka, kolicina: l.kolicina }))
  const totalNaMas = naMasinama.reduce((s, m) => s + m.kolicina, 0)
  return { ...r, uMagacinu, naMasinama, ukupno: uMagacinu + totalNaMas }
})
```

### 4.3 Filteri (server-side gde god moguće)

```ts
let q = supabase.from('rezni_alat').select(...)
if (status === 'aktivne') q = q.eq('status', 'aktivna')
if (status === 'povucene') q = q.eq('status', 'povučena')
if (klasa !== 'all') q = q.eq('klasa', klasaCapitalized)
if (search) {
  q = q.or(`oznaka.ilike.%${search}%,naziv.ilike.%${search}%,barkod.ilike.%${search}%`)
}
// Filter po mašini se primenjuje na klijentu nakon agregacije
```

### 4.4 Skener workflow

#### Zaduženje (skener)
Modal sa 3 koraka:
1. **Skeniraj radnika** (barkod kartice → `radnici.barkod`)
2. **Skeniraj mašinu** (opciono — ako je ovo zaduženje za mašinu, ne za radnika)
3. **Skeniraj šifre alata** (loop, dodaje stavke u listu sa količinom 1; korisnik može povećati)
4. **Potvrdi** → INSERT u `reversi` + `revers_stavke`, decrement `rezni_alat_lokacije` za WAREHOUSE

```ts
async function zaduzi(radnik_id, masina_id, stavke) {
  const { data: revers } = await supabase
    .from('reversi')
    .insert({ radnik_id, masina_id, status: 'aktivan', tip: 'rezni' })
    .select().single()
  
  for (const s of stavke) {
    await supabase.from('revers_stavke').insert({
      revers_id: revers.id,
      rezni_alat_id: s.rezni_alat_id,
      kolicina: s.kolicina,
    })
    // smanji magacinsko stanje
    await supabase.rpc('umanji_magacin', {
      p_rezni_alat_id: s.rezni_alat_id,
      p_kolicina: s.kolicina,
    })
    // poveca stanje na masini (ako je masina_id postavljen)
    if (masina_id) {
      await supabase.rpc('uvecaj_masinu', {
        p_rezni_alat_id: s.rezni_alat_id,
        p_masina_id: masina_id,
        p_kolicina: s.kolicina,
      })
    }
  }
}
```

#### Povraćaj (skener)
Sličan flow ali obratno: skeniraj revers (ili šifre + radnika), označi revers stavke kao vraćene, vrati količinu u magacin.

### 4.5 Štampa odabranih
- Skupi `oznaka + naziv + barkod` za sve selektovane redove
- Otvori novi prozor sa nalepnicama (postojeći modul `Štampa nalepnica` već ovo radi za 1 stavku — proširi za batch)
- Koristi `window.print()` sa `@media print` CSS-om

### 4.6 Sub-tab "Po mašinama" (predlog)
Pivot tabela:
- Redovi: šifre reznog alata
- Kolone: aktivne mašine
- Ćelije: količina za (šifra, mašina) iz `rezni_alat_lokacije WHERE tip='MASINA'`
- Sticky prva kolona (oznaka), sticky header
- Filter po klasi i pretraga šifre

### 4.7 Sub-tab "Po zaposlenima" (predlog)
- Lista radnika koji imaju aktivne reverse za rezni alat
- Expand po radniku → spisak šifri sa količinom i datumom zaduženja
- Akcija "Povrati sve" za radnika

---

## 5. Komponente koje već postoje u prototipu (kao referenca)

| Komponenta | Svrha |
|---|---|
| `components/ReversiTabs.tsx` | 5 glavnih tabova Reversi modula |
| `components/ReversiSubTabs.tsx` | Sub-tabovi (Katalog/Po mašinama/Po zaposlenima) |
| `components/RezniAlatStats.tsx` | 5 stat kartica (Ukupno/Aktivne/Na mašinama/U magacinu/Niska zaliha) |
| `components/RezniAlatToolbar.tsx` | Toolbar 2 reda (filteri + akcije) |
| `components/RezniAlatTable.tsx` | Tabela sa bulk-select i expandable redom |

Reusuj iste klase i strukturu, samo zameni mock podatke pravim Supabase query-jima.

---

## 6. Acceptance kriterijumi (mora da radi)

### Funkcionalno
- [ ] Lista kataloga se učitava iz Supabase, sa korektnom agregacijom (magacin + mašine)
- [ ] Pretraga radi server-side po oznaci, nazivu, barkodu
- [ ] Filter po klasi, mašini, statusu radi (kombinovano)
- [ ] Selekcija checkbox-om aktivira "Štampa odabranih" sa brojačem
- [ ] Klik na "Na mašinama" otvara expand red sa rasporedom
- [ ] **Zaduženje (skener)** modal radi: skeniraj radnika/mašinu → skeniraj šifre → potvrdi → ažurira `reversi`, `revers_stavke`, `rezni_alat_lokacije`
- [ ] **Povraćaj (skener)** modal radi: skeniraj revers ili šifre → potvrdi → ažurira sve tabele
- [ ] **+ Nova šifra** otvara formu za INSERT u `rezni_alat`
- [ ] **Excel export** dovuče sve filtrirane redove sa svim kolonama
- [ ] **Štampa odabranih** otvara batch nalepnice za sve selektovane šifre
- [ ] Status logika tačno menja boju i pill (Nema / Nisko / Aktivna / Povučena)

### Vizuelno
- [ ] Layout edge-to-edge (samo `px-6` margine)
- [ ] Coral underline za sub-tabove (ne plav)
- [ ] Klasa badges sa pastel bojama
- [ ] Mono font za oznaku, barkod, mašinu
- [ ] Hover red = `hover:bg-primary-light/30`
- [ ] Selected red = `bg-primary-light/40`

### Realtime (opciono v2)
- [ ] Subscribe na `rezni_alat_lokacije` izmene → automatsko osvežavanje brojeva bez refresha

---

## 7. Šta da prijaviš nakon implementacije

1. Lista promena u Supabase šemi (ako je bilo dodavanja)
2. Lista nedostajućih kolona/relacija u postojećoj šemi (ako neke ne postoje)
3. Eventualne razlike između predloga i postojećih naziva/struktura
4. Lista funkcionalnosti koje nisu mogle biti implementirane sa trenutnim podacima i šta nedostaje




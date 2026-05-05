# Ažuriranje `first_name` / `last_name` (april 2026)

## Šta je urađeno

U tabeli **`public.employees`** (Supabase) za **sve aktivne zapise** polja **`last_name`** i **`first_name`** su popunjena iz **`full_name`**, po pravilu:

| Izvor | Pravilo |
|--------|--------|
| `full_name` | Normalizacija višestrukih razmaka u jedan; zatim **prva reč → `last_name`**, **ostatak stringa → `first_name`**. |
| Jedna reč u `full_name` | `last_name` = ta reč, `first_name` = `NULL` (trenutno nema takvih redova u setu od 145 zaposlenih). |

Primer: `Durutović Jelena` → `last_name = Durutović`, `first_name = Jelena`.

**`full_name` se ne menja** osim gde je eksplicitno ispravljen pravopis (vidi ispod). Kolona `updated_at` je osvežena.

## Istorija (zašto je bilo pomešano)

U starijoj migraciji `sql/migrations/add_kadr_employee_extended.sql` backfill je tumačio `full_name` kao *„sve do poslednje reči = ime, poslednja reč = prezime”* (bolje za format „Ime Prezime”). U bazi su **`full_name` vrednosti u formi „Prezime Ime”**, pa su `first_name` / `last_name` često bili zamenjeni ili prazni.

Sada su kolone usklađene sa korišćenjem u app-u i u izvozu (Kadrovska, XLSX).

## Ručna korekcija dijakritike (Jelena Durutović)

Zapis je imao `Durutovic Jelena` u `full_name` dok je očekivani pravopis **Durutović**. Posle glavnog `UPDATE`‑a, za taj red je i **`full_name`** postavljen na **`Durutović Jelena`**, sa odgovarajućim `last_name` / `first_name`.

Za druge slične slučajeve: ispraviti **`full_name`** u interfejsu (ili kratkim SQL‑om), pa ponoviti **isti** algoritam (migracija `20260426233000__employees_ime_prezime_from_full_name.sql` ili `UPDATE` ispod).

## Dijakritike opšte

- **`first_name` i `last_name` kopiraju pisanje iz `first_name` / `rest` reči u `full_name`**. Ako u `full_name` piše `Durutovic`, u `last_name` će biti `Durutovic` dok se `full_name` ne ispravi.
- Nema automatskog „c → ć” mapeiranja; to bi zahtevalo rečnik ili ručni unos.

## Kada proveriti ručno

- **`full_name` nije u obliku „Prezime Ime”** (npr. strani format, samo jedno polje, „van der …”, dvostruko prezime drugačije zapisano).
- **Tri ili više reči**: prezime = prva reč; **sve ostalo = ime** (npr. `Jovanović Petar Marko` → `Jovanović` + `Petar Marko`). Ako treba druga podela, korigovati u UI.

## Reprodukcija u drugom okruženju

Migracija: `supabase/migrations/20260426233000__employees_ime_prezime_from_full_name.sql`.

Ekvivalentni `UPDATE` (skraćeno):

```sql
UPDATE public.employees e
SET
  last_name = split_part(t.fn, ' ', 1),
  first_name = CASE
    WHEN strpos(t.fn, ' ') > 0
    THEN btrim(substr(t.fn, strpos(t.fn, ' ') + 1))
    ELSE NULL
  END,
  updated_at = now()
FROM (
  SELECT
    id,
    btrim(regexp_replace(coalesce(full_name, ''), E'\s+', ' ', 'g')) AS fn
  FROM public.employees
) t
WHERE e.id = t.id
  AND t.fn IS NOT NULL
  AND t.fn <> '';
```

## Stanje posle (produkcija)

- **145** redova u `public.employees`.
- Svi imaju i `last_name` i `first_name` (nema `NULL` imena gde `full_name` sadrži razmak).

Lokalni fajl **`docs/reports/employees_full_export.csv`** / **`employees_kadrovska_export.xlsx`** mogu biti zastareli do sledećeg izvoza; ponovo generisati: `python scripts/export_employees_kadrovska_report.py` (sa MCP fajlom ili `--from-csv` posle osvežavanja).

**Veličine (očekivano):** `employees_kadrovska_pregled.html` je oko **140–150 KB** (puni HTML sa tabelama). `employees_kadrovska_export.xlsx` je **mnogo manji** (npr. ~20–30 KB) jer je to ZIP arhiva i manje su podaci nego u HTML; to je u redu. **Otvoriti `.xlsx` u Excelu** (dvoklik iz Explorer-a). U editoru (Cursor) često se prikazuje kao mali/neočit binarni fajl — to **nije** tačna veličina sadržaja u ćelijama; broj „linija” u IDE za Excel nema smisla.

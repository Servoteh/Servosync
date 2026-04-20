# pgTAP testovi za modul Lokacije delova

Testovi proveravaju šeme, RLS, enum vrednosti, potpise RPC funkcija i ponašanje triggera bez izvršavanja "realnih" korisničkih transakcija (za to bi trebao seed auth korisnika sa ulogama, što radimo kroz dedicated test instancu).

## Preduslovi

- pgTAP (Supabase ga ima u `extensions` šemi):
  ```sql
  CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
  ```
- Sve SQL migracije modula primenjene:
  - `sql/migrations/add_loc_module.sql`
  - `sql/migrations/add_loc_step2_ci_unique.sql`
  - `sql/migrations/add_loc_step3_cleanup.sql`
  - `sql/migrations/add_loc_step5_sync_rpcs.sql`

## Pokretanje (Supabase SQL Editor)

Otvori `loc_module_schema.sql` u SQL Editoru, selektuj sve i pokreni. pgTAP vraća TAP output u obliku niza redova `ok 1 - ...`. Traženi rezultat: sve `ok`, nijedno `not ok`.

## Pokretanje (psql + pg_prove)

```bash
# Ako koristiš pg_prove (iz Perl ekosistema):
pg_prove -d "postgresql://USER:PASS@HOST:5432/DB" sql/tests/*.sql
```

## Struktura

- `loc_module_schema.sql` — struktura: tabele, enumi, indeksi, RLS, postojanje funkcija.
- `loc_module_behavior.sql` — trigger-i: cycle detection, path_cached, sync queue ubacivanje.

Behavior testovi ne pretpostavljaju seed auth korisnika — stvari koje zahtevaju `auth.uid()` (npr. direktan RPC poziv `loc_create_movement`) se ne pokreću ovde, već kroz integracione testove na dedicated test instanci.

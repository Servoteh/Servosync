# CI SQL bootstrap

Ovaj folder sadrži pomoćne fajlove koje koristi GitHub Actions workflow
(`.github/workflows/ci.yml`) za automatsko testiranje SQL migracija i pgTAP
testova nad praznom Postgres 15 instancom.

## Sadržaj

- `00_bootstrap.sql` — stubuje Supabase-specifične primitive (`auth.users`,
  `auth.uid()`, role `authenticated`/`anon`/`service_role`, `public.user_roles`,
  ekstenzije `pgcrypto` i `pgtap`). Bez toga migracije ne prolaze na čistom
  Postgres-u jer referenciraju strukture koje u Supabase dolaze po default-u.
- `migrations.txt` — redosled primenjivanja migracija u CI (komentari
  preko `#`). Namerno izostavlja `pg_cron` migraciju koja zavisi od
  Supabase-specifične ekstenzije.

## Lokalno pokretanje

```bash
# 1) Pokreni Postgres 15 sa pgTAP
docker run -d --name pg15-pgtap \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  cloudnativepg/postgresql:15-4

# 2) Apply bootstrap
export PGPASSWORD=postgres
psql -h localhost -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f sql/ci/00_bootstrap.sql

# 3) Apply migracije u redosledu
grep -v '^#' sql/ci/migrations.txt | grep -v '^$' | while read f; do
  psql -h localhost -U postgres -d postgres -v ON_ERROR_STOP=1 -f "$f"
done

# 4) Pokreni pgTAP testove
pg_prove -h localhost -U postgres -d postgres sql/tests/*.sql
```

## Dodavanje nove migracije u CI

1. Dodaj novu liniju (putanja od repo root-a) u `migrations.txt` iznad ili
   ispod zavisnih migracija.
2. Ako zavisi od nečega što `00_bootstrap.sql` ne obezbeđuje (npr. nova
   Supabase-specifična funkcija), dodaj stub u bootstrap.
3. Ako migracija zahteva ekstenziju koja nije dostupna u PG kontejneru
   (npr. `pg_cron`, `pgaudit`), ne dodaj je — zabeleži razlog kao komentar
   u `migrations.txt`.

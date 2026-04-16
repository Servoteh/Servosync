# Plan Montaze v5.1

Single-file HTML aplikacija za pracenje plana montaze sa modelom `projects -> work_packages -> phases` i Supabase backendom za auth, role logiku i cuvanje podataka.

## Sta koristi

- `index.html` kao jedini frontend
- `sql/schema.sql` za Supabase semu i RLS
- Supabase Auth za login/session restore
- Supabase tabele: `projects`, `work_packages`, `phases`, `user_roles`, `reminder_log`

## SUPABASE_CONFIG

Supabase se podesava direktno u `index.html` kroz `SUPABASE_CONFIG`.

Upisati:
- `url`
- `anonKey`
- opciono `reminderEndpoint`

## Role

- `PM`
- `LeadPM`
- `Viewer`

Role se kontrolisu kroz tabelu `user_roles`, a pilot hardening koristi lowercase email lookup i RLS provere preko baze.

## Pilot test

1. Pusti `sql/schema.sql` u Supabase SQL editoru.
2. Napravi korisnike u Supabase Auth.
3. Popuni `user_roles` sa odgovarajucim rolama.
4. Otvori `index.html` preko statickog hostinga ili lokalnog servera.
5. Testiraj login, session restore, role ogranicenja i cuvanje izmena.

## Struktura repoa

- `index.html`
- `sql/schema.sql`
- `docs/notes.md`
- `README.md`

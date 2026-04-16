# Plan Montaze v5.1.1

Pilot hardening patch za online Supabase test.

## Promene

- Lowercase email role lookup u `index.html`
- Login i session restore normalizuju `currentUser.email` na lowercase
- `user_roles` dobija partial unique indekse preko `lower(email)`
- `has_edit_role()` i RLS su uskladjeni sa `user_roles`, bez oslanjanja na JWT role claim
- `sql/schema.sql` je uskladjen sa aktuelnom v5.1 semom
- Repo cleanup: uklonjeni probni i duplikat fajlovi

## Status

Spremno za pilot Supabase test i GitHub verzionisanje.

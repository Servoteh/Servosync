# Podešavanje predmeta

**Podešavanja → Podeš. predmeta** — tabela svih predmeta iz `bigtehn_items_cache` sa prekidačem **Aktivan**, napomenom i poslednjom izmenom. Izvor u bazi: `production.predmet_aktivacija`, RPC `list_predmet_aktivacija_admin` / `set_predmet_aktivacija`.

## Ko vidi rutu

- **Admin** i **menadžment** (isto ulazno pravilo kao za ostala Podešavanja za menadžment: vidi tab „Održ. profili” i ovaj tab).
- Ostale uloge nemaju tab u navigaciji; direktan pristup stranici preko storage tab kôda ne menja to — backend i dalje vraća `forbidden` ako korisnik nema `can_manage_predmet_aktivacija()`.

## Ručni smoke

1. Uloguj se kao **admin** ili **menadžment** — otvori **Podešavanja → Podeš. predmeta**, lista se učita (broj redova = broj predmeta u cache-u).
2. Isključi jedan predmet (toggle) — u **Planu proizvodnje** operacije tog predmeta nestaju sa ekrana (view `v_production_operations_effective`).
3. U **Praćenju** (bez `?rn=`) taj predmet nestaje sa liste aktivnih ako je bio u MES aktivnom skupu — `get_aktivni_predmeti()` poštuje `je_aktivan`.
4. (Opciono) uloguj se kao **PM** / **viewer** — tab se ne vidi; API `list_predmet_aktivacija_admin` vraća grešku pri pristupu.

## SQL smoke

Vidi `supabase/seeds/predmet_aktivacija_smoke.sql` (zahtev ulogovanog konteksta sa JWT za `list`/`set`).

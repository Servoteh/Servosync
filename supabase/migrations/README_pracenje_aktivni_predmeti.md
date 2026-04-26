# Migracija: `20260426203000__pracenje_aktivni_predmeti_init`

## Šta pravi

- Tabela `production.predmet_prioritet` (PK `predmet_item_id integer`, bez FK ka `bigtehn_items_cache`), RLS: SELECT za `authenticated`, I/U/D samo ako `public.current_user_is_admin()`.
- RPC u šemi `production`: `get_aktivni_predmeti()`, `get_podsklopovi_predmeta(integer)`, `set_predmet_prioritet(integer, integer)`, `shift_predmet_prioritet(integer, text)` — svi `SECURITY DEFINER` sa `search_path = public, production, pg_temp` (osim što wrapper-i u `public` koriste samo `public, pg_temp` + kvalifikovano `production.*`).
- Javni wrapper-i u `public` + `GRANT EXECUTE` za `authenticated`.
- `NOTIFY pgrst, 'reload schema'`.

Rollback: `20260426203000__pracenje_aktivni_predmeti_init.down.sql`.

## Smoke test (Supabase MCP / SQL editor)

Preduslov Faze 0: `v_bigtehn_rn_struktura`, `bigtehn_rn_components_cache`, `v_bigtehn_rn_root_count` — potvrđeno `to_regclass` pre primene.

**Napomena:** `set_predmet_prioritet` / `shift_predmet_prioritet` proveravaju `current_user_is_admin()` preko JWT email-a; u SQL editoru bez korisničkog JWT-a očekuj `forbidden`. Skripta `supabase/seeds/pracenje_aktivni_predmeti_smoke.sql` grana admin korake u `DO $$ … NOTICE`.

### Rezultati (povezana dev instanca, posle primene DDL)

1. `SELECT public.get_aktivni_predmeti();`  
   - **Očekivano:** `jsonb` niz objekata sa poljima `item_id`, `broj_predmeta`, `naziv_predmeta`, `customer_name`, `sort_priority` (nullable), `broj_root_rn`, `redni_broj`.  
   - **Uzorkovani red (prvi element):** `item_id: 8693`, `redni_broj: 1`, `broj_root_rn: 1467`, `sort_priority: null`, `broj_predmeta: "7351"`, `customer_name: "Kovački centar d.o.o."`  
   - Ukupno ~68 predmeta u tom snimku (zavisi od `v_active_bigtehn_work_orders`).

2. `SELECT public.get_podsklopovi_predmeta(810102);` (seed A/B/C)  
   - Na instanci **bez** `bigtehn_rn_components_test.sql`: **`[]`**.  
   - Sa seed-om: očekivano 5 redova za predmet C.

3. `SELECT public.get_podsklopovi_predmeta(810100);`  
   - Bez seed-a: **`[]`**. Sa seed-om: 1 red (samo root).

4. `SELECT jsonb_array_length(public.get_podsklopovi_predmeta(9470)) AS n_rows;`  
   - **Rezultat:** `588` (predmet sa velikim stablom u produkcijskom snimku).

5. `SELECT COUNT(*) FROM production.predmet_prioritet;`  
   - **Rezultat:** `0` (pre admin pomeranja).

### Poznata ograničenja

- `shift_predmet_prioritet` posle zamene **renumeriše** `sort_priority` na `0..N-1` za sve aktivne predmete (konzistentan redosled; prvi `shift` upisuje redove za sve predmete u listi).
- `get_podsklopovi_predmeta` vraća **ravnu** listu (nije ugnježden JSON); UI gradi stablo na klijentu.
- Admin mutacije zahtevaju **admin** ulogu u `user_roles` (isti helper kao ostatak aplikacije).

---

## Faza A — status

**FAZA A: ✅ smoke test prošao (read RPC + struktura na povezanoj bazi), DDL primenjen.**  
**FAZA B: ✅ završena u repou** (service + state + UI + README modula).

- RPC read pozivi vraćaju očekivan oblik.  
- Admin write smoke u čistom SQL editoru zavisi od JWT konteksta — ručno u aplikaciji kao admin.

# Migracija: pracenje_predmet_pracenje_izvestaj

## Šta migracija pravi

### `20260429140000__pracenge_predmet_pracenje_izvestaj.sql`

**Sekcija 1 — Helper za završnu kontrolu**
`production._pracenge_line_is_final_control(machine_code, machine_name, no_procedure)` — IMMUTABLE SQL funkcija.
Heuristika (prioritet):
1. `machine_code ~ '^8\.3'` → RJ kod 8.3* = odeljenje za završnu kontrolu
2. `no_procedure = true AND machine_name ~* '(zavr|final|zav\.?\s*kontr|zavrsna|kontrol)'` — proceduralna operacija sa nazivom kontrole

**Sekcija 2 — Tabela napomena**
`production.pracenge_proizvodnje_napomene`:
- Ključ: `(predmet_item_id integer, bigtehn_rn_id bigint)` — stabilan BigTehn legacy ID
- RLS: SELECT = authenticated, INSERT/UPDATE/DELETE = `public.can_manage_predmet_aktivacija()` (admin + menadžment)
- Bez FK ka BigTehn cache tabelama (sync tabele se resync-uju)

**Sekcija 3 — Upsert napomene**
`production.upsert_pracenge_proizvodnje_napomena(predmet_item_id, bigtehn_rn_id, note, rn_id)`:
- SECURITY DEFINER, proverava `can_manage_predmet_aktivacija()` u body-u
- Prazan string / NULL u `p_note` → upsert prazan string (soft-clear, red ostaje)
- Vraća `uuid` novokreiranog/ažuriranog reda

**Sekcija 4 — Glavni izveštajni RPC**
`production.get_predmet_pracenge_izvestaj(p_predmet_item_id, p_root_rn_id, p_lot_qty)`:
- STABLE, SECURITY DEFINER, dostupan svim authenticated korisnicima
- Dvostruki izvor operacija/završene količine: BigTehn cache (primarno) + local production tabele (ako je RN ensure-ovan)
- `crtez_url` i `sklop_url` su uvek NULL — client dohvata signed URL na klik
- `qty_per_assembly` = `bigtehn_rn_components_cache.broj_komada`
- `required_for_lot` = `qty_per_assembly * p_lot_qty` (ne rekurzivno kumulativan)
- Filter podstabla: rekurzivni CTE nad `v_bigtehn_rn_struktura` po `path_idrn`

**Sekcija 5 — Public wrappers**
`public.get_predmet_pracenge_izvestaj` i `public.upsert_pracenge_proizvodnje_napomena` — tanki SQL wrapper-i za PostgREST izloženost.

### `20260429150100__pracenge_predmet_izvestaj_rpc_complete.sql`
Re-aplikacija istog RPC-a i wrappera iz prethodne migracije. Kreira se sa `CREATE OR REPLACE` — idempotentno.

## R1 istraživački nalazi

| Pitanje | Nalaz |
|---------|-------|
| Da li `tp_operacija` ima `is_final_control` kolonu? | **NE** — detekcija završne kontrole je isključivo heuristička (department kod 'KK' ili naziv operacije) |
| Gde se čuva URL crteža? | `bigtehn_drawings_cache.url` — signed URL; u RPC-u se vraća NULL, frontend dohvata via `getBigtehnDrawingSignedUrl(drawing_no)` iz `src/services/drawings.js` |
| Da li `bigtehn_work_orders_cache` ima `datum_lansiranja_tp` i `datum_izrade`? | Da — kolone `datum_unosa` (≈datum lansiranja TP) i `rok_izrade` (≈datum izrade/rok) |
| Da li u repou postoji PDF biblioteka? | **NE u `package.json`** — jsPDF 2.5.1 + html2canvas 1.4.1 se lazy-loaduju sa CDN-a (`src/lib/pdf.js`) na zahtev, izvan Vite bundle-a |
| Da li ima `is_final_control` flag u BigTehn cache-u? | NE — BigTehn ne eksponira ovaj flag; heuristika je jedini način |

## Smoke test

Videti `supabase/seeds/pracenje_izvestaj_smoke.sql`.

Ručno pokrenuti u Supabase SQL editoru:
```sql
\i supabase/seeds/pracenje_izvestaj_smoke.sql
```

Očekivani rezultati opisani u komentarima unutar smoke test fajla.

## R1 ✅ — Frontend R2 i export R3 su implementirani

- R1 ✅ — Backend: migracija, napomene, RPC, wrappers
- R2 ✅ — Frontend: service (`pracenjeProizvodnje.js`), state (`pracenjeProizvodnjeState.js`), UI (`tabelaPracenjaTab.js`)
- R3 ✅ — Export: `src/services/pracenjeIzvestajExport.js` (Excel via SheetJS, PDF via jsPDF CDN)

## Poznata ograničenja

- `crtez_url` / `sklop_url` = NULL u RPC-u; signed URL-ovi su kratkotrajan i dohvataju se client-side
- `required_for_lot` nije dubinski rekurzivan (qty_per_asm × lot, ne × parent_qty × lot) — svesna simplifikacija
- Filteri su client-side; za > 1000 redova razmotriti server-side filter (P2 backlog)
- UI implementiran kao monolitni `tabelaPracenjaTab.js` umesto 6 fajlova u `izvestaj/` (funkcionalno ekvivalentno)
- PDF biblioteka (jsPDF) nije u `package.json` — lazy CDN load; radi u browser-u, ne u Node.js

## TODO (backlog)
- Real-time refresh za izveštaj (trenutno samo ?rn= view ima polling)
- Server-side filteri za predmete sa > 1000 RN-ova
- Multi-predmet komparativni izveštaj
- Rekurzivni kumulativni `required_for_lot` za duboka stabla (> 2 nivoa)

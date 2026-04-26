# Praćenje proizvodnje — frontend smoke test

## Otvaranje modula (Aktivni predmeti + Inkrement 2)

Bez `?rn=` modul prvo učitava **listu aktivnih predmeta** (`public.get_aktivni_predmeti` → distinct `item_id` iz `v_active_bigtehn_work_orders`). Kolone: redni broj, naziv predmeta (ispod: broj predmeta), komitent, badge **broj root MES RN** (`broj_root_rn` iz `v_bigtehn_rn_root_count`). Klik na red ili badge otvara **ekran 2** (`?predmet=<item_id>`): stablo iz `get_podsklopovi_predmeta` (flat RPC, expand/collapse, `localStorage` po `item_id`). Klik na RN (`IdentBroj — NazivDela`) poziva `ensure_radni_nalog_iz_bigtehn` + `loadPracenje` i prebacuje na `?rn=<uuid>`.

**URL:**

- Lista: `/pracenje-proizvodnje` (ili bez query-ja koji nisu `rn`/`predmet`)
- Stablo: `?predmet=810102` (nakon seed-a `bigtehn_rn_components_test.sql`)
- Inkrement 2: `?rn=<uuid|broj>` (direktan ulaz, kao ranije)

Ruta modula:

```text
/pracenje-proizvodnje?rn=55555555-5555-5555-5555-555555555501#tab=po_pozicijama
```

Test RN ID iz Inkrementa 1 seed-a:

```text
55555555-5555-5555-5555-555555555501
```

Tabovi su deep-linkable:

```text
#tab=po_pozicijama
#tab=operativni_plan
```

## Ručni smoke (Aktivni predmeti)

1. Otvori modul bez `?rn=` — vidiš **listu predmeta** (broj redova = aktivni predmeti u MES-u).
2. Ako postoji seed `bigtehn_rn_components_test.sql`: klik na **Predmet C** (`810102`) — stablo sa više nivoa; klik na podsklop koji ima RN — otvara se Inkrement 2.
3. **Nazad** u stablu (`← Nazad na listu predmeta`) → lista; browser **Back** vraća kroz istoriju (`?predmet=` ↔ lista ↔ `?rn=`).
4. **Admin:** u listi vidiš strelice ↑ ↓; klik ↓ na prvom redu → redosled se menja; refresh stranice → redosled ostaje (server `shift_predmet_prioritet`).
5. **Non-admin:** nema strelica; `set_predmet_prioritet` / `shift` na backend-u vraćaju `forbidden` / RLS.

## Očekivano ponašanje

- Header se učita sa kupcem, RN brojem, datumom isporuke, koordinatorom i agregatima.
- Tab `Po pozicijama` prikazuje 3 pozicije i 5 operacija iz seed-a.
- Expand/collapse radi preko native `<details>/<summary>`.
- Tab `Operativni plan` prikazuje 4 aktivnosti i dashboard.
- Status badge prikazuje auto indikator kada `status_is_auto = true`.
- Dugme `Nova aktivnost` je vidljivo samo ako `production.can_edit_pracenje` vrati `true`.
- Posle dodavanja/izmene/zatvaranja aktivnosti state se osvežava iz RPC-ja.

## Inkrement 3 ručni testovi

- Promocija akcione tačke: napravi/open akcioni plan za isti `projekat_id`, klikni `Iz akcione tačke`, izaberi odeljenje, promoviši i potvrdi da se aktivnost vidi u Tab 2 sa izvorom `iz_sastanka`.
- Excel export: klikni `Excel export` na oba taba i otvori fajlove `pracenje_<rn>_po_pozicijama_<YYYYMMDD>.xlsx` i `pracenje_<rn>_operativni_plan_<YYYYMMDD>.xlsx`.
- Napredni filteri: kombinuј 3+ filtera (odeljenja, statusi, prioritet, rok, kasni), refreshuj stranicu i proveri da se filteri vraćaju iz URL/localStorage stanja.
- Polling refresh: otvori isti RN u dva taba browser-a, izmeni aktivnost u jednom i sačekaj do 30s da drugi tab prikaže osveženje.
- Side-panel prijava: na Tab 1 klikni red operacije i proveri listu `prijava_rada` za poziciju + TP operaciju.
- Audit istorija: u modal aktivnosti otvori tab `Istorija`, postavi/skini blokadu i proveri da se vidi istorija blokada; audit log je vidljiv samo ako RLS dozvoli korisniku čitanje.

## Poznata ograničenja

- Lista aktivnih predmeta (ekran 1) nema realtime osvežavanje — potreban ručni refresh ili ponovni ulazak u modul.
- Pravi Supabase websocket realtime nije uveden jer projekat trenutno koristi custom REST `sbReq`, ne Supabase JS realtime client. Modul koristi polling fallback od 30s.
- Export audit je best-effort upis u postojeći `audit_log`; ako RLS odbije direktan insert, export se ne prekida.
- Deep-link na originalnu akcionu tačku vodi na `/sastanci?akcija=<id>`; modul Sastanci ne menja se u ovom inkrementu.
- Dokumentacija/crteži u Tab 1 side-panelu ostaju placeholder dok se ne uvedu fajl tabele za TP operacije/PDM linkovi u runtime payload.

# Praćenje proizvodnje — frontend smoke test

## Otvaranje modula

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

## Očekivano ponašanje

- Header se učita sa kupcem, RN brojem, datumom isporuke, koordinatorom i agregatima.
- Tab `Po pozicijama` prikazuje 3 pozicije i 5 operacija iz seed-a.
- Expand/collapse radi preko native `<details>/<summary>`.
- Tab `Operativni plan` prikazuje 4 aktivnosti i dashboard.
- Status badge prikazuje auto indikator kada `status_is_auto = true`.
- Dugme `Nova aktivnost` je vidljivo samo ako `production.can_edit_pracenje` vrati `true`.
- Posle dodavanja/izmene/zatvaranja aktivnosti state se osvežava iz RPC-ja.

## Placeholder-i za Inkrement 3

- `Excel export` je disabled.
- `Iz akcione tačke` je disabled.
- Nema realtime-a, polling-a ni naprednih filtera.
- Nema side-panel istorije prijava rada.

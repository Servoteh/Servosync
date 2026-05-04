# Reversi modul

Modul za pracenje zaduzenja alata i kooperacione robe u vlasnistvu Servoteh.

## Tipovi dokumenata

- **TOOL** — zaduzenje alata (brusilice, srafilice, instrumenti) radniku, odeljenju ili eksternoj firmi
- **COOPERATION_GOODS** — roba na medjufaznu uslugu kooperantu (identifikovana brojem crteza)

## Integracija sa Lokacije modulom

Reversi je nadsloj nad Lokacije modulom. Svako zaduzenje kreira `loc_location_movements`
zapis tipa `REVERSAL_ISSUE`. Svaki povracaj kreira zapis tipa `REVERSAL_RETURN`.

Za svakog primaoca kreira se virtuelna `loc_locations` lokacija (lazy, pri prvom zaduzenju):
- `ZADU-R-*` — radnik (tip FIELD)
- `ZADU-O-*` — odeljenje (tip FIELD)
- `ZADU-K-*` — eksterna firma (tip SERVICE)

## Tabele

| Tabela | Svrha |
|--------|-------|
| `rev_tools` | Inventar alata |
| `rev_documents` | Zaglavlje reversal dokumenta |
| `rev_document_lines` | Stavke dokumenta |
| `rev_recipient_locations` | Mapa primalac → virtuelna lokacija |

## RPC funkcije

| Funkcija | Poziva | Svrha |
|----------|--------|-------|
| `rev_issue_reversal(jsonb)` | Frontend | Kreira dokument + loc pokrete |
| `rev_confirm_return(jsonb)` | Frontend | Potvrda povracaja |
| `rev_next_doc_number(text)` | Interno | Generisanje broja dokumenta |
| `rev_get_or_create_recipient_location(...)` | Interno | Lazy kreiranje virtuelne lok. |
| `rev_can_manage()` | RLS | Provera ovlascenja |

## RBAC

| Akcija | Uloge |
|--------|-------|
| Kreiranje i potvrda reversala | admin, menadzment, pm, leadpm, magacioner |
| Citanje liste svih reversala | svi ulogovani |
| Moja zaduzenja (self-service) | svi ulogovani (view `v_rev_my_issued_tools`) |

## Sledeci sprintovi

- **R2** — Seed alata iz xlsx fajlova (brusilice + srafilice Hilti)
- **R3** — UI: inventar alata, lista reversal dokumenata, filteri
- **R4** — jsPDF potpisnica (obrazac sa prostorom za potpis)

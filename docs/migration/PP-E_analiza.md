# PP-E — bulk REASSIGN i pregled po crtežu

## Trenutni single / bulk REASSIGN

- Jedan red: `onReassign` → `openReassignDialog([row], { bulk: false })` → RPC `reassign_production_line`.
- Više redova: checkbox + `#ppBulkReassignBtn` → `openReassignDialog(selectedRows, { bulk: true })` → `bulkReassignLines` (isti RPC u petlji / servis već implementiran u `planProizvodnje.js`).
- Kandidati mašina: `buildReassignCandidates` + **`machineGroupSlugForCode`** — **samo ista kategorija** osim admin/menadžment **force** sa razlogom.

## Izmene PP-E

- Logika ostaje; **UI** refaktor: modal prebačen u **`bulkReassignModal.js`** (deljiv `openPlanBulkReassignModal`) radi čitljivosti; naslov u bulk režimu: **„Premesti N pozicija …”**.
- Akciona traka: postojeće dugme preimenovano u **„Premesti odabrane (N) na drugu mašinu”** (N dinamički).
- **`pregledTab.js`**: matrica je **mašina × dani**, nema redova operacija — **checkbox bulk REASSIGN ovde nije primenjen** (korisnik koristi „Po mašini”). Dokumentovano ovde.

## Po crtežu

- Novi tab **„Po crtežu”** (`poCrtezuTab.js`): pretraga po **broju crteža** ili **ident_broju RN**; lista svih operacija iz **`v_production_operations_operational_plan`** koje odgovaraju upitu, sort **`operacija`**, kolone: operacija, mašina, status, planirano vreme, spremno, hitno, skart (ako kolone postoje u view-u). Bez drag-drop.

## Backend

- **Bez novih tabela / RPC / RLS** — samo drugi view (`v_production_operations_operational_plan`) kao izvor.

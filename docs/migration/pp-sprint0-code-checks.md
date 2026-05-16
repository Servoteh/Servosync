# PP Sprint 0 — Code grep nalazi

> Datum: 2026-05-16 · Status: završen za code/bridge deo · DB nalazi su odvojeno u [pp-sprint0-status.md](pp-sprint0-status.md) posle SQL izvršavanja.

Ovaj dokument je sirov inventar nalaza iz grep + read prolaza. Ništa nije menjano u kodu. Cilj: pripremni snimak pre Sprint 1 refaktorizacija.

---

## 1. `is_ready_for_processing` u repo-u

**Zaključak:** Kolonu **NIJEDAN JS / TS fajl** više ne čita. Posle PP-A merge-a (commit 5085848), svi servisi i UI komponente koriste isključivo `is_ready_for_machine`. Stari naziv ostaje samo u SQL view-ovima kao back-compat alias i u dokumentaciji.

### JS / TS reference
**0 hit-ova** — grep `is_ready_for_processing` nad `src/**/*.js` vraća prazno.

### SQL reference
| Fajl | Linija | Kontekst |
|---|---:|---|
| [sql/migrations/add_production_g2_readiness_urgency.sql](../../sql/migrations/add_production_g2_readiness_urgency.sql) | 128 | Originalna G2 definicija: `(prev_block.operacija IS NULL) AS is_ready_for_processing` |
| [sql/migrations/fix_v_production_operations_ready.sql](../../sql/migrations/fix_v_production_operations_ready.sql) | 108 | PP-A: `COALESCE(_ready_chain.is_ready_rb, FALSE) AS is_ready_for_processing` (alias istog logičkog izraza kao `is_ready_for_machine`) |
| [sql/migrations/fix_v_production_operations_ready.sql](../../sql/migrations/fix_v_production_operations_ready.sql) | 8, 15 | Komentari u migraciji |

### Dokumentacija (info only — bez code dependency)
- [docs/migration/PP-A_ready_analiza.md](PP-A_ready_analiza.md) — više referenci, sve istorijski opis
- [docs/Plan_proizvodnje_modul_analiza.md](../Plan_proizvodnje_modul_analiza.md:29,123,342)
- [docs/Planiranje_proizvodnje_modul.md](../Planiranje_proizvodnje_modul.md:85)

### TBD — van repo-a
- **`servoteh-bridge` repo** (poseban) — nije proveren u ovom prolazu. Pre brisanja kolone iz view-a, ručno grep nad bridge repo-om.
- **Reporting / Excel skripte** koje moglo neko da koristi PostgREST direktno — Jara mora da potvrdi.

### Preporuka
- Sprint 1 može bezbedno da ukloni `is_ready_for_processing` iz view-a SQL-a — uslov: proveriti `servoteh-bridge` repo grep pre apply-a.
- Ostavi to za posebnu malu migraciju (drop column iz view-a + GRANT re-issue), ne mešaj sa drugim PP-A follow-up-ima.

---

## 2. `archived_at` u `production_overlays` — ko ga postavlja?

**Zaključak:** **NIJEDAN aktivni code path ne postavlja `production_overlays.archived_at`**. Kolona se isključivo **čita** (filter `IS NULL` u view-ovima i servisima) i nigde ne piše. SQL upit #8 u [pp-sprint0-checks.sql](pp-sprint0-checks.sql) će potvrditi da li je nekada ručno postavljen.

### Pisanje (UPDATE ili INSERT sa vrednošću)
**0 hit-ova** za regex `UPDATE.*archived_at|archived_at\s*=` u:
- `src/services/planProizvodnje.js`
- `sql/migrations/add_*production*.sql`
- `supabase/migrations/*.sql`
- `workers/**/*.js`

(Hits za druge module — `maint_*` tabele — su irelevantni; Lokacije i Maintenance imaju svoj `archived_at` flow.)

### Čitanje (filter)
| Fajl | Linija | Kontekst |
|---|---:|---|
| [src/services/planProizvodnje.js](../../src/services/planProizvodnje.js) | 260 | `loadOperationsForMachine` (legacy fallback) — `p.set('overlay_archived_at', 'is.null')` |
| [src/services/planProizvodnje.js](../../src/services/planProizvodnje.js) | 329 | `loadOperationsForDept` — `overlay_archived_at.is.null` u OR filter-u |
| [src/services/planProizvodnje.js](../../src/services/planProizvodnje.js) | 411, 435 | `loadAllOpenOperations`, `listForCooperation` |
| [sql/migrations/add_plan_proizvodnje.sql](../../sql/migrations/add_plan_proizvodnje.sql) | 81 | Partial index `WHERE archived_at IS NULL` |
| [sql/migrations/add_production_g6_auto_in_progress.sql](../../sql/migrations/add_production_g6_auto_in_progress.sql) | 41 | G6 UPDATE: `AND o.archived_at IS NULL` (samo aktivne overlay-e tretiraj) |
| Više view migracija | various | `o.archived_at AS overlay_archived_at` projekcija |
| [supabase/migrations/20260513120000__plan_pp_open_ops_machine_wo_pagination.sql](../../supabase/migrations/20260513120000__plan_pp_open_ops_machine_wo_pagination.sql) | 52 | RPC filter |
| [sql/migrations/fix_v_production_operations_ready.sql](../../sql/migrations/fix_v_production_operations_ready.sql) | 372 | PP-A RPC filter |

### Preporuka
**M12 u audit-u potvrđen.** Tri opcije, sledi razgovor sa Jarom:

- **(A) Implementiraj** — dodaj logiku „kada `rn_zavrsen=TRUE` ili `plan_rn_final_control_done=TRUE`, postavi `archived_at=now()` u overlay-u". Mesto: ili kao kolona u G6 RPC-u (proširi `mark_in_progress_from_tech_routing` da uradi i archive pass), ili kao poseban bridge poziv.
- **(B) Obriši kolonu** — `ALTER TABLE production_overlays DROP COLUMN archived_at, archived_reason;` + obriši sve filter-e u view-ovima i servisima. Manje koda.
- **(C) Ostavi kao opciju za buduće ručno arhiviranje** — admin UI „arhiviraj overlay" koji je nikad nije implementiran. Dokumentuj da je rezervisano.

Najekonomičnije: **(A)** — već postoji KK heuristic koji sakriva RN iz plana (`plan_rn_final_control_done`); proširi G6 ili dodaj cron job koji `UPDATE production_overlays SET archived_at = now() WHERE wo_id IN (RN-ovi posle KK)`. Ovo bi povećalo brzinu plana jer LEFT JOIN ide kroz manje overlay-a.

---

## 3. `addEventListener` u `src/ui/planProizvodnje/poMasiniTab.js`

**Zaključak:** Snimljeno 35 `addEventListener` poziva. Najveća koncentracija je u `wireRows` (linije 1258–1308) — 13 listenera **per row** koji se re-bind-uju na svakom `renderTable()`. To je glavni kandidat za event delegation refactor (H13 u audit-u).

### Tab-level / setup (jednom po mount-u)
| Linija | Element | Tip | Komentar |
|---:|---|---|---|
| 256 | dept chip container | click | Tab promena |
| 418 | `.pp-machine-list` | click | Drill-down klik |
| 489 | machine list (alt) | click | Drugi prikaz |
| 533 | machine `<select>` | change | Dropdown |
| 542 | back/load btn | click | Navigacija |
| 553 | Još RN btn | click | Paginacija |
| 601 | back btn (dept view) | click | — |
| 612, 618 | refresh + load more | click | — |
| 644 | refresh btn | click | — |
| 693 | bulk action input | change | Bulk select |
| 716 | „Premesti odabrane" | click | Bulk REASSIGN |
| 723 | RN filter input | input | **Debounce 200ms, vidi setTimeout sekciju** |

### Per-row listeneri (re-bind na svakom renderTable!)
Sve u `wireRows`, [poMasiniTab.js:1258-1308](../../src/ui/planProizvodnje/poMasiniTab.js#L1258):

| Linija | Element | Tip | Akcija |
|---:|---|---|---|
| 1258 | row checkbox | change | `onToggleRowSelection` |
| 1262 | header „select all" | change | `onToggleAllRowsSelection` |
| 1266 | status btn | click | `onCycleStatus` |
| 1270 | CAM checkbox | change | `onToggleCamReady` |
| 1275, 1276 | napomena `<textarea>` | focus + blur | Save on blur |
| 1280 | reassign btn | click | `onReassign` |
| 1284 | „→ Kooperacija" btn | click | `onSendCooperation` |
| 1288 | HITNO btn | click | `onToggleUrgent` |
| 1292 | pin btn | click | `onTogglePin` |
| 1296 | skice btn | click | `onOpenDrawings` |
| 1300 | bigtehn drawing btn | click | `onOpenBigtehnDrawing` |
| 1304 | TP btn | click | `onOpenTechProcedure` |
| 1308 | „Zašto" btn | click | `onWhyBottleneck` |

**Rast:** 13 listenera × N redova × broj re-render-a. Za mašinu sa 100 ops i 10 filter pritisaka = 13 000 bind operacija u jednoj sesiji.

### Reassign dialog modal (per modal-open)
| Linija | Tip | Akcija |
|---:|---|---|
| 1752 | click | Close handle |
| 1753 | click (overlay) | Click outside |
| 1756 | change (force toggle) | Re-render options |
| 1759 | click (submit) | Pošalji RPC |

### Drag-drop (na tbody-u — re-bind na svakom renderTable)
| Linija | Tip |
|---:|---|
| 1827 | dragstart |
| 1836 | dragend |
| 1844 | dragover |
| 1858 | drop |

### Preporuka za Sprint 1 (H13 implementacija)
Refactor pattern:
```js
// Jedan listener na wrap (preživljava re-render-e):
wrap.addEventListener('click', e => {
  const btn = e.target.closest('[data-action]');
  if (!btn) return;
  const action = btn.dataset.action;
  const row = btn.closest('tr');
  if (!row) return;
  const key = row.dataset.key;
  switch (action) {
    case 'cycle-status': return onCycleStatus(btn, key);
    case 'reassign':     return onReassign(btn, key);
    // ...
  }
});
```
Onda u `rowHtml` umesto bind-a po elementu, dodaj `data-action="..."` na svaki btn/input. Ukupno: 1 click + 1 change listener po tabeli umesto 13 po redu.

---

## 4. `setTimeout` / `setInterval` u modulu

**Zaključak:** Svi `setInterval` pozivi: **0 hit-ova** — modul nikad ne koristi `setInterval`. Svi `setTimeout` pozivi:

### Debounce timeri (čišćenje obavezno u teardown-u)
| Fajl | Linija | Svrha | Cleanup status |
|---|---:|---|---|
| [poMasiniTab.js](../../src/ui/planProizvodnje/poMasiniTab.js) | 727 | RN filter (200ms) | `state.rnFilterTimer = setTimeout(...)` — vidi M16 u audit-u |
| [zauzetostTab.js](../../src/ui/planProizvodnje/zauzetostTab.js) | 222 | RN filter (200ms) | isto |
| [pregledTab.js](../../src/ui/planProizvodnje/pregledTab.js) | 104 | RN filter (200ms) | isto |
| [kooperacijaTab.js](../../src/ui/planProizvodnje/kooperacijaTab.js) | 67 | RN filter (200ms) | isto |

### UI feedback (kratki, niski rizik)
| Fajl | Linija | Svrha |
|---|---:|---|
| [poMasiniTab.js](../../src/ui/planProizvodnje/poMasiniTab.js) | 1615 | „Sačuvano" indikator skidanje (1400ms) |
| [drawingManager.js](../../src/ui/planProizvodnje/drawingManager.js) | 49 | Modal close button focus (50ms) |
| [whyBottleneckModal.js](../../src/ui/planProizvodnje/whyBottleneckModal.js) | 299 | Modal close button focus (30ms) |
| [techProcedureModal.js](../../src/ui/planProizvodnje/techProcedureModal.js) | 57 | Modal close button focus (50ms) |

### Preporuka
- Sprint 1 (M16 fix): u svakom `teardown` pozovi `clearTimeout(state.rnFilterTimer)` PRE postavljanja na null. Ovo je trivijalna izmena (4 fajla, 1 linija svaki).
- UI feedback timer-i (1400ms, 50ms) — nepristrašno, mogu ostati. Najgori scenario: focus se baci na detached element, browser baci nečujno.

---

## 5. Bridge integracija — backfill skripta za G6

### Lokacija
- [workers/loc-sync-mssql/scripts/backfill-production-cache.js:870-882](../../workers/loc-sync-mssql/scripts/backfill-production-cache.js#L870) — funkcija `runPostProductionSyncRpc(sb, args)`

### Kako se poziva
```js
async function runPostProductionSyncRpc(sb, args) {
  if (args.dryRun) return null;
  if (!args.tables.includes('tech')) return null;

  logger.info('post-sync rpc starting', { rpc: 'mark_in_progress_from_tech_routing' });
  const { data, error } = await sb.rpc('mark_in_progress_from_tech_routing');
  if (error) throw new Error(`mark_in_progress_from_tech_routing failed: ${error.message}`);
  logger.info('post-sync rpc complete', {
    rpc: 'mark_in_progress_from_tech_routing',
    result: data,
  });
  return data;
}
```

**Uslovi:**
- `--dry-run`: skip
- `args.tables.includes('tech')`: poziva se samo ako je tech tabela sync-ovana u istom run-u. Ako bridge sinhronizuje samo `wo`/`lines` (npr. neki run), G6 RPC se NE poziva.

**Error handling:**
- `error` iz Supabase JS klijenta → `throw new Error(...)`. **Nema try/catch sa fallback-om.** Greška propagira gore, ceo run script-a faila.
- **Posledica:** ako G6 RPC pukne (npr. timeout, deadlock), trenutni bridge run je fail-ovan; sledeći run (15 min kasnije) će probati ponovo. Bez DEAD letter mehanizma.
- **Persistent log:** samo `logger.info(...)` (Pino logger u worker procesu). **NEMA upisivanja u bilo koju tabelu Supabase strane** (`bridge_sync_log`, `production_g6_sync_log` itd.).

### Idempotency analiza RPC-a (na osnovu čitanja [add_production_g6_auto_in_progress.sql](../../sql/migrations/add_production_g6_auto_in_progress.sql))

| Aspekt | Status | Komentar |
|---|---|---|
| Idempotentnost UPDATE | ✅ OK | Filter `local_status = 'waiting'` — drugi run pronalazi 0 redova jer je već postavljen `in_progress`. |
| Idempotentnost INSERT | ✅ OK | `WHERE NOT EXISTS` guard po `(work_order_id, line_id)` — drugi run preskače sve. |
| `updated_by` truje forenziku | ⚠️ Da | UPDATE setuje `updated_by = 'system:bridge:g6'` čak i kad se ništa stvarno ne menja u tom redu. M30 u audit-u potvrđen. **Ali**: praktično UPDATE faila po `local_status='waiting'` filter-u kad nema šta da menja, pa truje samo prvi put kada se overlay automatski tranzicija. OK kompromis. |
| `blocked` se ne dira | ✅ OK | Filter striktno na `waiting`. |
| `completed` se ne dira | ✅ OK | Isto. |
| Manual `in_progress` se ne dira | ✅ OK | UPDATE filter `waiting` znači ako je korisnik već ručno postavio `in_progress`, RPC ga ne menja. |
| Race sa korisnikom | ⚠️ Mali rizik | Ako korisnik klikne `blocked` u istom prozoru kad RPC se izvršava, redosled je nedeterminističan. Praktično: blocked je explicitni izbor operatera; ako je već applied pre RPC-a, RPC ga ne menja. |

### Preporuke
1. **H28 banner** (bridge health):
   - Postoji `bridge_sync_log` tabela u Lokacije modulu — proveriti šemu (van Sprint 0 scope-a).
   - Predlog: bridge worker upisuje **kraj** svakog PP-related run-a (`tables=tech`) u zajedničku tabelu sa `module = 'plan_proizvodnje'`. UI banner čita `last_run_at WHERE module = 'plan_proizvodnje'`.
2. **M29 DEAD letter za G6**:
   - Wrap u try/catch + persistent log: ako RPC failu-je, upisi grešku u `bridge_sync_log` (ili `production_g6_sync_log`) sa stack trace-om. Admin UI prikazuje crveni red.
3. **Trenutno radi** — error handling kroz `throw` je dovoljno za development; produkcija ima 15-min retry preko sledećeg cron run-a.

---

## 6. Šta NIJE proveravano u Sprint 0

Ova područja zahtevaju SQL pristup ili odluku korisnika:
- DB query rezultati (svih 13 upita iz [pp-sprint0-checks.sql](pp-sprint0-checks.sql)) — TBD posle ručnog izvršavanja u Supabase Studio.
- `servoteh-bridge` repo (poseban) — eksterni grep za `is_ready_for_processing` reference.
- Reporting skripte / Excel makroi van repo-a — Jara treba da potvrdi.
- Storage `production-drawings` bucket — sadržaj fajlova, path uzorci (van scope-a Sprint 0).
- Pravi production EXPLAIN ANALYZE za `plan_pp_open_ops_for_machine` na top-3 mašine sa najviše ops.

---

**Status:** code/bridge audit ZAVRŠEN. Čekamo SQL rezultate za kompletan Sprint 0 status.

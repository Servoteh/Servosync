# PP Sprint 1B — pre-flight analiza (H1: G5 REASSIGN idempotency)

> Datum: 2026-05-16 · Sprint: 1B · Audit ref: H1 u [Plan_proizvodnje_modul_analiza.md](../Plan_proizvodnje_modul_analiza.md)

## Cilj

Sprečiti duplikate u `production_reassign_audit` kada klijent retry-uje RPC poziv (timeout, network drop, double-click korisnika).

## Problem (audit H1)

`reassign_production_line()` i `bulk_reassign_production_lines()` rade UPSERT u `production_overlays` (idempotentno po `(work_order_id, line_id)`) i INSERT u `production_reassign_audit` (bez idempotency ključa).

Ako klijent pošalje isti zahtev dva puta:
- Overlay state: OK (UPSERT, drugi put samo prepiše istim vrednostima).
- Audit: **DVA reda sa istim force_reason-om** — izveštaj prikazuje dva force-a za jedan stvarni event.

## Mitigation pattern

1. Klijent generiše `crypto.randomUUID()` pre RPC poziva.
2. RPC prima novi opcioni parametar `p_client_event_uuid uuid DEFAULT NULL`.
3. `production_reassign_audit` dobija novu kolonu `client_event_uuid uuid` + UNIQUE indeks `(client_event_uuid, line_id)`.
4. INSERT u audit: `ON CONFLICT (client_event_uuid, line_id) DO NOTHING`.
5. Retry istog zahteva: drugi audit INSERT je no-op.

### Zašto UNIQUE `(uuid, line_id)` umesto samo `(uuid)`?

Bulk reassign za N parova: ako koristimo **jedan** UUID po pozivu, petlja kreira **N audit redova** sa istim UUID-om. Sa unique samo na UUID-u, prvi prolazi a ostali se blokiraju. Sa `(uuid, line_id)` svi prolaze prvi put, a retry istog bulk poziva preskoče sve.

### NULL semantika

Postgres UNIQUE ne tretira NULL kao konfliktan. Istorijski redovi (gde je `client_event_uuid` NULL) i stari klijenti koji ne šalju UUID i dalje rade — INSERT ne baca konflikt. Backward compat ✅.

## Postojeća implementacija

### SQL ([add_production_g5_reassign_rpc.sql](../../sql/migrations/add_production_g5_reassign_rpc.sql))

Tabela `production_reassign_audit` (linija 68-79):
```sql
CREATE TABLE production_reassign_audit (
  id             bigserial PRIMARY KEY,
  work_order_id  bigint NOT NULL,
  line_id        bigint NOT NULL,
  actor_email    text,
  source_machine text,
  target_machine text,
  source_group   text,
  target_group   text,
  force_reason   text NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);
```

RPC potpisi:
- `reassign_production_line(p_work_order_id bigint, p_line_id bigint, p_target_machine text, p_force boolean DEFAULT false, p_force_reason text DEFAULT NULL)` — 5 parametara
- `bulk_reassign_production_lines(p_pairs jsonb, p_target_machine text, p_force boolean DEFAULT false, p_force_reason text DEFAULT NULL)` — 4 parametra

Audit INSERT u `reassign_production_line` (linija 208-227): bez ON CONFLICT, plain INSERT.

### JS klijent ([planProizvodnje.js](../../src/services/planProizvodnje.js))

- `reassignLine({ workOrderId, lineId, targetMachine, force, reason })` linija 938
- `bulkReassignLines({ pairs, targetMachine, force, reason })` linija 957

Oba zovu `sbReq('rpc/...', 'POST', { p_... })`.

### UI ([poMasiniTab.js](../../src/ui/planProizvodnje/poMasiniTab.js))

- Linija 1634: single reassign (`onReassign` → vraćanje na originalnu mašinu)
- Linija 1773: bulk path u `openReassignDialog`
- Linija 1779: single path u `openReassignDialog`

UI ne mora da zna o UUID-u — service sloj ga generiše transparentno.

## Plan izmena

### Commit 1: pre-flight analiza (ovaj fajl)

### Commit 2: SQL draft migracija

Novi fajl: `sql/migrations/add_production_g5_idempotency.sql` (NE izvršava se automatski — Jara ručno u Supabase Studio).

Sadrži:
1. `ALTER TABLE production_reassign_audit ADD COLUMN IF NOT EXISTS client_event_uuid uuid;`
2. `CREATE UNIQUE INDEX IF NOT EXISTS pra_uq_client_event_uuid_line ON production_reassign_audit (client_event_uuid, line_id);`
3. `CREATE OR REPLACE FUNCTION reassign_production_line(...6 parametara)` sa novim `p_client_event_uuid uuid DEFAULT NULL` i `ON CONFLICT (client_event_uuid, line_id) DO NOTHING`
4. `CREATE OR REPLACE FUNCTION bulk_reassign_production_lines(...5 parametara)` sa istom novom kolonom
5. Re-issue GRANT-ova za nove varijante
6. `NOTIFY pgrst, 'reload schema';`

**Bitno o function overloading:** `CREATE OR REPLACE FUNCTION` sa različitim brojem parametara pravi **novu varijantu**. Stara varijanta sa 5/4 parametra ostaje. PostgREST razrešava po payload-u: klijent koji šalje `p_client_event_uuid` dobija novu, klijent koji ne šalje — staru. Backward compat tokom rollout-a.

TODO komentar u migraciji: posle 1-2 sprint-a (kad svi klijenti šalju UUID), `DROP FUNCTION` stare varijante.

### Commit 3: JS klijent update

`src/services/planProizvodnje.js`:
- `reassignLine()` generiše `crypto.randomUUID()` i prosleđuje kao `p_client_event_uuid`
- `bulkReassignLines()` isto, jedan UUID za ceo bulk poziv

UI fajlovi (`poMasiniTab.js`) — **bez izmena**. Service sloj generiše UUID transparentno.

## `crypto.randomUUID` browser support

- Chrome 92+, Firefox 95+, Safari 15.4+, Edge 92+
- Node 19+
- Servoteh modul je za desktop browser (PC u proizvodnji), pa su sve verzije dovoljne.

Fallback ako nije dostupan: nema (modul već zahteva moderne browser-e).

## Acceptance kriterijumi

- Pošalje se 1 reassign sa force_reason → 1 red u audit-u, `client_event_uuid` postavljen
- Klijent simulira retry (poziv istog payload-a 2× brzo) → 1 red u audit-u (drugi je ON CONFLICT)
- Bulk reassign 5 force pairs → 5 redova u audit-u, svi sa istim UUID-om, različitim line_id-jevima
- Retry bulk-a sa istim UUID-om → 0 novih redova u audit-u
- Stari klijent (ako bi postojao) bez UUID-a → INSERT prolazi normalno (NULL nije konfliktan)

## Rollback plan

SQL je strogo aditivan:
- ADD COLUMN — može da se DROP
- CREATE UNIQUE INDEX — može da se DROP
- CREATE OR REPLACE FUNCTION — nova varijanta može da se DROP, stara ostaje

JS rollback je `git revert` jednog commit-a — `reassignLine` se vraća na 5-parametar potpis.

## Vremenska procena

- Commit 2 (SQL): 30 min pisanja + Jara apply ~5 min
- Commit 3 (JS): 15 min
- Manuelni test: 15 min
- **Ukupno: ~1h Cursor work + 15 min Jara apply.**

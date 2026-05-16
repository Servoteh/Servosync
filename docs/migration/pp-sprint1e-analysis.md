# PP Sprint 1E — pre-flight analiza (security hardening: L5 + H5 + H9)

> Datum: 2026-05-16 · Sprint: 1E · Audit ref: L5, H5, H9 u [Plan_proizvodnje_modul_analiza.md](../Plan_proizvodnje_modul_analiza.md)

## Cilj

Tri SQL-only hardening izmene koje smanjuju defense-in-depth attack surface bez izmene poslovne logike. Sve tri su strogo aditivne, mogu se aplicirati u istoj migraciji bez koordinacije sa JS-om.

## Sadržaj

### L5 — `pg_temp` u search_path-u SECURITY DEFINER gate funkcija

**Problem:** `public.can_edit_plan_proizvodnje()` i `public.can_force_plan_reassign()` su SECURITY DEFINER funkcije sa `SET search_path = public`. Nedostaje `pg_temp` na kraju liste.

**Zašto je važno:** kada SECURITY DEFINER funkcija ima `search_path` koji ne uključuje `pg_temp` eksplicitno, Postgres ga **podrazumevano stavlja na početak**. To znači da maliciozni user koji ima `TEMPORARY` privilegiju može da napravi funkciju u `pg_temp` šemi sa istim imenom kao neku ne-qualified-call funkciju u telu DEFINER-a, i da je tako prevari. Najbolja praksa: eksplicitno staviti `pg_temp` **na kraj** search_path-a — Postgres tada ne dodaje ga na početak.

G5/G6 RPC-i (`reassign_production_line`, `bulk_reassign_production_lines`, `mark_in_progress_from_tech_routing`) već imaju `public, auth, pg_temp` — referenca obrazac. Gate funkcije nisu pratile isti pattern.

**Praktični risk:** trenutno NIZAK jer:
- Gate funkcije su SQL (ne plpgsql), bez proceduralne logike koju bi pg_temp trojanac mogao da hijack-uje.
- Telo poziva samo `SELECT EXISTS ... FROM public.user_roles ...` i `auth.jwt()` — sve fully qualified.
- Korisnici nemaju `TEMPORARY` privilegiju na Supabase production bazi po default-u.

**Ali:** konzistentnost sa ostalim DEFINER funkcijama + best practice + zero-cost izmena = treba primeniti.

**Izmena:**
```sql
CREATE OR REPLACE FUNCTION public.can_edit_plan_proizvodnje()
  ... (telo nepromenjeno) ...
  SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION public.can_force_plan_reassign()
  ... (telo nepromenjeno) ...
  SET search_path = public, pg_temp;
```

### H5 — Explicit REVOKE write na `production_reassign_audit`

**Problem (potvrđeno Sprint 0 SQL #7):** `authenticated`, `anon`, `postgres`, `service_role` svi imaju INSERT/UPDATE/DELETE/SELECT GRANT-ove na audit tabeli. RLS politike (Sprint 0 SQL #10) **eksplicitno** blokiraju sve write-ove (`pra_no_client_write/update/delete` sa `USING/WITH CHECK false`). Trenutno bezbedno.

**Defense-in-depth:** ako neko ikad slučajno uradi `ALTER TABLE ... DISABLE ROW LEVEL SECURITY` tokom debug-a, tabela odjednom postaje slobodna za write — bilo koji `authenticated` korisnik može da unese lažan audit red ili izbriše stvarne.

**Izmena:**
```sql
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.production_reassign_audit FROM authenticated, anon;
-- service_role zadržava write (jedini upisuje kroz SECURITY DEFINER RPC).
```

**Risk:** NIZAK — SECURITY DEFINER RPC za audit INSERT je `reassign_production_line` koji se izvršava sa DEFINER privilegijama, ne sa caller-ovim. To znači da RPC i dalje radi posle REVOKE-a — DEFINER bypass-uje GRANT/RLS check.

**Verifikacija posle apply-a:** force reassign od običnog korisnika treba i dalje da kreira audit red (kroz RPC). Direktni klijent INSERT (npr. iz Postgres klijenta) treba da bude odbijen.

### H9 — `storage_path` CHECK constraint (path traversal)

**Problem:** `production_drawings.storage_path TEXT NOT NULL UNIQUE`. App sloj konstruiše putanju kao `${work_order_id}/${line_id}/${uuid}_${safeName}` ([planProizvodnje.js:1082](../../src/services/planProizvodnje.js#L1082)). Nema DB-side validacije — maliciozni POST sa `storage_path='../../foo/bar.pdf'` ili `storage_path='../../../etc/passwd.pdf'` može da prođe.

**Realan format** (iz koda):
- `<work_order_id>/<line_id>/<uuid_12_hex>_<safe_filename>`
- Komentar u SQL migraciji (linija 112) **pogrešno opisuje** kao `production-drawings/<wo>/<line>/<filename>` — bucket prefix nije u koloni!
- `safeName` filter u JS-u: `.replace(/[^\w.\-]+/g, '_')` — dozvoljeni karakteri su `[A-Za-z0-9_.\-]`.
- `uuid` segment: 12 hex chars (`crypto.randomUUID().replace(/-/g, '').slice(0, 12)`).

**CHECK constraint:**
```sql
ALTER TABLE public.production_drawings
  ADD CONSTRAINT pd_storage_path_safe CHECK (
    storage_path ~ '^[0-9]+/[0-9]+/[A-Za-z0-9._-]+$'
    AND storage_path !~ '\.\.'
  );
```

Drugi `!~ '\.\.'` blokira `abc..def` unutar segmenta (regex ne dozvoljava lookahead u Postgres POSIX).

**Risk apply-a:** SREDNJI — ako postojeći redovi imaju path-ove koji ne match-uju regex (npr. stari format pre konvencije), `ALTER TABLE ... ADD CONSTRAINT` će failovati. Treba prvo proveriti:

```sql
SELECT storage_path FROM public.production_drawings
WHERE NOT (storage_path ~ '^[0-9]+/[0-9]+/[A-Za-z0-9._-]+$' AND storage_path !~ '\.\.')
LIMIT 20;
```

Ako vraća 0 redova → CHECK je bezbedan. Ako vraća > 0 redova → treba ili korigovati path-ove ili ublažiti regex.

**Verifikacija posle apply-a:** uploadDrawing iz UI-a treba i dalje da radi normalno. Test sa fajlom čije ime sadrži unicode → safeName-ov sanitizer ga konvertuje u `_`, putanja prolazi CHECK.

## Plan implementacije

### Commit 1: Pre-flight analiza (ovaj fajl)

### Commit 2: SQL draft migracija

Novi fajl `sql/migrations/add_production_security_hardening.sql` — sve 3 izmene u jednoj migraciji. Komentar pre H9 ADD CONSTRAINT-a nudi pre-flight SELECT za proveru postojećih redova.

NE izvršava se automatski — Jara aplicira ručno u Supabase Studio. Pre apply-a treba:
1. Pokrenuti pre-flight SELECT (komentar u migraciji)
2. Ako 0 redova ne match-uje, apply migraciju ceo blok
3. Posle apply-a: verifikacija (smoke test reassign + drawing upload)

## Risk i rollback

| Izmena | Risk | Rollback |
|---|---|---|
| L5 (pg_temp) | 0 | `CREATE OR REPLACE FUNCTION ... SET search_path = public;` (vrati staro) |
| H5 (REVOKE) | 0 | `GRANT INSERT, UPDATE, DELETE ON ... TO authenticated;` |
| H9 (CHECK) | Srednji (može da blokira apply ako postojeći redovi ne match-uju) | `ALTER TABLE ... DROP CONSTRAINT pd_storage_path_safe;` |

## Acceptance kriterijumi

- L5: Sprint 0 SQL #5 (re-run posle apply-a) — `proconfig` za `can_edit_plan_proizvodnje` i `can_force_plan_reassign` sadrži `pg_temp`.
- H5: GRANT check (`SELECT grantee, privilege_type FROM information_schema.table_privileges WHERE table_name='production_reassign_audit'`) — `authenticated` ima samo SELECT.
- H9:
  - `SELECT storage_path FROM production_drawings WHERE storage_path ~ '\.\.' OR storage_path LIKE '%//%';` vraća 0 redova.
  - Pokušaj `INSERT ... ('test/../etc/passwd')` faila sa CHECK violation.
  - Normalan upload skica radi.

## Vremenska procena

- Pre-flight: 30 min ✅
- SQL fajl: 15 min
- Jara apply: 10 min (uključujući pre-flight SELECT)
- Smoke test: 15 min
- **Ukupno: ~1.5h**

## Stvari koje NEĆE biti u Sprint 1E

- Brisanje stare 5-parametar varijante `reassign_production_line` (Sprint 1B+1, kasnije).
- H6 cross-module guards (samo za novu env, ne hitno).
- H8 orphan cleanup job (0 orphan-a trenutno, vidi Sprint 0 SQL #9).
- M30 G6 `updated_by` smart guard (forenzika, kasnije).

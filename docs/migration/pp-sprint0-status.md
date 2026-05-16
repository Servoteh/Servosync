# PP Sprint 0 — Status izveštaj

> Datum: 2026-05-16 · Cilj: pre Sprint 1, potvrditi stvarno stanje baze + koda + bridge integracije. Ništa se ne menja — samo se dokumentuje.

**Tri output fajla Sprint 0:**
- [pp-sprint0-checks.sql](pp-sprint0-checks.sql) — 13 read-only SELECT upita za ručno izvršavanje
- [pp-sprint0-code-checks.md](pp-sprint0-code-checks.md) — kompletan code/bridge audit (ZAVRŠEN)
- **Ovaj fajl** — sažeti izveštaj sa preporukama

---

## 1. Šta je primenjeno i radi (potvrđeno code-side)

### PP-A merge na main
- Commit `5085848` mergovan na main 2026-05-15 (FF, bez konflikata).
- JS sloj već referira `is_ready_for_machine` (0 referenci na stari `is_ready_for_processing` u kodu).
- SQL migracija `fix_v_production_operations_ready.sql` postoji u repo-u kao DRAFT.

⏳ **TBD posle SQL #1, #2, #3:** da li je migracija stvarno izvršena u produkcijskoj bazi? Code je pripremljen, ali Supabase Studio apply nije potvrđen.

### G6 bridge integracija
- [backfill-production-cache.js:870-882](../../workers/loc-sync-mssql/scripts/backfill-production-cache.js#L870) zove `mark_in_progress_from_tech_routing` posle `tech` sync-a.
- RPC je idempotentan (UPDATE filtrira po `local_status='waiting'`, INSERT ima `WHERE NOT EXISTS`).
- DEFINER + `SET search_path = public, auth, pg_temp` ✅.
- `GRANT EXECUTE TO service_role` jedini ✅.

### Sigurnosna higijena vidljiva u kodu
- Svi `innerHTML =` template-i u modulu koriste `escHtml()` — XSS audit clean (L24).
- `security_invoker = true` na svim PP view-ovima.
- `anon` REVOKE primenjen kroz `revoke_anon_v_production_operations.sql`.
- G5 RPC-i imaju `SET search_path` zaštitu.

---

## 2. Šta nije primenjeno ili nedostaje

### Code-side nalazi (potvrđeni grep-om)

| Nalaz | Status | Audit ref |
|---|---|---|
| `archived_at` na `production_overlays` se **nigde** ne postavlja | ❌ Mrtva kolona ili rezervisana — Jara mora da odluči | M12 |
| 13 per-row event listenera u `wireRows` re-bind na svakom renderTable | ❌ Event delegation refactor potreban | H13 |
| Debounce `setTimeout` se ne `clearTimeout`-uje u 4 tab teardown-a | ❌ Trivijalan fix | M16 |
| Bridge skripta ne piše u persistent log tabelu za PP eventove | ❌ Health banner nemoguć bez log-a | H28, M29 |
| Bridge G6 poziv bez try/catch / DEAD letter | ❌ Greška propagira, sledeći run probava ponovo | M29 |

### DB-side nalazi — REZULTATI (izvršeno 2026-05-16)

```
SQL #1  (PP-A column check):                ✅ obe kolone (is_ready_for_machine + is_ready_for_processing)
SQL #2  (v_production_operations_pre_g4):   ✅ view postoji, sadrži is_ready_for_machine
SQL #3  (plan_pp_open_ops definicija):      ✅ RPC apliciran
SQL #4  (cross-module deps):                ✅ sve 4 funkcije postoje
                                              - production._pracenje_line_is_final_control (INVOKER)
                                              - public.can_edit_plan_proizvodnje (DEFINER)
                                              - public.can_force_plan_reassign (DEFINER)
                                              - public.current_user_is_admin (DEFINER, ima pg_temp)
SQL #5  (DEFINER search_path):              ⚠️ 2 funkcije bez pg_temp:
                                              - can_edit_plan_proizvodnje: search_path=public
                                              - can_force_plan_reassign: search_path=public
                                              (G5/G6 RPC-i imaju public,auth,pg_temp ✅)
SQL #6  (bigtehn_tech_routing_cache idx):   ✅ bigtehn_tr_cache_wo_op_idx (work_order_id, operacija) POSTOJI
                                              + 7 dodatnih korisnih indeksa
SQL #7  (production_reassign_audit GRANT):  ⚠️ authenticated i anon imaju INSERT/UPDATE/DELETE GRANT
                                              ALI #10 pokazuje da RLS sve blokira
SQL #8  (archived_at count):                ✅ M12 POTVRĐEN — 674 ukupno, 0 archived
SQL #9  (orphan machine_code count):        ✅ 0 orphan-a (H8 nije akutan)
SQL #10 (RLS policies audit):               ✅✅ EKSPLICITNA STROGA RLS:
                                              - pra_no_client_delete: DELETE USING false
                                              - pra_no_client_write:  INSERT WITH CHECK false
                                              - pra_no_client_update: UPDATE USING/WITH CHECK false
                                              - pra_select_force_users: SELECT preko can_force_plan_reassign()
SQL #11 (total open ops):                   ⚠️ 18 299 otvorenih ops vs 10K cap u loadAllOpenOperations
SQL #12 (distinct machines):                76 mašina sa otvorenim ops
SQL #13 (top 10 mašina po ops):             ⚠️ 8.4=4543, 8.3=3263, 8.2=2041, 1.10=1100, 5.3=838, ...
```

### Tumačenje — šta se menja u prioritetima

| Audit ID | Original | Posle SQL-a | Razlog |
|---|---|---|---|
| **H5** (audit write RLS) | H | **M** | RLS je već eksplicitno stroga (4 policy-ja); REVOKE je defense-in-depth |
| **H6** (cross-module deps) | H | **L** | Sve funkcije postoje u trenutnoj prod bazi; risk samo za novu/dev env |
| **H8** (orphan machine) | H | **L** (insurance) | 0 orphan-a trenutno; cleanup job je preventiva, ne hitan |
| **M22** (10K cap) | M | **H** | **18 299 ops vs 10K** — operater u Pregled/Zauzetost vidi 55% slike |
| **M21** (PP-A perf) | M | **M-H** | 4543 ops na mašini 8.4 — EXPLAIN ANALYZE potreban |
| **M12** (archived_at mrtva) | M | **M (potvrđeno)** | 0/674 redova; odluka Jare |

---

## 3. Otkriveni nepoznati uslovi

### A) `archived_at` na `production_overlays` — verovatno mrtva kolona
**Šta znamo:**
- Kolona postoji od bazne migracije [add_plan_proizvodnje.sql:66](../../sql/migrations/add_plan_proizvodnje.sql#L66).
- Filter `archived_at IS NULL` se koristi u 7+ mesta (view-ovi, services, G6 RPC).
- **NIJEDAN code path je ne postavlja** — nema `UPDATE ... SET archived_at = now()` u JS, SQL ili workers/.

**Šta ne znamo (TBD posle SQL #8):**
- Da li je iko ručno postavio `archived_at` direktno u bazi (npr. kroz Table Editor).
- Da li je planirano da se postavlja preko buduće bridge logike posle `rn_zavrsen` ili `plan_rn_final_control_done`.

**Odluka za Jaru:**
1. Implementiraj automatski archive (predlog A iz [pp-sprint0-code-checks.md](pp-sprint0-code-checks.md#2-archived_at-u-production_overlays--ko-ga-postavlja))
2. Obriši kolonu i sve filter-e (predlog B)
3. Ostavi rezervisano za buduće ručno arhiviranje (predlog C)

### B) Cross-module funkcije — ⏳ TBD
Audit pretpostavlja da `production._pracenje_line_is_final_control` i `public.current_user_is_admin` postoje. SQL #4 će potvrditi.

**Ako fali bilo koja:** PP migracije pucaju kod sledećeg re-apply-a. Iako trenutno radi (već primenjeno), redosled za novi env nije garantovan (H6).

### C) Indeks na `bigtehn_tech_routing_cache(work_order_id, operacija)` — ⏳ TBD
PP-A `NOT EXISTS` provera za readiness po definiciji zahteva ovaj indeks. SQL #6 će pokazati šta postoji.

**Ako fali:** posle ~3-5K otvorenih operacija po RN-u, query plan ide u seq scan, `plan_pp_open_ops_for_machine` može da pređe 30s. Statement timeout 180s znači da neće pucati, ali UI će biti spor.

### D) `production_reassign_audit` write GRANT — ⏳ TBD
Audit nije siguran da li `authenticated` ima INSERT/UPDATE/DELETE privilegije. SQL #7 + #10 će pokazati.

**Ako ima:** H5 fix je potreban — `REVOKE INSERT, UPDATE, DELETE` ili eksplicitna RLS policy `WITH CHECK(false)`.

---

## 4. Preporuke za Sprint 1 — prioriteti

### Prag pre Sprint 1 starta
Mora se izvršiti [pp-sprint0-checks.sql](pp-sprint0-checks.sql) u Supabase Studio i upisati rezultate u sekciju 2 gore. Bez tih brojeva ne možemo prioritizovati.

### Definitivan Sprint 1 plan (na osnovu stvarnih brojeva)

Pošto su SQL #1–#4 zelene (PP-A radi, deps postoje, indeks postoji), idemo direktno na operativne fix-eve. Predlog redosleda po **odnos vrednost/rizik**:

#### Faza 1A — „Quick wins" (1 dan rada ukupno, low risk)

1. **M16 — `clearTimeout` u 4 teardown-a** *(30 min)*
   - 4 fajla, 1 linija po fajlu (`poMasiniTab.js:teardown`, `zauzetostTab.js`, `pregledTab.js`, `kooperacijaTab.js`)
   - Zatvara pending setTimeout race condition pre tab switch-a
   - Risk: ~0, jednostavan defensive fix

2. **H14 — `Promise.all` timeout u `pregledTab.js`** *(1 sat)*
   - `Promise.race([Promise.all(...), timeout(15000)])`
   - Sprečava beskonačni spinner ako request visi
   - Risk: minimalan

3. **M22 — UI warning kad `loadAllOpenOperations` hit 10K** *(1 sat)*
   - **Real-world problem:** 18 299 ops vs 10K cap = operater vidi 55%
   - Quick fix: ako `rows.length === 10000`, prikaži banner „Prikazano 10K od više otvorenih — neke operacije nisu uračunate"
   - Pravi fix (sledeća faza): podigni cap na 25K ili dodaj paginaciju

#### Faza 1B — H1 idempotency *(1 dan)*

4. **H1 — G5 REASSIGN idempotency**
   - Klijent generiše UUID, šalje kao `p_client_event_uuid`
   - `production_reassign_audit` dobija `UNIQUE (client_event_uuid)`
   - RPC INSERT u audit: `ON CONFLICT DO NOTHING`
   - Sprečava duplikate u audit log-u kod retry-a
   - SQL migracija + JS payload patch

#### Faza 1C — H13 event delegation *(2-3 dana, jedan veliki fajl)*

5. **H13 — `poMasiniTab.js` `wireRows` refactor**
   - 13 per-row listenera → 2 globalna (click + change) sa `data-action` dispatcher-om
   - Bind cost: ~13K → ~20 po sesiji
   - Pripremljen inventar: [pp-sprint0-code-checks.md sekcija 3](pp-sprint0-code-checks.md#3-addeventlistener-u-srcuiplanproizvodnjepomasinitabjs)
   - Risk: srednji — `poMasiniTab.js` je 1954 linije, refactor zahteva test sa svim akcijama

#### Faza 1D — Real-world performance test *(0.5 dan)*

6. **M21 — EXPLAIN ANALYZE `plan_pp_open_ops_for_machine('8.4')` u produkciji**
   - Mašina 8.4 = 4 543 ops, najveća
   - Ako execution time > 5s → optimizacija (npr. cover indeks `(work_order_id, operacija) INCLUDE (is_completed)`)
   - Ako < 1s → ne diramo, OK

### Šta ide u Sprint 2+ (ne hitno)

- **L5 hardening:** `can_edit_plan_proizvodnje` i `can_force_plan_reassign` → dodaj `pg_temp` u search_path. Trivijalna migracija, low value.
- **H5 → M (defense-in-depth):** `REVOKE INSERT, UPDATE, DELETE ON production_reassign_audit FROM authenticated, anon` — sigurnosno udvostručavanje.
- **L8 (insurance):** orphan machine cleanup cron — može ostati za kasnije pošto je orphan_count = 0.
- **L6 (deferred):** cross-module dependency guards — samo za novu env / DR.
- **M12 — odluka Jare:** šta sa `archived_at` (implement / drop / reserve).
- **H2 (drag-drop OCC):** sačekati da vidimo da li se dva korisnika konfliktuju u stvarnosti. Trenutno mali tim, low frequency. Implementacija je kompleksna.
- **H28 (bridge health banner):** zahteva bridge log infrastrukturu (`bridge_sync_log` analog za PP), srednje kompleksno.

### Šta NE diramo
- PP-A SQL — već primenjen i radi.
- RLS na audit tabeli — već idealna (4 policy-ja).
- Indeksi na cache tabelama — već prisutni.
- Cross-module deps — sve postoje.

### Šta NE diramo u Sprint 1
- `archived_at` flow (čeka odluku Jare iz tačke 3.A).
- Audit log za overlay-e (M11) — kompleksno, čeka prioritetnije.
- Admin UI za kooperaciju (M31) — UX poboljšanje, ne reliability.
- Virtualizacija tabele (L23) — nije gore u stvarnoj produkciji.

---

## 5. Sledeći najmanji korak

**Sprint 0 ZAVRŠEN.** Stanje baze je verifikovano, prioriteti su reaktualizovani na osnovu stvarnih brojeva.

**Pre kretanja sa Sprint 1, donesi 1 odluku:**
- **M12 — `archived_at` mrtva kolona:** implement (cron job postavlja kad `plan_rn_final_control_done`), drop (jednostavnije, manje koda), ili reserve (ostavi za buduće ručno arhiviranje)?

**Posle odluke, Sprint 1 kreće sa Fazom 1A** (3 quick wins, oko pola dana rada).

Procena ukupnog Sprint 1: ~5–7 dana razvoja + testovi.

---

## 6. Decision log

| Datum | Pitanje | Odluka | Razlog |
|---|---|---|---|
| 2026-05-15 | Da li mergovati PP-A na main? | Da (FF) | Bug-fix, izolovan, back-compat alias zadržan |
| 2026-05-16 | Da li krenuti sa Sprint 1 odmah? | Ne — prvo Sprint 0 verifikacija | Audit ima 33 nalaza, prioritizacija zavisi od stvarnog stanja baze |
| 2026-05-16 | Koliko fajlova Sprint 0 generiše? | 3 (SQL + 2 MD) | Granularan readonly snimak za sledeću sesiju |
| 2026-05-16 | SQL #1–#13 izvršeni | Sve zelene osim L5 (pg_temp), M22 (10K cap), M21 (4543 ops) | Sprint 1 fokus: quick wins + H1 idempotency + H13 delegation |
| 2026-05-16 | Da li je H5 (audit write) i dalje H? | Snižen na M | RLS već eksplicitno blokira sve write — 4 policy-ja u #10 |
| 2026-05-16 | Da li je H6 (cross-module) i dalje H? | Snižen na L | Sve funkcije postoje u prod; risk samo za novu env |
| 2026-05-16 | Da li je M22 (10K cap) i dalje M? | Podignut na H | 18 299 ops vs 10K = realna 55% vidljivost |

---

**Status:** Sprint 0 — **ZAVRŠEN**. Definitivan Sprint 1 plan u sekciji 4. Čeka jednu odluku Jare o `archived_at` flow-u.

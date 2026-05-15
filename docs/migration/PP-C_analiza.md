# PP-C — agregati u „Po mašini”, pozicije u Zauzetosti, vidljivost skart-puštenih

## Zauzetost: gde je broj pozicija

- Kolona **„Otvoreno”** (`summarizeByMachine` → `totalOps`) već broji **otvorene TP operacije** (pozicije) po mašini — jedan red u listi plana = jedan increment.
- Za jasnoću PP-C dodaje **`title`** na zaglavlje „Otvoreno” (`zauzetostTab.js`) da tekst eksplicitno kaže da je to broj **TP pozicija (operacija)**.

## Pregled svih (matrica)

- Nema pojedinačnih redova po operaciji; red je **po mašini**.
- `buildDeadlineMatrix` sada ima **`scrapOps`**: ako bar jedna operacija na mašini prolazi **`operationIsScrapRelease`**, red mašine dobija klasu **`pm-row-has-scrap`** i mini bedž **„⚠ skart”** (linija `pregledTab.js`).
- Vizuel oznaka **„Po mašini”** (žuti red operacije + ikonica pored broja crteža) i dalje je primarni UX za operatera tokom obrade liste.

## Šta označava „pušteno po skartu” (konvencija dok se ne potvrdi definicija)

**Pitanje za Jaru / poslovni tim:** Da li „skart release” treba da bude (a) RN/linija nakon kontrole sa `ŠKART` u izvšenju, (b) poseban status RN-a u BigTehn-u, ili (c) potpuno drugačen signal od G4 rekorda po `(work_order_id, operacija)`?

**Implementirana privremena pretpostavka (do potvrde):**

- Kolona **`is_scrap_release`** u budućem view sloju (draft) ima istu kao G4 **`is_scrap`** na operaciji: **`bigtehn_rework_scrap_cache`** sa `quality_type_id = 2` (ŠKART), vidi `docs/migration/g4-skart-analiza.md` i `QMegaTeh_Dokumentacija.md` (DORADA / ŠKART).
- Frontend koristi **`operationIsScrapRelease(row)`** (`planProizvodnje.js`): ako postoji eksplicitna kolona `is_scrap_release`, ona pobedi; inače se koristi **`is_scrap`** (backward compatible pre migracije view-a).

Ovo je **vizuelni signal i eksplicitni UI za „skart”; ne utiče na PP-B sort.**

## PP-B / sortiranje

- **Sort se ne menja:** skart-puštene pozicije prolaze istim `sortByUrgencyAndReady` kao sve ostalo; dodata je samo oznaka (klasa reda / ikonica / matrica-bedž mašine).

## Predlog SQL-a (opciono eksplicitna kolona)

Videti **`sql/migrations/extend_v_production_operations_scrap.sql`**: dodati u `CREATE VIEW public.v_production_operations` izraz kao

`COALESCE(g4.is_scrap, false) AS is_scrap_release`

(uz komentar da semantiku potvrdi posao). **Ne izvršavati dok se ne složi ceo DROP/CREATE** sa poslednjom verzijom wrapper view-a iz `fix_v_production_operations_ready.sql` + grant/revoke.

## Σ planiranog vremena („Po mašini”)

- Jedan izvor pravila: **`sumPlannedSecondsForRows`** koristi **`OPEN_PLAN_SUM_LOCAL_STATUSES`** — isti skup kao Σ u footer-u tabele („waiting”, „in_progress”, „blocked”); formulacija i dalje preko **`plannedSeconds`** (tpz/tk u min × komada, u sekunde kao u ostatku modula).

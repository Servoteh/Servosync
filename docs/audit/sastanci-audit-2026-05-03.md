# Audit izveštaj: Modul Sastanci
Datum: 2026-05-03

## Rezime
- Kritičnih nalaza (CRITICAL): 0
- Važnih nalaza (HIGH): 4
- Srednjih nalaza (MEDIUM): 7
- Preporuka (LOW): 4

## CRITICAL nalazi

Nema potvrđenih CRITICAL nalaza u read-only pregledu.

## HIGH nalazi

### H1 — WRITE RLS nije vezan za parent sastanak
Oblast: RLS

Opis: SELECT politike su zategnute u `harden_sastanci_rls_phase2.sql`, ali INSERT/UPDATE/DELETE za `sastanci`, `sastanak_ucesnici`, `pm_teme`, `akcioni_plan`, `presek_aktivnosti`, `presek_slike`, `sastanak_arhiva` ostaju jedna `FOR ALL` politika preko `public.has_edit_role()` iz `add_sastanci_module.sql:346-379`. `WITH CHECK` ne proverava da je korisnik učesnik, kreator, vodio/zapisničar ili management za konkretan `sastanak_id`.

Rizik: svaki korisnik koji prođe `has_edit_role()` može upisati, menjati ili brisati child redove za sastanak koji ne bi smeo ni da čita po Faza 2 modelu.

Preporučena akcija: razdvojiti INSERT/UPDATE/DELETE politike po tabeli i dodati parent-scope proveru: `is_sastanak_ucesnik(sastanak_id) OR current_user_is_management() OR creator/organizer role`, uz posebno pravilo za ad-hoc `akcioni_plan` i `pm_teme`.

### H2 — Zaključan sastanak nije read-only na nivou baze
Oblast: RLS / Logika

Opis: SQL komentar kaže da je `status='zakljucan'` read-only (`add_sastanci_module.sql:68`), ali nema RLS/trigger uslova koji blokira UPDATE/DELETE nad `sastanci` i child tabelama kada je parent zaključan. UI sakriva edit akcije, ali RLS i write politike to ne sprovode.

Rizik: direktan PostgREST poziv ili bug u UI-u može menjati zapisnik, učesnike, akcije, slike ili arhivu posle zaključavanja.

Preporučena akcija: dodati DB guard za zaključane sastanke, idealno trigger/funkciju koja odbija mutacije child tabela kada je parent `zakljucan`, osim eksplicitnog admin/menadzment reopen toka.

### H3 — Arhiviranje i zaključavanje nisu atomski i postoje dva različita toka
Oblast: Logika / Notifikacije

Opis: Postoje dva toka:
- `src/services/sastanakArhiva.js:110-152` prvo INSERT-uje arhivu, zatim PATCH-uje `sastanci.status='zakljucan'`, ali ne proverava rezultat PATCH-a.
- `src/services/sastanciDetalj.js:112-117` prvo zaključava sastanak, zatim snima snapshot; PDF se generiše posebno u `src/ui/sastanci/sastanakDetalj/index.js:243-265`.

Rizik: moguće je dobiti arhivu bez stvarno zaključanog sastanka, zaključan sastanak bez kompletnog snapshot-a/PDF-a, ili `meeting_locked` notifikaciju pre nego što je PDF spreman. Greške u drugom koraku nisu transakcione.

Preporučena akcija: zaključavanje, snapshot i status promena treba da budu jedan SECURITY DEFINER RPC sa transakcijom; PDF može ostati best-effort, ali status notifikacija treba da bude posle pouzdane arhive.

### H4 — Notifikacioni triggeri nemaju punu idempotenciju
Oblast: Notifikacije

Opis: `sast_trg_ucesnik_invite()` ima dedup proveru (`add_sastanci_notification_triggers.sql:272-284`), ali `sast_trg_akcija_new()`, `sast_trg_akcija_changed()` i `sast_trg_meeting_locked()` nemaju sličan idempotent check. `meeting_locked` se okida na prelaz statusa (`190-242`), a akcije na svaki INSERT / relevantni UPDATE (`41-84`, `93-180`).

Rizik: retry/upsert, dvoklik ili ponovni reopen/lock može proizvesti više istih emailova za isti događaj.

Preporučena akcija: dodati dedup uslov ili unique partial index po `(kind, recipient_email, related_sastanak_id, related_akcija_id, status)` za queued/sent događaje gde je to poslovno očekivano.

## MEDIUM nalazi

### M1 — Widespread `select=*`
Oblast: Frontend

Opis: Većina REST poziva koristi `select=*`, npr. `sastanci.js:98,129,136,147`, `sastanciDetalj.js:166,226,320,372`, `akcioniPlan.js:81,103`, `pmTeme.js:110,134`, `sastanakArhiva.js:52,60`, `sastanciTemplates.js:114,118,199`.

Rizik: veći payload, nenamerno izlaganje novih kolona, teže održavanje RLS/audit očekivanja i lošije performanse.

Preporučena akcija: zameniti sa eksplicitnim listama kolona po ekranu.

### M2 — Nedostaju indeksi za deo RLS i čestih email filtera
Oblast: Šema / Performanse

Opis: Postoje indeksi za `sastanci.status`, `akcioni_plan.status`, `akcioni_plan.odgovoran_email`, `pm_teme.predlozio_email`, ali ne i za `sastanci.vodio_email`, `sastanci.zapisnicar_email`, `sastanci.created_by_email`. RLS koristi `LOWER(COALESCE(...))` (`harden_sastanci_rls_phase2.sql:105-107,156,168`), a postojeći plain email indeksi nisu funkcionalni `lower(...)` indeksi.

Rizik: SELECT politike mogu degradirati na većim setovima podataka.

Preporučena akcija: dodati funkcionalne indekse na lowercase email kolone koje učestvuju u RLS i listama.

### M3 — Neke tabele modula nemaju UUID PK kao jedinstveni `id`
Oblast: Šema

Opis: Većina core tabela ima UUID PK, ali `sastanak_ucesnici` ima kompozitni PK `(sastanak_id,email)` (`add_sastanci_module.sql:86-94`), a `sastanci_notification_prefs` ima `email TEXT PRIMARY KEY` (`add_sastanci_notification_prefs.sql:24-35`). To je logično za dedup po email-u, ali odstupa od zahteva "sve tabele imaju UUID PK".

Rizik: nije bezbednosni incident, ali otežava uniformne audit/alate i buduće reference.

Preporučena akcija: dokumentovati izuzetak ili dodati UUID `id` uz unique constraint na postojeće prirodne ključeve.

### M4 — Redundantna nullable polja mogu divergovati
Oblast: Šema / Logika

Opis: `akcioni_plan` i `presek_aktivnosti` čuvaju paralelno `odgovoran_email`, `odgovoran_label`, `odgovoran_text`, kao i `rok` i `rok_text` (`add_sastanci_module.sql:167-176,215-224`). Nema CHECK pravila koja garantuju da postoji bar jedan odgovorni ili da je `rok_text` fallback samo kada nema `rok`.

Rizik: UI, PDF i notifikacije mogu prikazati različit "izvor istine"; reminderi rade samo na `rok`, pa stavke sa samo `rok_text` nikada ne dobijaju reminder.

Preporučena akcija: uvesti jasna pravila: strukturisana polja za workflow, tekstualna samo kao snapshot/fallback; dodati CHECK ili normalizaciju u servis/RPC.

### M5 — Multi-step mutacije ignorišu neke greške
Oblast: Frontend

Opis: `saveUcesnici()` prvo briše sve učesnike i ne proverava rezultat DELETE pre INSERT-a (`src/services/sastanci.js:206-223`). `arhivirajSastanak()` ne proverava rezultat status PATCH-a posle INSERT arhive (`src/services/sastanakArhiva.js:140-150`). `reorderAktivnosti()` vraća `true` iako pojedinačni PATCH može vratiti `null` (`src/services/projektniSastanak.js:127-137`).

Rizik: UI može prijaviti uspeh dok je stanje delimično upisano.

Preporučena akcija: za multi-step tokove koristiti RPC/transakciju ili proveriti svaki korak i rollback/kompenzaciju gde je moguće.

### M6 — Nema potvrđenih RLS/security testova za Sastanci
Oblast: RLS / Testovi

Opis: `sql/tests/` sadrži security testove za druge module, ali nema `sastanci` RLS test fajla. RLS model je dokumentovan i migriran, ali nije automatski proveravan cross-user scenarijima.

Rizik: buduća migracija može vratiti `USING(true)` ili oslabiti write scope bez detekcije u CI.

Preporučena akcija: dodati pgTAP testove: ne-učesnik ne vidi sastanak, učesnik vidi child redove, editor ne može pisati u tuđi sastanak, prefs su own-only.

### M7 — Deo lista nema limit/order ili paginaciju
Oblast: Frontend / Performanse

Opis: Glavne liste uglavnom imaju `order` i `limit`, ali batch/child upiti često nemaju oba: `loadUcesniciForMany()` nema `order`/`limit` (`src/services/sastanci.js:142-155`), template učesnici nemaju order/limit (`src/services/sastanciTemplates.js:117-124`), a dashboard count-like upiti nemaju limit i čitaju sve vidljive redove (`src/services/sastanci.js:255-260`).

Rizik: kod već izbegava N+1 za učesnike, ali bez limit/paginacije veće instalacije mogu dobiti nepotrebno velike odgovore.

Preporučena akcija: za liste dodati eksplicitni `limit`/range i stabilan `order`; za statistike koristiti `sbReqWithCount()` ili dedicated RPC umesto preuzimanja svih redova.

## LOW / preporuke

### L1 — Default notifikacija je opt-out
Oblast: Notifikacije

Opis: `sastanci_notification_prefs` defaultuje svih 6 toggle-a na `TRUE` (`add_sastanci_notification_prefs.sql:26-31`), a enqueue helper za nepostojeći prefs red takođe tretira default kao TRUE (`add_sastanci_notification_outbox.sql:176-190`).

Rizik: proizvodno je jasno "svi primaju dok ne opt-out"; to može biti neželjeno za šire korisničke grupe.

Preporučena akcija: potvrditi product odluku i dokumentovati je u korisničkom tekstu / privacy politici.

### L2 — Nema realtime subscription-a u Sastanci modulu
Oblast: Frontend

Opis: Pretraga nije našla `postgres_changes`/`channel().subscribe()` u `src/ui/sastanci` ili Sastanci servisima. Nema rizika od nečišćenja subscription-a, ali ekran zavisi od ručnog reload-a.

Rizik: istovremeni rad više korisnika može prikazati zastarele podatke.

Preporučena akcija: ako se doda realtime, obavezno čistiti subscription na teardown i filtrirati po `sastanak_id`.

### L3 — Tekst meeting reminder šablona nije usklađen sa cron logikom
Oblast: Notifikacije

Opis: README kaže "24h pre sastanka" (`supabase/functions/sastanci-notify-dispatch/README.md:9-10`), SQL šalje za sastanke koji počinju za 15-45 minuta (`add_sastanci_reminder_jobs.sql:10-13,127-160`), a email subject kaže "Sutra" (`templates.ts:280-287`).

Rizik: zbunjujuća poruka korisniku.

Preporučena akcija: uskladiti README, SQL komentar i template tekst.

### L4 — `docs/SUPABASE_PUBLIC_SCHEMA.md` je snapshot, ne kompletan izvor istine
Oblast: Dokumentacija

Opis: dokument je generisan 2026-04-27 i pokriva core tabele, ali npr. outbox/prefs detalji su pouzdanije vidljivi u migracijama i RBAC matrici.

Rizik: audit koji se osloni samo na snapshot može propustiti novije migracije.

Preporučena akcija: pre sledećeg security pregleda regenerisati schema docs iz žive baze.

## Inventar Supabase upita

| Tabela | Tip | Fajl:linija | select(*) | error handled |
|--------|-----|-------------|-----------|---------------|
| sastanci | SELECT list | `src/services/sastanci.js:93-108` | Da | Centralno kroz `sbReq`, lokalno fallback `[]` |
| sastanci | SELECT one | `src/services/sastanci.js:127-130` | Da | Centralno kroz `sbReq`, lokalno `null` |
| sastanci | INSERT/UPSERT | `src/services/sastanci.js:182-185` | n/a | Centralno kroz `sbReq`, lokalno `null` |
| sastanci | PATCH | `src/services/sastanci.js:188-196`, `src/services/sastanciDetalj.js:120-124` | n/a | Centralno kroz `sbReq`, lokalno `null` |
| sastanci | DELETE | `src/services/sastanci.js:199-201` | n/a | Centralno kroz `sbReq` |
| sastanak_ucesnici | SELECT | `src/services/sastanci.js:133-138` | Da | Centralno kroz `sbReq`, lokalno `[]` |
| sastanak_ucesnici | SELECT batch | `src/services/sastanci.js:142-155` | Da | Centralno kroz `sbReq`, lokalno empty map |
| sastanak_ucesnici | DELETE+INSERT replace | `src/services/sastanci.js:206-223` | n/a | INSERT checked; DELETE result ignored |
| sastanak_ucesnici | PATCH | `src/services/sastanciDetalj.js:129-138` | n/a | Centralno kroz `sbReq` |
| pm_teme / v_pm_teme_pregled | SELECT list | `src/services/pmTeme.js:104-129` | Da | Centralno kroz `sbReq`, lokalno `[]` |
| pm_teme | SELECT one | `src/services/pmTeme.js:132-135` | Da | Centralno kroz `sbReq`, lokalno `null` |
| pm_teme | INSERT/UPSERT | `src/services/pmTeme.js:175-178` | n/a | Centralno kroz `sbReq`, lokalno `null` |
| pm_teme | PATCH status/flags | `src/services/pmTeme.js:190-310` | n/a | Centralno kroz `sbReq`, lokalno `null` |
| pm_teme | DELETE | `src/services/pmTeme.js:181-183` | n/a | Centralno kroz `sbReq` |
| v_akcioni_plan | SELECT list | `src/services/akcioniPlan.js:79-97` | Da | Centralno kroz `sbReq`, lokalno `[]` |
| v_akcioni_plan | SELECT one | `src/services/akcioniPlan.js:100-105` | Da | Centralno kroz `sbReq`, lokalno `null` |
| akcioni_plan | INSERT/UPSERT | `src/services/akcioniPlan.js:142-145` | n/a | Centralno kroz `sbReq`, lokalno `null` |
| akcioni_plan | PATCH status | `src/services/akcioniPlan.js:148-165` | n/a | Centralno kroz `sbReq`, lokalno `null` |
| akcioni_plan | DELETE | `src/services/akcioniPlan.js:168-170` | n/a | Centralno kroz `sbReq` |
| presek_aktivnosti | SELECT | `src/services/sastanciDetalj.js:163-168`, `src/services/projektniSastanak.js:81-86` | Da | Centralno kroz `sbReq`, lokalno `[]` |
| presek_aktivnosti | INSERT/UPSERT | `src/services/sastanciDetalj.js:171-199`, `src/services/projektniSastanak.js:113-116` | n/a | Centralno kroz `sbReq`, lokalno `null` |
| presek_aktivnosti | PATCH reorder | `src/services/sastanciDetalj.js:207-218`, `src/services/projektniSastanak.js:127-137` | n/a | Prvi proverava sve; drugi ne proverava pojedinačne rezultate |
| presek_aktivnosti | DELETE | `src/services/sastanciDetalj.js:202-204`, `src/services/projektniSastanak.js:119-121` | n/a | Centralno kroz `sbReq` |
| presek_slike | SELECT | `src/services/sastanciDetalj.js:223-228`, `src/services/projektniSastanak.js:142-149` | Da | Centralno kroz `sbReq`, lokalno `[]` |
| presek_slike | INSERT meta | `src/services/sastanciDetalj.js:237-278`, `src/services/projektniSastanak.js:160-220` | n/a | Storage error checked; DB error maps to `null` |
| presek_slike | DELETE | `src/services/sastanciDetalj.js:281-291`, `src/services/projektniSastanak.js:223-246` | n/a | Storage delete best-effort; DB checked |
| sastanak_arhiva | SELECT | `src/services/sastanciDetalj.js:317-322`, `src/services/sastanakArhiva.js:49-62` | Da | Centralno kroz `sbReq` |
| sastanak_arhiva | INSERT/UPSERT snapshot | `src/services/sastanciDetalj.js:329-364`, `src/services/sastanakArhiva.js:110-152` | n/a | Insert checked; status patch ignored in one flow |
| sastanak_arhiva | PATCH via upsert PDF metadata | `src/services/sastanciArhiva.js:23-75` | n/a | Storage and DB checked |
| sastanci_notification_prefs | RPC get/create | `src/services/sastanciPrefs.js:30-33` | n/a | Centralno kroz `sbReq`, UI catch/log |
| sastanci_notification_prefs | PATCH own row | `src/services/sastanciPrefs.js:41-68` | n/a | Centralno kroz `sbReq`, local `null` |
| sastanci_templates | SELECT | `src/services/sastanciTemplates.js:112-126` | Da | Centralno kroz `sbReq`, local `[]` |
| sastanci_templates | INSERT/PATCH/DELETE | `src/services/sastanciTemplates.js:149-190` | n/a | Delimično: child delete/insert rezultati ignorisani |
| sastanci_template_ucesnici | SELECT/INSERT/DELETE | `src/services/sastanciTemplates.js:117-124,156-183` | Da | Delimično provereno |
| rpc/sastanci_get_or_create_my_prefs | RPC | `src/services/sastanciPrefs.js:32` | n/a | Centralno kroz `sbReq`; parametara nema |
| sastanci_dispatch_* | RPC | `supabase/functions/sastanci-notify-dispatch/index.ts:65-86,171-224` | n/a | `res.ok` provereno; vraća `null` na RPC grešku |

Napomena: projekat ne koristi `supabase-js .from(...)`; koristi REST wrapper `sbReq()` (`src/services/supabase.js:50-119`). Zbog toga "error handled" znači: HTTP/mrežna greška se loguje centralno i vraća `null`; pozivajući servis često nema detaljan uzrok greške.

## RLS pokrivenost

| Tabela | SELECT | INSERT | UPDATE | DELETE | Napomena |
|--------|--------|--------|--------|--------|----------|
| sastanci | Da | Da (`FOR ALL`) | Da (`FOR ALL`) | Da (`FOR ALL`) | SELECT scoped Faza 2; write samo `has_edit_role()` |
| sastanak_ucesnici | Da | Da (`FOR ALL`) | Da (`FOR ALL`) | Da (`FOR ALL`) | SELECT parent-scope; write nije parent-scope |
| pm_teme | Da | Da (`FOR ALL`) | Da (`FOR ALL`) | Da (`FOR ALL`) | SELECT predlagač/management/učesnik parenta |
| akcioni_plan | Da | Da (`FOR ALL`) | Da (`FOR ALL`) | Da (`FOR ALL`) | SELECT odgovoran/management/učesnik parenta |
| presek_aktivnosti | Da | Da (`FOR ALL`) | Da (`FOR ALL`) | Da (`FOR ALL`) | SELECT parent-scope |
| presek_slike | Da | Da (`FOR ALL`) | Da (`FOR ALL`) | Da (`FOR ALL`) | SELECT parent-scope; Storage bucket ima posebne politike |
| sastanak_arhiva | Da | Da (`FOR ALL`) | Da (`FOR ALL`) | Da (`FOR ALL`) | SELECT parent-scope |
| sastanci_notification_prefs | Da | Da | Da | Da | Own row; management vidi/menja/briše sve |
| sastanci_notification_log | Da | Da | Da | Da | Own notifications ili management; enqueue helper service_role |
| sastanci_templates | Da | Da (`FOR ALL`) | Da (`FOR ALL`) | Da (`FOR ALL`) | SELECT `USING(true)` |
| sastanci_template_ucesnici | Da | Da (`FOR ALL`) | Da (`FOR ALL`) | Da (`FOR ALL`) | SELECT `USING(true)` |
| projekt_bigtehn_rn | Da | Da (`FOR ALL`) | Da (`FOR ALL`) | Da (`FOR ALL`) | Namerno ostavljeno `USING(true)` za SELECT |

## Logički tok

1. Kreiranje sastanka
   - Tabele: `sastanci`, zatim opciono `sastanak_ucesnici`.
   - Fajlovi: `src/ui/sastanci/createSastanakModal.js`, `src/services/sastanci.js`.
   - RPC: nema.

2. Učesnici
   - Tabela: `sastanak_ucesnici`.
   - Fajlovi: `src/services/sastanci.js`, `src/services/sastanciDetalj.js`, `src/ui/sastanci/sastanakModal.js`.
   - RPC: nema.
   - Notifikacije: AFTER INSERT trigger `sast_trg_ucesnik_invite()` enqueue-uje `meeting_invite`.

3. Presek aktivnosti
   - Tabele: `presek_aktivnosti`, `presek_slike`, Storage bucket `sastanak-slike`.
   - Fajlovi: `src/services/sastanciDetalj.js`, `src/services/projektniSastanak.js`, `src/ui/sastanci/projektniContent.js`.
   - RPC: nema.

4. Akcioni plan
   - Tabela/view: `akcioni_plan`, `v_akcioni_plan`.
   - Fajlovi: `src/services/akcioniPlan.js`, `src/ui/sastanci/akcioniPlanTab.js`, `src/ui/sastanci/sastanakDetalj/akcijeTab.js`.
   - RPC: nema.
   - Notifikacije: INSERT/UPDATE triggeri enqueue-uju `akcija_new` / `akcija_changed`.

5. PDF zapisnik
   - Tabele/Storage: `sastanak_arhiva`, bucket `sastanci-arhiva`.
   - Fajlovi: `src/lib/sastanciPdf.js`, `src/services/sastanciArhiva.js`, `src/services/sastanakArhiva.js`, `src/ui/sastanci/sastanakDetalj/arhivaTab.js`.
   - RPC: nema.

6. Notifikacije
   - Tabele: `sastanci_notification_prefs`, `sastanci_notification_log`.
   - SQL: `add_sastanci_notification_prefs.sql`, `add_sastanci_notification_outbox.sql`, `add_sastanci_notification_triggers.sql`, `add_sastanci_dispatch_rpc.sql`, `add_sastanci_reminder_jobs.sql`.
   - Edge: `supabase/functions/sastanci-notify-dispatch/index.ts`.
   - RPC: `sastanci_get_or_create_my_prefs`, `sastanci_dispatch_dequeue`, `sastanci_dispatch_mark_sent`, `sastanci_dispatch_mark_failed`.

7. Arhiviranje
   - Tabele: `sastanak_arhiva`, `sastanci.status='zakljucan'`.
   - Fajlovi: `src/services/sastanakArhiva.js`, `src/services/sastanciDetalj.js`, `src/services/sastanciArhiva.js`.
   - RPC: nema.

## Šta radi ispravno (potvrđeno OK)

- `is_sastanak_ucesnik(UUID)` je `SECURITY DEFINER` i ima `SET search_path = public, pg_temp` (`harden_sastanci_rls_phase2.sql:69-89`).
- SELECT politike za core tabele više nisu `USING(true)` i prate učesnik/management model (`harden_sastanci_rls_phase2.sql:99-171`).
- `sastanak_ucesnici` ima unique zaštitu kroz kompozitni PK `(sastanak_id, email)`.
- FK cascade postoji gde je najbitnije za parent sastanak: učesnici, presek aktivnosti, presek slike i arhiva se brišu uz `sastanci`; `sastanak_arhiva.sastanak_id` je UNIQUE.
- Outbox tabela postoji (`sastanci_notification_log`) sa retry kolonama, queue indexom i dispatch RPC-ovima.
- Edge Function šalje `X-Audit-Actor: sastanci-notify-dispatch@edge.servoteh` na sve PostgREST RPC pozive (`index.ts:63-76`).
- Retry logika postoji: dequeue koristi `FOR UPDATE SKIP LOCKED`, attempts/max_attempts i exponential backoff (`add_sastanci_dispatch_rpc.sql`, `index.ts:88-93,196-210`).
- Preference se poštuju u enqueue helperu pre slanja; opt-out redovi se upisuju kao `skipped`.
- Realtime subscription-i nisu nađeni u Sastanci modulu, pa nema curenja subscription-a na unmount.

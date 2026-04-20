# Modul: Lokacije delova — uputstvo za agenta (usklađeno sa ovim repo-om)

Dokument nadovezuje na spoljašnju specifikaciju (*Modul_Lokacije_Delova_Specifikacija.md*) i sprečava implementaciju pogrešnog stack-a ili uloga.

---

## Kako pokrenuti „Agent B” u Cursor-u

Cursor nema posebno dugme „Agent A / Agent B” — to je vaša oznaka za **drugi, odvojeni kontekst**:

1. Otvorite **Composer** ili **Chat** (npr. **Ctrl+I** / **Cmd+I** za Composer, ili ikona četa u bočnoj traci).
2. Započnite **novu sesiju**: **+** / **New chat** / **New Composer** da Agent B **ne nasledi** kontekst drugog agenta.
3. U tom prozoru zakačite (`@`) repozitorijum i/ili ovaj fajl `docs/Modul_Lokacije.md`.
4. U **istom** chatu držite **jedan** glavni zadatak (npr. samo lokacije), da ne meša module.

Ako koristite **Background Agent** (ako je uključen u planu), ista logika: nova sesija, jasna prva poruka.

---

## Gde originalna spec (sekcija G) ne odgovara ovom repo-u

| Šta često piše spec | Šta je u `servoteh-plan-montaze` |
|---------------------|----------------------------------|
| React + TypeScript + TanStack Query + Zustand | **Vite + vanilla JS** (`package.json`, `README.md`). |
| `src/modules/locations/**/*.tsx` | Obrasci: `src/ui/<modul>/`, `src/services/`, `src/state/`, `main.js`, `router.js`. |
| React Router (`/locations/items/...`) | **Nema** URL rutera kao u Reactu; `router.js` koristi screen/module hub + `sessionStorage`. |
| Uloge: magacioner, tehnicar, sef | U bazi/kodu: **`admin`, `leadpm`, `pm`, `menadzment`, `hr`, `viewer`** (`user_roles`, migracije, `src/state/auth.js`). Spec uloge zahtevaju **migraciju** + proširenje `effectiveRoleFromMatches` u `src/services/userRoles.js`. |
| RLS primer sa `auth.jwt() -> 'app_metadata' ->> 'role'` | Aplikacija koristi **`user_roles`** + lookup; ne kopirati JWT primere slepo. |
| Design system iz npm paketa | **`src/styles/legacy.css`** + postojeći hub/kadrovska layout. |

**Zaključak:** Sekcije A–F (model `loc_*`, queue, worker, MSSQL) mogu ostati **konceptualno** iste; implementacija frontenda i autorizacije mora da prati **ovaj** repo.

---

## Čega se držati (bez greške)

1. **Ne uvoditi React** samo zbog ovog modula bez eksplicitne odluke tima.
2. **Ne vezivati RLS** za JWT `app_metadata` bez usklađivanja sa `user_roles` i postojećim helperima.
3. **Ne uvoditi uloge** magacioner/tehnicar/sef bez migracije `user_roles` CHECK-a i ažuriranja `effectiveRoleFromMatches` / `auth.js` — inače rola može pasti na `viewer` ili biti nepoznata.
4. **Service role** samo u workeru, nikad u frontendu (kao u specifikaciji).
5. Pre UI-ja potvrditi **koji Supabase view/tablе** drže delove/sklopove/alate i **koje MSSQL kolone** write-back menja.

---

## Instrukcija za agenta (copy-paste kao prva poruka u novoj sesiji)

```
# AGENT — Modul Lokacije delova (usklađeno sa repo-om servoteh-plan-montaze)

## Obavezni tehnički kontekst (NE ignoriši)
- Repo je Vite 5 + vanilla JavaScript (ES modules), bez React-a, bez TypeScript-a, bez TanStack Query, bez Zustand.
- UI: postojeći obrasci u src/ui/ (tabovi, modali), stilovi u src/styles/legacy.css.
- API: src/services/supabase.js (sbReq), auth u src/state/auth.js, uloge iz tabele user_roles preko src/services/userRoles.js (loadAndApplyUserRole, effectiveRoleFromMatches).
- Navigacija: src/ui/router.js + module hub — nije React Router. Novi modul: novi screen ili novi entry u hub-u, konzistentno sa plan-montaze, kadrovska, itd.

## Šta preuzmi iz spoljašnje specifikacije (sekcije A–F)
- Polimorfna tabela loc_locations, loc_item_placements, loc_location_movements (append-only), loc_sync_outbound_events.
- Queue + Node worker + MSSQL SP sa idempotency — kao u specifikaciji.
- Quick Move, path_cached, triggeri — kao u specifikaciji.

## Obavezne izmene u odnosu na generičku „React“ instrukciju
1. Ne kreirati src/modules/locations/**/*.tsx. Umesto toga npr. src/ui/lokacije/ (ili dogovoreno ime) sa .js fajlovima koji prate stil ostalih modula.
2. Ne uvoditi TanStack Query/Zustand; server state: async funkcije + eventualno mali state u src/state/ ili lokalno u modulu; prati postojeći pattern iz drugog modula.
3. Uloge: pre implementacije RLS/UI matrice odlučiti: (a) proširiti user_roles.role migracijom za uloge iz specifikacije (magacioner, tehnicar, sef…) ili (b) mapirati ih na postojeće (admin, pm, …) i dokumentovati mapiranje. Ažurirati effectiveRoleFromMatches i auth.js helper-e da nova rola ne padne na viewer.
4. RLS i RPC: praviti u skladu sa email + user_roles modelom koji aplikacija već koristi, ne slepo kopirati JWT app_metadata primere.
5. Acceptance kriterijume prilagoditi: virtualizacija lista ako eksplicitno dodate zavisnost; keyboard shortcuts i i18n po dogovoru.

## Redosled (predlog)
1. SQL migracije + enum-i + triggeri (sql/migrations/).
2. RLS + loc_create_movement RPC (SECURITY DEFINER).
3. Servisi u src/services/lokacije*.js + tanak state po potrebi.
4. UI shell u hub-u + ekrani (dashboard, lista, detalj, browser, sync za admin).
5. Worker u odvojenom folderu ili repo-u kao u specifikaciji.

## Pre pisanja koda — od tima dobiti odgovore
- Tačni Supabase objekti za stavke (parts/tools/assemblies).
- Tačne MSSQL kolone za write-back i da li sync_processed_events već postoji.
- Da li postoji dokumentacija Servoteh dizajn tokena (ako ne — prati legacy.css i postojeće module).
```

---

## Referenca

- Spoljašnja specifikacija: `Modul_Lokacije_Delova_Specifikacija.md` (prilozi sa strane).
- Repo: `README.md`, `MIGRATION.md`, `sql/schema.sql`, `sql/migrations/`.

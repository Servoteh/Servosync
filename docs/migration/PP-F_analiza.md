# PP-F — Auto `local_status = in_progress` iz BigTehn prijave

## Kontekst

- **`bigtehn_tech_routing_cache`** sinhronizuje bridge worker (van ovog repoa).
- Kolona **`started_at`** (vidi `SUPABASE_PUBLIC_SCHEMA.md`) signalizuje da je prijava pokrenuta.

## Matching `(work_order_id, operacija)` → `line_id`

- Plan red u **`v_production_operations`** već spaja **`bigtehn_work_order_lines_cache`** (`line_id` = `id` stavke) sa **`operacija`**; isti broj **`operacija`** koristi **`bigtehn_tech_routing_cache`** po RN-u.
- Za auto-status koristiti **isti par** `(work_order_id, operacija)` da se pronađe overlay `(work_order_id, line_id)`.

## Predlog A — trigger

- `AFTER INSERT OR UPDATE OF started_at` na **`bigtehn_tech_routing_cache`**
- Kad **`NEW.started_at IS NOT NULL`** i (opciono) staro bilo NULL → **UPSERT** `production_overlays`: `local_status = 'in_progress'` **samo ako** trenutni `local_status` **nije** `'blocked'`.
- **SECURITY DEFINER**, `SET search_path = public, pg_temp`.

## Predlog B — pg_cron

- Periodični job (npr. 2 min) — manje rizično za performanse sync-a, veća latencija.

## Odluka (čeka Jaru)

- A vs B i da li **`blocked`** sme da bude preskočen u svim slučajevima.

## UI (implementirano kao priprema)

- Pogled **`v_production_operations_operational_plan`** u migraciji PP-D dodaje **`tech_routing_started_at`** (agregat po prijavama za par wo+operacija).
- U **„Po mašini”**: mali bedž **„auto”** pored statusa ako je `local_status === 'in_progress'` i postoji **`tech_routing_started_at`** — heuristika da je status usklađen sa prijavom (bez posebne kolone `auto_set_at` na overlay-u).

## Performanse

- Trigger na velikoj cache tabeli može usporiti bulk sync — obavezno test sa Jaretom pre produkcije.

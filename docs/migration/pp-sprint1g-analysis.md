# PP Sprint 1G — pre-flight analiza (M11: audit log za production_overlays)

> Datum: 2026-05-16 · Sprint: 1G · Audit ref: M11 u [Plan_proizvodnje_modul_analiza.md](../Plan_proizvodnje_modul_analiza.md)

## Cilj

Dodati forenzički audit log za `production_overlays` tabelu. Trenutno se istorija promena ne čuva — postoje samo `updated_at` + `updated_by` kao "snapshot poslednje promene". Pitanja tipa „ko je skinuo HITNO sa RN X i kada", „kako je status išao kroz vreme za ovu operaciju", „ko je toggle-ovao CAM ready dva puta" trenutno **nisu odgovorljiva** bez database log-ova.

## Tracked field-ovi

Ne pratimo svaku kolonu. Cilj je forenzička vrednost, ne kompletan snapshot.

| Field | Trackuje se? | Razlog |
|---|---|---|
| `local_status` | ✅ Da | Status tranzicije su najvažniji za audit (blocked → in_progress) |
| `assigned_machine_code` | ✅ Da | REASSIGN history (već postoji `production_reassign_audit` za FORCE; ovo dodaje regularne reassign-e) |
| `cam_ready` | ✅ Da | CAM toggle = bitna proizvodna odluka |
| `shift_note` | ✅ Da | Napomena šefa smene može biti operativno bitna |
| `cooperation_status` | ✅ Da | Kooperacija start/stop |
| `archived_at` | ✅ Da | Posredna podrška za M12 ako se ikad implementira |
| `shift_sort_order` | ❌ Ne | Drag-drop je vrlo čest (svaki reorder od 100 redova = 100 update-a). Audit bi bio noise. |
| `updated_at` | ❌ Ne | Mehanizam, ne korisnička akcija |
| `cam_ready_at` / `cam_ready_by` | ❌ Ne | Već je metadata, ne nezavisna promena |
| `cooperation_partner` / `cooperation_set_*` | ❌ Ne | Sub-detail; prati `cooperation_status` |

## Šema

### Tabela `production_overlays_history`

```sql
CREATE TABLE public.production_overlays_history (
  id              BIGSERIAL PRIMARY KEY,
  overlay_id      BIGINT NOT NULL,        -- logički FK na production_overlays(id), bez constraint-a
  work_order_id   BIGINT NOT NULL,        -- denormalizovano za pretragu po RN-u
  line_id         BIGINT NOT NULL,        -- denormalizovano
  field_name      TEXT   NOT NULL,        -- jedan od tracked field-ova ili '_created'
  old_value       TEXT,                   -- pre promene (NULL za _created)
  new_value       TEXT,                   -- posle promene
  changed_by      TEXT,                   -- iz NEW.updated_by ili current_user_email()
  changed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT poh_field_check CHECK (field_name IN (
    '_created', 'local_status', 'assigned_machine_code', 'cam_ready',
    'shift_note', 'cooperation_status', 'archived_at'
  ))
);
```

**Logički FK bez constraint-a:** ako se `production_overlays` red ikada obriše (trenutno se ne briše, samo `archived_at`), history preživljava. To je namera — forenzika ne sme da nestane.

### Indeksi

```sql
CREATE INDEX poh_idx_overlay   ON public.production_overlays_history (overlay_id, changed_at DESC);
CREATE INDEX poh_idx_line      ON public.production_overlays_history (work_order_id, line_id, changed_at DESC);
CREATE INDEX poh_idx_field     ON public.production_overlays_history (field_name, changed_at DESC);
CREATE INDEX poh_idx_changed_by ON public.production_overlays_history (changed_by, changed_at DESC);
```

Indeks po `changed_by` omogućava upite tipa „šta je admin@servoteh.com radio prošle nedelje".

### Trigger

Jedan `AFTER UPDATE` trigger za 6 field-ova + jedan `AFTER INSERT` za `_created` event. Trigger je SECURITY DEFINER da bi mogao da pisi u history tabelu uprkos REVOKE-u (vidi RLS sekciju).

```sql
CREATE OR REPLACE FUNCTION public.production_overlays_audit_history()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_changed_by text;
BEGIN
  v_changed_by := COALESCE(NEW.updated_by, public.current_user_email(), 'unknown');

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.production_overlays_history (
      overlay_id, work_order_id, line_id, field_name, old_value, new_value, changed_by
    ) VALUES (
      NEW.id, NEW.work_order_id, NEW.line_id, '_created',
      NULL, NEW.local_status, COALESCE(NEW.created_by, v_changed_by)
    );
    RETURN NEW;
  END IF;

  -- UPDATE: po jedan INSERT za svaki tracked field koji se promenio
  IF NEW.local_status IS DISTINCT FROM OLD.local_status THEN
    INSERT INTO public.production_overlays_history (
      overlay_id, work_order_id, line_id, field_name, old_value, new_value, changed_by
    ) VALUES (
      NEW.id, NEW.work_order_id, NEW.line_id, 'local_status',
      OLD.local_status, NEW.local_status, v_changed_by
    );
  END IF;

  -- ... istovetan blok za assigned_machine_code, cam_ready, shift_note, cooperation_status, archived_at ...

  RETURN NEW;
END;
$$;

CREATE TRIGGER po_audit_history
  AFTER INSERT OR UPDATE ON public.production_overlays
  FOR EACH ROW
  EXECUTE FUNCTION public.production_overlays_audit_history();
```

### RLS

```sql
ALTER TABLE public.production_overlays_history ENABLE ROW LEVEL SECURITY;

-- SELECT za sve authenticated (svako sa pristupom PP modulu vidi history)
CREATE POLICY poh_select_authenticated
  ON public.production_overlays_history FOR SELECT
  TO authenticated
  USING (true);

-- Eksplicitno blokirаj klijentske write (pattern iz Sprint 1E)
CREATE POLICY poh_no_client_write   FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY poh_no_client_update  FOR UPDATE TO authenticated USING (false) WITH CHECK (false);
CREATE POLICY poh_no_client_delete  FOR DELETE TO authenticated USING (false);

REVOKE INSERT, UPDATE, DELETE, TRUNCATE
  ON public.production_overlays_history
  FROM authenticated, anon;
```

Trigger funkcija je SECURITY DEFINER → INSERT u history prolazi uprkos REVOKE-u.

## Skala i performance

- Procena promena: ~50 manualnih akcija dnevno (status/CAM/HITNO/note) + G6 RPC ~100 INSERT-a po bridge sync-u (svakih 15 min) → ~10K INSERT-a/dan u history.
- Godišnje: ~3.6M redova. Bezopasno za PostgreSQL sa indeksima.
- Posle 5 godina: ~18M redova. Tada je vredno razmotriti partition po `changed_at` (kvartalno).

**Performance impact na UPDATE:**
- Trigger se pokreće na svakom UPDATE-u (uključujući reorder).
- Reorder pravi UPDATE samo `shift_sort_order` → nijedan tracked field se ne menja → trigger prolazi kroz 6 `IS DISTINCT FROM` provera i ne radi INSERT. **Trošak: ~0.1ms po UPDATE-u.**
- Pravi UPDATE (npr. status promena) → 1 INSERT u history → ~0.5ms.

Ukupni overhead je minimalan.

## Migracija postojećih podataka

`production_overlays` ima 674 redova (Sprint 0 SQL #8). Migracija ne traži populaciju history-ja iz postojećih redova — nemamo OLD vrednosti, samo trenutno stanje.

Opciono: jedan **bootstrap INSERT** koji za svaki postojeći overlay upiše `_created` event sa current state-om kao "snapshot zatečenog stanja na dan migracije":

```sql
-- Opcioni bootstrap: označi sve postojeće redove kao "_created" na trenutni datum
INSERT INTO public.production_overlays_history (
  overlay_id, work_order_id, line_id, field_name, old_value, new_value, changed_by, changed_at
)
SELECT
  id, work_order_id, line_id, '_created',
  NULL, local_status, COALESCE(created_by, updated_by, 'unknown'),
  COALESCE(created_at, NOW())
FROM public.production_overlays;
```

**Predlog:** uključim bootstrap u migraciju iza trigger-a, sa komentarom da Jara može da je preskoči ako želi prazan history.

## UI za pregled history-ja

**Ne radimo u Sprint 1G.** Razlozi:
- UI traži dodatni tab ili modal — značajan dizajn rad.
- SQL pristup je dovoljan za prvih nekoliko meseci (admin može da pita kroz Studio).
- Kada bude potreba, Sprint 1G+1 dodaje "History" akciju na red u Po mašini tabu sa modal-om.

Bez UI-a, trenutno može se konsultovati:
```sql
SELECT changed_at, field_name, old_value, new_value, changed_by
FROM production_overlays_history
WHERE work_order_id = :wo AND line_id = :line
ORDER BY changed_at DESC;
```

## Risk i rollback

- **Risk:** Srednji. Trigger se pokreće na svakom UPDATE/INSERT u `production_overlays`. Bug u trigger-u (npr. nevalidan CAST) bi blokirao SVE update-e na overlay-u — kritičan deo modula.
- **Rollback:** `DROP TRIGGER po_audit_history ON production_overlays;` — trigger off, overlay-i rade normalno. Tabela `production_overlays_history` ostaje (ima istorijski podatke do tog trenutka).

## Test plan

Posle apply-a, manuelni testovi:

1. **CAM toggle** → 1 red u history (`cam_ready` polje, old=false new=true)
2. **Status promena** (klik na pill) → 1 red (`local_status`)
3. **HITNO toggle** — nije u overlay-u (`production_urgency_overrides` je posebna tabela), pa NE rezultira history red — to je očekivano, audit za HITNO je tracked elsewhere.
4. **Napomena change** → 1 red (`shift_note`)
5. **REASSIGN** → 1 red (`assigned_machine_code`)
6. **Drag-drop reorder** → 0 redova (jer `shift_sort_order` nije tracked) ✓
7. **G6 RPC** (auto in_progress) → po INSERT/UPDATE za svaki novi/promenjeni red

Performance verifikacija: izvršiti drag-drop sa 100 redova, izmeri vreme. Treba da ostane < 200ms.

## Vremenska procena

- Pre-flight: 30 min ✅
- SQL migracija (tabela + trigger + RLS + bootstrap): 60 min
- Manuelni smoke test posle apply-a: 30 min
- **Ukupno: ~2h**

## Stvari koje NEĆE biti u Sprint 1G

- UI za pregled history-ja — Sprint 1G+1 ako bude potreba.
- Partition po `changed_at` — odložiti dok tabela ne pređe ~10M redova.
- M30 (G6 `updated_by` smart guard) — posle ponovne analize G6 koda, M30 nije akutan jer UPDATE filter `local_status = 'waiting'` već štiti od trovanja na ne-waiting redovima.
- M12 (`archived_at` flow) — još uvek čeka tvoju policy odluku (implement/drop/reserve).

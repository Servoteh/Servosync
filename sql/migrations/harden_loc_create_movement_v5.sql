-- ============================================================================
-- harden_loc_create_movement_v5.sql
-- Sprint LOC-Härd-1: integritet podataka
-- ============================================================================
-- Rešava nalaze iz docs/Lokacije_modul_analiza.md / docs/lokacije/sprint-1-analiza.md:
--   H1  — race u kapacitet validaciji (advisory lock na bucket)
--   H2  — race u INITIAL_PLACEMENT; OPCIJA B: akumulacija dozvoljena
--          (ukidamo `already_placed`; trigger v4 i dalje radi ON CONFLICT DO UPDATE
--           sa quantity = old + EXCLUDED → količina se sabira)
--   H15 — offline retry duplikati (client_event_uuid idempotency, opcioni)
--   M5  — rekurzivna provera deaktiviranih predaka odredišne police
--   L34 — eksplicitno hvatanje check_violation (bolja poruka umesto generic exception)
--
-- Napomene:
--   * Postojeće migracije v1..v4 i `add_loc_menadzment_manage_locations.sql`
--     se NE diraju.
--   * Trigger `loc_after_movement_insert` (v4) ostaje netaknut — on i dalje
--     radi UPSERT placement-a + insert sync queue. Promena je samo u
--     validaciji unutar `loc_create_movement`.
--   * `client_event_uuid` je OPCIONI parametar (odluka korisnika Q1=A):
--       - ako klijent pošalje UUID i isti je već prisutan → idempotent replay
--         (vraćamo postojeći movement.id sa `idempotent:true`)
--       - ako klijent ne pošalje UUID → RPC generiše gen_random_uuid()
--         (drugi moduli — Reversi, Štampa nalepnica — i dalje rade bez izmena)
--   * Potpis funkcije ostaje `loc_create_movement(payload jsonb)` (Q4).
--   * `item_ref_id` ostaje TEXT (sprint draft ga je naveo kao bigint —
--     to bi slomilo Reversi koji koristi numerički ID kao TEXT i scanModal
--     koji šalje broj TP kao string).
--
-- Primeni nakon: add_loc_v4_drawing_no.sql
-- ============================================================================

BEGIN;

-- ── 1) Idempotency: client_event_uuid kolona + partial unique indeks ───────
ALTER TABLE public.loc_location_movements
  ADD COLUMN IF NOT EXISTS client_event_uuid uuid;

/* UNIQUE samo na ne-NULL vrednostima — postojeća istorija ima NULL i
 * sprečen je sukob sa stranim klijentima koji još ne šalju UUID. */
CREATE UNIQUE INDEX IF NOT EXISTS uq_loc_movements_client_event_uuid
  ON public.loc_location_movements (client_event_uuid)
  WHERE client_event_uuid IS NOT NULL;

-- ── 2) Rewrite RPC `loc_create_movement` v5 ────────────────────────────────
CREATE OR REPLACE FUNCTION public.loc_create_movement(payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn_cm$
DECLARE
  v_uid                uuid;
  v_client_event_uuid  uuid;
  v_existing_id        uuid;
  v_item_table         text;
  v_item_id            text;
  v_order              text;
  v_drawing            text;
  v_to                 uuid;
  v_from               uuid;
  v_mtype              public.loc_movement_type_enum;
  v_qty                numeric(12,3);
  v_avail              numeric(12,3);
  v_new_id             uuid;
  v_lock_key           bigint;
BEGIN
  /* ── Auth ─────────────────────────────────────────────────────────── */
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  /* ── Idempotency: opcioni client_event_uuid ──────────────────────── */
  /* Ako klijent pošalje UUID, koristi ga (i potencijalno odmah replay-uj).
   * Ako ne pošalje, RPC generiše novi (nema idempotency, ali RPC i dalje
   * radi — kompatibilno sa Reversi/Štampa nalepnica modulima). */
  BEGIN
    v_client_event_uuid := nullif(trim(payload->>'client_event_uuid'), '')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_client_event_uuid');
  END;

  IF v_client_event_uuid IS NOT NULL THEN
    /* Ako je već procesiran — vrati prethodni rezultat (idempotent replay).
     * Bitno za offline queue retry posle network drop-a između RPC i klijenta. */
    SELECT mv.id INTO v_existing_id
      FROM public.loc_location_movements mv
     WHERE mv.client_event_uuid = v_client_event_uuid
     LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
      RETURN jsonb_build_object(
        'ok', true,
        'id', v_existing_id,
        'idempotent', true
      );
    END IF;
  ELSE
    v_client_event_uuid := gen_random_uuid();
  END IF;

  /* ── Parsing ostatka payload-a ───────────────────────────────────── */
  v_item_table := nullif(trim(payload->>'item_ref_table'), '');
  v_item_id    := nullif(trim(payload->>'item_ref_id'), '');
  v_order      := COALESCE(trim(payload->>'order_no'), '');
  v_drawing    := COALESCE(trim(payload->>'drawing_no'), '');
  v_mtype      := (payload->>'movement_type')::public.loc_movement_type_enum;

  v_qty := coalesce((payload->>'quantity')::numeric, 1);
  IF v_qty IS NULL OR v_qty <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_quantity');
  END IF;

  IF char_length(v_order) > 40 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_order_no');
  END IF;
  IF char_length(v_drawing) > 40 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_drawing_no');
  END IF;

  IF payload ? 'to_location_id' AND nullif(trim(payload->>'to_location_id'), '') IS NOT NULL THEN
    v_to := (payload->>'to_location_id')::uuid;
  END IF;
  IF payload ? 'from_location_id' AND nullif(trim(payload->>'from_location_id'), '') IS NOT NULL THEN
    v_from := (payload->>'from_location_id')::uuid;
  END IF;

  IF v_item_table IS NULL OR v_item_id IS NULL OR v_to IS NULL OR v_mtype IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_fields');
  END IF;

  /* ── TO lokacija mora biti aktivna ──────────────────────────────── */
  IF NOT EXISTS (
    SELECT 1 FROM public.loc_locations loc_chk
    WHERE loc_chk.id = v_to AND loc_chk.is_active
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_to_location');
  END IF;

  /* ── M5: rekurzivna provera predaka odredišne lokacije ─────────── */
  /* Ako je bilo koji predak deaktiviran, blokiraj. Inače operater može
   * da zatrpa „mrtvu" halu kroz aktivne police u njoj. */
  IF EXISTS (
    WITH RECURSIVE anc(id, parent_id, is_active, depth) AS (
      SELECT l.id, l.parent_id, l.is_active, 0
        FROM public.loc_locations l
       WHERE l.id = v_to
      UNION ALL
      SELECT p.id, p.parent_id, p.is_active, a.depth + 1
        FROM public.loc_locations p
        JOIN anc a ON a.parent_id = p.id
       WHERE a.depth < 200  /* defense protiv pokvarene hijerarhije */
    )
    SELECT 1 FROM anc WHERE NOT is_active AND id <> v_to LIMIT 1
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'parent_inactive');
  END IF;

  /* ── ADVISORY LOCK na bucket (table, id, order) ────────────────── */
  /* Serijalizuje sve istovremene operacije za isti bucket. Rešava H1
   * (kapacitet race) i pruža defense-in-depth za H2 (INITIAL akumulacija
   * je inače bezbedna preko UNIQUE constraint-a + ON CONFLICT u trigger-u,
   * ali lock štiti i od istovremenog DELETE u FROM grani). */
  v_lock_key := hashtextextended(
    v_item_table || ':' || v_item_id || ':' || v_order,
    0
  );
  PERFORM pg_advisory_xact_lock(v_lock_key);

  /* ── Validacija po tipu pokreta ────────────────────────────────── */
  IF v_mtype = 'INITIAL_PLACEMENT' THEN
    /* OPCIJA B: NEMA `already_placed` check.
     * Trigger v4 radi ON CONFLICT (item, id, order, location) DO UPDATE
     * pa se quantity sabira ako placement već postoji.
     * Ako placement ne postoji na (item, id, order, location), kreira se. */
    v_from := NULL;

  ELSIF v_mtype = 'INVENTORY_ADJUSTMENT' THEN
    v_from := NULL;

  ELSE
    /* TRANSFER/ASSIGN/RETURN/SCRAP itd. — treba from. Ako nije prosleđen
     * i postoji TAČNO JEDAN placement za (item, id, order) → automatski. */
    IF v_from IS NULL THEN
      DECLARE
        v_cnt integer;
      BEGIN
        v_cnt := (
          SELECT count(*)::int
            FROM public.loc_item_placements lp
           WHERE lp.item_ref_table = v_item_table
             AND lp.item_ref_id    = v_item_id
             AND lp.order_no       = v_order
        );
        IF v_cnt = 0 THEN
          RETURN jsonb_build_object('ok', false, 'error', 'no_current_placement');
        ELSIF v_cnt > 1 THEN
          RETURN jsonb_build_object('ok', false, 'error', 'from_ambiguous');
        END IF;
        v_from := (
          SELECT lp.location_id
            FROM public.loc_item_placements lp
           WHERE lp.item_ref_table = v_item_table
             AND lp.item_ref_id    = v_item_id
             AND lp.order_no       = v_order
           LIMIT 1
        );
      END;
    END IF;

    /* Kapacitet FROM lokacije pod advisory lock-om (H1). */
    v_avail := (
      SELECT lp.quantity
        FROM public.loc_item_placements lp
       WHERE lp.item_ref_table = v_item_table
         AND lp.item_ref_id    = v_item_id
         AND lp.order_no       = v_order
         AND lp.location_id    = v_from
       LIMIT 1
    );

    IF v_avail IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'error', 'from_has_no_placement');
    END IF;
    IF v_qty > v_avail THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'insufficient_quantity',
        'available', v_avail,
        'requested', v_qty
      );
    END IF;
  END IF;

  /* ── INSERT movement (trigger v4 radi UPSERT placement-a) ──────── */
  v_new_id := gen_random_uuid();

  BEGIN
    INSERT INTO public.loc_location_movements (
      id, item_ref_table, item_ref_id, order_no, drawing_no,
      from_location_id, to_location_id,
      movement_type, movement_reason, quantity, note,
      moved_at, moved_by, client_event_uuid
    ) VALUES (
      v_new_id,
      v_item_table,
      v_item_id,
      v_order,
      v_drawing,
      v_from,
      v_to,
      v_mtype,
      nullif(trim(payload->>'movement_reason'), ''),
      v_qty,
      nullif(trim(payload->>'note'), ''),
      coalesce((payload->>'moved_at')::timestamptz, now()),
      v_uid,
      v_client_event_uuid
    );
  EXCEPTION
    WHEN unique_violation THEN
      /* Race: dva paralelna poziva sa istim client_event_uuid stigli
       * između check-a i INSERT-a. Drugi vraća postojeći rezultat. */
      SELECT mv.id INTO v_existing_id
        FROM public.loc_location_movements mv
       WHERE mv.client_event_uuid = v_client_event_uuid
       LIMIT 1;
      IF v_existing_id IS NOT NULL THEN
        RETURN jsonb_build_object('ok', true, 'id', v_existing_id, 'idempotent', true);
      END IF;
      /* Drugačiji unique violation (ne-UUID) — vraćamo eksplicitno
       * jer to ne sme tiho da padne kao `exception`. */
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'constraint_violation',
        'detail', SQLERRM
      );
    WHEN check_violation THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'constraint_violation',
        'detail', SQLERRM
      );
    WHEN others THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'exception',
        'detail', SQLERRM
      );
  END;

  RETURN jsonb_build_object('ok', true, 'id', v_new_id);
END;
$fn_cm$;

GRANT EXECUTE ON FUNCTION public.loc_create_movement(jsonb) TO authenticated;

COMMENT ON FUNCTION public.loc_create_movement(jsonb) IS
  'v5 (Härd-1): advisory lock na (item, order) bucket; INITIAL_PLACEMENT akumulira '
  '(opcija B); opcioni client_event_uuid idempotency; rekurzivna provera predaka odredišta; '
  'eksplicitno hvatanje check_violation. Trigger loc_after_movement_insert v4 i dalje '
  'radi UPSERT placement-a i insert sync queue-a.';

-- ── 3) Sanity check ────────────────────────────────────────────────────────
DO $sanity$
DECLARE
  v_has_uuid_col BOOLEAN;
  v_has_uuid_idx BOOLEAN;
BEGIN
  v_has_uuid_col := EXISTS(
    SELECT 1 FROM information_schema.columns
     WHERE table_schema='public'
       AND table_name='loc_location_movements'
       AND column_name='client_event_uuid'
  );
  v_has_uuid_idx := EXISTS(
    SELECT 1 FROM pg_indexes
     WHERE schemaname='public'
       AND tablename='loc_location_movements'
       AND indexname='uq_loc_movements_client_event_uuid'
  );

  IF NOT (v_has_uuid_col AND v_has_uuid_idx) THEN
    RAISE EXCEPTION 'harden v5 sanity failed: uuid_col=%, uuid_idx=%',
      v_has_uuid_col, v_has_uuid_idx;
  END IF;

  RAISE NOTICE 'harden_loc_create_movement_v5 OK (client_event_uuid + advisory lock + opcija B + parent_inactive).';
END
$sanity$;

COMMIT;

-- ============================================================================
-- harden_loc_create_movement_v5_roles.sql
-- Sprint LOC-Härd-2: autorizacija
-- ============================================================================
-- Rešava H4 (svako sa Supabase nalogom može da zove loc_create_movement).
--
-- Preko helper-a `loc_can_create_movement()` ograničavamo pozive na:
--   (1) user_roles uloge: admin, leadpm, pm, menadzment (potvrđeno od korisnika)
--   (2) zaposlenj kojima e.is_active = true i:
--       - e.department_id IN (2, 3)  → Proizvodnja, Montaža (opcija B)
--       - sub_departments.name = 'Magacin i logistika'  → magacioneri u
--         Infrastrukturi (sub of departments.id=8)
--
-- Mapping korisnika ide preko email-a (auth.jwt()->>'email' = lower(email)),
-- konzistentno sa ostatkom kodbase-a (pb4_rls, menadzment_full_edit, maint).
-- `employees.auth_user_id` ne postoji — sprint draft je bio pogrešan.
--
-- Postojeće migracije v5 (Härd-1) i ranije se NE diraju. Ovde samo:
--   * Dodaje se helper `loc_can_create_movement()`.
--   * Modifikuje se RPC `loc_create_movement` da poziva helper ODMAH posle
--     auth.uid() check-a (pre svake druge logike).
--
-- Primeni nakon: harden_loc_create_movement_v5.sql
-- ============================================================================

BEGIN;

-- ── 1) Helper: ko sme da zove loc_create_movement ─────────────────────────
CREATE OR REPLACE FUNCTION public.loc_can_create_movement()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn_authz$
DECLARE
  v_email TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  /* (1) user_roles spisak — loc_auth_roles() već lower-case-uje i filtrira po
   * is_active. Härd-2 lista uloga (potvrđeno od korisnika). */
  IF public.loc_auth_roles() && ARRAY['admin','leadpm','pm','menadzment']::text[] THEN
    RETURN true;
  END IF;

  /* (2) Employee match preko email-a iz JWT-a, plus odeljenje / pododeljenje.
   * `auth_user_id` ne postoji na employees u ovoj šemi; pratimo postojeći
   * obrazac (pb4_rls, menadzment_full_edit). */
  v_email := lower(trim(coalesce(auth.jwt()->>'email', '')));
  IF v_email = '' THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
      FROM public.employees e
      LEFT JOIN public.sub_departments sd ON sd.id = e.sub_department_id
     WHERE e.is_active
       AND lower(coalesce(e.email, '')) = v_email
       AND (
         e.department_id IN (2, 3)              /* Proizvodnja + Montaža (opcija B) */
         OR sd.name = 'Magacin i logistika'     /* Infrastruktura/Magacin */
       )
  );
END;
$fn_authz$;

GRANT EXECUTE ON FUNCTION public.loc_can_create_movement() TO authenticated;

COMMENT ON FUNCTION public.loc_can_create_movement() IS
  'Härd-2 autorizacija za RPC loc_create_movement: admin/leadpm/pm/menadzment '
  '(preko user_roles) ili zaposleni sa department_id IN (2,3) ili sub_department '
  '"Magacin i logistika". Mapping preko lower(email) = auth.jwt()->>email.';

-- ── 2) Modifikacija RPC-a: provera autorizacije pre svega ostalog ─────────
/* Cela definicija RPC-a se ponavlja (kao i u v5). Razlog: PostgreSQL `CREATE OR
 * REPLACE FUNCTION` zahteva pun body — nema „partial replace". Vraćamo identičan
 * body kao Härd-1, sa JEDNIM dodatkom: `IF NOT loc_can_create_movement()` blok
 * odmah posle auth.uid() check-a. */
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

  /* ── Härd-2: autorizacija (uloga ili odeljenje) ──────────────────── */
  IF NOT public.loc_can_create_movement() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authorized');
  END IF;

  /* ── Idempotency (Härd-1, opcioni client_event_uuid) ────────────── */
  BEGIN
    v_client_event_uuid := nullif(trim(payload->>'client_event_uuid'), '')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_client_event_uuid');
  END;

  IF v_client_event_uuid IS NOT NULL THEN
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
  IF EXISTS (
    WITH RECURSIVE anc(id, parent_id, is_active, depth) AS (
      SELECT l.id, l.parent_id, l.is_active, 0
        FROM public.loc_locations l
       WHERE l.id = v_to
      UNION ALL
      SELECT p.id, p.parent_id, p.is_active, a.depth + 1
        FROM public.loc_locations p
        JOIN anc a ON a.parent_id = p.id
       WHERE a.depth < 200
    )
    SELECT 1 FROM anc WHERE NOT is_active AND id <> v_to LIMIT 1
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'parent_inactive');
  END IF;

  /* ── ADVISORY LOCK na bucket (table, id, order) ────────────────── */
  v_lock_key := hashtextextended(
    v_item_table || ':' || v_item_id || ':' || v_order,
    0
  );
  PERFORM pg_advisory_xact_lock(v_lock_key);

  /* ── Validacija po tipu pokreta ────────────────────────────────── */
  IF v_mtype = 'INITIAL_PLACEMENT' THEN
    v_from := NULL;
  ELSIF v_mtype = 'INVENTORY_ADJUSTMENT' THEN
    v_from := NULL;
  ELSE
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
      SELECT mv.id INTO v_existing_id
        FROM public.loc_location_movements mv
       WHERE mv.client_event_uuid = v_client_event_uuid
       LIMIT 1;
      IF v_existing_id IS NOT NULL THEN
        RETURN jsonb_build_object('ok', true, 'id', v_existing_id, 'idempotent', true);
      END IF;
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
  'v5+Härd-2: advisory lock + INITIAL akumulacija (opcija B) + opcioni client_event_uuid '
  'idempotency + parent_inactive + check_violation. Härd-2: poziv ide kroz '
  'loc_can_create_movement() — odbija korisnike bez admin/leadpm/pm/menadzment uloge '
  'i bez employee zapisa u Proizvodnji/Montaži/Magacinu.';

-- ── 3) Sanity check ────────────────────────────────────────────────────────
DO $sanity$
DECLARE
  v_helper_exists BOOLEAN;
BEGIN
  v_helper_exists := EXISTS(
    SELECT 1 FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'loc_can_create_movement'
  );

  IF NOT v_helper_exists THEN
    RAISE EXCEPTION 'harden v5_roles sanity failed: loc_can_create_movement() ne postoji';
  END IF;

  RAISE NOTICE 'harden_loc_create_movement_v5_roles OK (helper + RPC autorizacija).';
END
$sanity$;

COMMIT;

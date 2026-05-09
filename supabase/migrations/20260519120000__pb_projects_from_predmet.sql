-- Projektni biro: lista projekata = BigTehn predmeti sa je_aktivan AND je_projektovanje_montaza.
-- public.projects dobija opcioni bigtehn_item_id; novi redovi koriste stabilan UUID po item_id (md5).
-- Postojeći Plan Montaže red (bez bigtehn_item_id) koji odgovara šifri po normalizaciji se spaja (UPDATE bigtehn_item_id).
-- Migracija zadataka: RN 9000 → RN 9400 (7701 ostaje na svom predmet-redu).

ALTER TABLE public.projects
  ADD COLUMN IF NOT EXISTS bigtehn_item_id INTEGER;

COMMENT ON COLUMN public.projects.bigtehn_item_id IS
  'bigtehn_items_cache.id kada je red PB/plan kataloga vezan za zvanični predmet; NULL = ručno/legacy.';

CREATE UNIQUE INDEX IF NOT EXISTS idx_projects_bigtehn_item_id
  ON public.projects (bigtehn_item_id)
  WHERE bigtehn_item_id IS NOT NULL;

-- RN / razmaci → uporedive šifre (RN9000, RN 9000, 9000 → 9000)
CREATE OR REPLACE FUNCTION public.pb_normalize_project_code(txt text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT regexp_replace(
    regexp_replace(lower(trim(COALESCE(txt, ''))), '^rn[[:space:]]*', ''),
    '[[:space:]]',
    '',
    'g'
  );
$$;

REVOKE ALL ON FUNCTION public.pb_normalize_project_code(text) FROM PUBLIC;

-- Deterministički UUID iz md5 (bez uuid-ossp uuid_generate_v5 na svim Supabase projektima).
CREATE OR REPLACE FUNCTION public.pb_predmet_project_uuid(p_item_id integer)
RETURNS uuid
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT (
    substr(m, 1, 8) || '-' ||
    substr(m, 9, 4) || '-' ||
    '5' || substr(m, 13, 3) || '-' ||
    '8' || substr(m, 17, 3) || '-' ||
    substr(m, 21, 12)
  )::uuid
  FROM (SELECT md5('servoteh_pb_predmet:v1:' || p_item_id::text) AS m) s;
$$;

REVOKE ALL ON FUNCTION public.pb_predmet_project_uuid(integer) FROM PUBLIC;

CREATE OR REPLACE FUNCTION production.sync_pb_project_from_predmet(p_item_id integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
DECLARE
  v_code text;
  v_name text;
  v_norm text;
  v_new_id uuid;
  v_legacy_id uuid;
BEGIN
  IF p_item_id IS NULL OR p_item_id <= 0 THEN
    RETURN;
  END IF;

  SELECT
    NULLIF(trim(COALESCE(i.broj_predmeta, '')), ''),
    COALESCE(NULLIF(trim(COALESCE(i.naziv_predmeta, '')), ''), '(bez naziva)')
  INTO v_code, v_name
  FROM public.bigtehn_items_cache i
  WHERE i.id = p_item_id;

  IF v_code IS NULL THEN
    RETURN;
  END IF;

  v_norm := public.pb_normalize_project_code(v_code);
  v_new_id := public.pb_predmet_project_uuid(p_item_id);

  SELECT p.id INTO v_legacy_id
  FROM public.projects p
  WHERE p.bigtehn_item_id IS NULL
    AND public.pb_normalize_project_code(p.project_code) = v_norm
  ORDER BY p.created_at ASC NULLS FIRST
  LIMIT 1;

  IF v_legacy_id IS NOT NULL THEN
    UPDATE public.projects
    SET
      bigtehn_item_id = p_item_id,
      project_code = v_code,
      project_name = v_name,
      status = 'active',
      updated_at = now()
    WHERE id = v_legacy_id;
    RETURN;
  END IF;

  BEGIN
    INSERT INTO public.projects (id, project_code, project_name, status, bigtehn_item_id)
    VALUES (v_new_id, v_code, v_name, 'active', p_item_id)
    ON CONFLICT (id) DO UPDATE SET
      project_code = EXCLUDED.project_code,
      project_name = EXCLUDED.project_name,
      bigtehn_item_id = EXCLUDED.bigtehn_item_id,
      status = 'active',
      updated_at = now();
  EXCEPTION
    WHEN unique_violation THEN
      UPDATE public.projects p
      SET
        bigtehn_item_id = p_item_id,
        project_name = v_name,
        status = 'active',
        updated_at = now()
      WHERE p.id = (
        SELECT p2.id
        FROM public.projects p2
        WHERE (
            p2.project_code = v_code
            OR (
              p2.bigtehn_item_id IS NULL
              AND public.pb_normalize_project_code(p2.project_code) = v_norm
            )
          )
          AND (p2.bigtehn_item_id IS NULL OR p2.bigtehn_item_id = p_item_id)
        ORDER BY CASE WHEN p2.project_code = v_code THEN 0 ELSE 1 END,
          p2.created_at ASC NULLS FIRST
        LIMIT 1
      );
  END;
END;
$$;

REVOKE ALL ON FUNCTION production.sync_pb_project_from_predmet(integer) FROM PUBLIC;

CREATE OR REPLACE FUNCTION production.tg_predmet_pb_project_sync()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
BEGIN
  IF NEW.je_aktivan IS TRUE AND NEW.je_projektovanje_montaza IS TRUE THEN
    PERFORM production.sync_pb_project_from_predmet(NEW.predmet_item_id);
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION production.tg_predmet_pb_project_sync() FROM PUBLIC;

DROP TRIGGER IF EXISTS tr_predmet_pb_project_sync ON production.predmet_aktivacija;
CREATE TRIGGER tr_predmet_pb_project_sync
AFTER INSERT OR UPDATE OF je_aktivan, je_projektovanje_montaza
ON production.predmet_aktivacija
FOR EACH ROW
EXECUTE PROCEDURE production.tg_predmet_pb_project_sync();

-- Backfill sinhronizacije za sve predmete koji ulaze u PB listu
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT pa.predmet_item_id
    FROM production.predmet_aktivacija pa
    WHERE pa.je_aktivan IS TRUE
      AND pa.je_projektovanje_montaza IS TRUE
  LOOP
    PERFORM production.sync_pb_project_from_predmet(r.predmet_item_id);
  END LOOP;
END $$;

-- Zadaci sa RN 9000 → RN 9400 (predmet šifre tačno '9000' ili legacy kod koji normalizuje na 9000); ostalo diramo jedino ako je red vezan za predmet 9000.
UPDATE public.pb_tasks t
SET
  project_id = p9400.id,
  updated_at = now()
FROM public.projects p9400
WHERE p9400.bigtehn_item_id = (
    SELECT i.id
    FROM public.bigtehn_items_cache i
    WHERE trim(i.broj_predmeta) = '9400'
    ORDER BY i.id
    LIMIT 1
  )
  AND t.deleted_at IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.projects ps
    WHERE ps.id = t.project_id
      AND (
        ps.bigtehn_item_id = (
          SELECT i2.id
          FROM public.bigtehn_items_cache i2
          WHERE trim(i2.broj_predmeta) = '9000'
          ORDER BY i2.id
          LIMIT 1
        )
        OR (
          ps.bigtehn_item_id IS NULL
          AND public.pb_normalize_project_code(ps.project_code) = '9000'
        )
      )
  );

CREATE OR REPLACE FUNCTION public.pb_list_projects()
RETURNS TABLE (
  id uuid,
  project_code text,
  project_name text,
  status text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
  SELECT p.id, p.project_code, p.project_name, p.status
  FROM public.projects p
  INNER JOIN production.predmet_aktivacija pa ON pa.predmet_item_id = p.bigtehn_item_id
  WHERE p.bigtehn_item_id IS NOT NULL
    AND pa.je_aktivan IS TRUE
    AND pa.je_projektovanje_montaza IS TRUE
  ORDER BY p.project_code ASC NULLS LAST, p.project_name ASC;
$$;

COMMENT ON FUNCTION public.pb_list_projects() IS
  'Projektni biro: dropdown projekata = predmeti iz cache-a sa aktivacija.je_aktivan AND je_projektovanje_montaza.';

REVOKE ALL ON FUNCTION public.pb_list_projects() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_list_projects() TO authenticated;

-- Plan montaže: work_packages (+ phases.project_id) sa projekta predmeta 9000 → 9400.
-- RN kodovi: 9400/1, 9400/2, … po sort_order; nazivi iz bigtehn_items_cache po šifri, inače Presa 350t / 1000t / 400t za prva tri.
-- Zahteva migraciju pb_projects_from_predmet (pb_normalize_project_code).

DO $$
DECLARE
  v_src uuid;
  v_tgt uuid;
  v_cnt int;
BEGIN
  SELECT p.id INTO v_tgt
  FROM public.projects p
  WHERE p.bigtehn_item_id = (
      SELECT i.id FROM public.bigtehn_items_cache i
      WHERE trim(i.broj_predmeta) = '9400'
      ORDER BY i.id LIMIT 1
    )
  LIMIT 1;

  SELECT p.id INTO v_src
  FROM public.projects p
  WHERE p.bigtehn_item_id = (
      SELECT i.id FROM public.bigtehn_items_cache i
      WHERE trim(i.broj_predmeta) = '9000'
      ORDER BY i.id LIMIT 1
    )
  LIMIT 1;

  IF v_src IS NULL THEN
    SELECT p.id INTO v_src
    FROM public.projects p
    WHERE p.bigtehn_item_id IS NULL
      AND public.pb_normalize_project_code(p.project_code) = '9000'
    ORDER BY p.created_at ASC NULLS FIRST
    LIMIT 1;
  END IF;

  IF v_tgt IS NULL OR v_src IS NULL OR v_src = v_tgt THEN
    RAISE NOTICE 'plan_montaze_wp_merge_9000_9400: preskočeno (src=% tgt=%)', v_src, v_tgt;
    RETURN;
  END IF;

  DROP TABLE IF EXISTS _plan_merge_moved_wp;
  CREATE TEMP TABLE _plan_merge_moved_wp (id uuid PRIMARY KEY) ON COMMIT DROP;

  INSERT INTO _plan_merge_moved_wp (id)
  SELECT wp.id FROM public.work_packages wp WHERE wp.project_id = v_src;

  SELECT COUNT(*)::int INTO v_cnt FROM _plan_merge_moved_wp;
  IF v_cnt = 0 THEN
    RAISE NOTICE 'plan_montaze_wp_merge_9000_9400: nema RN paketa na projektu 9000';
    DROP TABLE IF EXISTS _plan_merge_moved_wp;
    RETURN;
  END IF;

  -- Izbegni jedinstveni konflikt na (project_id, rn_code) na 9400
  UPDATE public.work_packages wp
  SET
    rn_code = wp.rn_code || '__bak_' || left(replace(wp.id::text, '-', ''), 8),
    updated_at = now()
  WHERE wp.project_id = v_tgt
    AND trim(wp.rn_code) IN ('9400/1', '9400/2', '9400/3');

  UPDATE public.work_packages wp
  SET
    project_id = v_tgt,
    updated_at = now()
  WHERE wp.id IN (SELECT id FROM _plan_merge_moved_wp);

  UPDATE public.phases ph
  SET
    project_id = v_tgt,
    updated_at = now()
  WHERE ph.work_package_id IN (SELECT id FROM _plan_merge_moved_wp);

  UPDATE public.work_packages wp
  SET
    rn_code = '9400/' || r.rn::text,
    name = COALESCE(
      NULLIF(trim(COALESCE(ic.naziv_predmeta, '')), ''),
      CASE r.rn
        WHEN 1 THEN 'Presa 350t'
        WHEN 2 THEN 'Presa 1000t'
        WHEN 3 THEN 'Presa 400t'
        ELSE wp.name
      END
    ),
    sort_order = r.rn,
    rn_order = r.rn,
    updated_at = now()
  FROM (
    SELECT
      z.id,
      row_number() OVER (
        ORDER BY z.sort_order NULLS LAST, z.rn_order NULLS LAST, z.created_at NULLS LAST
      ) AS rn
    FROM public.work_packages z
    WHERE z.id IN (SELECT id FROM _plan_merge_moved_wp)
  ) r
  LEFT JOIN public.bigtehn_items_cache ic
    ON trim(ic.broj_predmeta) = ('9400/' || r.rn::text)
  WHERE wp.id = r.id;

  RAISE NOTICE 'plan_montaze_wp_merge_9000_9400: prebačeno % RN paketa 9000→9400', v_cnt;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- PB Engineering Tips (Saveti) — tabele, RLS, Storage, RPC
-- Zavisi od: pb_current_employee_id(), pb_get_mechanical_projecting_engineers(),
--            current_user_is_admin(), update_updated_at(), public.projects
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1) Enum statusa ───────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE public.pb_eng_tip_status AS ENUM ('draft', 'published');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 2) Tabele ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.pb_eng_tip_categories (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  naziv        TEXT NOT NULL UNIQUE,
  slug         TEXT NOT NULL UNIQUE,
  ikona        TEXT,
  boja         TEXT,
  redosled     INTEGER NOT NULL DEFAULT 0,
  je_aktivna   BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.pb_eng_tips (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  naslov        TEXT NOT NULL CHECK (length(naslov) BETWEEN 3 AND 200),
  telo          TEXT NOT NULL CHECK (length(telo) >= 10),
  category_id   UUID REFERENCES public.pb_eng_tip_categories(id) ON DELETE SET NULL,
  tags          TEXT[] NOT NULL DEFAULT '{}',
  vendor        TEXT,
  url           TEXT,
  project_id    UUID REFERENCES public.projects(id) ON DELETE SET NULL,
  status        public.pb_eng_tip_status NOT NULL DEFAULT 'draft',
  author_id     UUID REFERENCES public.employees(id) ON DELETE SET NULL,
  author_email  TEXT,
  likes_count   INTEGER NOT NULL DEFAULT 0 CHECK (likes_count >= 0),
  views_count   INTEGER NOT NULL DEFAULT 0 CHECK (views_count >= 0),
  search_tsv    TSVECTOR,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by    TEXT,
  updated_by    TEXT,
  deleted_at    TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.pb_eng_tip_likes (
  tip_id      UUID NOT NULL REFERENCES public.pb_eng_tips(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL,
  user_email  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (tip_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.pb_eng_tip_files (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tip_id       UUID NOT NULL REFERENCES public.pb_eng_tips(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  file_name    TEXT NOT NULL,
  mime_type    TEXT,
  size_bytes   BIGINT,
  is_image     BOOLEAN GENERATED ALWAYS AS (mime_type LIKE 'image/%') STORED,
  uploaded_by  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.pb_eng_tips IS
  'Projektni biro — baza znanja (saveti inženjera projektovanja).';
COMMENT ON TABLE public.pb_eng_tip_categories IS
  'Fiksne kategorije saveta (admin CRUD u PB Podešavanjima).';

-- ── 3) Indeksi ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS pb_eng_tips_status_idx
  ON public.pb_eng_tips(status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS pb_eng_tips_category_idx
  ON public.pb_eng_tips(category_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS pb_eng_tips_author_idx
  ON public.pb_eng_tips(author_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS pb_eng_tips_created_idx
  ON public.pb_eng_tips(created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS pb_eng_tips_likes_idx
  ON public.pb_eng_tips(likes_count DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS pb_eng_tips_search_idx
  ON public.pb_eng_tips USING GIN (search_tsv);
CREATE INDEX IF NOT EXISTS pb_eng_tips_tags_idx
  ON public.pb_eng_tips USING GIN (tags);
CREATE INDEX IF NOT EXISTS pb_eng_tip_files_tip_idx
  ON public.pb_eng_tip_files(tip_id);
CREATE UNIQUE INDEX IF NOT EXISTS pb_eng_tip_files_storage_path_uidx
  ON public.pb_eng_tip_files(storage_path);

-- ── 4) Triggeri ─────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS pb_eng_tips_updated_at ON public.pb_eng_tips;
CREATE TRIGGER pb_eng_tips_updated_at
  BEFORE UPDATE ON public.pb_eng_tips
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS pb_eng_tip_categories_updated_at ON public.pb_eng_tip_categories;
CREATE TRIGGER pb_eng_tip_categories_updated_at
  BEFORE UPDATE ON public.pb_eng_tip_categories
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE OR REPLACE FUNCTION public.pb_eng_tip_likes_count_sync()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.pb_eng_tips
       SET likes_count = likes_count + 1
     WHERE id = NEW.tip_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.pb_eng_tips
       SET likes_count = GREATEST(0, likes_count - 1)
     WHERE id = OLD.tip_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS pb_eng_tip_likes_count_trg ON public.pb_eng_tip_likes;
CREATE TRIGGER pb_eng_tip_likes_count_trg
  AFTER INSERT OR DELETE ON public.pb_eng_tip_likes
  FOR EACH ROW EXECUTE FUNCTION public.pb_eng_tip_likes_count_sync();

CREATE OR REPLACE FUNCTION public.pb_eng_tips_search_tsv_sync()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.search_tsv :=
    setweight(to_tsvector('simple', coalesce(NEW.naslov, '')), 'A') ||
    setweight(to_tsvector('simple', array_to_string(coalesce(NEW.tags, '{}'::text[]), ' ')), 'B') ||
    setweight(to_tsvector('simple', coalesce(NEW.vendor, '')), 'B') ||
    setweight(to_tsvector('simple', coalesce(NEW.telo, '')), 'C');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS pb_eng_tips_search_tsv_trg ON public.pb_eng_tips;
CREATE TRIGGER pb_eng_tips_search_tsv_trg
  BEFORE INSERT OR UPDATE OF naslov, telo, tags, vendor ON public.pb_eng_tips
  FOR EACH ROW EXECUTE FUNCTION public.pb_eng_tips_search_tsv_sync();

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'audit_row_change'
  ) THEN
    EXECUTE 'DROP TRIGGER IF EXISTS trg_audit_pb_eng_tips ON public.pb_eng_tips';
    EXECUTE 'CREATE TRIGGER trg_audit_pb_eng_tips
      AFTER INSERT OR UPDATE OR DELETE ON public.pb_eng_tips
      FOR EACH ROW EXECUTE FUNCTION public.audit_row_change()';
    EXECUTE 'DROP TRIGGER IF EXISTS trg_audit_pb_eng_tip_categories ON public.pb_eng_tip_categories';
    EXECUTE 'CREATE TRIGGER trg_audit_pb_eng_tip_categories
      AFTER INSERT OR UPDATE OR DELETE ON public.pb_eng_tip_categories
      FOR EACH ROW EXECUTE FUNCTION public.audit_row_change()';
  END IF;
END $$;

-- ── 5) Helperi ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.can_write_pb_eng_tips()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    public.current_user_is_admin()
    OR EXISTS (
      SELECT 1
      FROM public.pb_get_mechanical_projecting_engineers() eng
      WHERE eng.id IS NOT DISTINCT FROM public.pb_current_employee_id()
    );
$$;

COMMENT ON FUNCTION public.can_write_pb_eng_tips() IS
  'PB Saveti — pisanje: admin ili inženjer iz pb_get_mechanical_projecting_engineers().';

REVOKE ALL ON FUNCTION public.can_write_pb_eng_tips() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_write_pb_eng_tips() TO authenticated;

CREATE OR REPLACE FUNCTION public.pb_eng_tip_visible(p_tip_id uuid)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.pb_eng_tips t
    WHERE t.id = p_tip_id
      AND t.deleted_at IS NULL
      AND (
        t.status = 'published'::public.pb_eng_tip_status
        OR public.current_user_is_admin()
        OR t.author_id IS NOT DISTINCT FROM public.pb_current_employee_id()
      )
  );
$$;

REVOKE ALL ON FUNCTION public.pb_eng_tip_visible(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_eng_tip_visible(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.pb_eng_tip_can_manage(p_tip_id uuid)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.pb_eng_tips t
    WHERE t.id = p_tip_id
      AND t.deleted_at IS NULL
      AND (
        public.current_user_is_admin()
        OR t.author_id IS NOT DISTINCT FROM public.pb_current_employee_id()
      )
  );
$$;

REVOKE ALL ON FUNCTION public.pb_eng_tip_can_manage(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_eng_tip_can_manage(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.pb_eng_tip_excerpt(p_telo text, p_len int DEFAULT 240)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT left(
    trim(regexp_replace(
      regexp_replace(coalesce(p_telo, ''), E'```[\\s\\S]*?```', ' ', 'g'),
      E'[#*_`\\[\\]()>~\\-]+', ' ', 'g'
    )),
    p_len
  );
$$;

-- ── 6) RLS ──────────────────────────────────────────────────────────────────
ALTER TABLE public.pb_eng_tips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pb_eng_tip_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pb_eng_tip_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pb_eng_tip_files ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pb_eng_tips_select ON public.pb_eng_tips;
CREATE POLICY pb_eng_tips_select ON public.pb_eng_tips
  FOR SELECT TO authenticated
  USING (
    deleted_at IS NULL
    AND (
      status = 'published'::public.pb_eng_tip_status
      OR public.current_user_is_admin()
      OR author_id IS NOT DISTINCT FROM public.pb_current_employee_id()
    )
  );

DROP POLICY IF EXISTS pb_eng_tips_insert ON public.pb_eng_tips;
CREATE POLICY pb_eng_tips_insert ON public.pb_eng_tips
  FOR INSERT TO authenticated
  WITH CHECK (public.can_write_pb_eng_tips());

DROP POLICY IF EXISTS pb_eng_tips_update ON public.pb_eng_tips;
CREATE POLICY pb_eng_tips_update ON public.pb_eng_tips
  FOR UPDATE TO authenticated
  USING (
    public.current_user_is_admin()
    OR author_id IS NOT DISTINCT FROM public.pb_current_employee_id()
  )
  WITH CHECK (
    public.current_user_is_admin()
    OR author_id IS NOT DISTINCT FROM public.pb_current_employee_id()
  );

DROP POLICY IF EXISTS pb_eng_tips_delete ON public.pb_eng_tips;
CREATE POLICY pb_eng_tips_delete ON public.pb_eng_tips
  FOR DELETE TO authenticated
  USING (public.current_user_is_admin());

DROP POLICY IF EXISTS pb_eng_tip_categories_select ON public.pb_eng_tip_categories;
CREATE POLICY pb_eng_tip_categories_select ON public.pb_eng_tip_categories
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS pb_eng_tip_categories_insert ON public.pb_eng_tip_categories;
CREATE POLICY pb_eng_tip_categories_insert ON public.pb_eng_tip_categories
  FOR INSERT TO authenticated
  WITH CHECK (public.current_user_is_admin());

DROP POLICY IF EXISTS pb_eng_tip_categories_update ON public.pb_eng_tip_categories;
CREATE POLICY pb_eng_tip_categories_update ON public.pb_eng_tip_categories
  FOR UPDATE TO authenticated
  USING (public.current_user_is_admin())
  WITH CHECK (public.current_user_is_admin());

DROP POLICY IF EXISTS pb_eng_tip_categories_delete ON public.pb_eng_tip_categories;
CREATE POLICY pb_eng_tip_categories_delete ON public.pb_eng_tip_categories
  FOR DELETE TO authenticated
  USING (public.current_user_is_admin());

DROP POLICY IF EXISTS pb_eng_tip_likes_select ON public.pb_eng_tip_likes;
CREATE POLICY pb_eng_tip_likes_select ON public.pb_eng_tip_likes
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS pb_eng_tip_likes_insert ON public.pb_eng_tip_likes;
CREATE POLICY pb_eng_tip_likes_insert ON public.pb_eng_tip_likes
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS pb_eng_tip_likes_delete ON public.pb_eng_tip_likes;
CREATE POLICY pb_eng_tip_likes_delete ON public.pb_eng_tip_likes
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS pb_eng_tip_files_select ON public.pb_eng_tip_files;
CREATE POLICY pb_eng_tip_files_select ON public.pb_eng_tip_files
  FOR SELECT TO authenticated
  USING (public.pb_eng_tip_visible(tip_id));

DROP POLICY IF EXISTS pb_eng_tip_files_insert ON public.pb_eng_tip_files;
CREATE POLICY pb_eng_tip_files_insert ON public.pb_eng_tip_files
  FOR INSERT TO authenticated
  WITH CHECK (public.pb_eng_tip_can_manage(tip_id));

DROP POLICY IF EXISTS pb_eng_tip_files_delete ON public.pb_eng_tip_files;
CREATE POLICY pb_eng_tip_files_delete ON public.pb_eng_tip_files
  FOR DELETE TO authenticated
  USING (public.pb_eng_tip_can_manage(tip_id));

REVOKE ALL ON TABLE public.pb_eng_tips FROM PUBLIC;
REVOKE ALL ON TABLE public.pb_eng_tip_categories FROM PUBLIC;
REVOKE ALL ON TABLE public.pb_eng_tip_likes FROM PUBLIC;
REVOKE ALL ON TABLE public.pb_eng_tip_files FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE ON public.pb_eng_tips TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pb_eng_tip_categories TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.pb_eng_tip_likes TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.pb_eng_tip_files TO authenticated;

-- ── 7) Seed kategorija ──────────────────────────────────────────────────────
INSERT INTO public.pb_eng_tip_categories (naziv, slug, ikona, boja, redosled) VALUES
  ('Materijali',   'materijali',   '🧱', '#7c3aed', 10),
  ('Dobavljači',   'dobavljaci',   '🏭', '#0ea5e9', 20),
  ('Mašine',       'masine',       '⚙️', '#f59e0b', 30),
  ('CAD trikovi',  'cad-trikovi',  '🎨', '#10b981', 40),
  ('Algoritmi',    'algoritmi',    '🧮', '#ef4444', 50),
  ('Standardi',    'standardi',    '📐', '#6366f1', 60),
  ('Bezbednost',   'bezbednost',   '🦺', '#dc2626', 70),
  ('Razno',        'razno',        '💡', '#64748b', 99)
ON CONFLICT (slug) DO NOTHING;

-- ── 8) RPC ──────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.pb_list_eng_tips(p_filter jsonb DEFAULT '{}'::jsonb)
RETURNS TABLE (
  id                uuid,
  naslov            text,
  excerpt           text,
  category_id       uuid,
  category_naziv    text,
  category_ikona    text,
  category_boja     text,
  tags              text[],
  vendor            text,
  project_id        uuid,
  project_code      text,
  project_name      text,
  author_id         uuid,
  author_full_name  text,
  status            public.pb_eng_tip_status,
  likes_count       integer,
  views_count       integer,
  files_count       bigint,
  is_liked_by_me    boolean,
  created_at        timestamptz,
  updated_at        timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_search text := nullif(trim(coalesce(p_filter->>'search', '')), '');
  v_sort text := coalesce(nullif(trim(p_filter->>'sort', ''), ''), 'recent');
  v_limit int := LEAST(GREATEST(coalesce((p_filter->>'limit')::int, 100), 1), 500);
  v_offset int := GREATEST(coalesce((p_filter->>'offset')::int, 0), 0);
  v_my_only boolean := coalesce((p_filter->>'my_only')::boolean, false);
  v_include_drafts boolean := coalesce((p_filter->>'include_drafts')::boolean, false);
  v_category_ids uuid[];
  v_tags text[];
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Niste prijavljeni' USING ERRCODE = '42501';
  END IF;

  IF p_filter ? 'category_ids' AND jsonb_typeof(p_filter->'category_ids') = 'array' THEN
    SELECT coalesce(array_agg(x::uuid), '{}')
    INTO v_category_ids
    FROM jsonb_array_elements_text(p_filter->'category_ids') AS t(x)
    WHERE nullif(trim(x), '') IS NOT NULL;
  END IF;

  IF p_filter ? 'tags' AND jsonb_typeof(p_filter->'tags') = 'array' THEN
    SELECT coalesce(array_agg(lower(trim(x))), '{}')
    INTO v_tags
    FROM jsonb_array_elements_text(p_filter->'tags') AS t(x)
    WHERE nullif(trim(x), '') IS NOT NULL;
  END IF;

  RETURN QUERY
  SELECT
    t.id,
    t.naslov,
    public.pb_eng_tip_excerpt(t.telo, 240) AS excerpt,
    t.category_id,
    c.naziv AS category_naziv,
    c.ikona AS category_ikona,
    c.boja AS category_boja,
    t.tags,
    t.vendor,
    t.project_id,
    p.project_code,
    p.project_name,
    t.author_id,
    e.full_name AS author_full_name,
    t.status,
    t.likes_count,
    t.views_count,
    (SELECT count(*)::bigint FROM public.pb_eng_tip_files f WHERE f.tip_id = t.id) AS files_count,
    EXISTS (
      SELECT 1 FROM public.pb_eng_tip_likes l
      WHERE l.tip_id = t.id AND l.user_id = v_uid
    ) AS is_liked_by_me,
    t.created_at,
    t.updated_at
  FROM public.pb_eng_tips t
  LEFT JOIN public.pb_eng_tip_categories c ON c.id = t.category_id
  LEFT JOIN public.projects p ON p.id = t.project_id
  LEFT JOIN public.employees e ON e.id = t.author_id
  WHERE t.deleted_at IS NULL
    AND (
      t.status = 'published'::public.pb_eng_tip_status
      OR (
        v_include_drafts
        AND (
          public.current_user_is_admin()
          OR t.author_id IS NOT DISTINCT FROM public.pb_current_employee_id()
        )
      )
    )
    AND (NOT v_my_only OR t.author_id IS NOT DISTINCT FROM public.pb_current_employee_id())
    AND (v_category_ids IS NULL OR cardinality(v_category_ids) = 0 OR t.category_id = ANY (v_category_ids))
    AND (v_tags IS NULL OR cardinality(v_tags) = 0 OR t.tags && v_tags)
    AND (
      v_search IS NULL
      OR t.search_tsv @@ websearch_to_tsquery('simple', v_search)
    )
  ORDER BY
    CASE WHEN v_search IS NOT NULL THEN ts_rank(t.search_tsv, websearch_to_tsquery('simple', v_search)) END DESC NULLS LAST,
    CASE WHEN v_sort = 'popular' THEN t.likes_count END DESC NULLS LAST,
    t.created_at DESC
  LIMIT v_limit
  OFFSET v_offset;
END;
$$;

CREATE OR REPLACE FUNCTION public.pb_get_eng_tip(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Niste prijavljeni' USING ERRCODE = '42501';
  END IF;
  IF p_id IS NULL THEN
    RAISE EXCEPTION 'id je obavezan' USING ERRCODE = '22023';
  END IF;

  IF NOT public.pb_eng_tip_visible(p_id) THEN
    RAISE EXCEPTION 'Savet nije pronađen' USING ERRCODE = 'P0002';
  END IF;

  BEGIN
    UPDATE public.pb_eng_tips SET views_count = views_count + 1 WHERE id = p_id;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  SELECT jsonb_build_object(
    'id', t.id,
    'naslov', t.naslov,
    'telo', t.telo,
    'category_id', t.category_id,
    'category', CASE WHEN c.id IS NULL THEN NULL ELSE jsonb_build_object(
      'id', c.id, 'naziv', c.naziv, 'slug', c.slug, 'ikona', c.ikona, 'boja', c.boja
    ) END,
    'tags', t.tags,
    'vendor', t.vendor,
    'url', t.url,
    'project_id', t.project_id,
    'project', CASE WHEN p.id IS NULL THEN NULL ELSE jsonb_build_object(
      'id', p.id, 'project_code', p.project_code, 'project_name', p.project_name
    ) END,
    'status', t.status,
    'author_id', t.author_id,
    'author', CASE WHEN e.id IS NULL THEN NULL ELSE jsonb_build_object(
      'id', e.id, 'full_name', e.full_name, 'email', e.email
    ) END,
    'author_email', t.author_email,
    'likes_count', t.likes_count,
    'views_count', t.views_count,
    'is_liked_by_me', EXISTS (
      SELECT 1 FROM public.pb_eng_tip_likes l
      WHERE l.tip_id = t.id AND l.user_id = auth.uid()
    ),
    'created_at', t.created_at,
    'updated_at', t.updated_at,
    'files', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', f.id,
        'file_name', f.file_name,
        'mime_type', f.mime_type,
        'is_image', f.is_image,
        'size_bytes', f.size_bytes,
        'storage_path', f.storage_path
      ) ORDER BY f.created_at)
      FROM public.pb_eng_tip_files f
      WHERE f.tip_id = t.id
    ), '[]'::jsonb)
  )
  INTO v_row
  FROM public.pb_eng_tips t
  LEFT JOIN public.pb_eng_tip_categories c ON c.id = t.category_id
  LEFT JOIN public.projects p ON p.id = t.project_id
  LEFT JOIN public.employees e ON e.id = t.author_id
  WHERE t.id = p_id AND t.deleted_at IS NULL;

  IF v_row IS NULL THEN
    RAISE EXCEPTION 'Savet nije pronađen' USING ERRCODE = 'P0002';
  END IF;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.pb_save_eng_tip(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text := nullif(trim(coalesce(auth.jwt() ->> 'email', '')), '');
  v_author_id uuid := public.pb_current_employee_id();
  v_naslov text;
  v_telo text;
  v_status public.pb_eng_tip_status;
  v_tags text[];
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Niste prijavljeni' USING ERRCODE = '42501';
  END IF;

  v_naslov := nullif(trim(coalesce(p_payload->>'naslov', '')), '');
  v_telo := nullif(trim(coalesce(p_payload->>'telo', '')), '');

  IF v_naslov IS NULL OR length(v_naslov) < 3 OR length(v_naslov) > 200 THEN
    RAISE EXCEPTION 'Naslov mora imati 3–200 karaktera' USING ERRCODE = '22023';
  END IF;
  IF v_telo IS NULL OR length(v_telo) < 10 THEN
    RAISE EXCEPTION 'Telo mora imati najmanje 10 karaktera' USING ERRCODE = '22023';
  END IF;

  IF p_payload ? 'tags' AND jsonb_typeof(p_payload->'tags') = 'array' THEN
    SELECT coalesce(array_agg(DISTINCT nullif(trim(x), '')), '{}')
    INTO v_tags
    FROM jsonb_array_elements_text(p_payload->'tags') AS t(x);
    IF cardinality(v_tags) > 10 THEN
      RAISE EXCEPTION 'Maksimalno 10 tag-ova' USING ERRCODE = '22023';
    END IF;
  ELSE
    v_tags := '{}';
  END IF;

  v_status := coalesce(
    nullif(trim(p_payload->>'status'), '')::public.pb_eng_tip_status,
    'draft'::public.pb_eng_tip_status
  );

  v_id := nullif(trim(coalesce(p_payload->>'id', '')), '')::uuid;

  IF v_id IS NULL THEN
    IF NOT public.can_write_pb_eng_tips() THEN
      RAISE EXCEPTION 'Nemate pravo da kreirate savete' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.pb_eng_tips (
      naslov, telo, category_id, tags, vendor, url, project_id, status,
      author_id, author_email, created_by, updated_by
    ) VALUES (
      v_naslov,
      v_telo,
      nullif(trim(coalesce(p_payload->>'category_id', '')), '')::uuid,
      v_tags,
      nullif(trim(coalesce(p_payload->>'vendor', '')), ''),
      nullif(trim(coalesce(p_payload->>'url', '')), ''),
      nullif(trim(coalesce(p_payload->>'project_id', '')), '')::uuid,
      v_status,
      v_author_id,
      v_email,
      v_email,
      v_email
    )
    RETURNING id INTO v_id;
  ELSE
    IF NOT (
      public.current_user_is_admin()
      OR EXISTS (
        SELECT 1 FROM public.pb_eng_tips t
        WHERE t.id = v_id
          AND t.deleted_at IS NULL
          AND t.author_id IS NOT DISTINCT FROM v_author_id
      )
    ) THEN
      RAISE EXCEPTION 'Nemate pravo da menjate ovaj savet' USING ERRCODE = '42501';
    END IF;

    UPDATE public.pb_eng_tips
    SET
      naslov = v_naslov,
      telo = v_telo,
      category_id = nullif(trim(coalesce(p_payload->>'category_id', '')), '')::uuid,
      tags = v_tags,
      vendor = nullif(trim(coalesce(p_payload->>'vendor', '')), ''),
      url = nullif(trim(coalesce(p_payload->>'url', '')), ''),
      project_id = nullif(trim(coalesce(p_payload->>'project_id', '')), '')::uuid,
      status = v_status,
      updated_by = v_email
  WHERE id = v_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Savet nije pronađen' USING ERRCODE = 'P0002';
    END IF;
  END IF;

  RETURN public.pb_get_eng_tip(v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.pb_soft_delete_eng_tip(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email text := nullif(trim(coalesce(auth.jwt() ->> 'email', '')), '');
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Niste prijavljeni' USING ERRCODE = '42501';
  END IF;
  IF p_id IS NULL THEN
    RAISE EXCEPTION 'id je obavezan' USING ERRCODE = '22023';
  END IF;

  IF NOT public.pb_eng_tip_can_manage(p_id) THEN
    RAISE EXCEPTION 'Nemate pravo da brišete ovaj savet' USING ERRCODE = '42501';
  END IF;

  UPDATE public.pb_eng_tips
  SET deleted_at = now(), updated_by = v_email
  WHERE id = p_id AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Savet nije pronađen' USING ERRCODE = 'P0002';
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.pb_toggle_eng_tip_like(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_email text := nullif(trim(coalesce(auth.jwt() ->> 'email', '')), '');
  v_liked boolean;
  v_count int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Niste prijavljeni' USING ERRCODE = '42501';
  END IF;
  IF p_id IS NULL THEN
    RAISE EXCEPTION 'id je obavezan' USING ERRCODE = '22023';
  END IF;
  IF NOT public.pb_eng_tip_visible(p_id) THEN
    RAISE EXCEPTION 'Savet nije pronađen' USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (SELECT 1 FROM public.pb_eng_tip_likes WHERE tip_id = p_id AND user_id = v_uid) THEN
    DELETE FROM public.pb_eng_tip_likes WHERE tip_id = p_id AND user_id = v_uid;
    v_liked := false;
  ELSE
    INSERT INTO public.pb_eng_tip_likes (tip_id, user_id, user_email)
    VALUES (p_id, v_uid, v_email);
    v_liked := true;
  END IF;

  SELECT likes_count INTO v_count FROM public.pb_eng_tips WHERE id = p_id;
  RETURN jsonb_build_object('liked', v_liked, 'likes_count', coalesce(v_count, 0));
END;
$$;

CREATE OR REPLACE FUNCTION public.pb_add_eng_tip_file(
  p_tip_id uuid,
  p_storage_path text,
  p_file_name text,
  p_mime_type text,
  p_size_bytes bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text := nullif(trim(coalesce(auth.jwt() ->> 'email', '')), '');
  v_cnt bigint;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Niste prijavljeni' USING ERRCODE = '42501';
  END IF;
  IF NOT public.pb_eng_tip_can_manage(p_tip_id) THEN
    RAISE EXCEPTION 'Nemate pravo da dodajete priloge' USING ERRCODE = '42501';
  END IF;
  IF nullif(trim(p_storage_path), '') IS NULL OR nullif(trim(p_file_name), '') IS NULL THEN
    RAISE EXCEPTION 'storage_path i file_name su obavezni' USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_cnt FROM public.pb_eng_tip_files WHERE tip_id = p_tip_id;
  IF v_cnt >= 8 THEN
    RAISE EXCEPTION 'Maksimalno 8 priloga po savetu' USING ERRCODE = '22023';
  END IF;

  IF p_mime_type IS NOT NULL
     AND p_mime_type NOT LIKE 'image/%'
     AND p_mime_type <> 'application/pdf' THEN
    RAISE EXCEPTION 'Dozvoljeni su samo slike i PDF' USING ERRCODE = '22023';
  END IF;

  IF p_size_bytes IS NOT NULL AND p_size_bytes > 5 * 1024 * 1024 THEN
    RAISE EXCEPTION 'Fajl je veći od 5 MB' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.pb_eng_tip_files (
    tip_id, storage_path, file_name, mime_type, size_bytes, uploaded_by
  ) VALUES (
    p_tip_id, trim(p_storage_path), trim(p_file_name), nullif(trim(p_mime_type), ''),
    p_size_bytes, v_email
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'id', v_id,
    'tip_id', p_tip_id,
    'storage_path', trim(p_storage_path),
    'file_name', trim(p_file_name),
    'mime_type', nullif(trim(p_mime_type), ''),
    'size_bytes', p_size_bytes
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.pb_delete_eng_tip_file(p_file_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tip_id uuid;
  v_path text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Niste prijavljeni' USING ERRCODE = '42501';
  END IF;

  SELECT f.tip_id, f.storage_path
  INTO v_tip_id, v_path
  FROM public.pb_eng_tip_files f
  WHERE f.id = p_file_id;

  IF v_tip_id IS NULL THEN
    RAISE EXCEPTION 'Prilog nije pronađen' USING ERRCODE = 'P0002';
  END IF;
  IF NOT public.pb_eng_tip_can_manage(v_tip_id) THEN
    RAISE EXCEPTION 'Nemate pravo da brišete prilog' USING ERRCODE = '42501';
  END IF;

  DELETE FROM public.pb_eng_tip_files WHERE id = p_file_id;
  RETURN jsonb_build_object('ok', true, 'storage_path', v_path);
END;
$$;

CREATE OR REPLACE FUNCTION public.pb_list_eng_tip_categories()
RETURNS SETOF public.pb_eng_tip_categories
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT *
  FROM public.pb_eng_tip_categories
  WHERE je_aktivna IS TRUE
  ORDER BY redosled ASC, naziv ASC;
$$;

CREATE OR REPLACE FUNCTION public.pb_upsert_eng_tip_category(p_payload jsonb)
RETURNS public.pb_eng_tip_categories
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_naziv text;
  v_slug text;
  v_row public.pb_eng_tip_categories;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Niste prijavljeni' USING ERRCODE = '42501';
  END IF;
  IF NOT public.current_user_is_admin() THEN
    RAISE EXCEPTION 'Samo admin' USING ERRCODE = '42501';
  END IF;

  v_naziv := nullif(trim(coalesce(p_payload->>'naziv', '')), '');
  IF v_naziv IS NULL THEN
    RAISE EXCEPTION 'naziv je obavezan' USING ERRCODE = '22023';
  END IF;

  v_slug := nullif(trim(coalesce(p_payload->>'slug', '')), '');
  IF v_slug IS NULL THEN
    v_slug := lower(regexp_replace(regexp_replace(v_naziv, '\s+', '-', 'g'), '[^a-zA-Z0-9\-]+', '', 'g'));
  END IF;

  v_id := nullif(trim(coalesce(p_payload->>'id', '')), '')::uuid;

  IF v_id IS NULL THEN
    INSERT INTO public.pb_eng_tip_categories (naziv, slug, ikona, boja, redosled, je_aktivna)
    VALUES (
      v_naziv,
      v_slug,
      nullif(trim(coalesce(p_payload->>'ikona', '')), ''),
      nullif(trim(coalesce(p_payload->>'boja', '')), ''),
      coalesce((p_payload->>'redosled')::int, 0),
      coalesce((p_payload->>'je_aktivna')::boolean, true)
    )
    RETURNING * INTO v_row;
  ELSE
    UPDATE public.pb_eng_tip_categories
    SET
      naziv = v_naziv,
      slug = v_slug,
      ikona = coalesce(nullif(trim(coalesce(p_payload->>'ikona', '')), ''), ikona),
      boja = coalesce(nullif(trim(coalesce(p_payload->>'boja', '')), ''), boja),
      redosled = coalesce((p_payload->>'redosled')::int, redosled),
      je_aktivna = coalesce((p_payload->>'je_aktivna')::boolean, je_aktivna)
    WHERE id = v_id
    RETURNING * INTO v_row;
  END IF;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.pb_delete_eng_tip_category(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Niste prijavljeni' USING ERRCODE = '42501';
  END IF;
  IF NOT public.current_user_is_admin() THEN
    RAISE EXCEPTION 'Samo admin' USING ERRCODE = '42501';
  END IF;

  DELETE FROM public.pb_eng_tip_categories WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Kategorija nije pronađena' USING ERRCODE = 'P0002';
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.pb_list_eng_tips(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pb_get_eng_tip(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pb_save_eng_tip(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pb_soft_delete_eng_tip(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pb_toggle_eng_tip_like(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pb_add_eng_tip_file(uuid, text, text, text, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pb_delete_eng_tip_file(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pb_list_eng_tip_categories() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pb_upsert_eng_tip_category(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pb_delete_eng_tip_category(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.pb_list_eng_tips(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pb_get_eng_tip(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pb_save_eng_tip(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pb_soft_delete_eng_tip(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pb_toggle_eng_tip_like(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pb_add_eng_tip_file(uuid, text, text, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pb_delete_eng_tip_file(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pb_list_eng_tip_categories() TO authenticated;
GRANT EXECUTE ON FUNCTION public.pb_upsert_eng_tip_category(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pb_delete_eng_tip_category(uuid) TO authenticated;

-- ── 9) Storage bucket ───────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'pb-eng-tip-files',
  'pb-eng-tip-files',
  false,
  5 * 1024 * 1024,
  ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "petf_storage_read" ON storage.objects;
CREATE POLICY "petf_storage_read"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'pb-eng-tip-files');

DROP POLICY IF EXISTS "petf_storage_insert" ON storage.objects;
CREATE POLICY "petf_storage_insert"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'pb-eng-tip-files'
    AND public.pb_eng_tip_can_manage(
      NULLIF(split_part(name, '/', 1), '')::uuid
    )
  );

DROP POLICY IF EXISTS "petf_storage_update" ON storage.objects;
CREATE POLICY "petf_storage_update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'pb-eng-tip-files'
    AND (
      public.current_user_is_admin()
      OR public.pb_eng_tip_can_manage(NULLIF(split_part(name, '/', 1), '')::uuid)
    )
  )
  WITH CHECK (bucket_id = 'pb-eng-tip-files');

DROP POLICY IF EXISTS "petf_storage_delete" ON storage.objects;
CREATE POLICY "petf_storage_delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'pb-eng-tip-files'
    AND (
      public.current_user_is_admin()
      OR public.pb_eng_tip_can_manage(NULLIF(split_part(name, '/', 1), '')::uuid)
      OR owner = auth.uid()
    )
  );

NOTIFY pgrst, 'reload schema';
COMMIT;

-- ============================================================================
-- HARDEN sastanci write RLS (Sprint 1 — H1)
-- ============================================================================
-- Razdvaja stare FOR ALL write politike iz add_sastanci_module.sql i uvodi
-- parent-scope proveru za mutacije nad sastanci child tabelama.
--
-- Bezbedno za re-run: DROP POLICY IF EXISTS pre CREATE POLICY.
-- ============================================================================

-- ─── sastanci ────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "sastanci_write" ON public.sastanci;
DROP POLICY IF EXISTS "sastanci_insert" ON public.sastanci;
DROP POLICY IF EXISTS "sastanci_update" ON public.sastanci;
DROP POLICY IF EXISTS "sastanci_delete" ON public.sastanci;

CREATE POLICY "sastanci_insert" ON public.sastanci
  FOR INSERT TO authenticated
  WITH CHECK (public.has_edit_role());

CREATE POLICY "sastanci_update" ON public.sastanci
  FOR UPDATE TO authenticated
  USING (
    public.current_user_is_management()
    OR LOWER(COALESCE(vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
    OR LOWER(COALESCE(zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
    OR LOWER(COALESCE(created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
  )
  WITH CHECK (
    public.current_user_is_management()
    OR LOWER(COALESCE(vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
    OR LOWER(COALESCE(zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
    OR LOWER(COALESCE(created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
  );

CREATE POLICY "sastanci_delete" ON public.sastanci
  FOR DELETE TO authenticated
  USING (
    public.current_user_is_management()
    OR LOWER(COALESCE(vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
    OR LOWER(COALESCE(zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
    OR LOWER(COALESCE(created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
  );

-- ─── sastanak_ucesnici ──────────────────────────────────────────────────────

DROP POLICY IF EXISTS "su_write" ON public.sastanak_ucesnici;
DROP POLICY IF EXISTS "su_insert" ON public.sastanak_ucesnici;
DROP POLICY IF EXISTS "su_update" ON public.sastanak_ucesnici;
DROP POLICY IF EXISTS "su_delete" ON public.sastanak_ucesnici;

CREATE POLICY "su_insert" ON public.sastanak_ucesnici
  FOR INSERT TO authenticated
  WITH CHECK (
    public.has_edit_role()
    AND (
      public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = sastanak_ucesnici.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  );

CREATE POLICY "su_update" ON public.sastanak_ucesnici
  FOR UPDATE TO authenticated
  USING (
    public.has_edit_role()
    AND (
      public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = sastanak_ucesnici.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  )
  WITH CHECK (
    public.has_edit_role()
    AND (
      public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = sastanak_ucesnici.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  );

CREATE POLICY "su_delete" ON public.sastanak_ucesnici
  FOR DELETE TO authenticated
  USING (
    public.has_edit_role()
    AND (
      public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = sastanak_ucesnici.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  );

-- ─── pm_teme ────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "pmt_write" ON public.pm_teme;
DROP POLICY IF EXISTS "pmt_insert" ON public.pm_teme;
DROP POLICY IF EXISTS "pmt_update" ON public.pm_teme;
DROP POLICY IF EXISTS "pmt_delete" ON public.pm_teme;

CREATE POLICY "pmt_insert" ON public.pm_teme
  FOR INSERT TO authenticated
  WITH CHECK (
    public.has_edit_role()
    AND (
      (sastanak_id IS NULL AND public.current_user_is_management())
      OR (
        sastanak_id IS NOT NULL
        AND (
          public.is_sastanak_ucesnik(sastanak_id)
          OR public.current_user_is_management()
          OR EXISTS (
            SELECT 1
            FROM public.sastanci s
            WHERE s.id = pm_teme.sastanak_id
              AND (
                LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
                OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
                OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
              )
          )
        )
      )
    )
  );

CREATE POLICY "pmt_update" ON public.pm_teme
  FOR UPDATE TO authenticated
  USING (
    public.has_edit_role()
    AND (
      (sastanak_id IS NULL AND public.current_user_is_management())
      OR (
        sastanak_id IS NOT NULL
        AND (
          public.is_sastanak_ucesnik(sastanak_id)
          OR public.current_user_is_management()
          OR EXISTS (
            SELECT 1
            FROM public.sastanci s
            WHERE s.id = pm_teme.sastanak_id
              AND (
                LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
                OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
                OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
              )
          )
        )
      )
    )
  )
  WITH CHECK (
    public.has_edit_role()
    AND (
      (sastanak_id IS NULL AND public.current_user_is_management())
      OR (
        sastanak_id IS NOT NULL
        AND (
          public.is_sastanak_ucesnik(sastanak_id)
          OR public.current_user_is_management()
          OR EXISTS (
            SELECT 1
            FROM public.sastanci s
            WHERE s.id = pm_teme.sastanak_id
              AND (
                LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
                OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
                OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
              )
          )
        )
      )
    )
  );

CREATE POLICY "pmt_delete" ON public.pm_teme
  FOR DELETE TO authenticated
  USING (
    public.has_edit_role()
    AND (
      (sastanak_id IS NULL AND public.current_user_is_management())
      OR (
        sastanak_id IS NOT NULL
        AND (
          public.is_sastanak_ucesnik(sastanak_id)
          OR public.current_user_is_management()
          OR EXISTS (
            SELECT 1
            FROM public.sastanci s
            WHERE s.id = pm_teme.sastanak_id
              AND (
                LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
                OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
                OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
              )
          )
        )
      )
    )
  );

-- ─── akcioni_plan ───────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "ap_write" ON public.akcioni_plan;
DROP POLICY IF EXISTS "ap_insert" ON public.akcioni_plan;
DROP POLICY IF EXISTS "ap_update" ON public.akcioni_plan;
DROP POLICY IF EXISTS "ap_delete" ON public.akcioni_plan;

CREATE POLICY "ap_insert" ON public.akcioni_plan
  FOR INSERT TO authenticated
  WITH CHECK (
    public.has_edit_role()
    AND (
      (sastanak_id IS NULL AND public.current_user_is_management())
      OR public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = akcioni_plan.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  );

CREATE POLICY "ap_update" ON public.akcioni_plan
  FOR UPDATE TO authenticated
  USING (
    public.has_edit_role()
    AND (
      (sastanak_id IS NULL AND public.current_user_is_management())
      OR public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = akcioni_plan.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  )
  WITH CHECK (
    public.has_edit_role()
    AND (
      (sastanak_id IS NULL AND public.current_user_is_management())
      OR public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = akcioni_plan.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  );

CREATE POLICY "ap_delete" ON public.akcioni_plan
  FOR DELETE TO authenticated
  USING (
    public.has_edit_role()
    AND (
      (sastanak_id IS NULL AND public.current_user_is_management())
      OR public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = akcioni_plan.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  );

-- ─── presek_aktivnosti ──────────────────────────────────────────────────────

DROP POLICY IF EXISTS "pa_write" ON public.presek_aktivnosti;
DROP POLICY IF EXISTS "pa_insert" ON public.presek_aktivnosti;
DROP POLICY IF EXISTS "pa_update" ON public.presek_aktivnosti;
DROP POLICY IF EXISTS "pa_delete" ON public.presek_aktivnosti;

CREATE POLICY "pa_insert" ON public.presek_aktivnosti
  FOR INSERT TO authenticated
  WITH CHECK (
    public.has_edit_role()
    AND (
      public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = presek_aktivnosti.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  );

CREATE POLICY "pa_update" ON public.presek_aktivnosti
  FOR UPDATE TO authenticated
  USING (
    public.has_edit_role()
    AND (
      public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = presek_aktivnosti.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  )
  WITH CHECK (
    public.has_edit_role()
    AND (
      public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = presek_aktivnosti.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  );

CREATE POLICY "pa_delete" ON public.presek_aktivnosti
  FOR DELETE TO authenticated
  USING (
    public.has_edit_role()
    AND (
      public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = presek_aktivnosti.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  );

-- ─── presek_slike ───────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "ps_write" ON public.presek_slike;
DROP POLICY IF EXISTS "ps_insert" ON public.presek_slike;
DROP POLICY IF EXISTS "ps_update" ON public.presek_slike;
DROP POLICY IF EXISTS "ps_delete" ON public.presek_slike;

CREATE POLICY "ps_insert" ON public.presek_slike
  FOR INSERT TO authenticated
  WITH CHECK (
    public.has_edit_role()
    AND (
      public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = presek_slike.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  );

CREATE POLICY "ps_update" ON public.presek_slike
  FOR UPDATE TO authenticated
  USING (
    public.has_edit_role()
    AND (
      public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = presek_slike.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  )
  WITH CHECK (
    public.has_edit_role()
    AND (
      public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = presek_slike.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  );

CREATE POLICY "ps_delete" ON public.presek_slike
  FOR DELETE TO authenticated
  USING (
    public.has_edit_role()
    AND (
      public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = presek_slike.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  );

-- ─── sastanak_arhiva ────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "sa_write" ON public.sastanak_arhiva;
DROP POLICY IF EXISTS "sa_insert" ON public.sastanak_arhiva;
DROP POLICY IF EXISTS "sa_update" ON public.sastanak_arhiva;
DROP POLICY IF EXISTS "sa_delete" ON public.sastanak_arhiva;

CREATE POLICY "sa_insert" ON public.sastanak_arhiva
  FOR INSERT TO authenticated
  WITH CHECK (
    public.has_edit_role()
    AND (
      public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = sastanak_arhiva.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  );

CREATE POLICY "sa_update" ON public.sastanak_arhiva
  FOR UPDATE TO authenticated
  USING (
    public.has_edit_role()
    AND (
      public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = sastanak_arhiva.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  )
  WITH CHECK (
    public.has_edit_role()
    AND (
      public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = sastanak_arhiva.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  );

CREATE POLICY "sa_delete" ON public.sastanak_arhiva
  FOR DELETE TO authenticated
  USING (
    public.has_edit_role()
    AND (
      public.is_sastanak_ucesnik(sastanak_id)
      OR public.current_user_is_management()
      OR EXISTS (
        SELECT 1
        FROM public.sastanci s
        WHERE s.id = sastanak_arhiva.sastanak_id
          AND (
            LOWER(COALESCE(s.vodio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.zapisnicar_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
            OR LOWER(COALESCE(s.created_by_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
          )
      )
    )
  );

NOTIFY pgrst, 'reload schema';

-- Deployed: 2026-05-03
-- Zamenjuje write politike iz: add_sastanci_module.sql (lines 346-379)
-- Vidi: docs/audit/sastanci-audit-2026-05-03.md H1

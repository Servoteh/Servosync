-- ============================================================================
-- Supabase: isti sadrzaj kao sql/migrations/add_maint_it_asset_details.sql
-- ============================================================================

-- ============================================================================
-- ODRŽAVANJE (CMMS) — detalji za IT opremu
-- ============================================================================
-- MORA posle:
--   * add_maint_assets_supertable.sql
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.maint_it_asset_details (
  asset_id          UUID PRIMARY KEY REFERENCES public.maint_assets (asset_id) ON DELETE CASCADE,
  device_type       TEXT,
  hostname          TEXT,
  ip_address        INET,
  mac_address       TEXT,
  operating_system  TEXT,
  assigned_to       TEXT,
  license_key       TEXT,
  license_expires_at DATE,
  warranty_expires_at DATE,
  backup_required   BOOLEAN NOT NULL DEFAULT false,
  last_backup_at    TIMESTAMPTZ,
  notes             TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by        UUID REFERENCES auth.users (id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_maint_it_asset_hostname
  ON public.maint_it_asset_details (lower(hostname))
  WHERE hostname IS NOT NULL AND length(trim(hostname)) > 0;

CREATE INDEX IF NOT EXISTS idx_maint_it_asset_license_due
  ON public.maint_it_asset_details (license_expires_at);

CREATE INDEX IF NOT EXISTS idx_maint_it_asset_warranty_due
  ON public.maint_it_asset_details (warranty_expires_at);

DROP TRIGGER IF EXISTS maint_it_asset_details_touch_updated ON public.maint_it_asset_details;
CREATE TRIGGER maint_it_asset_details_touch_updated
  BEFORE UPDATE ON public.maint_it_asset_details
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE OR REPLACE FUNCTION public.maint_it_asset_details_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.maint_assets a
    WHERE a.asset_id = NEW.asset_id
      AND a.asset_type = 'it'::public.maint_asset_type
  ) THEN
    RAISE EXCEPTION 'maint_it_asset_details.asset_id must reference an IT asset'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS maint_it_asset_details_guard_biu ON public.maint_it_asset_details;
CREATE TRIGGER maint_it_asset_details_guard_biu
  BEFORE INSERT OR UPDATE ON public.maint_it_asset_details
  FOR EACH ROW EXECUTE FUNCTION public.maint_it_asset_details_guard();

ALTER TABLE public.maint_it_asset_details ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS maint_it_asset_details_select ON public.maint_it_asset_details;
CREATE POLICY maint_it_asset_details_select ON public.maint_it_asset_details
  FOR SELECT USING (public.maint_asset_visible(asset_id));

DROP POLICY IF EXISTS maint_it_asset_details_insert ON public.maint_it_asset_details;
CREATE POLICY maint_it_asset_details_insert ON public.maint_it_asset_details
  FOR INSERT WITH CHECK (
    public.maint_asset_visible(asset_id)
    AND (
      public.maint_is_erp_admin_or_management()
      OR public.maint_profile_role() IN ('chief', 'admin')
    )
  );

DROP POLICY IF EXISTS maint_it_asset_details_update ON public.maint_it_asset_details;
CREATE POLICY maint_it_asset_details_update ON public.maint_it_asset_details
  FOR UPDATE USING (
    public.maint_asset_visible(asset_id)
    AND (
      public.maint_is_erp_admin_or_management()
      OR public.maint_profile_role() IN ('chief', 'admin')
    )
  )
  WITH CHECK (public.maint_asset_visible(asset_id));

GRANT SELECT, INSERT, UPDATE ON public.maint_it_asset_details TO authenticated;
GRANT EXECUTE ON FUNCTION public.maint_it_asset_details_guard() TO authenticated;

COMMIT;

-- ============================================================================
-- CI ONLY — minimal Supabase Storage stub (plain Postgres u GitHub Actions)
-- ============================================================================
-- Produkcioni Supabase već ima šemu storage.*; ovaj fajl se primenjuje samo u
-- CI pre migracija koje rade INSERT u storage.buckets / CREATE POLICY na
-- storage.objects.
-- ============================================================================

\set ON_ERROR_STOP 1

CREATE SCHEMA IF NOT EXISTS storage;

CREATE TABLE IF NOT EXISTS storage.buckets (
  id                   TEXT PRIMARY KEY,
  name                 TEXT NOT NULL,
  public               BOOLEAN NOT NULL DEFAULT false,
  file_size_limit      BIGINT,
  allowed_mime_types   TEXT[]
);

CREATE TABLE IF NOT EXISTS storage.objects (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_id   TEXT NOT NULL,
  name        TEXT NOT NULL
);

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

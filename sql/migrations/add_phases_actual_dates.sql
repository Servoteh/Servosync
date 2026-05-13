-- Migracija: dodavanje kolona ostvarenih datuma na tabelu phases
-- DRAFT — ne izvršavati bez potvrde korisnika u Supabase Studio
-- Datum: 2026-05-13

ALTER TABLE phases
  ADD COLUMN IF NOT EXISTS actual_start_date date,
  ADD COLUMN IF NOT EXISTS actual_end_date date;

COMMENT ON COLUMN phases.actual_start_date IS 'Automatski upisuje se kada faza pređe u status U toku';
COMMENT ON COLUMN phases.actual_end_date   IS 'Automatski upisuje se kada faza pređe u status Završeno';

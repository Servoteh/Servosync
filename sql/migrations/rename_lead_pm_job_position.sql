-- Skraćen naziv radnog mesta u katalogu org strukture + Milan Stojadinović (employees).
-- Idempotentno: bez greške ako su vrednosti već ažurirane.

UPDATE public.job_positions
SET name = 'LEAD PM'
WHERE name = 'Viši projekt menadžer (Lead PM)';

UPDATE public.employees
SET position = 'LEAD PM'
WHERE full_name IN ('Stojadinovic Milan', 'Stojadinović Milan')
  AND position IN ('Glavni Projekt Menadzer', 'Viši projekt menadžer (Lead PM)');

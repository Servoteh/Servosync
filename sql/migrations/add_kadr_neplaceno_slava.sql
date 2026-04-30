-- ═══════════════════════════════════════════════════════════════════════
-- KADROVSKA — Neplaćeno odsustvo + Slava + grid kod 'nop' (Faza K3.4)
--
-- Šta radi:
--   1) absences.slobodan_reason — dodaje 'slava' u CHECK constraint
--   2) work_hours.absence_code  — dodaje 'nop' u CHECK constraint
--
-- Stanje pre ove migracije (citirano iz prethodnih migracija):
--
-- absences.type — constraint absences_type_check_v2 (add_kadr_employee_extended.sql):
--   CHECK (type IN ('godisnji','bolovanje','slobodan','placeno',
--                   'neplaceno','sluzbeno','slava','ostalo'))
--   → 'neplaceno' VEĆ POSTOJI od phase1 i extended. Bez izmena na type CHECK.
--
-- absences.slobodan_reason — constraint absences_slobodan_reason_chk (add_kadr_absence_subtype.sql):
--   CHECK (slobodan_reason IS NULL
--          OR slobodan_reason IN ('brak','rodjenje_deteta','selidba',
--                                 'smrt_clana_porodice',
--                                 'dobrovoljno_davanje_krvi','ostalo'))
--   → DODAJEMO 'slava' pre 'ostalo'.
--
-- work_hours.absence_code — constraint work_hours_absence_code_check_v2 (add_kadr_employee_extended.sql):
--   CHECK (absence_code IS NULL
--          OR absence_code IN ('go','bo','sp','np','sl','pr','sv','pl'))
--   → DODAJEMO 'nop' (neplaćeno odsustvo; sati=0, dan se ne plaća).
--
-- RLS: bez izmena — has_edit_role() na absences i work_hours već pokriva
--       novi tip i novi absence_code.
--
-- Depends on: add_kadr_employee_extended.sql, add_kadr_absence_subtype.sql
-- Aditivno, idempotentno, safe za re-run.
-- ═══════════════════════════════════════════════════════════════════════

-- Pre apply-a — proveri postojeće vrednosti (ručno, ne pukne ništa):
-- SELECT DISTINCT type FROM public.absences ORDER BY type;
-- SELECT DISTINCT slobodan_reason FROM public.absences WHERE slobodan_reason IS NOT NULL ORDER BY slobodan_reason;
-- SELECT DISTINCT absence_code FROM public.work_hours WHERE absence_code IS NOT NULL ORDER BY absence_code;

-- ─── 1) absences.slobodan_reason — dodaj 'slava' ──────────────────────────
-- Stare vrednosti: brak, rodjenje_deteta, selidba, smrt_clana_porodice,
--                  dobrovoljno_davanje_krvi, ostalo
-- Nova lista: + slava

ALTER TABLE public.absences DROP CONSTRAINT IF EXISTS absences_slobodan_reason_chk;
ALTER TABLE public.absences
  ADD CONSTRAINT absences_slobodan_reason_chk
  CHECK (slobodan_reason IS NULL
         OR slobodan_reason IN ('brak','rodjenje_deteta','selidba',
                                'smrt_clana_porodice',
                                'dobrovoljno_davanje_krvi','slava','ostalo'));

-- ─── 2) work_hours.absence_code — dodaj 'nop' ─────────────────────────────
-- Stare vrednosti: go, bo, sp, np, sl, pr, sv, pl
-- Nova lista: + nop (neplaćeno odsustvo; hours=0, dan se ne plaća)

ALTER TABLE public.work_hours DROP CONSTRAINT IF EXISTS work_hours_absence_code_check_v2;
ALTER TABLE public.work_hours
  ADD CONSTRAINT work_hours_absence_code_check_v3
  CHECK (absence_code IS NULL
         OR absence_code IN ('go','bo','sp','np','sl','pr','sv','pl','nop'));

-- ─── 3) Dokumentacioni komentari ──────────────────────────────────────────
COMMENT ON COLUMN public.absences.slobodan_reason IS
  'Razlog slobodnog plaćenog dana (tip=slobodan): brak | rodjenje_deteta | selidba | smrt_clana_porodice | dobrovoljno_davanje_krvi | slava | ostalo.';

COMMENT ON COLUMN public.work_hours.absence_code IS
  'Šifra odsustva u mesečnom gridu: go=godišnji | bo=bolovanje | sp=slobodan/plaćeni praznik | np=neplaćeno-legacy | sl=slobodan dan | pr=praznik | sv=slava | pl=plaćeno | nop=neplaćeno odsustvo (odobreno; sati=0, dan se ne plaća).';

-- ─── VERIFIKACIJA (ručno pokreni posle apply-a) ────────────────────────────
-- Proveri constraint-e:
-- SELECT conname, pg_get_constraintdef(oid)
--   FROM pg_constraint
--  WHERE conrelid IN ('public.absences'::regclass, 'public.work_hours'::regclass)
--    AND conname IN ('absences_slobodan_reason_chk', 'work_hours_absence_code_check_v3');
--
-- Test INSERT-ovi (zameni <uuid> validnim employee_id):
-- INSERT INTO public.absences(employee_id, type, date_from, date_to, days_count)
--   VALUES ('<uuid>', 'neplaceno', '2026-05-01', '2026-05-03', 3);
--
-- INSERT INTO public.absences(employee_id, type, slobodan_reason, date_from, date_to, days_count)
--   VALUES ('<uuid>', 'slobodan', 'slava', '2026-05-10', '2026-05-10', 1);
--
-- UPDATE public.work_hours
--    SET absence_code='nop', hours=0, overtime_hours=0, field_hours=0, two_machine_hours=0
--  WHERE employee_id='<uuid>' AND work_date='2026-05-15';
--
-- Ove INSERT/UPDATE ne smeju baciti grešku — ako bace, apply nije uspeo.

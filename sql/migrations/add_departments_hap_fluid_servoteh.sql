-- ═══════════════════════════════════════════════════════════════════════
-- Dodata odeljenja: HAP Fluid, Servoteh (usklađeno sa employees.department)
--
-- Primeni posle add_kadr_org_structure.sql (ili koristi samo
-- supabase/migrations/20260430160000__departments_hap_fluid_servoteh.sql).
-- Idempotentno (ON CONFLICT DO NOTHING na id).
-- ═══════════════════════════════════════════════════════════════════════

INSERT INTO public.departments (id, name, sort_order)
VALUES
  (12, 'HAP Fluid', 108),
  (13, 'Servoteh',  109)
ON CONFLICT (id) DO NOTHING;

SELECT setval(
  'public.departments_id_seq',
  GREATEST(
    (SELECT COALESCE(MAX(id), 1) FROM public.departments),
    (SELECT last_value FROM public.departments_id_seq)
  )
);

UPDATE public.employees e
SET department_id = d.id, updated_at = now()
FROM public.departments d
WHERE e.department_id IS NULL
  AND btrim(e.department) = 'HAP Fluid'
  AND d.id = 12;

UPDATE public.employees e
SET department_id = d.id, updated_at = now()
FROM public.departments d
WHERE e.department_id IS NULL
  AND btrim(e.department) = 'Servoteh'
  AND d.id = 13;

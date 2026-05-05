-- Izveštaj: ime, prezime, odeljenje, pododeljenje, radno mesto, aktivan, id
-- Izvor: employees + departments / sub_departments / job_positions (migracija add_kadr_org_structure.sql)
-- Pokreni u Supabase SQL Editor; rezultat eksportuj kao CSV ili kopiraj u Excel.
--
-- Za TSV (tabulator): u rezultatu koristi Copy pa u Excelu „Zalepi”, ili u psql:
--   \copy (SELECT ...) TO 'employees.tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, ENCODING 'UTF8');

SELECT
  COALESCE(NULLIF(TRIM(e.first_name), ''), split_part(e.full_name, ' ', 1), '') AS ime,
  COALESCE(
    NULLIF(TRIM(e.last_name), ''),
    NULLIF(trim(regexp_replace(e.full_name, E'^\\S+\\s*', '')), ''),
    ''
  ) AS prezime,
  COALESCE(d.name, NULLIF(TRIM(e.department), ''), '') AS odeljenje,
  COALESCE(sd.name, '') AS pododeljenje,
  COALESCE(jp.name, NULLIF(TRIM(e.position), ''), '') AS radno_mesto,
  CASE WHEN e.is_active THEN 'da' ELSE 'ne' END AS aktivan,
  e.id::text AS employee_id
FROM public.employees e
LEFT JOIN public.departments d ON d.id = e.department_id
LEFT JOIN public.sub_departments sd ON sd.id = e.sub_department_id
LEFT JOIN public.job_positions jp ON jp.id = e.position_id
ORDER BY odeljenje, pododeljenje, prezime, ime;

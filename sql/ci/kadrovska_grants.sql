-- GRANT-ovi za pgTAP (authenticated + RLS). Posle Kadrovska DDL migracija.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.absences TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vacation_entitlements TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vacation_requests TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.employee_children TO authenticated;

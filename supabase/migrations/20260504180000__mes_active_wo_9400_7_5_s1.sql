-- MES: aktiviraj RN 9400/7-5-S1 varijanta 1 u ručnoj listi (production_active_work_orders).
-- Work order id iz bigtehn_work_orders_cache za ident_broj = '9400/7-5-S1' AND varijanta = 1.
-- Idempotentno: ON CONFLICT ažurira is_active.

INSERT INTO public.production_active_work_orders (work_order_id, is_active, reason, source)
SELECT w.id,
       true,
       'MES aktivacija: 9400/7-5-S1 (varijanta 1) — skener / lokacije',
       'migration_mes_active_9400_7_5_s1'
FROM public.bigtehn_work_orders_cache w
WHERE w.ident_broj = '9400/7-5-S1'
  AND w.varijanta = 1
LIMIT 1
ON CONFLICT (work_order_id) DO UPDATE SET
  is_active = true,
  reason    = EXCLUDED.reason,
  source    = EXCLUDED.source,
  updated_at = now();

-- ============================================================================
-- SASTANCI — proširenje vrednosti kolone `tip` (tematski, dnevni)
-- ============================================================================
-- Idempotentno: DROP + ADD constraint po imenu.
-- Preduslov: tabela public.sastanci (add_sastanci_module.sql).
-- ============================================================================

ALTER TABLE public.sastanci DROP CONSTRAINT IF EXISTS sastanci_tip_check;

ALTER TABLE public.sastanci
  ADD CONSTRAINT sastanci_tip_check
  CHECK (tip IN ('sedmicni', 'projektni', 'tematski', 'dnevni'));

COMMENT ON COLUMN public.sastanci.tip IS
  'sedmicni | projektni | tematski (npr. biro+tehnologija) | dnevni (operativa/proizvodnja)';

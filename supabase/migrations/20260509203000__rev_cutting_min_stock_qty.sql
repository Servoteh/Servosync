-- Minimalna željena zaliha po šifri (Rezni alat — upozorenje u UI).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'rev_cutting_tool_catalog'
      AND column_name = 'min_stock_qty'
  ) THEN
    ALTER TABLE public.rev_cutting_tool_catalog
      ADD COLUMN min_stock_qty integer NOT NULL DEFAULT 0;
  END IF;
END $$;

COMMENT ON COLUMN public.rev_cutting_tool_catalog.min_stock_qty IS
  'Minimalna željena ukupna zaliha (magacin + mašine); UI prikazuje upozorenje kada je zbir ispod.';

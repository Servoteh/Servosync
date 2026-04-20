-- ============================================================================
-- ODRŽAVANJE — priprema za kanal notifikacija (WhatsApp Business Cloud API)
-- ============================================================================
-- Kontekst: Telegram je PAUZIRAN odlukom korisnika. U ovoj fazi samo proširujemo
-- enum kanala da u budućoj iteraciji prihvati 'whatsapp' bez menjanja šeme.
--
-- Ne kreira Edge Function, ne šalje poruke. Samo priprema bazu.
--
-- Pokreni u Supabase SQL Editoru (idempotentno).
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_enum e ON e.enumtypid = t.oid
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'maint_notification_channel'
      AND e.enumlabel = 'whatsapp'
  ) THEN
    ALTER TYPE public.maint_notification_channel ADD VALUE 'whatsapp';
  END IF;
END $$;

COMMENT ON COLUMN public.maint_notification_log.channel IS
  'telegram (pauzirano), email, in_app, whatsapp (planirano preko WhatsApp Business Cloud API).';

-- ═══════════════════════════════════════════════════════════
-- Migration: add `description` column to phases table
-- ═══════════════════════════════════════════════════════════
-- Dodaje detaljan opis onoga što faza montaže obuhvata
-- (opisno polje koje se otvara u posebnom dijalogu preko
--  dugmeta "Opis" ispod naziva faze u tabeli/mob. karticama).
--
-- Safe to run multiple times (idempotent).
-- Backward compatible: postojeći redovi imaju NULL → UI prikazuje prazno.
-- Klijent (services/projects.js) ima schema-support fallback — ako
-- kolona ne postoji, opisi se samo ne snimaju u DB već ostaju lokalno.
-- ═══════════════════════════════════════════════════════════

ALTER TABLE phases
  ADD COLUMN IF NOT EXISTS description TEXT;

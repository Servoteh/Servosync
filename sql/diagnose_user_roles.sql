-- ═══════════════════════════════════════════════════════════
-- Dijagnostika: zašto ulogovan korisnik ostaje VIEWER
-- Zameni <USER_EMAIL> stvarnim emailom iz Auth (npr. iz CURRENT USER RAW u konzoli).
-- Izvršavaj u Supabase SQL Editoru (service role / postgres vidi sve; običan korisnik vidi ono što RLS dozvoli).
-- ═══════════════════════════════════════════════════════════

-- A) Da li postoji red u tabeli (bez RLS — zavisi od uloge u SQL editoru)
select email, role, is_active, project_id
from public.user_roles
where lower(trim(email)) = lower(trim('<USER_EMAIL>'));

-- B) Da li je RLS uključen na tabeli
select relname, relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = 'user_roles';

-- C) Postojeće policies na user_roles
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where tablename = 'user_roles'
order by policyname;

-- D) Primer SELECT policy: authenticated vidi samo svoj red po email-u iz JWT-a
-- PAŽNJA: proveri u (C) da li već postoji policy koja suzi ili blokira SELECT.
-- Ako postoji "roles_select" sa USING (true), svi authenticated vide sve redove — ovaj policy nije neophodan.
-- Ako SELECT vraća 0 redova iz klijenta, često treba policy tipa:

-- create policy "user can read own role by email"
-- on public.user_roles
-- for select
-- to authenticated
-- using (lower(trim(email)) = lower(trim(auth.jwt() ->> 'email')));

-- Pre kreiranja: DROP POLICY IF EXISTS "user can read own role by email" ON public.user_roles;

-- Brza provera podataka (skriveni razmaci / dužina stringa)
select
  email,
  length(email) as email_len,
  role,
  length(role::text) as role_len,
  is_active,
  project_id
from public.user_roles
where lower(trim(email)) = lower(trim('<USER_EMAIL>'));

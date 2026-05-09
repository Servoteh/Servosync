-- GoTrue /recover i slični pozivi padaju sa:
--   converting NULL to string is unsupported (kolona email_change)
-- kada su korisnici ubačeni direktno u auth.users (SQL) bez praznih stringova.
-- Idempotentno: ostavi postojeće vrednosti, NULL → ''.

UPDATE auth.users
SET email_change = COALESCE(email_change, '')
WHERE email_change IS NULL;

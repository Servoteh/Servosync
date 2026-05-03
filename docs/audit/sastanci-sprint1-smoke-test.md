# Sastanci Sprint 1 — smoke test posle deploy-a

Datum: 2026-05-03

Pokrenuti nakon ručne primene migracija:

1. Kao korisnik bez edit role: pokušaj `POST /rest/v1/akcioni_plan`.
   - Očekivano: `403` ili prazan rezultat.

2. Kao editor koji NIJE učesnik sastanka: pokušaj `PATCH` na `akcioni_plan` tog sastanka.
   - Očekivano: `403` ili `0` redova affected.

3. Kao editor koji JESTE učesnik: `INSERT` u `akcioni_plan`.
   - Očekivano: upis prolazi.

4. Zaključaj jedan test sastanak (`status = 'zakljucan'`) direktno u Supabase Studio ili SQL; kao editor pokušaj `INSERT` u `presek_aktivnosti`.
   - Očekivano: exception sa tekstom `Sastanak je zaključan.`

5. Kao management korisnik: isti `INSERT` na zaključan sastanak.
   - Očekivano: upis prolazi.

6. Pokreni pgTAP testove:

   ```bash
   pg_prove -U postgres sql/tests/security_sastanci_rls.sql
   ```

   Očekivano: svi testovi prolaze.

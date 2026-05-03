# Sastanci Sprint 2+3 — smoke test posle deploy-a

Datum: 2026-05-03

Pokrenuti nakon ručne primene migracija:

## Sprint 2 testovi

1. Zaključaj sastanak kroz UI.
   - Očekivano: u Supabase Studio postoji tačno jedan red u `sastanak_arhiva` za taj sastanak i `sastanci.status = 'zakljucan'`.

2. Pokušaj ponovo zaključati isti sastanak.
   - Očekivano: RPC vraća `already_locked`; nema tihog uspeha i nema duplog arhiva reda. Trenutni UI prikazuje generičku grešku ako korisnik ponovo pritisne zaključavanje.

3. Dodaj učesnika dva puta na isti sastanak.
   - Očekivano: `sastanak_ucesnici` nema dupli red; kompozitni PK `(sastanak_id, email)` brani duplikat.

4. Okini isti event koji generiše notifikaciju dva puta (npr. isti status update).
   - Očekivano: `sastanci_notification_log` ima samo jedan `queued`/`sent` red za isti event i recipijenta.

5. U `saveUcesnici` simuliraj grešku na DELETE (privremeno kroz RLS ili test sa nedozvoljenim korisnikom).
   - Očekivano: INSERT novih učesnika se ne izvršava posle neuspelog DELETE koraka.

## Sprint 3 testovi

6. Otvori Network tab u browseru i proveri listu sastanaka.
   - Očekivano: query više ne traži `select=*`; vraćaju se samo kolone koje servis mapira.

7. Proveri lower() indekse u Supabase Studio:

   ```sql
   SELECT indexname
   FROM pg_indexes
   WHERE schemaname = 'public'
     AND tablename = 'sastanci'
     AND indexdef ILIKE '%lower%';
   ```

   Očekivano: postoje 3 nova indeksa za `vodio_email`, `zapisnicar_email`, `created_by_email`.

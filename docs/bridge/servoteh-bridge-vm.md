# Servoteh Bridge VM — pristup i radna kopija

Ovaj dokument opisuje **gde se na mreži nalazi mašina na kojoj radi eksterni BigTehn → Supabase bridge** i **gde je lokalni klon repoa** koji se koristi za skripte (npr. backfill Planiranja proizvodnje). Ne sadrži lozinke ni tajne.

## Mašina

| Stavka | Vrednost |
|--------|----------|
| Uloga | Host za bridge sync (MSSQL → Supabase) i srodne node skripte |
| Lokalna IP adresa (LAN) | `192.168.64.24` |
| Glavni korisni nalog (operativno) | Nenad Jarakovic |
| Pristup | Tipično **Remote Desktop (RDP)** sa računara u istoj LAN mreži ili preko postojećeg **VPN** do mreže gde je ova adresa ruta. Tačan RDP domen/ime i grupna politika zavise od IT-a — ako RDP nije otvoren, otvorite ticket za pristup. |

**Bezbednost:** ova mašina drži pristup MSSQL-u i (u `.env` skriptama) `SUPABASE_SERVICE_ROLE_KEY`. Ne sme biti izložena javnom internetu bez stroge zaštite; preporučeno je pristup samo iz odobrene mreže + jaka autentikacija.

## Repo na VM-u (servoteh-bridge)

| Stavka | Vrednost |
|--------|----------|
| Folder na disku | `C:\servoteh\servoteh-bridge` |
| Svrha | Radna kopija repoa gde se nalaze `package.json`, skripte (npr. `scripts/backfill-production-cache.js` nakon `git pull`), i `.env` sa konekcionim stringovima. |

**Tipičan tok nakon RDP logina:**

1. Otvoriti PowerShell ili Command Prompt.
2. `cd C:\servoteh\servoteh-bridge`
3. `git pull` (povući poslednje izmene)
4. `npm install` (samo kada se promene zavisnosti)
5. Pokretanje backfill / bridge komandi koje su dokumentovane u tom repou (npr. `npm run backfill:production` za Planiranje proizvodnje, ako postoji u `package.json`).

Napomena: identičan izvor skripte postoji i u monorepu `servoteh-plan-montaze` pod `workers/loc-sync-mssql/`; na VM-u se koristi ona kopija koju održavate u `servoteh-bridge` nakon `git pull`.

## Šta povezati ako nešto ne radi

- **Mreža:** sa klijentskog računara, `ping 192.168.64.24` (samo provera dostupnosti; ako ne ide, problem je LAN/VPN/firewall).
- **MSSQL:** bridge skripte očekuju da `MSSQL_HOST` (ili ekvivalent u `.env`) bude dostižan sa ove mašine.
- **Supabase:** HTTPS mora biti otvoren sa VM-a; greške u logu `upsert` / `rpc` obično znače key, URL ili RLS/permisiju na Supabase strani.
- **Aplikacija u browseru i dalje ne vidi G4/G6** dok se ne pozove backfill posle deploy-a, jer prazne cache tabele ne mogu da prikažu signale u UI.

## Povezani dokumen u ovom repou

- Opšti kontekst bridge-a: [01-current-state.md](./01-current-state.md)

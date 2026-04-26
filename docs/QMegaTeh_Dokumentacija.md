# QMegaTeh / QBigTehn — Tehnička dokumentacija aplikacije

**Klijent:** Servoteh
**Vendor:** identifikatori u kodu su `BIT CO.` i workgroup ID `BIGBIT224163`
**Aplikacija:** QMegaTeh (kratko ime), interno čuvana kao QBigTehn (front-end)
**Backend baza:** SQL Server `Vasa-SQL,5765`, baza `QBigTehn`
**Front-end:** MS Access 2010 (Jet 4.0 / `.mdb`, AccessVersion 09.50)
**Dokumentovani build:** 1134, ProjVer 119
**Datum dokumentacije:** april 2026
**Autor dokumentacije:** rekonstruisano iz dekompilovanog VBA koda (92.633 linije, 454 modula) i SQL definicija (404 upita) nakon skidanja workgroup zaštite (ULS) i VBA project password-a

---

## 0. Predgovor — zašto ova dokumentacija postoji i kome je namenjena

Ova dokumentacija je naknadna rekonstrukcija. Nije pisana kad je aplikacija pravljena, nego naknadno — iz izvornog koda nakon što je vendor (BIT CO.) prestao da daje podršku, a Servoteh kao vlasnik imao legitiman interes da razume i sačuva sopstveni poslovni sistem pre eventualnog gašenja, migracije ili replatformizacije.

Ciljana publika su:

- developeri koji treba da održavaju aplikaciju u sledećoj fazi (bug-fixing, sitne izmene)
- developeri koji treba da je **zamene** novim sistemom (Web/Cloud) i moraju razumeti šta postojeći radi pre nego što napišu novi
- IT operacija u Servoteh-u koja održava SQL Server i prateću infrastrukturu
- konsultanti za migraciju podataka

Stil: pretpostavljam da čitalac je iskusan developer ali **nije** Access/VBA specijalista. Gde god je terminologija specifična za Microsoft Access, kratko je objašnjena. Imena modula, formi i tabela ostaju na originalnom srpskom jer ih ne treba menjati.

---

## 1. Šta je ova aplikacija

QMegaTeh je **klijent-server ERP sistem za proizvodno preduzeće**, sa fokusom na praćenje radnih naloga (RN), upravljanje konstrukcionim podacima (PDM — Product Data Management), planiranje materijala (MRP), magacinsko poslovanje, finansijsko knjigovodstvo, PDV evidenciju i obračun zarada. Ima i sekundarne module za maloprodaju i POS u ugostiteljstvu (Kafe), koji se najverovatnije ne koriste u Servoteh-u.

Originalno je razvijana kao **monolit-MDB** aplikacija za jednu firmu (BIT CO. / "BigBit" iz brendinga modula i klasa), pa je vremenom preseljena na arhitekturu **Access front-end + SQL Server backend**, dok je deo poslovanja koji se nije migrirao i dalje vezan za pomoćne `.mdb` fajlove i jedan **eksterni legacy MDB** (`BB_T_25.MDB`, eksterni magacin) sa kojim novi sistem sinhronizuje podatke.

Aplikacija je multi-tenant: kroz pojam "Firma" (`IDFirma`, `AktivnaFirma`) više pravnih lica može da deli istu instancu, sa razdvojenim podacima i konfiguracijom po firmi.

Glavni jezik UI-ja, identifikatora i komentara je **srpski** (sa povremenim engleskim varijablama u BB framework-u). Datumi, valuta i decimalni formati su lokalizovani za RS.

---

## 2. Topologija sistema (fizička arhitektura)

```
┌─────────────────────────────────────────────────────────────────────┐
│  KLIJENT MAŠINA (Windows + MS Access 2010 ili runtime)              │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │  QBigTehn_APL.MDB  (front-end, ~454 VBA modula, sve forme) │     │
│  │  putanja: C:\SHARES\SERVOTEH\QBigTehn\                     │     │
│  └─────────────┬──────────────────────────────────────────────┘     │
│                │                                                    │
│   ┌────────────┴──────────┬──────────────┬───────────────┐          │
│   ▼                       ▼              ▼               ▼          │
│ BB_CFG_Lokal.mdb     BB_FIT.MDB     BB_TMP.mdb      EXT_BB_T_25.MDB │
│ (lokal config)       (files+tables) (temp/scratch)  (legacy lager)  │
│ ACE.OLEDB            ACE.OLEDB      ACE.OLEDB       ACE.OLEDB       │
└──────────────────────────────────┬──────────────────────────────────┘
                                   │ ODBC (SQL Server Native Client)
                                   │ konekcija: Vasa-SQL:5765
                                   │ kredencijali: QBigTehn / QbigTehn.9496
                                   ▼
                ┌────────────────────────────────────────┐
                │  SQL Server  →  baza:  QBigTehn        │
                │  ~120+ tabela, gomila SP-ova, UDF-ova  │
                │  (RobnaDokumentaMirror,                │
                │   RobneStavkeMirror, t* tabele,        │
                │   PDM_*, RN_*, KEPU_*, GK_*, ...)      │
                └────────────────────────────────────────┘
```

### 2.1 Komponente

| Komponenta | Lokacija (default) | Tip | Svrha |
|---|---|---|---|
| `QBigTehn_APL.MDB` | `C:\SHARES\SERVOTEH\QBigTehn\` | Access front-end | UI, VBA logika, linked tables ka SQL-u |
| `BB_CFG_Lokal.mdb` | `C:\SHARES\SERVOTEH\QBigTehn\` | Access (ACE.OLEDB) | Lokalna konfiguracija, parametri po mašini |
| `BB_FIT.MDB` | `C:\SHARES\SERVOTEH\QBigTehn\` | Access (ACE.OLEDB) | **Files & Tables registry** — katalog svih baza i mapping koja tabela se linkuje iz koje baze (vidi Dodatak G) |
| `BB_TMP.mdb` | `C:\SHARES\SERVOTEH\QBigTehn\` | Access (ACE.OLEDB) | Privremeni/scratch fajl, `tmp_*` tabele |
| `EXT_BB_T_25.MDB` | varira (per `BazaZaTip("EXTBAZA")`) | Access | Legacy magacinski sistem starog vendora — sync source za mirror tabele |
| SQL Server `QBigTehn` | `Vasa-SQL,5765` | MS SQL Server | Sva kritična poslovna data, sve tabele dokumenata, knjiženja, RN, PDM |

### 2.2 Konekcioni stringovi (iz `QBigTehn_APL.MDB` properties — plain text!)

```
CNN_CFG_Global       = DRIVER=SQL Server;SERVER=tcp:Vasa-SQL,5765;UID=QBigTehn;PWD=QbigTehn.9496;APP=QBigTehn;DATABASE=QBigTehn
CNN_CFG_Lokal        = Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\SHARES\SERVOTEH\QBigTehn\BB_CFG_Lokal.mdb;Persist Security Info=False
CNN_CFG_Sys          = (isto kao Global, samo SysVodiDnevnik i sistemski parametri)
CNN_CurrentDataBase  = (isto kao Global — glavni handle ka SQL-u)
CNN_FIT              = Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\SHARES\SERVOTEH\QBigTehn\BB_FIT.MDB
CNN_TempDB           = Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\SHARES\SERVOTEH\QBigTehn\BB_TMP.mdb
CNN_ESDB             = Provider=Microsoft.ACE.OLEDB.12.0;Data Source=-;...   (placeholder — verovatno neaktivan)
CNN_SHUTTLE          = Provider=Microsoft.ACE.OLEDB.12.0;Data Source=-;...   (placeholder — neaktivan)
CNN_MasterDB         = (isto kao Global)
```

**Bezbednosno upozorenje:** SQL Server šifra je u plain-text-u u properties grupi MDB-a. Svako sa file-system pristupom `.mdb` fajlu (uključujući backup-ove) je može pročitati u `Notepad`-u. Pre bilo kakve buduće izmene aplikacije promeniti šifru i prebaciti je u Windows Authentication ili u barem registry-shielded vault.

### 2.3 Domeni baza po nameni

- **`CFG_Sys` (na SQL-u)** — sistemski parametri vidljivi za sve firme i sve mašine (npr. `SysVodiDnevnik`)
- **`CFG_Global` (na SQL-u, per IDFirma)** — globalni parametri po firmi (npr. fiskalna konfiguracija, default printer-i)
- **`CFG_Lokal` (u `BB_CFG_Lokal.mdb`, per IDFirma)** — parametri specifični za jednu radnu stanicu (StartFormName, lokalni COM port, putanje)
- **`CFG_Apl_Parametri_DEF` (na SQL-u)** — fallback default-ovi za sve parametre koji nisu eksplicitno postavljeni

Ovaj četvoroslojni look-up (`Lokal → Global → Sys → DEF`) implementira `LIB_CFGRW.ReadParametar()` (vidi sekciju **4**).

---

## 3. Boot sekvenca i ciklus života aplikacije

### 3.1 Šta se okida pri otvaranju .MDB-a

```
1. MS Access otvori QBigTehn_APL.MDB
2. Pokreće se makro AutoExec  ──→  RunCode "Autoexec()"
3. StartUp.AutoExec()  čita Command-line parametar
   - ako je "Z"  →  DoCmd.OpenForm "Zastita"  (lock screen)
   - inače       →  BBStart(startFormName)
```

Source: `Makroi/Autoexec.txt` poziva `StartUp.bas:AutoExec()` → on poziva `StartUp.bas:BBStart()`.

### 3.2 BBStart — prava inicijalizacija

`StartUp.bas:BBStart` (linija 331, aktuelna verzija; prethodna varijanta je u istom fajlu pod imenom `BBStart_OLD` linija 176, ostavljena radi reference). Redosled koraka:

| Korak | Šta radi |
|---|---|
| `BBTimerStart` | startuje timer za merenje vremena bootovanja |
| `DoCmd.OpenForm "Intro"` | otvara splash/loading formu (lokalna sat-prozor, `Forms!Intro`) |
| `F_CheckBBFIT` | proverava da li je `BB_FIT.MDB` dostupan (Files & Tables registry — vidi Dodatak G) |
| `Postavi_Lokal_CFG` | linkuje tabele iz `BB_CFG_Lokal.mdb` |
| `Postavi_Lokal_TMP` | linkuje tabele iz `BB_TMP.mdb` |
| `RefreshDaoLink` | refresh-uje sve linked tables (DAO TableDef.Connect) |
| `RegSQLAccess_Login` | prijavljuje se na SQL i upisuje u Access log tabelu (vraća `SQLAccess_Login_ID`) |
| `UpisiUDnevnik` | upisuje "Start" event u tabelu `Dnevnik` (audit trail) |
| `If Zastita.Zasticen Then QuitBigBit` | proverava hardware-locked zaštitu (vidi sekciju 5.3); ako je aktivirana — gašenje aplikacije |
| `PrikaziLoseReference` | proverava da li sve VBA reference (npr. ActiveX, ADO) postoje |
| `SetStartupProperties` | postavlja Access startup properties (`AllowBypassKey`, `AllowFullMenus` itd. — sve na 0) |
| `F_CheckLink("_T_Rev")` | sanity check: da li link ka SQL tabeli `_T_Rev` radi |
| `PostaviGlobalneParametre` | inicijalizuje `BBCFG` objekat i učitava sve globale |
| `RegUser(0)` | placeholder, danas no-op |
| `BBOpenForm "P_PorukeTimerForm"` | (ako je interval poruka > 0) timer forma za interne poruke korisnicima |
| `FinalStartFormName` razrešavanje | u tri koraka: argument funkcije → `Command()` → `CFG_Lokal!StartFormName` |
| `DoCmd.Close acForm, "Intro"` | zatvara splash |
| `BBOpenForm FinalStartFormName` | otvara početnu formu (per-korisnik / per-mašina) |

Tipične startne forme koje su konfigurisane u `CFG_Lokal!StartFormName`:

- `Prva maska` / `Prva maska_BB` / `Prva maskaPregledi` / `Prva maskaMagacin` — glavni meni (više varijanti za različite role)
- `PrvaMaskaKonobar` — POS za konobare (Kafe modul)
- `RNPregled` — direktno na pregled radnih naloga (proizvodnja)

### 3.3 Pokretanje sa komandne linije

Aplikacija prima dva načina specifikacije startne forme:

```
MSACCESS.EXE QBigTehn_APL.MDB /cmd RNPregled
MSACCESS.EXE QBigTehn_APL.MDB /cmd Z         (otvara Zastita formu — admin lock screen)
```

Komandni argument se čita kroz `Command()` u `AutoExec()`.

### 3.4 Forme `Intro` i Splash mehanika

Za vreme bootovanja `Form_Intro` ima text-box `OpisPoslaKojiSeRadi` koji `IntroComment(stComment)` puni statusima, pa korisnik vidi "Postavljam Lokal CFG…", "Login na SQL…" itd. — što je istovremeno i progres bar i debug log. Tekst se na kraju snimi u globalnu `BBStart_LogText` (može se kasnije ispitati za dijagnostiku).

### 3.5 Gašenje aplikacije

`StartUp.bas:QuitBigBit(bQuit, bRegUserLogOff, bUpisiUDnevnik)` je centralna funkcija za izlazak. Po default-u upisuje "End" u `Dnevnik`, deregistruje SQL session i zove `DoCmd.Quit acQuitSaveAll`. Pozivaju je `Form_Zastita`, `Form_Intro` (kad je login fail), i ručna dugmad za izlazak.

---

## 4. Konfiguracioni sistem

### 4.1 Tabele parametara

Sva konfiguracija se čuva u tabelama sa kolonama `Parametar`, `Vrednost` (i u nekim slučajevima `IDFirma`):

| Tabela | Lokacija | Per-firma? | Default fallback |
|---|---|---|---|
| `CFG_Sys` | SQL Server | Ne (sistem-wide) | `CFG_Apl_Parametri_DEF` |
| `CFG_Global` | SQL Server | Da (`IDFirma`) | `CFG_Apl_Parametri_DEF` |
| `CFG_Lokal` | `BB_CFG_Lokal.mdb` | Da (`IDFirma`) | `CFG_Apl_Parametri_DEF` |
| `CFG_Apl_Parametri_DEF` | SQL Server (~412 redova) | Ne | — |
| `CFG_Apl_Parametri_DozvoljeneVrednosti` | SQL Server (~565 redova) | Ne | enum value catalog |
| `CFG_TabStop` | SQL Server | Da | redosled kontrola pri Tab-u u formama |

### 4.2 Centralni access pattern

`LIB_CFGRW.ReadParametar(TablePropName, txtParametar, [SetDefaultTableName], [IDFirma])` je jedini **podržan** način čitanja konfiguracije. Skoro svaki modul ga koristi. Ponašanje:

```
ReadParametar("CFG_Lokal", "StartFormName")
   → ide u BB_CFG_Lokal.mdb tabelu CFG_Lokal preko ADO_Lookup
   → ako je NULL ili greška → fallback na CFG_Apl_Parametri_DEF
```

Pisanje parametara: `LIB_CFGRW.WriteParametar(...)` (paralelna funkcija u istom modulu, koristi insert-or-update logiku).

### 4.3 BBCFG klasa (`BBCFG_Class.cls`)

`BBCFG` je **globalna instanca singleton-tipa** (`Public BBCFG As New BBCFG_Class`) koja drži sav cached state aplikacije za jednu sesiju. Ima ~130 javnih property-ja. Najvažnije grupe:

- **Identitet sesije:** `AppName`, `APLUserName`, `DBUserName`, `MaticnaSifra`, `IDJezik`, `SQLAccess_Login_ID`
- **Konekcija:** `CNNString`, `CnnStringBezPWD()` (utility za logging bez šifre), `SQLDB`
- **Računovodstveno ponašanje:** `KEPUPoNabavnojCeni`, `KEPUPoKursu`, `GKPoKursu`, `GKPoKursuObrnuto`, `KnjiziRazlikeNaTK/KEPU/MPKEPU`, `BrDecUlKl`, `BrDecIzKl`
- **PDV/POPDV:** `POPDV_PrikaziTotale`, `POPDV_BrDec`
- **UI defaults:** `MemorandumHeaderVisible`, `UFKLStampaOkreni`, `IntroIsOpen`
- **Razvoj/test:** `SysRazvojAPL` (developer mode flag), `TestPravaPristupa`, `SysVodiDnevnik` (audit on/off)
- **Debug:** `SetAppEcho(setVal, [strStatusBarText])`, `CheckEcho`, `EchoStatusBarText`

`BBCFG` se inicijalizuje pozivom `PostaviGlobalneParametre()` u `Bliski susret.bas` na kraju boot sekvence. Većina property-ja čita iz `CFG_Global` ili `CFG_Sys` jednom i kešira; neki se reaktivno menjaju iz UI-ja (npr. `BBPravaPristupa` forma menja `BBCFG.TestPravaPristupa` direktno).

### 4.4 Glavni globalni državni objekti

Pored `BBCFG`, aplikacija drži još nekoliko globalnih instanci u `LIB_GlobalniModul` i razasuto:

```vba
Public BBCFG       As New BBCFG_Class    ' konfig + sesija
Public BBTehn      As New BBTehn_Class   ' tehnološki postupci stanje
Public RNP         As New RN_Class       ' aktivni Radni Nalog state
Public PDMSklop    As New PDM_Class      ' aktivni PDM sklop
Public IFP         As New IF_Class       ' Izlazna Faktura state (creating)
Public UFP         As New UF_Class       ' Ulazna Faktura state
Public USLF        As New USLF_Class     ' Usluga Faktura state
Public EmailClass  As New Email_Class    ' SMTP setup (kešovan iz CFG)

' "Plitke" globale, plain VBA tipovi:
Public AktivnaFirma           As String
Public KorisnikAplikacije     As Long      ' Servoteh user ID (nije isto što i CurrentUser())
Public IzabraniArtikal        As Long
Public IzabraniRadnik         As Long
Public IzabraniPostupak       As Long
Public BBStart_LogText        As String    ' boot dijagnostika
Public ADO_IDENTITY           As Variant   ' poslednji @@IDENTITY iz INSERT-a
Public ADO_ROWCOUNT           As Long      ' poslednji @@ROWCOUNT
Public ADO_EXECUTE_DURATION   As Single    ' merenje brzine SQL-a
```

Svaki put kad se otvori forma za novi nalog, RN ili IF, odgovarajuća klasa se "puni" (Open eventom forme) i koristi kao radni state-holder umesto da se podaci stalno provlače kroz UI kontrole. Kad se forma zatvori, klasa se obično resetuje (`Set RNP = New RN_Class`).

---

## 5. Sigurnost i pristup

Aplikacija je u svom istorijskom razvoju imala **četiri sloja zaštite**, od kojih su tri trenutno demontirana (april 2026):

### 5.1 Workgroup (ULS — User Level Security) — **DEMONTIRANO**

Originalno je `.mdb` bio zaštićen Access ULS-om vezanim za workgroup fajl `BIGBIT.MDW` sa parametrima:

```
Name: SLAVISA
Org:  BIT CO.
WID:  BIGBIT224163
```

Korisničke grupe i korisnici (vidi izveštaj `QBigTehn_APL_security.csv` iz Access Forensics-a):

- `std group 'Admins'` (vendor — sa `BIGBIT224163` SID-om) — pun pristup, 3145 ACE-ova
- `std group 'Admins'` (default Access — prazna trojka)
- `std group 'Users'` — read-only baseline, 3149 ACE-ova
- 15 imenovanih korisničkih naloga sa različitim brojem ACE-ova (Access Control Entries): `Slavisa` (3142), `Negovan` (623), `AcaS`, `DijanaK`, `IgorV`, `JovicaM`, `Kasa`, `Korisnik`, `Milica`, `MiljanN`, `Nikola`, `ReadOnly`, `ZoranJ`, `hala2`, `hala5` (po 1 ACE — minimalni grant-ovi). Imena naloga su tehnički identifikatori unutar `.mdb` fajla i nemaju nikakav značaj van legacy auth sistema

Ovaj sloj je **nepovratno skinut** preko Thegrideon Access Forensics 2025-08-08 alata na patch-ovanoj kopiji. ACL strukture više ne važe. Trenutni `.mdb` se otvara bez login-a sa punim pravima.

Posledica: kod koji proverava `CurrentUser()` i `UserUGrupi(...)` (npr. `LIB_GlobalniModul.UserUGrupi`) više neće raditi pouzdano — `CurrentUser()` vraća `Admin` umesto stvarnog korisnika.

### 5.2 VBA project password — **DEMONTIRANO**

Iznad ULS-a postojao je VBA project password (DPB marker u binaru). Skinut DPB-patch tehnikom (slovo `B` u `DPB="..."` zamenjeno sa `x`, pa je Access reagovao kao da je hash invalidan i pustio editor; nakon `Tools → VBAProject Properties → Protection → Lock=off` projekat je trajno otvoren).

### 5.3 `Zastita` modul — **AKTIVAN, ali zaobiđen**

Ovo je vendor-ova "kill switch" zaštita, **softverski hardware-locked**. Logika:

1. Pri instalaciji vendor postavlja u `.mdb` property `BBHDSn` (Hard Disk Serial Number ciljne mašine) i u Windows Registry (`HKLM\Software\BitCo\...`) još jedan reference set.
2. Pri svakom startu `BBStart` poziva `Zastita.Zasticen` koji proverava poklapanje runtime HD SN-a sa stored vrednostima. Ako se ne poklapa — `QuitBigBit`.
3. **Tajni "key reset" mehanizam:** funkcija `DozvoljenoPostavljenjeZastite()` koja dozvoljava promenu zaštite samo ako je `CurrentUser() = "Negovan"` (hardkodirano!) i ako se unese key u formatu `Dan & GetComputerName & Mesec & Godina`. Tipičan vendor backdoor.

Pošto je trenutno `.mdb` na drugoj mašini (kopija na kojoj smo radili), `Zastita` je verovatno aktivirana ali izlaz iz BBStart blokira normalan run. Konstanta `Public Const ProgName = "BigBit"` i `Public Const RegGrana = "Software\BitCo\"` u `Zastita.bas` ostaju.

**Za buduće održavanje:** ako se `.mdb` koristi za development bez vendor-ovog odobrenja, najjednostavnije je u `Zastita.Zasticen()` privremeno postaviti `Zasticen = False` i pre BBStart `If Zastita.Zasticen Then QuitBigBit` neutralizovati. Trajno rešenje je da se kompletno izvuče logika i da se zameni real-licensing modulom.

### 5.4 Aplikacijski nivo prava — `BBPravaPristupa`

Nezavisno od Access ULS-a, postoji aplikacijski authorization sloj kroz tabele u SQL-u i formu `Form_BBPravaPristupa`. Provera:

- `BBCFG.TestPravaPristupa` flag — ako je `True`, kontrole na formama se enable/disable po pravilima iz `BBPravaPristupa` tabele po (`UserName`, `ImeForme`, `ImeKontrole`)
- Ako je `False` — sve dozvoljeno (developer mode)

Pripadnost grupi se proverava preko `LIB_GlobalniModul.UserUGrupi(ImeUsera, ImeGrupe)` koji hituje stari Access workgroup API. **Posle skidanja ULS-a, ovo NE RADI** — uvek vraća `False` ili greške. Ako želiš da koristiš `BBPravaPristupa`, taj rad mora da se rewrite-uje da koristi neku aplikacijsku tabelu mapiranja `User → Grupa`.

### 5.5 `tRadnici.PasswordRadnika`

Za POS forme (Kafe, magacin) postoji forma `Form_UnosPassworda` koja proverava password polje `PasswordRadnika` u tabeli `tRadnici` direktnim DLookup-om. **Šifre su u plain text-u u tabeli.** Ovo treba ozbiljno popraviti pre bilo kakve buduće izmene — minimalno bcrypt + salt.

### 5.6 Audit log

Tabela `Dnevnik` (na SQL-u) prima zapise iz `Dnevnik.UpisiUDnevnik(Korisnik, Opis, ImeForme, Akcija)`. Polja: `Korisnik` (max 20 char), `Opis`, `Forma` (max 50), `Akcija` (max 10). Aktiviranje kontrolisano sa `BBCFG.SysVodiDnevnik` (CFG_Sys flag).

Pozivaju ga: BBStart (Start), QuitBigBit (End), Kafe login, Konobari login, najznačajnije akcije po formama.

**Mana:** logovi su append-only iz aplikacije ali nemaju nikakvu zaštitu od UPDATE/DELETE iz drugog klijenta. Za pravu auditnu vrednost treba na SQL-u staviti trigger koji blokira non-INSERT operacije na `Dnevnik`.

---

## 6. Sloj pristupa podacima

Aplikacija ima **dva paralelna pristupa bazi**:

1. **DAO** (Data Access Objects) — Access-ov nativni API, koristi se za rad sa linked tabelama i lokalnim `.mdb` fajlovima
2. **ADO** (ActiveX Data Objects) — preko ODBC za rad direktno sa SQL Server-om, posebno za pass-through upite, SP-ove i UDF-ove

### 6.1 ADO_Module — centralni SQL helper

`ADO_Module.bas` (1901 linija) je `static class` (modul sa `Public` funkcijama). Pruža sve generičke operacije nad SQL-om:

| Funkcija | Šta radi |
|---|---|
| `ADO_TestConnection(CNNString, Timeout)` | health-check |
| `ADO_GetRST(CNNString, SQLText, ...)` | vraća `ADODB.Recordset` |
| `ADO_Lookup(CNNString, Expr, Domain, Criteria)` | ekvivalent DLookup ali nad SQL-om |
| `ADO_ExecSQL(CNNString, stSQLText, ...)` | INSERT/UPDATE/DELETE/DDL — postavlja `ADO_ROWCOUNT`, `ADO_IDENTITY`, `ADO_EXECUTE_DURATION` kao globalne |
| `ADO_ExecSP(CNNString, SPName, ParamArray Arg())` | poziv stored procedure |
| `ADO_GetRSTFromSP / ADO_GetRSTFromUDFT / ADO_GetValFromUDFS` | TVF i scalar UDF wrapper-i |
| `ADO_PostojiTabelaUBazi`, `ADO_PostojiKolonaUTabeli`, `ADO_CreateTable`, `ADO_AddTableColumn`, `ADO_KreirajTabeluPoModeluRecordseta` | DDL helper-i |
| `ADO_ExportTable / ADO_UpdateTable` | bulk transfer između baza |
| `ADO_SledeciAutoID(CNNString, ImeTabele, ImeIDPolja)` | rezerviše sledeći ID kad ne postoji IDENTITY |
| `BackupCurrentSQLDB(stDestFileName)` | server-side BACKUP DATABASE preko ADO |
| `SQLFormatVreme / SQLFormatDatuma / SQLFormatBoolean / CheckFieldToSQL` | escape & format utility-i (centralni!) |
| `GetParFromCnnString / SetParToCNNString` | parsiraju i menjaju connection string parametre |

**Konvencija u kodu:** posle svakog `ADO_ExecSQL` (INSERT) automatski je `ADO_IDENTITY` postavljen na novi ID — koristi se umesto eksplicitnog `SELECT @@IDENTITY`.

### 6.2 BBSQLModule — viši nivo, SQL Server specifično

| Funkcija | Šta radi |
|---|---|
| `LinkTableToNewSQLServer(TblName, NewCnnString)` | linkuje SQL tabelu u Access kao linked table sa novim conn string-om |
| `ConnectSQLToNewServer(NewCnnString)` | masovno relinkuje sve SQL linked tabele kad se promeni server |
| `RefreshLinkedSQLTables` | periodični refresh linked-table konekcija |
| `BBCreateQuery(QName, SQLText, [CNNString])` | dinamički kreira saved query (ako je sa `CNNString` postaje pass-through) |
| `TextSelectQForUDFT / TextSelectQForSP / TextExecuteSP` | SQL text builderi za UDF-ove i SP-ove |
| `ExportujTabeluUSQL / ExportujTabeluUSQLBezIdentityKolone` | jednokratni export Access tabele u SQL |

### 6.3 BBQueryTool — Access query introspection i parametrizacija

`BBQueryTool.bas` (1657 linija) je vendor-ov framework za rad sa Access saved query-jima:

- `PostojiQuery(QName)` — postoji li query
- `ExecuteSQLActionQuery(stSQLText, ByRef recaff, ...)` — execute action query sa rowcount
- `AccQueryEvalPar(SQLText, ParamArray Par())` — zamenjuje placeholder-e u SQL-u sa stvarnim vrednostima
- `ReplaceSQLArgWithValue(stQuery, stArgName, stArgVal, [Delimiter])` — string replace sa SQL escape
- `PassTroughQueryMakeSQLTextFromTDef(QueryName, [EvalPar], [ErrorCode])` — uzima Access saved query (pass-through) i vraća konkretni SQL string sa popunjenim parametrima
- `PassTroughQueryAutoMap(QueryName)` — auto-mapira Access parametre na ODBC parametre (radi sa T-SQL UDF-ima i SP-ovima)
- `DodajACCParametreUTabelu / DodajODBCParametreUTabelu` — generišu metadata o parametrima query-ja

### 6.4 LinkovaneTabele — refresh & rerouting

Kad se mašina premešta ili se menja path-ovi `.mdb` fajlovima, koristi se `LinkovaneTabele.bas`:

- `RefreshujSveLinkoveUSvimBazama()` — masovni refresh
- `ForsirajSveLinkoveUSvimBazama([Silent])` — refresh + ako fail, rebind
- `UpisiNoviCNNStringZaTipBaze(TipBaze, NewCnnString)` — promeni connection string za "tip baze" (npr. "EXTBAZA", "FIT", "TMP")
- `BazaZaTip(TipBaze)` — vraća putanju do `.mdb` za dati tip
- `ForsirajNoveLinkoveZaIDBaze(IDBaze, CNNString, ...)` — relink po IDBaze (kad postoji više konfigurisanih baza u tabeli `BazeITabele`)

Tabele `BazeITabele_APL` (681 redova) i `Baze_Firme` čuvaju katalog svih baza i koja tabela treba da se linkuje iz koje. Tabela `SveLinkovaneTabele` (100 redova) je trenutno aktivna mapa.

### 6.5 modSyncMirrorTabele — sinhronizacija sa eksternim BB_T_25.MDB

Centralna sinhronizacija između legacy `BB_T_25.MDB` (eksterni magacin) i SQL `RobnaDokumentaMirror` / `RobneStavkeMirror`:

- `SyncMirrorZaKatBroj(KatBroj, SessionID)` — za jedan kataloški broj povuče sve stavke iz eksternog magacina
- `SyncMirrorZaProjekt(ZaIDCrtez, SessionID)` — za jedan PDM crtež povuče BOM iz SQL-a, za nabavne delove iz BOM-a povuče magacin iz BB_T_25
- Brisanje pre-stari po `SessionID`-u, pa novi insert — last-write-wins per sesija

**Bitno za migraciju:** ako se BB_T_25 gasi, ova logika treba ili da se zameni direktnim brkanjem podataka u SQL `RobnaDokumentaMirror`, ili da se mirror tabele migriraju u `RobnaDokumenta` kao prave kolone.

### 6.6 ODBC_Synch_Module / ODBC_Synch_Class — sync MP dokumenata

POS-side sinhronizacija. `F_SynchMPDok(IDDok, IDProdavnica, IDKasa)` šalje jedan maloprodajni dokument na SQL; `F_SynchAllMPDok([WhereInput], ByRef Ukupno, Uspesno, Neuspesno)` masovni sync. Koristi se kad MP terminali rade offline pa periodično šalju.

---

## 7. BB framework — vendor-ova osnova

Sve što počinje sa `BB` je framework koji je vendor (BIT CO.) razvio kao reusable layer za sve svoje aplikacije. QMegaTeh je samo jedna od više aplikacija koje koriste ovaj framework. Veliki deo BB-modula je generic helper, ne business logika.

| Modul | Veličina | Svrha |
|---|---|---|
| `BBCMD_SYS` | 3496 | DDL operacije nad MDB-ovima: kreiranje upita, prebacivanje formi/izveštaja/modula iz baze u bazu, sync indeksa, sync relacija, sync polja. Verovatno je vendor koristio za upgrade install-acije kod klijenata |
| `BBCMD_BigBit` | manji | varijanta za BigBit branding |
| `BBKreiranjeDokumenata` | 2185 | **CENTRALNI** — kreiranje svih tipova dokumenata: `KreirajRobniDok`, `KreirajProfakturaDok`, `KreirajUslugaDok`, `KreirajNalogGK`, `KreirajTrebovanjeDok`, `KreirajMPDok`, `KreirajPopisDok`, `KreirajRadniNalog`, `KreirajIliPronadjiPredmet` |
| `BBQueryTool` | 1657 | introspection & param resolution za saved query-je |
| `BBSQLModule` | 741 | SQL Server specifični helper-i |
| `BBSys` | 753 | sistemske utility-je: `TurnOffSubDataSheets`, podešavanja Access opcija |
| `BBHotKeys` | 681 | F-tasteri po formama, definicije globalnih hotkey-eva |
| `BBT_BrojDokumenataPoGodinama` | 65 | numeracija dokumenata po godini |
| `BB2CMD` | manji | aliasi/wrapper-i ka starim BBCMD imenima |
| `BBCFG_Class` | 1713 | Singleton konfiguracija (vidi 4.3) |
| `BBTehn_Module / BBTehn_Class` | 1553 / klasa | Tehnološki postupci state |

**Konvencija:** `BB` modul = framework, ne menjati lakomisleno; verovatno je deljen sa drugim vendor-ovim instalacijama (kod drugih klijenata) i u teoriji se može oštetiti zavisnost koju ne vidiš odmah.

---

## 8. Poslovni domeni

### 8.1 Radni nalozi (RN) — core proizvodnje

**Glavni moduli:** `RN_Modul`, `RN_Class`, `BBKreiranjeDokumenata.KreirajRadniNalog`
**Glavna forma:** `Form_UnosRN` (1328 linija — najveća forma u sistemu)
**Pregledne forme:** `RNPregled`, `RNPregledZag`, `RNPregledStavke`, `RNPregledPostupci`, `RNPregledPoRJ`, `RNPregledPoRadniku`, `RNLansiranStatus`, `RNSaglasanStatus`
**Izveštaji:** `rRN`, `rRN_BezBarKoda`, `rRN_SaSlikama`, `rRN_tKomponente`, `rRN_tNDKomponente`, `rRN_tPDM`, `rRN_tPLP`, `rRN_tPND`, `RNPregled`, `RNPregledPoRJ`, `RNPregledPoRadniku`

**Glavne tabele:** `tRN`, `tRN_Stavke`, `tRN_Postupci`, `tTehPostupak`, `tLokacijeDelova`

**Ključni pojmovi:**
- **RN (Radni Nalog)** — glavni dokument proizvodnje; ima identifikator `IDRN`, vezan je za `IDPredmet` (poslovni projekat) i `IDKomitent` (investitor)
- **Identbroj** — string identifikator dela koji se proizvodi
- **Postupak** — operacija koja se izvodi nad delom (npr. struganje, brušenje, pranje)
- **Saglasan / Lansiran statusi** — workflow stanja koja kontrolišu ko sme šta da menja
- **`tRN.IDVrstaKvaliteta`** vs **`Query3.IDVrstaKvaliteta`** — status kontrole tehnologa vs status kontrole kvaliteta (vidi `000_ProveraSkartova` upit)

**RN_Class properties:** `IDRN`, `IDKomitent`, `SifraRadnika`, `IDPredmet`, `IdentBroj`, `Varijanta`, `RJgrupaRC`, `RootFolderDokumentacije`, `FolderTehnologa`, `FolderKontrole`

**Workflow:**
1. RN se otvara kroz `Form_UnosRN` ili `BBKreiranjeDokumenata.KreirajRadniNalog(BrojRadnogNaloga, Pozicija, DatumOtvaranja, IDInvestitor, Napomena, [NazivProizvoda])`
2. Dodaju se stavke (delovi koji se prave) i postupci (operacije po stavci)
3. Tehnolog daje saglasnost (`PostojiSaglasnost(IDRN)`)
4. Lansiranje (`DefiniseLansiran`) — počinje proizvodnja
5. Radnici upisuju kroz primopredaje (`Primopredaja*` forme) ili bar-kod ulaze (`BarKod_Unos`, `BarKod_Status`)
6. Kontrola kvaliteta evidentira `IDVrstaKvaliteta` — `000_ProveraSkartova` traži stavke gde se status tehnologa razlikuje od statusa kontrole kvaliteta
7. Završavanje RN i prebacivanje u arhivu

### 8.2 PDM — Product Data Management

**Glavni moduli:** `PDM_Common` (1452), `PDM_Class`, `PDMXMLParser`, `PDM_PDFCommon`
**Glavne forme:** `Form_PDMTreeView`, `Form_PDMSklop`, `Form_PDMCrteziPregled`, `Form_PDMPodSklopReference`, `Form_PDMXMLImportLog`
**Izveštaji:** `rPDM-jedan`

**Glavne tabele (na SQL-u):** `PDM_Document_APL`, `KomponentePDMCrteza`, `PDM_PlaniranjeStavke`, `Crtezi`

**Ključni pojmovi:**
- **Crtez** — konstrukcioni crtež dela; ima `BrojCrteza`, `Revizija`, `Varijanta`
- **Sklop / PodSklop / PodPodSklop / PodPodPodSklop** — hijerarhija sklopova (4 nivoa hardkodirano)
- **TrebaIDCrtez** — komponenta crteza pokazuje na koji drugi crtež (BOM relacija)
- **PotrebnoKomada** — količina komponente potrebna po sklopu

**Tipičan workflow:**
1. Konstruktor crta deo u CAD-u, eksportuje BOM kao XML
2. `PDM_Common.UveziPDM_XMLFajl(stPathFile)` ili `PDMXMLParser.ImportXMLWithReferences(xmlFilePath)` parsiraju XML
3. Insert-uju se zapisi u `Crtezi` i `KomponentePDMCrteza`
4. Postoji rekurzivni traversal za ekspanziju BOM-a do najnižeg nivoa (`PotrebneKomponenteZaCrtez`, `PotrebneTopLevelKomponenteZaCrtez`, `PotrebniGotoviDeloviZaCrtez`)
5. Iz BOM-a se generišu MRP potrebe i radni nalozi

XML parsing koristi `MSXML2.DOMDocument.6.0`. Test putanja u kodu je `C:\PDMExport\XML\` što ukazuje da je transfer iz CAD-a fajl-bazirani drop-folder workflow.

### 8.3 MRP — Material Requirements Planning

**Glavna form-grupa:** `Form_MRP_Pregled`, `Form_MRP_DetaljanPregledSaZalihama`, `Form_MRP_DetaljanPregledSvihMRPPotreba`, `Form_MRP_PotrebaStavke`, `Form_MRP_PregledRezervisano`, `Form_MRP_PregledSaZalihama`, `Form_MRP_PregledSamoNabavku`, `Form_MRP_PregledPoDobavljacima`, `Form_frmMRP_Akcija`
**Glavni modul:** `MRP_Module`

**Šta radi:** uzima sve aktivne RN-ove, ekspanduje BOM (preko PDM-a), oduzima zalihe (iz `RobnaDokumentaMirror` koji sync-uje sa BB_T_25), i generiše listu nedostajućeg materijala koji treba naručiti. Grupiše po dobavljaču.

Iz toga se generišu:
- **Specifikacija nabavke** (forme `Form_SpecifikacijaZahtevaZaNabavku`, `Form_SpecifikacijaUpitaZaNabavku`, `Form_SpecifikacijaTrebovanjaZaNabavku`)
- **Trebovanja** (forme `Form_Trebovanje - Podforma`, `BBKreiranjeDokumenata.KreirajTrebovanjeDok`)
- **Email upita za ponudu** (forme `Form_BBMail_ZaNabavku`, `SendMail_Module.BBMail_OtvoriFormuZaSlanjeSpecifikacijeNabavke`)

### 8.4 Proizvodnja i tehnološki postupci

**Moduli:** `Proizvodnja`, `BBTehn_Module`, `BBTehn_Class`, `PPS_Modul` (Proizvodnja Po Sektorima ili Plansko Praćenje Sopstveno)

**Forme:** `Form_PregledPoPostupcima` i 4 varijante (Zbir, ZbirGrupno, LoseEvidentirani, SviZapocetiPostupci), `Form_PregledOperacijaPoPrioritetima`, `Form_UnosOperacije`, `Form_PregledTehnoloskihPostupaka`, `Form_PregledPostupakaSaDokumentacijom`, `Form_KarticaLokacijaDela`, `Form_LokacijaSvihNapravljenihDelovaPoRN`

**Operacije:**
- `Proizvodnja.DodajDokZaProizvodnju()` — kreira dokument za proizvodnju
- `Proizvodnja.DodajStavkeUDokZaProizvodnju(NoviIDDok, IDMag)` — popuni stavke
- `Proizvodnja.CenaKostanjaGotovogProizvoda(ZaIDArtikal, [NaDan], [ZaLevel], [ZaMagacinSirovina])` — obračun cene koštanja po BOM-u i tehnološkim postupcima

PPS (Pregled Postupaka po Statusu) je odvojeno modul/forme koje rade real-time monitoring proizvodnje — koja operacija je u toku, na kojoj mašini, koji radnik radi.

### 8.5 Računovodstvo

#### Glavna knjiga (GK)
**Moduli:** `GlavnaKnjiga`, `GKEval`, `GKS`, `GRK`, `Kontiranje`, `SemaZaKontiranje`
**Forme:** `Form_BB_UsersQuery` i pregledne forme za karticu konta, otvorene stavke, IOS

Centralne funkcije:
- `KarticaKomitenta(Konto, IDKomitent, [ZaKonto2], [ZaGodinu])` — kartica
- `OtvoreneStavkeKomitenta(Konto, IDKomitent, [ZaGodinu])` — otvorene stavke
- `GKKarticaKontaSinteticka(Konto1, Konto2, [PrimeniUslove], [stPodforma])` — sintetička kartica
- `PrintujIOS(IDKomitent, VrstaIOS, [CheckDev], [ZaDevValutu])` — IOS izveštaj
- `ZakljucanNalogGK(IDNaloga)` / `ZakljucanaStavkaGK(IDStavka)` — proverava lock
- `PrintujNalogGK(rptName, IDNaloga)` — print

#### KEPU (Knjiga Evidencije Prometa Usluga / robe)
**Moduli:** `NKEPU`, `TK_KEPU_MP`
**Specifični prema vrsti:** `KEPUPoNabavnojCeni`, `KEPUPoKursu`, `KEPUPoKNGCeni`, `KEPUPoMPKEPU` (BBCFG flagovi)

#### POPDV / PDV (poreska prijava)
**Modul:** `POPDV_Module` (649 linija), `PDV_Modul`
**Tabela definicija:** `POPDV_DEF`

POPDV je serbian PDV evidencioni format. Funkcije:
- `F_POPDV_OJ()`, `F_POPDV_PoreskiSavetnik()`, `F_POPDV_JMBGPoreskiSavetnik()`, `F_POPDV_OdgovornoLice()`, `F_POPDV_TipPodnosioca()` — header podaci
- `F_POPDV_MesecnaIliKvartalnaObaveza()` — periodicitet
- `MozeEvalDefKonto(Izraz)` — evaluator izraza za mapiranje konta na POPDV polja
- `SekcijaZaPOPDVOznaku(PDVOznaka, [imeTabele])` / `BrojKolonaZaPOPDVOznaku(...)` — mapiranje oznaka

#### Otvorene stavke i kompenzacije
Modul `Otvorene stavke.bas` (sa razmakom u imenu — Access tolerise), `OP_Fakturisanje`, `Uskladjivanje prodaje` (705 linija — komplikovan modul za usklađivanje prometa).

#### Kamate
Modul `Kamate.bas` (1349 linija) — obračun zateznih kamata, vremensko diskontovanje, deviznih razlika.

### 8.6 Robni dokumenti i fakturisanje

**Centralni kreator:** `BBKreiranjeDokumenata.KreirajRobniDok(...)` — kreira ulazni ili izlazni robni dokument
**Klase za stanje:** `UF_Class` (Ulazna Faktura), `IF_Class` (Izlazna Faktura), `USLF_Class` (Usluga Faktura)

**Tip dokumenata** koji se kreiraju kroz `BBKreiranjeDokumenata`:
- `KreirajRobniDok` — generic robni dokument (ulaz/izlaz)
- `KreirajProfakturaDok` — profaktura
- `KreirajUslugaDok` (+ `DodajStavkuUUslugaDok`) — uslužni dokument
- `KreirajMPDok` — maloprodajni dokument
- `KreirajPopisDok` (+ `DodajStavkuUPopis`) — popis (inventory count)
- `KreirajTrebovanjeDok` (+ `DodajStavkeUTrebovanje`) — trebovanje
- `KreirajNalogGK` — nalog za knjiženje GK
- `spKreirajRobniDokIzProfakture` — konverzija profaktura → robni
- `spKreirajMPDokIStavkeIzVPDok` — konverzija veleprodaja → maloprodaja
- `spPrepisiStavke_RobniDok / spPrepisiStavke_UslugeDok` — kopiranje stavki između dokumenata
- `KreirajUslogaDokPoUgovoru / KreirajSveUslugeDok_Ugovori` — ciklično fakturisanje ugovora (npr. mesečna naknada)

**Glavna SQL tabela:** `T_Robna dokumenta` (sa razmakom u imenu — vidi upit `07_PrenesiRobnaDokumenta_SERVOTEH_SVE` za kompletnu šemu sa svim 60+ kolona)

**Konvencija imena tabela:** prefiks `t` (lowercase) za radne tabele, `T_` za glavne dokument-tabele, `MSys*` su sistemske Access metadata.

### 8.7 Fiskalizacija i POS

#### ZR (Zatvarač Računa / Fiskalna kasa)
**Moduli:** `ZR.bas`, `ZRXML.bas` (XML format za novu fiskalizaciju)

#### Galeb fiskalni štampač
- `BBCFG.F_Galeb()` — flag da li koristi Galeb
- `BBCFG.F_ServerZaGaleb / F_KlijentZaGaleb` — server/klijent mode (više terminala deli štampač)
- `BBCFG.F_SaljiBosson` — alternativni protokol
- Konfiguracija preko `ComPortPar` klase (CommPortNo, CommPortSettings, TestGaleb, TestPapirGaleb, ProveraNaplataCek, ProveraNaplataKartica, ProveraPoklopac, DelayTimeMiliSec)
- Forma `Form_FP_Server` (FP = Fiskalni Printer) za Server-mode

#### Raster fiskal
- `BBCFG.F_Raster()` — alternativa Galebu
- `RasterModul.bas`

#### Kafe POS (sekundarni — verovatno se ne koristi u Servoteh-u)
**Moduli:** `Kafe`, `KafeKreiranjeDokumenata`, `KafeProdaja`, `KafeNaplata`, `Konobari`
**Forme:** `Form_PrvaMaskaKonobar`, `Form_IzborStolaPanel`, `Form_KbdNum`, `Form_Digitron`

Funkcionalnost konobarskog POS-a:
- Login konobara (4-cifren PIN preko `Form_UnosPassworda`)
- Otvaranje računa za sto (`KafeKreiranjeDokumenata.OtvoriRacun`)
- Dodavanje stavki, splitovanje računa
- Konobar uzima/daje račun (`Konobari.KonobarUzimaRacun / KonobarDajeRacun`)
- Storniranje (`Konobari.DozvoljenoStorniranjeZaPWD`)
- Naplata gotovinom/karticom/čekom/virmanom
- Štampa fiskalnog ili nefiskalnog računa

#### ZbrniRacun
Modul `ZbrniRacunModule` — zbirne dnevne kalkulacije za fiskal.

### 8.8 Banking integracija

#### Halcom
**Modul:** `FX_HALCOM.bas`
- `FX_DopuniTR(tr)` — popunjava nule u tekućem računu (format `XXX-NNNNNNNNNNNNN-XX`)
- `HALCOM_DopuniTR(tr)` — alias / kompatibilnost

Glavna integracija je generisanje XML/TXT fajlova platnih naloga (virmana) koji se zatim importuju u Halcom e-bank klijent. Mode: file-drop, ne API.

#### BEOHOME
**Modul:** `BEOHOME.bas` — verovatno integracija sa Beograđanin Home Banking (stari sistem). Koristi se kod nekih klijenata, ne nužno Servoteh.

### 8.9 Komitenti, ugovori, cene

**Moduli:** `Komitenti`, `KomitentiUgovori`, `KomitentiCrnaListaModul`, `Cene` (948 linija)
**Forme:** `Form_Pregled komitenata`, `Form_Unos komitenata`

- `Komitenti.spDodajTRZaKomitenta(IDKomitent)` — TR (tekući račun)
- `Komitenti.UpisiNoviRabatZa[Poreklo|Podgrupu|Grupu]KodSvihKomitenata(...)` — masovni rabati
- `Komitenti.spUpisiKomitentaUCrnuListu(...)` — crna lista
- `Cene.bas` — cenovnici, nivelacija, obračun (vidi modul `Nivelacija.bas`)

### 8.10 Pisarnica i predmeti

**Forme:** `Form_Pisarnica_PregledPredmeta`, `Form_Pisarnica_UnosPredmeta`, `Form_Predmeti`, `Form_T_Predmeti_Prilozi`
**Funkcija:** `BBKreiranjeDokumenata.KreirajIliPronadjiPredmet(BrojPredmeta, Opis, DatumOtvaranja, IDKomitent, Status, [Napomena])`

"Predmet" je sledeći nivo iznad RN-a — poslovni projekat / ugovor / case.

---

## 9. Eksterne integracije

| Sistem | Modul | Smer | Format | Frekvencija |
|---|---|---|---|---|
| SQL Server `QBigTehn` | `ADO_Module`, `BBSQLModule`, `LinkovaneTabele` | dvosmerno | ODBC, T-SQL | real-time |
| Eksterni magacin `BB_T_25.MDB` | `modSyncMirrorTabele` | jedno-smerno (čita) | DAO | po potrebi (per-katBroj ili per-projekat) |
| Halcom e-bank | `FX_HALCOM`, `ExportTXTCSVXML` | exportujemo | XML/TXT | manuelno |
| Galeb fiskalni štampač | `ComPortPar`, `ZR`, `ZRXML`, `Kafe*` | exportujemo | proprietary nad COM port-om | per račun |
| Raster fiskalni | `RasterModul`, `ComPortPar` | exportujemo | proprietary | per račun |
| PDM XML iz CAD-a | `PDMXMLParser`, `PDM_Common` | importujemo | XML | per fajl drop |
| Email | `Email_Class`, `SendMail_Module` | exportujemo | SMTP | manuelno (specifikacije nabavke) |
| SMS | `SMS_Modul` | exportujemo | proprietary (najverovatnije gateway HTTP API) | manuelno |
| BigBit XML | `BigBitXML.bas` | importujemo | proprietary XML | manuelno |
| BIG TEHN podaci legacy | `ImportIzBB_Module` (`DodajNoveKomitenteIzBigBita`, `DodajNovePredmeteIzBigBita`, `DodajNoveProdavceIzBigBita`, `DodajNoveArtikleIzBigBita`) | importujemo | DAO iz spojene baze | po potrebi |
| TXT/CSV/XML generic export | `ExportTXTCSVXML` (969 linija) | exportujemo | konfigurabilno | manuelno |
| KEPU XML eksterno | `IFExportXML_AG`, `IFExportCSV` | exportujemo | XML/CSV | mesečno |
| Vule Market | `VULEMARKET_*` queries (10) | dvosmerno | SQL ETL | manuelno |
| Jugolek | `JUGOLEK_*` queries (7) | importujemo | SQL ETL | manuelno |
| Servoteh interni | `SERVOTEH_*` queries (4) | importujemo | SQL ETL | manuelno |
| GR_ klijent | `GR_*` queries (30) | dvosmerno | SQL ETL | manuelno |
| DX_ klijent | `DX_*` queries (13) | dvosmerno | SQL ETL | manuelno |
| PSR_ klijent | `PSR_*` queries (15) | dvosmerno | SQL ETL | manuelno |
| PSF klijent | `PSF_*` queries (4) | dvosmerno | SQL ETL | manuelno |
| PG_ ETL | `PG_Prepisi_*` (4) | dvosmerno | SQL | manuelno |

**Pattern interpretacije klijent-prefiksa:** vendor je razvijao QMegaTeh kao **multi-klijentsku platformu**, gde su klijenti morali da migriraju sa starih sistema (Big Bit / BB_T_25, Jugolek, VuleMarket, drugi). Svaka serija upita sa `[KLIJENT]_Prenesi*` je jednokratan ETL korišćen pri inicijalnoj migraciji za tog klijenta. Posle migracije se ne koristi, ali je ostavljen u kodu za istoriju.

Servoteh-specifični upiti (`00_PrenesiTrebovanja_SERVOTEH`, `00_PrenesiProdavce_SERVOTEH`, `00_prenesiStavkeTrebovanja_SERVOTEH`, `07_PrenesiRobnaDokumenta_SERVOTEH_SVE`, `08_prenesiRobneStavke_SERVOTEH`, `SERVOTEH_DodajKomitente`, `SERVOTEH_Klijent`, `SERVOTEH_PrenesiArtikle`, `SERVOTEH_ProknjiziDonosPoPopisu`) su konkretni ETL koraci kojima je Servoteh-ov stari `BB_T_25.MDB` migriran u QMegaTeh / SQL `QBigTehn`.

### 9.1 ETL serija po brojevima (redosled migracije)

```
000_  – Provera (validacija)
00_   – Master data: Cenovnici, KEPU, Magacini, OS, PDV, Popisi, Predmeti, Prodavci,
        Recepti, Trebovanja, TrgovackaKnjiga, UplatniRacuni, VrsteNaloga
01_   – Komitenti
02_   – Kontni plan
04_   – Nalozi GK (sa i bez Level-a)
05_   – Stavke GK
06_   – R_Artikli (master katalog robe)
06a_  – Cenovnici po vrsti
06b_  – Update poreza
06c_  – Popravka MP cena
07_   – Robna dokumenta (zaglavlja)
08_   – Robne stavke
10_   – Usluge dokumenta
11_   – Usluge stavke
12_   – Radni nalozi
14_   – MP dokumenta
15_   – MP stavke
```

Ovo je **referentan redosled** za bilo koju buduću migraciju — DDL constraint-ovi i FK-ovi na SQL-u zahtevaju ovaj redosled.

---

## 10. UI sloj — forme i izveštaji

### 10.1 Forme — kategorije

Aplikacija ima **231 formu**. Nazivi su uglavnom u srpskom, sa CamelCase i bez razmaka (uz nekoliko izuzetaka kao "Prva maska", "Pregled komitenata").

#### Sistemske forme (boot, sigurnost, administracija)
- `Intro` — splash sa progres logom
- `Zastita` — hardware lock dialog
- `UnosPassworda` — POS PIN dialog
- `Baze`, `Baze_APL`, `Baze_Firme`, `Baze_Tipovi_APL`, `Form_BazeITabele`, `Form_BazeITabele-Podforma`, `Form_BazeITabele_APL`, `Form_BazeITabele_Brisanje` — config baza
- `CNN`, `CNN_Access`, `CNN_List`, `CNN_SQL`, `Form_CNN_SQL` — connection management
- `Form_BBPravaPristupa` — autorizacija
- `IzaberiFirmu` — multi-tenant izbor
- `Izbor radnog fajla` — wizard za selekciju lokal CFG-a
- `BB_UsersQuery` — admin pregled korisnika
- `BBBackup`, `BBExport`, `BBImport` — admin tooling
- `BBQueryDef`, `BBQueryDef_Pregled`, `BBQueryParDef` — meta-tooling za query-je
- `BBTools`, `BBExtra`, `BBAll`, `BBInfo`, `BBDetectIdleTime` — utility
- `frmRibbonOnForm`, `Form_RibbonOnClickDetails`, `frmUSysRibbons` — Ribbon (Office 2010+ traka) konfiguracija
- `_AppRev` — administrativna verzija/revizija aplikacije

#### Konfiguracija
- `CFGReadWrite`, `CFG_DozvoljeneVrednosti`, `CFG_Global`, `CFG_KatParPrip`, `CFG_Lokal`, `CFG_SviParametri_DEF`, `CFG_Sys`

#### Glavne radne forme
- `Prva maska` (4 varijante: glavna, `_BB`, `Magacin`, `Pregledi`) — root meni
- `QPrvaMaska` — query-driven meni
- `PrvaMaskaKonobar` — POS root
- `Form_UnosRN` — unos radnih naloga (1328 linija — najveća forma)
- `Form_RNPregled*` (8 varijanti) — pregledi naloga
- `Form_Predmeti`, `Pisarnica*` — predmeti
- `MRP_*` (10 formi) — material planning
- `PDM*` (15+ formi) — product data
- `Primopredaja*` (7 formi) — workflow između tehnologa, proizvodnje, kontrole
- `Pregled*` (15+ formi) — sve preglede
- `Specifikacija*` (5 formi) — nabavka
- `BarKod_*` (3 forme) — bar-kod radne stanice
- `Kreiranje*`, `IzborNalogaZa*`, `IzborPostupakaZa*` — wizard-i
- `Planer*` (4 forme) — terminski planer

#### Pregledne / dashboard forme
- `Form_AnalizaAktivnosti` — KPI dashboard
- `RNPregled*`, `MRP_Pregled*`, `PregledPo*` (puno formi za različite uglove)
- `Form_LokacijaSvihNapravljenihDelovaPoRN` — gde su delovi fizički
- `Form_GdeSeCrtezKoristi` — reverse lookup (where-used) za PDM
- `Form_RazlikeIzmedju_tRN_tTehPostupak` — debug/compare alat

#### "Reklamni paneli"
13 formi `Form_ReklamniPanel*` — najverovatnije ekrani za info-displeje u radionici (TV monitor sa rotacijom slika/poruka). `Form_ReklamniPanel_LogIn` je login overlay.

#### Tehničke / debug / dev forme
- `Form_TestForm` — test
- `Form_Form2` — placeholder
- `Form_Copy Of PDMTreeView` — backup
- `_AppRev` — verzija
- Forme sa prefiksom `frm` (lowercase, npr. `frmUSysRibbons`, `frmGrupe`, `frmPozicije`, `frmKriticniPostupci`) verovatno noviji refactor

### 10.2 Izveštaji (26 ukupno)

Svi izveštaji su na originalnom Access Report engine-u, štampaju se na windows printer (kontrolisano kroz `PRNModul`):

```
DigitronREPORT, DnevnaKnjiga, DostavnaKnjiga, OmotZaPredmet,
PregledPoPostupcima_Zbir, PregledPrimopredaja, PregledZavrsenihPredmeti,
RNPregled, RNPregledPoRJ, RNPregledPoRadniku,
rRN, rRN_BezBarKoda, rRN_NovaKontrola_NeKoristiSe, rRN_SaSlikama,
rRN_SaSlikamaPodReport, rRN_SaSlikama_NovaKontrola_NeKoristiSe,
rRN_tKomponente, rRN_tNDKomponente, rRN_tPDM, rRN_tPLP, rRN_tPND,
barkod_IDkarticaRadnika, barkod_StartStop,
rPDM-jedan, rPND-jedan,
_Copy Of rRN
```

**Konvencije:**
- `rRN_*` su sub-reporti za `rRN` glavnu (master-detail)
- Sufiks `_NeKoristiSe` znači zastareli izveštaj koji niko ne treba da otvara, ali nije obrisan
- `_Copy Of` je tipičan Access "duplicate" — ostalo nakon copy-paste; treba pregledati i obrisati ako se ne razlikuje

### 10.3 SaveAsText format formi i izveštaja

Sve forme i izveštaji su izvezeni u `Moduli_Tekst/` folderu kroz `SaveAsText` Access API. Ti `.txt` fajlovi sadrže kompletnu UI definiciju (kontrole, pozicije, propertije, događaje, code-behind reference). Mogu se uvesti nazad sa `LoadFromText` u prazan `.mdb`. Folder `Forme/` i `Izvestaji/` sadrže paralelno sve resurse.

---

## 11. Konvencije i obrasci u kodu

### 11.1 Imenovanje
- **Tabele:** `t<NazivLowercase>` za radne (`tRN`, `tRadnici`, `tLokacijeDelova`); `T_<Naziv>` za major dokumente (`T_Robna dokumenta`); `MSys*` su Access internal; `CFG_*` za konfiguraciju; bez prefiksa za reference podatke (`Komitenti`, `R_Artikli`, `Magacini`)
- **Forme:** Code-behind je u klasi `Form_<ImeForme>` (Access automatski). Ime forme je čitljivo srpsko ili CamelCase
- **Izveštaji:** prefix `r` (lowercase) za detaljne (`rRN`, `rPDM-jedan`); pune srpske reči za top-level (`DnevnaKnjiga`, `OmotZaPredmet`)
- **Moduli:** kategoriski prefiks (`BB`, `LIB_`, `ADO_`, `RN_`, `PDM_`, `MRP_`, `Form_`, `Report_`) ili pun srpski naziv (`Komitenti`, `Cene`, `Kamate`, `Proizvodnja`)
- **Funkcije:** `KreirajX`, `DodajX`, `UpisiX`, `PrikaziX`, `F_X` (često za boolean/scalar getter), `sp<Name>` za one koje pretežno rade serverski (stored-proc style), `ftX` za "function table" UDF-ove na SQL-u
- **VBA klase za state:** `<Tip>_Class` (`RN_Class`, `PDM_Class`, `IF_Class`)
- **Globalne instance:** kratka skraćenica (`RNP`, `IFP`, `UFP`, `USLF`, `BBCFG`, `BBTehn`, `IFP`, `EmailClass`)

### 11.2 Error handling pattern

Tipičan pattern u celoj aplikaciji:

```vba
Public Function NekaFunkcija(...) As Boolean
On Error GoTo Err_Point
    ' main logic
    NekaFunkcija = True
Exit_Point:
    ' cleanup (ako treba)
    Exit Function
Err_Point:
    NekaFunkcija = False
    ' opciono: BBMsgBox_BigBit Err.Description ili Debug.Print
    Resume Exit_Point
End Function
```

Postoji i `On Error Resume Next` lokalno gde je tolerance prema NULL-u potrebna (npr. `ReadParametar` rezultati). Greške se ne loguju centralno — što je tehnički dug.

### 11.3 Transakcije

Najveći deo INSERT/UPDATE rada se ne radi u eksplicitnim transakcijama, oslanja se na implicitnu auto-commit semantiku. Za kritične operacije (npr. kreiranje dokumenta sa stavkama) se koristi DAO BeginTrans / CommitTrans / Rollback ili — u novijim koracima — SQL stored procedure-i sa T-SQL transakcijama (`sp*` funkcije).

### 11.4 Datumi i locale

- VBA `Date` tip se koristi nativno (double precision)
- Format za prikaz: `dd.mm.yyyy` (RS standard) — kontrolisano `RegionalSettings.bas`
- Format u SQL-u: `SQLFormatDatuma()` u `ADO_Module` formatira u T-SQL kompatibilan
- Funkcije `IzDatumaMesecIDan`, `ObrniDatum`, `ObrniVelikiDatum` — za string konverzije

### 11.5 Currency vs Double

`Currency` tip (4 decimale, fixed-point) se koristi za novčane iznose. `Double` za količine i kurseve. `BBCFG.BrDecUlKl` i `BrDecIzKl` kontrolišu broj decimala u klijentskim cenama.

### 11.6 String escape i SQL injection

`ADO_Module.SQLFormatVreme/Datuma/Boolean`, `CheckFieldToSQL`, `stR()` (string-required, dodaje apostrofe), `AccesArgToSQL` su escape funkcije. **Nedosledno se koriste** — ima mesta gde se string vrednosti ubacuju direktno bez escape-a (potencijalni SQL injection u nekim formama). Pri bilo kakvoj reviziji za web/cloud — sve takve mesta moraju da prođu na parametrizovane query-je.

### 11.7 Globalne varijable kao "ad-hoc parameter passing"

Vendor-ova konvencija je da se umesto eksplicitnog prolaska parametara kroz funkcije, koriste globalne `Public` varijable (`IzabraniArtikal`, `IzabraniRadnik`, `IzabraniPostupak`, `KbdEditCtl`, `KbdEditForm`, `MyAnswer`, `LikeFilter`, `ProzorUSvet`). Forma A postavi globalu, otvori formu B, B čita globalu. Pattern radi ali je krhak — dva paralelna otvorena dijaloga se gaze.

### 11.8 Hard-coded korisnik `Negovan`

Funkcija `Zastita.DozvoljenoPostavljenjeZastite` proverava `If CurrentUser = "Negovan"`. `BBStart` ima posebnu granu `If CurrentUser() = "Negovan" Then` za prikaz error message-a. `Negovan` je literal hardkodiran u kodu (admin-username u istorijskom ULS sistemu). Ovo je primer **klijent-specifičnog tightly-coupled koda** koji je trebalo da bude konfiguracioni parametar.

---

## 12. Tehnički dug i poznata pitanja

### 12.1 Suffiksovani moduli (ostaviti / brisati)

| Sufiks / Prefiks | Značenje |
|---|---|
| `_OLD`, `_NeKoristiSe`, `_NETREBA` | Stara verzija, zadržana radi reference. Ima li je u code path-u? Najčešće NE — može se obrisati uz inspekciju |
| `_NOVI` (bez `_OLD` para) | Aktuelna verzija; pratećeg `_OLD`-a verovatno nema u izvozu jer je obrisan |
| `_TEST*`, `_Test`, `_Test1`, `_TEST_MOJ` | Razvojni scratch — sigurno za brisanje |
| `Module1`, `Module2` | Default Access imena, neimenovani moduli — ako nemaju kod, brisati. Vidi `wc -l` izlaz |
| `Form2`, `TestForm` | Isto — verovatno mrtvi |
| `Copy Of *` | Duplikati posle copy-paste — pregledati i konsolidovati |

Konkretno za brisanje (nakon code-review verifikacije da se nigde ne pozivaju):

```
_Test, _TEST1, _TEST_MOJ, _AppRev (forma), Module1, Module2,
PassTroughQueryMakeSQLTextFromTDef_NETREBA,
DX_PopraviNabavneCene_NE,
ForsirajNoveLinkoveZaTipBaze_NETREBA_20102021,
Form_Copy Of PDMTreeView, Form_Form2, Form_TestForm, Form_ReklamniPanel1_,
rRN_NovaKontrola_NeKoristiSe, rRN_SaSlikama_NovaKontrola_NeKoristiSe,
_Copy Of rRN
```

### 12.2 Nedosledni format datuma u code path-u

Negde se koristi `Date` tip nativno, negde se proslijedi kao string `"dd-mm-yyyy"`, pa se konvertuje. Naročito u SP pozivima — vidi inline komentare u `BBKreiranjeDokumenata`. Ova inkonzistencija je bug-prone: testirati sa srpskim Windows locale-om obavezno.

### 12.3 `On Error Resume Next` u kritičnim mestima

`Dnevnik.UpisiUDnevnik` ima `On Error Resume Next` na vrhu — ako audit log fail-uje, niko nikad ne sazna. Ako pravimo novi sistem — proveriti da minimalno log-ujemo na drugu lokaciju (file system) kad SQL fail-uje.

### 12.4 Tabele sa razmacima u imenima

`T_Robna dokumenta`, `Pregled komitenata`, `Unos komitenata`, `Otvorene stavke`, `Bliski susret`, `Izbor radnog fajla`, `Lager lista`, `Kartica TehPostupka - Podforma` itd. Razmaci u Access-u su tehnicki podržani ali se moraju encapsule-irati u brackets `[T_Robna dokumenta]`. Pri migraciji u bilo koji moderni framework — preimenovati u snake_case ili camelCase.

### 12.5 Hardware-locked zaštita (Zastita)

Vendor je verovatno hteo da zaštiti kod od kopiranja klijenata. Sad kad je vendor van slike, ova zaštita radi protiv samog vlasnika (Servoteh-a). Treba je trajno disable-ovati u `Zastita.bas`:

```vba
Public Function Zasticen() As Boolean
    Zasticen = False   ' bilo šta drugo se rezultuje gašenjem aplikacije
End Function
```

I obrisati `If Zastita.Zasticen Then QuitBigBit` u `BBStart`.

### 12.6 SQL šifra u plain-text-u u .mdb properties

Već pomenuto — promeniti i u idealnom slučaju preći na Windows Authentication.

### 12.7 Neefikasno ekspandovanje BOM-a u VBA

Modul `PDM_Common` rekurzivno ekspanduje BOM u VBA petljama umesto da koristi T-SQL recursive CTE. Za velike sklopove (4 nivoa duboko) ovo može biti sporo. Postoji ftPDMSklop UDF na SQL-u koji bi bio brži (`ODBC_ftPDMSklop` query) — verovatno je delimično prebačeno ali ne svuda.

### 12.8 `Zakljucavanje` modul i row-level lock-ovi

Modul `Zakljucavanje.bas` (zaključavanje radne tabele po RN-u, postupku, magacinu) implementira aplikacijski row-level lock kroz tabele `RNZakljucan*`, `RobaZakljucana`, itd. Ovo je workaround za Access-ov optimistic concurrency. Ako se migracija radi — pravi serverski lock-ovi (T-SQL row locks ili aplikacijski Redis lock manager) bolji su.

### 12.9 "Bliski susret" — moglo bi da bude bolje ime

Modul `Bliski susret.bas` (1130 linija) je u stvari **glavni dispatch i config layer** (definiše `Postavi_CFG_T_Tabele`, `PostaviGlobalneParametre`, `IDProdavacZaCurrentUser_BigBit`, kao i sve `F_*` getter funkcije). Ime je vendor-ova šala (filmska referenca). Pri rewrite-u — `AppDispatch` ili `BootstrapModule` smislenije.

---

## 13. Forenzička istorija — kako smo došli do koda

(za buduće generacije: ovo je važno da se ne ponavlja)

1. **Polazno stanje (april 2026):** Servoteh ima `BB_T_25.MDB` (legacy magacin) i pristup QMegaTeh aplikaciji koja je već u SQL Server arhitekturi. Vendor i dalje aktivno održava aplikaciju, ali Servoteh kao vlasnik donosi strateški odluku da je tehnološka osnova (Access front-end nad Jet/SQL backendom) zastarela i da dugoročno nije isplativo ulagati u nju. Pojavljuje se potreba da se sav VBA kod izvuče za dokumentaciju i potencijalnu replatformizaciju.

2. **Zaštita 1: ULS (workgroup security)** — `BIGBIT.MDW` workgroup file, primarni admin nalozi (po broju ACE-ova) `Slavisa` i `Negovan`. Bez login-a niko ništa ne vidi. Skinuto sa **Thegrideon Access Forensics 2025-08-08**, opcija "Remove User-Level Security". Izlaz: `.mdb` koji se otvara bez prompt-a.

3. **Zaštita 2: VBA Project Password** — DPB marker u binaru. Thegrideon verzija ne pokriva VBA password (to je odvojen Thegrideon-ov proizvod). Skinuto klasičnim **DPB hex-patch** trikom: zamena slova "B" u "x" u `DPB="..."` markeru pa Access reaguje kao da je hash invalidan i pušta otvaranje VBA editora; potom `Tools → VBAProject Properties → Protection → Lock=off` i sačuvati.

4. **Izvoz koda** — kreirani VBA snippet `IzveziSveModule` koji koristi `Application.SaveAsText` i `vbc.Export` API, izvozi 454 modula (~92.633 linija) + 197 SaveAsText fajlova formi/izveštaja + 404 SQL-jeva + 36 izveštaja sa svim resursima. Ukupno ~132 MB, organizovano u `Izvoz/{VBA, Forme, Izvestaji, Upiti, Makroi, Moduli_Tekst}`.

5. **Otkriće SQL Server-a** — analizom CSV izveštaja iz Forensics-a (`QBigTehn_APL_properties.csv`) otkriveno je da connection string-ovi u plain text-u upućuju na `Vasa-SQL,5765` SQL Server, što je promenilo plan: glavni podaci nisu u .MDB nego na server-u, .MDB je samo front-end.

6. **Postojeći SQL backup** — Servoteh već ima backup SQL-a i pristup; pomoćni MDB-ovi (`BB_CFG_Lokal`, `BB_FIT`, `BB_TMP`) takođe sačuvani.

7. **Trenutni status (april 2026):** kompletna aplikacija je u read-only formi dostupna kod Servoteh-a, sa kompletnom dokumentacijom (ovaj dokument). Originalni produkcijski `.MDB` ostao netaknut na serveru — radili smo isključivo nad kopijom.

---

## 14. Preporuke za buduću evoluciju sistema

### 14.1 Ako se aplikacija zadržava (read-only ili minor maintenance)

1. **Backup strategiju formalizovati:** SQL FULL backup nedeljno + diferencijalni dnevno + transaction log na sat. Backup `.mdb` fajlova svaki put pre ručne intervencije
2. **Promeniti SQL šifru** i prebaciti je iz plain-text-a u (idealno) Windows Authentication
3. **Disable Zastita** (sekcija 12.5)
4. **Dokumentovati trenutne korisnike i njihovu rolu** — ULS sad ne radi, treba mapping `WindowsUser → AppRole` na novom mestu
5. **Monitor `Dnevnik` tabelu** za neočekivane error pattern-e, periodicno pregled

### 14.2 Ako se planira replatformizacija (web / cloud)

**Šta vredi zadržati / migrirati u novi sistem:**
- SQL Server backend kao izvor istine (ne menjati šemu odmah, prebaciti samo presentation layer)
- Sav `00_Prenesi*` ETL kao referenca za migraciju
- POPDV mapiranje (`POPDV_DEF` tabela + `POPDV_Module` logika) — to je domenski znanje koje teško ponovo izgraditi
- Tehnološki postupci, PDM hijerarhija sklopova, RN workflow — to su Servoteh-ove poslovne procedure
- Kontni plan i sema za kontiranje (`SemaZaKontiranje`)
- Dnevnik audit log

**Šta odmah baciti:**
- Hardware-locked zaštita
- Kafe POS modul (verovatno se ne koristi)
- Sve `_OLD`, `_NeKoristiSe`, `_TEST*` module
- Globalne varijable kao parameter-passing — refaktorisati na pravi DI
- `Bliski susret` ime modula (preimenovati pri portu)
- Hardkodirano `Negovan` ime u `Zastita`

**Migracioni plan u 4 faze:**
1. **Schema migracija:** SQL Server šemu prevesti u Postgres šemu (snake_case, čišćenje razmaka u imenima, CHECK constraints, FK gde nedostaju)
2. **Mirror faza:** novi sistem čita iz Postgres baze (read-only) sa sync-ovanim podacima iz BigBit-a, validira da prikazuje iste vrednosti kao Access
3. **Cutover proizvodnih flowova:** RN, PDM, MRP — Servoteh korisnici prelaze na nov sistem; QMegaTeh ostaje paralelno za nedeljama da se uhvati svaki edge case
4. **Gašenje QMegaTeh-a:** posle stabilnog perioda, QMegaTeh se gasi. BigBit ostaje za knjigovodstvene operacije sa sync-om u nov sistem

**Tehnološki stack — odluka Servoteh-a (april 2026):**
- **Database:** PostgreSQL self-hosted na Servoteh serveru (umesto SQL Server-a). Razlog: open-source, bez licencnih troškova, IT operacija već ima infrastrukturu, suverenitet podataka. Postgres šema je projektovana tako da kasnije može da se ugradi u Supabase sloj (REST API, auth, storage) bez migracije podataka, ako se ukaže potreba
- **Backend:** opcija ostavljena otvorena (zavisi od izbora razvojnog tima)
- **Frontend:** opcija ostavljena otvorena
- **Auth:** Active Directory / Microsoft Entra ID za SSO sa Servoteh domenskim nalozima
- **Sync layer ka BigBit-u:** SQL Server linked server iz Postgres-a ili periodični ETL job — definisaće se pri implementaciji
- **BI/izveštaji:** Power BI ili Metabase za pregledne dashboard-e umesto Access izveštaja

### 14.3 Ako se zadržava kao spomen-aplikacija (čisto za pristup istoriji)

1. Snimiti Win10/Win11 VM sa instaliranim Office 2010 + Access
2. U toj VM-i držati `.mdb` + lokalnu kopiju SQL Express baze sa restored backup-om
3. VM zapakovati i čuvati offline kao "vremenska kapsula"
4. Dokumentovati ovaj snapshot u IT registru

---

## 15. Reference

- **Vendor identitet:** BIT CO. ("BigBit"), workgroup ID `BIGBIT224163`
- **SQL Server konekcija:** `tcp:Vasa-SQL,5765`, baza `QBigTehn`, login `QBigTehn` / `QbigTehn.9496` *(promeniti pre produkcije!)*
- **Front-end .mdb:** `C:\SHARES\SERVOTEH\QBigTehn\` (~ ime BB_T_25.MDB ili QBigTehn_APL.MDB zavisno od instalacije)
- **Izvor podataka za ovu dokumentaciju:** `Izvoz.zip` koji sadrži 454 VBA modula (3 MB), 404 SQL upita (323 KB), 197 SaveAsText form/report definicija (2 MB), 36 izveštaja sa resursima (100 MB), 236 forma sa resursima (28 MB), 2 makroa (32 KB) — ukupno ~132 MB
- **Forensics izveštaji:** `QBigTehn_APL_{properties,security,tables,vba_modules}.csv` iz Thegrideon Access Forensics 2025-08-08
- **Korišćeni alati pri ekstrakciji:** Thegrideon Access Forensics (ULS removal), HxD hex editor (DPB patch), MS Access 2010 (VBA editor i `Application.SaveAsText`)

---


## 16. Genealogija aplikacije — od BigBit-a do QMegaTeh-a

Ovo poglavlje je dodato u drugoj iteraciji dokumentacije, nakon što je analizom koda postalo jasno da je QMegaTeh **fork** prethodne aplikacije (BigBit) koja postoji nezavisno i nezavisno se održava. Ova distinkcija je važna jer objašnjava strukturu koda, postojanje "viška" funkcionalnosti i — što je presudno za bilo koju buduću zamenu — **integracioni model** kojim QMegaTeh zavisi od BigBit-a.

### 16.1 Dva proizvoda, jedan codebase

**BigBit** je originalni ERP sistem vendor-a `BIT CO.` (workgroup ID `BIGBIT224163`). Razvijan najverovatnije od ranih 2000-ih, primarno za segment maloprodaje, ugostiteljstva (kafići/restorani sa konobarima i stolovima), i klasičnog srpskog SME knjigovodstva (kontni plan, KEPU, POPDV, fakturisanje, fiskalizacija). U svojoj zreloj fazi BigBit je migriran sa čistog Access backend-a na Access front-end + SQL Server backend.

**QMegaTeh** je **derivativni** proizvod koji je za Servoteh napravljen tako što je BigBit codebase uzet kao osnova i nadograđen modulima za proizvodnju, radne naloge, tehnološke postupke, PDM (konstrukcionu dokumentaciju) i MRP (planiranje materijala). QMegaTeh i BigBit su **nezavisni proizvodi koji aktivno koegzistiraju** kod Servoteh-a — BigBit i dalje nosi knjigovodstvo, fakture, PDV, magacin i POS funkcionalnosti, dok QMegaTeh nadgrađuje proizvodni sloj iznad njega i sync-uje master data iz njega.

**Servoteh-ova relacija sa vendor-ima oba proizvoda je aktivna i podržana** — ova dokumentacija je tehničko-arhitektonski opis sistema iz Servoteh-ove perspektive vlasnika i operatera, namenjena buduće interne zamene proizvodnog sloja (QMegaTeh) modernim sistemom koji će se na isti način kačiti za izvor master podataka.

### 16.2 Tvrdi dokazi iz koda

| Dokaz | Lokacija | Šta govori |
|---|---|---|
| Modul `RunExtBigBit_Module.bas` | VBA | QMegaTeh može da pokrene BigBit kao zasebnu aplikaciju komandom `RunExtBigBit("/CMD GKNalog")`, što znači da kad korisniku treba GK nalog — QMegaTeh ne radi knjiženje sam, nego prosleđuje BigBit-u |
| Funkcije `Dodaj*IzBigBita` | `ImportIzBB_Module.bas` | `DodajNoveKomitenteIzBigBita`, `DodajNovePredmeteIzBigBita`, `DodajNoveProdavceIzBigBita`, `DodajNoveArtikleIzBigBita` — sve bukvalno povlače master data iz BigBit-a |
| Linked tabele `EXT_*` | preko 12 tabela | `EXT_Komitenti`, `EXT_Predmeti`, `EXT_Prodavci`, `EXT_R_Artikli`, `EXT_R_Tarife`, `EXT_R_Grupa`, `EXT_Magacini`, `EXT_T_Robna dokumenta`, `EXT_T_Robne stavke`, `EXT_T_Trebovanja`, `EXT_ZahteviZaNabavku`, `EXT_SpecifikacijaZahtevaNabavke`, `EXT_Vrste sifara` — sve linkovi ka BigBit bazi |
| `BazaZaTip("BigBit_T")` | više modula | "BigBit_T" je formalni "tip baze" u registry-ju aplikacije — pored njega postoje `MasterDB`, `EXTBAZA`, `TMP`, `FIT`, `BB_T_25`. Komentar u kodu: *"Ako nije definisana baza MasterDB, onda je to CurrentDatabase, tj. BigBit_T"* |
| `BBCFG.PrebaciKomitenteIzEXTBaze` / `PrebaciPredmeteIzEXTBaze` | `BBCFG_Class.cls` | CFG flagovi (kreirano 19-06-2024) za uključivanje/isključivanje sync-a master data iz BigBit-a pri startu |
| `RibbonModule.PreuzmiIzBigBitaRibbon` + `PreuzmiIzBB` | VBA | I Ribbon UI (Office 2010+ traka sa dugmadima) se može povući iz BigBit-a — vendor je svesno hteo da BigBit ostane "master" za izgled |
| `Public Const ProgName = "BigBit"` | `Zastita.bas` | Hardware-locked zaštita identifikuje program na ciljnoj mašini kao "BigBit" čak iako je QMegaTeh — kopirano iz BigBit-a i nikada nije rebrandirano |
| `Const RegGrana = "Software\BitCo\"` | `Zastita.bas` | Windows Registry license grana je `Software\BitCo` (BIT CO. = Slavisina firma), što je zajedničko za BigBit i QMegaTeh |
| Putanje u komentarima | razna mesta | `C:\SHARES\AcBaze\BigBit\BigBit_APL_2010.MDB`, `C:\SHARES\AcBaze\BJovanovic\BigBitTG\TG\BB_BT_TG.MDB`, `C:\SHARES\TGroup\AcBaze\BigBitTG\BB_FIT.mdb` — tragovi prethodnih BigBit instalacija kod drugih klijenata |
| `Form_Prva maska_BB.cls` | UI | Postoji posebna "BigBit varijanta" startne forme — paralelno sa `Form_Prva maska` koja je QMegaTeh-ova |
| Tri paralelna identitetska sistema | tabele | `Prodavci` (BigBit POS sa `Sifra prodavca`, `Password`, `NefiskalniRN`, `Storniranje`), `Konobari` (BigBit HoReCa sa `IDKonobar`), `tRadnici` (QMegaTeh proizvodnja sa `SifraRadnika`, `PasswordRadnika`) — svaki za svoj domen |
| Funkcije sa `_BigBit` sufiksom | razno | `BBMsgBox_BigBit`, `IDProdavacZaCurrentUser_BigBit`, `BigBit_UID`, `F_BigBitReklama`, `stSQL_Append_VrsteKomitentaIzBigBita`, `QuitBigBit` — eksplicitan namespace za stvari koje pripadaju BigBit-u |

### 16.3 Procena raspodele koda po slojevima

Na osnovu analize, gruba procena raspodele 92.633 linija VBA koda po slojevima:

| Sloj | LOC | % | Klasifikacija |
|---:|---:|---:|---|
| BB framework (zajednički core) | ~12.000 | ~13% | BigBit nasleđe |
| Knjigovodstvo, GK, KEPU, POPDV | ~8.500 | ~9% | BigBit nasleđe |
| Maloprodaja (POS, fiskal, kase) | ~6.500 | ~7% | BigBit nasleđe |
| HoReCa (Kafe, Konobari, stolovi) | ~3.500 | ~4% | BigBit nasleđe |
| Komitenti, cene, kamate, otvorene stavke | ~5.500 | ~6% | BigBit nasleđe |
| Eksterne integracije (Halcom, Galeb, Sopot, Bosson) | ~4.500 | ~5% | BigBit nasleđe |
| Banking, e-faktura, XML export | ~3.500 | ~4% | BigBit nasleđe |
| Numeracija, dokumenti, generic ERP utils | ~6.500 | ~7% | BigBit nasleđe |
| **— UKUPNO BigBit nasleđe —** | **~50.500** | **~55%** | **BigBit** |
| Radni nalozi (RN) | ~6.500 | ~7% | QMegaTeh nadogradnja |
| PDM (konstrukcioni crteži, BOM) | ~5.500 | ~6% | QMegaTeh nadogradnja |
| MRP (planiranje materijala) | ~3.500 | ~4% | QMegaTeh nadogradnja |
| Tehnološki postupci, primopredaje | ~5.500 | ~6% | QMegaTeh nadogradnja |
| BigBit↔QMegaTeh integracioni sloj | ~3.500 | ~4% | QMegaTeh nadogradnja |
| Forme i izveštaji za proizvodnju | ~12.000 | ~13% | QMegaTeh nadogradnja |
| Modifikacije/ekstenzije BB framework-a | ~5.500 | ~6% | QMegaTeh nadogradnja (radi u nasleđenom kodu) |
| **— UKUPNO QMegaTeh nadogradnja —** | **~42.000** | **~45%** | **QMegaTeh** |

**Procene su grube** — više od 100 modula bi trebalo svaki pojedinačno pregledati i klasifikovati po stilu kodiranja, datumima u komentarima, i prefiksima. Ali red veličine je verodostojan: **slično pola-pola po obimu, ali kvalitativno potpuno drugačije** — BigBit deo je generic ERP koji je deo posebnog proizvoda, QMegaTeh deo je tailor-made za Servoteh.

**Praktičan značaj ove podele za buduću zamenu:** za novi sistem koji bi zamenio QMegaTeh, samo ~45% koda je relevantan kao referenca šta sistem treba da radi. Preostalih ~55% (BigBit nasleđe) nije meta zamene — to ostaje u BigBit-u kao posebnom sistemu.

### 16.4 Posledice za buduću zamenu

Najvažnija praktična implikacija ove genealogije je da **buduća zamena QMegaTeh-a NIJE jedan projekat — već dva, sa različitim prioritetima**:

**Projekat A: Zamena proizvodnog dela (~14% realno potrebnog koda)**
- Sve QMegaTeh-native funkcionalnosti: RN, PDM, MRP, tehnološki postupci, primopredaje
- Ovo Servoteh **mora** da radi, jer je proizvodnja core-business
- **Integracija ka master-data izvoru je ključno pitanje** — koji god novi sistem zameni QMegaTeh, mora da se kači na BigBit (kao izvor komitenata, artikala, tarifa, dokumenata) na isti način kao što se trenutno kači

**Projekat B: Zamena/migracija knjigovodstvenog dela (BigBit nasleđe)**
- Knjigovodstvo, fakture, PDV/POPDV, KEPU, fiskal, banking, komitenti — sve to ostaje u BigBit-u kao zaseban sistem
- BigBit i dalje aktivno funkcioniše i podržan je od strane svog vendor-a
- Servoteh nema potrebu da menja BigBit u doglednoj budućnosti — samo proizvodni sloj iznad njega

**Posledica za projektovanje novog sistema:** novi proizvodni sistem mora da tretira BigBit kao "**source of truth za master data**" i da implementira sync layer (vidi sekciju 16.5). Knjigovodstveni events koji su rezultat proizvodnje (npr. konzumacija materijala iz magacina, otvaranje radnog naloga) se i dalje šalju u BigBit za proknjiženje — kao i danas.

### 16.5 Master-data sync flow (BigBit → QMegaTeh)

Pošto je sync iz BigBit-a u QMegaTeh **jedina kritična integraciona tačka** koja se mora razumeti i replicirati u bilo kojoj zameni — ovde je detaljan opis.

**Konceptualni model:**

```
   ┌──────────────────────────────────┐
   │   BigBit (master sistem)         │
   │   Vendor: BIT CO.                │
   │   Tehnologija: Access + SQL      │
   │                                  │
   │   ┌────────────────────────┐     │
   │   │ Master tabele:         │     │
   │   │ - Komitenti            │     │
   │   │ - Predmeti             │     │
   │   │ - Prodavci             │     │
   │   │ - R_Artikli (katalog)  │     │
   │   │ - R_Tarife (PDV stope) │     │
   │   │ - R_Grupa (grupe rob)  │     │
   │   │ - Magacini             │     │
   │   │ - Vrste sifara         │     │
   │   │ - T_Robna dokumenta    │     │
   │   │ - T_Robne stavke       │     │
   │   │ - T_Trebovanja         │     │
   │   │ - ZahteviZaNabavku     │     │
   │   └────────┬───────────────┘     │
   └────────────┼─────────────────────┘
                │
                │ Access linked tables (EXT_*)
                │ DAO/ODBC konekcija po `BazaZaTip("BigBit_T")`
                │ Read-only iz QMegaTeh perspektive
                ▼
   ┌──────────────────────────────────┐
   │   QMegaTeh (slave + nadogradnja) │
   │   Frontend za Servoteh           │
   │   Tehnologija: Access + SQL      │
   │                                  │
   │   ┌────────────────────────┐     │
   │   │ EXT_* linked tabele    │     │
   │   │ (čiste linkove)        │     │
   │   └────────┬───────────────┘     │
   │            │                     │
   │            │ INSERT na uslov     │
   │            │ "WHERE QMegaTehTbl  │
   │            │  .Sifra IS NULL"    │
   │            ▼                     │
   │   ┌────────────────────────┐     │
   │   │ Lokalne kopije:        │     │
   │   │ - Komitenti            │     │
   │   │ - Predmeti             │     │
   │   │ - Prodavci             │     │
   │   │ - R_Artikli            │     │
   │   │ - R_Tarife             │     │
   │   │ - R_Grupa              │     │
   │   │ - Magacini             │     │
   │   │ - Vrste sifara         │     │
   │   └────────────────────────┘     │
   │                                  │
   │   QMegaTeh-native tabele:        │
   │   - tRN, tRN_Stavke, tTehPostup. │
   │   - PDM_Document, KomponentePDM  │
   │   - MRP_Potreba, MRP_PotrebaSt.  │
   │   - tRadnici, RadniciPoMasinama  │
   │   - Crtezi, Sklopovi, BOM        │
   └──────────────────────────────────┘
```

**Kako se sync dešava (operativni nivo):**

1. **Konfiguracija:** `BBCFG.PrebaciKomitenteIzEXTBaze` i `BBCFG.PrebaciPredmeteIzEXTBaze` su flagovi koji se čitaju iz `CFG_Global` tabele (per IDFirma). Ako su `True` — sync je aktivan. Ako su `False` — sync se preskače
2. **Linkovi:** pri startu (i pri `RefreshujLinkoveZaTipBaze("BigBit_T")` tokom rada), Access linked tables sa prefiksom `EXT_*` se osvežavaju. Putanja do BigBit baze se čita iz tabele `Baze` ili `RadniFajlovi` (`BazaZaTip("BigBit_T")`)
3. **Provera novih zapisa:** funkcije `Dodaj*IzBigBita` rade isti pattern:
   ```sql
   INSERT INTO Komitenti (kolone...)
   SELECT EXT_Komitenti.kolone...
   FROM EXT_Komitenti LEFT JOIN Komitenti ON EXT_Komitenti.Sifra = Komitenti.Sifra
   WHERE Komitenti.Sifra IS NULL
   ```
   Što znači: **upiši samo one zapise iz BigBit-a koji u QMegaTeh-u još ne postoje (po primarnom ključu)**
4. **Ručno pokretanje:** sync nije automatski na promene — pokreće ga korisnik klikom na dugme `btnPreuzmiIzBB` u Ribbon-u, koji zove `RibbonModule.PreuzmiIzBigBitaRibbon` → `PreuzmiIzBB` koji redom poziva sve `Dodaj*IzBigBita` funkcije
5. **Smer:** isključivo **jedno-smerno BigBit → QMegaTeh**. QMegaTeh nikad ne piše nazad u BigBit master tabele. (Postoji jedan izuzetak: `RunExtBigBit("/CMD GKNalog")` otvara BigBit GK formu i tu BigBit sam pravi nalog — ne QMegaTeh, ali on je inicijator)
6. **Konflikti:** šta ako Komitent sa istom Sifrom postoji u oba sistema sa različitim podacima? Trenutni kod **zanemaruje** tu mogućnost — `WHERE IS NULL` filter samo gleda primarni ključ, ne uporedjuje sadržaj. Update se nikada ne radi. Ako neko u BigBit-u promeni adresu komitenta posle prvog sync-a, QMegaTeh tu promenu nikada ne vidi. To je poznat tehnički dug

**Šta se sync-uje, šta se ne sync-uje:**

| Domen | Sync iz BigBit-a? | Komentar |
|---|---|---|
| Komitenti (kupci/dobavljači) | DA | One-time, samo novi |
| Predmeti (poslovni projekti) | DA | One-time, samo novi |
| Prodavci | DA | One-time, samo novi |
| Artikli (R_Artikli) | DA | One-time, samo novi |
| PDV tarife (R_Tarife) | DA | Read-only kroz EXT linkove |
| Grupe artikala (R_Grupa) | DA | Read-only kroz EXT linkove |
| Magacini | DA | Read-only kroz EXT linkove |
| Vrste šifara komitenata | DA | Sa specijalnim SQL append-om |
| Robna dokumenta (T_Robna dokumenta) | DELIMIČNO | Samo kroz `RobnaDokumentaMirror` mehanizam za PDM/MRP |
| Robne stavke | DELIMIČNO | Samo kroz `RobneStavkeMirror` |
| Trebovanja, Zahtevi za nabavku | NA-ZAHTEV | Linkovani EXT_*, čitaju se po potrebi, ne kopiraju |
| Knjiženje GK | NE | Otvara se BigBit eksterno za to (`RunExtBigBit "/CMD GKNalog"`) |
| Faktura izlazna | NE | Isto — BigBit radi |
| KEPU, POPDV | NE | BigBit radi |
| Cenovnici | NE | Iz BigBit-a se ne sync-uje, QMegaTeh ima sopstvene |
| Radni nalozi | NE | QMegaTeh-native |
| PDM/BOM | NE | QMegaTeh-native |

**Replikacija ovog sync-a u zamenskom sistemu:**

Bilo koji sistem koji bi zamenio QMegaTeh proizvodni deo (Projekat A iz 16.4) **mora da implementira ekvivalentan sync layer prema BigBit-u**. Servoteh-ova odluka je da BigBit ostane kao master-data izvor i dalje, što znači da nov sistem nasleđuje istu integracionu poziciju koju trenutno ima QMegaTeh — samo modernu implementaciju.

**Karakteristike sync layer-a koji nov sistem mora da implementira:**

- **Read-pristup** ka master entitetima u BigBit-u (komitenti, artikli, magacini, tarife, predmeti, prodavci) — najčistije rešenje je SQL Server linked server / read-only ODBC konekcija ka BigBit SQL bazi (BigBit već koristi SQL Server, ne mora ništa Vasinom kraju da se menja)
- **Inkrementalno povlačenje** — replicirati `LEFT JOIN ... WHERE PK IS NULL` pattern, ali sa unapređenjima (vidi E.6 problem 1-7 u Dodatku E)
- **Detekcija promena** — periodično polling po `LastModifiedTimestamp` koloni ili event-driven mehanizam ako BigBit baza dozvoli SQL triggere
- **Detekcija brisanja** — soft-delete propagacija (vidi E.6 problem 2)
- **Konflikt rezolucija** — definisana strategija po polju (npr. "BigBit-ov PIB uvek pobeđuje", "lokalna izmena prodavca pobeđuje BigBit-ovu"). Upisuje se u sync log
- **Audit log** — kada, ko, koji entitet, koliko zapisa, koje greške
- **Write-back** — za retke slučajeve kad proizvodnja kreira entitet koji master mora da zna (npr. nov kupac otkriven kroz proizvodni RN — to bi moralo da ide nazad u BigBit). Trenutni QMegaTeh ovo ne podržava, novi sistem treba

---

## 17. Pregled tehničkog duga koji NIJE specifikovan ovde

Ova dokumentacija identifikuje **klase** tehničkog duga (sekcija 12) i daje **smernice** (sekcija 14, 16.4, 16.5), ali svestrano analizu postojećeg koda po sledećim dimenzijama **ostavlja za naredne iteracije**:

- **Mrtav kod inventarisanje per-modul:** koji od 454 modula se realno ne pozivaju nigde u Servoteh kontekstu (POS, HoReCa, klijent-specifični prefiksi). Dodatak D ovog dokumenta daje grubu klasifikaciju, ali **ne preporučuje konkretno uklanjanje** — to zahteva dodatnu verifikaciju kroz call-graph analizu i potvrdu od strane korisnika
- **SQL injection audit:** sva mesta gde se string vrednosti ubacuju u SQL bez `SQLFormat*` escape-a. Postoji ih više desetina, treba ih sve identifikovati i markirati za pre-write kod novog sistema
- **Performanse hot-spot-ova:** koje forme/upiti su sporiji (`MRP_Pregled`, `PDM` BOM ekspanzija, `KarticaKomitenta` za velike komitente) i kako su trenutno workaround-ovani
- **Mapping starih shema na potencijalne nove:** ako se pravi nov sistem, koja tabela u kojem domenu odgovara čemu (Komitenti → Customer, Predmeti → Project, Trebovanja → PurchaseRequisition, itd.)
- **Glossary srpskih domenskih termina:** za buduće stranje developere ili za AI prompt engineering — Predmet, RN, KEPU, POPDV, Trebovanje, Primopredaja, IOS, KEPU, Tarifa, Magacin, Konto, Pravac, Otvorena stavka, itd.

---

## Dodaci

### Dodatak A: Čitav modulski indeks (po veličini, top 50)

| LOC | Modul | Tip | Domen |
|---:|---|---|---|
| 3496 | BBCMD_SYS | bas | BB framework — DDL & schema sync |
| 2185 | BBKreiranjeDokumenata | bas | BB framework — kreiranje dokumenata (centralno) |
| 1901 | ADO_Module | bas | DAL — ADO/SQL helper |
| 1713 | BBCFG_Class | cls | Konfiguracija (singleton state) |
| 1657 | BBQueryTool | bas | Query introspection & param-binding |
| 1553 | BBTehn_Module | bas | Tehnološki postupci |
| 1493 | LinkovaneTabele | bas | Linked tables management |
| 1452 | PDM_Common | bas | PDM core |
| 1349 | Kamate | bas | Obračun kamata |
| 1328 | Form_UnosRN | cls | UI — unos radnog naloga |
| 1193 | RN_Modul | bas | Radni nalozi business logic |
| 1130 | Bliski susret | bas | Boot dispatch & global params |
| 969 | ExportTXTCSVXML | bas | Export framework |
| 948 | Cene | bas | Cene & cenovnici |
| 905 | LIB_CFGRW | bas | Config R/W (`ReadParametar`, `WriteParametar`) |
| 820 | BiranjeArtikla | bas | Article picker dialog logic |
| 786 | LIB_GlobalniModul | bas | Global utility (CurrentUser, helper-i) |
| 753 | BBSys | bas | Sistem utility |
| 741 | BBSQLModule | bas | SQL Server linked-table helper |
| 720 | Form_BBQueryDef | cls | UI — query meta-editor |
| 714 | Form_KreirajNoveNalogeZaIDPredmet | cls | UI — wizard za naloge po predmetu |
| 705 | Uskladjivanje prodaje | bas | Reconcile prodaje |
| 681 | Form_PregledPrimopredaje | cls | UI — pregled primopredaja |
| 681 | BBHotKeys | bas | Globalni hotkey-evi |
| 680 | StartUp | bas | Boot (BBStart, AutoExec, Quit) |
| 680 | Form_PregledPrimopredaje | (duplikat naziva — proveriti) |
| 673 | DodelaPLU | bas | PLU (Price Look-Up) za POS |
| 672 | ZR | bas | Fiskalna kasa logika |

### Dodatak B: Spisak svih klijent-prefiksiranih query serija

| Prefiks | Broj upita | Verovatno klijent |
|---|---:|---|
| `ODBC_*` | 55 | Pass-through prema SQL — generic, ne klijent |
| `GR_*` | 30 | "GR" klijent (možda gradnja/građevina) |
| `00_, 01_, ..., 15_` | ~24 | ETL serija (brojevi su faze) |
| `PSR_*` | 15 | "PSR" klijent (prosečne nabavne cene roba?) |
| `DX_*` | 13 | "DX" klijent |
| `VULEMARKET_*` / `VuleMarket_*` | 12 | Vule Market (verovatno maloprodajni lanac) |
| `CFG_*` | 9 | Config queries |
| `Baze_* / BazeITabele_*` | 16 | Meta queries za baze |
| `BarKodUnos_*` | 8 | Bar-kod radne stanice |
| `JUGOLEK_*` / `Jugolek_*` | 12 | Jugolek (apoteka? — ime je farmaceutsko) |
| `PS_*` | 6 | "PS" klijent |
| `Obrisi_*` | 6 | Cleanup queries |
| `tmp_*` | 5 | Temporary scratch |
| `Jugolek_*` (mali) | 5 | Jugolek varijanta |
| `X_*` | 4 | Eksperimentalni / debug |
| `SERVOTEH_*` | 4 | Servoteh-specifični |
| `Q_*` | 4 | Naked query-prefiks |
| `Prepisi_*` | 4 | Copy/transfer query-ji |
| `PSF_*` | 4 | "PSF" klijent (Profitni Sistem Faktura?) |
| `PG_*` | 4 | "PG" — možda PostgreSQL pripreme? |
| `B_*` | 4 | Backup ili B-prefix grupa |
| `qry_*` | 3 | qry-prefiks generičkih |
| `Pregled_*` | 3 | Pregled query-ji |
| `PDM_*` | 3 | PDM-specifični SQL-ovi |

### Dodatak C: Connection-string sigurnosna napomena

**KRITIČNO za production change:** SQL Server credentials (`QBigTehn / QbigTehn.9496`) su trenutno u plain-text-u na više mesta:
1. U `.mdb` properties (`CNN_*`)
2. U svim Access linked tabelama (encrypted ali sa poznatim Access scheme — trivialno reverse-engineer-ovati)
3. U svim chat istorijama vezanim za ovaj posao
4. Verovatno u eventualnim screenshot-ovima i email-ovima

Promeniti šifru na SQL-u, zatim u Access-u kroz `BBSQLModule.ConnectSQLToNewServer(NewCnnString)` ili manuelno relink-ovati sve linked tabele sa novim credentials-ima. Nakon toga update `CNN_*` properties (kroz Access-ov DAO API: `db.Properties("CNN_CFG_Global").Value = ...`).

Idealna meta — **prebaciti na Windows Authentication** (`Trusted_Connection=yes`), pa nikakve šifre nisu u fajlovima.

---

### Dodatak D: Klasifikacija modula — QMegaTeh-native, BigBit nasleđe (živo), BigBit nasleđe (mrtvo u Servoteh kontekstu)

**Svrha ovog dodatka:** identifikovati gde je šta i odakle je došlo — **bez** preporuke šta da se obriše. Konačna odluka šta je sigurno za uklanjanje zahteva (a) call-graph analizu sa proverom da modul zaista nigde nije pozivan, (b) potvrdu od korisnika da odgovarajuća poslovna funkcionalnost nije i neće biti potrebna, (c) testiranje na produkcijskoj kopiji pre brisanja iz live okruženja.

Klasifikacija se zasniva na: prefiksima imena (`BB`, `Kafe`, `Form_`), poslovnom domenu (proizvodnja vs maloprodaja), datumima u komentarima, i prisustvu reference iz Servoteh-specifičnih ETL upita.

**Legenda:**
- 🟢 **QMegaTeh-native** — Vasin doprinos, specifično za Servoteh (proizvodnja, RN, PDM, MRP)
- 🟡 **BigBit nasleđe — živo** — Slavisin originalni kod koji se aktivno koristi u Servoteh kontekstu (računovodstvo, komitenti, fakture, magacin, framework)
- 🔴 **BigBit nasleđe — mrtvo (verovatno) u Servoteh kontekstu** — kod nasleđen iz BigBit-a koji se odnosi na funkcionalnosti koje Servoteh nema (POS u kafićima/maloprodajni terminali, fiskalne kase za maloprodaju, klijent-specifični ETL za druge firme)
- ⚪ **Sistemski / framework** — generic helper-i koji su uvek korisni bez obzira na domen

#### D.1 — Standardni moduli (.bas)

| Modul | LOC | Klasa | Beleška |
|---|---:|:---:|---|
| BBCMD_SYS | 3496 | ⚪ | BB framework — DDL & schema sync. Verovatno se i sad koristi pri ažuriranjima |
| BBKreiranjeDokumenata | 2185 | 🟡 | Centralna kreator dokumenata, deli ga sve poslovanje |
| ADO_Module | 1901 | ⚪ | Generic ADO/SQL helper, neophodan |
| BBQueryTool | 1657 | ⚪ | Query introspection — neophodan za pass-through upite |
| BBTehn_Module | 1553 | 🟢 | Tehnološki postupci — Servoteh proizvodnja |
| LinkovaneTabele | 1493 | ⚪ | Linked tables management — neophodan |
| PDM_Common | 1452 | 🟢 | PDM core — Servoteh proizvodnja |
| Kamate | 1349 | 🟡 | Obračun kamata — koristi finansija |
| RN_Modul | 1193 | 🟢 | Radni nalozi — Servoteh proizvodnja |
| Bliski susret | 1130 | ⚪ | Boot dispatch & global params — neophodan |
| ExportTXTCSVXML | 969 | 🟡 | Export framework (XML/CSV/TXT) — koristi finansija/PDV |
| Cene | 948 | 🟡 | Cenovnici i nivelacija — koristi maloprodaja i veleprodaja |
| LIB_CFGRW | 905 | ⚪ | Config R/W — neophodan |
| BiranjeArtikla | 820 | 🟡 | Article picker — koristi se kod fakturisanja, magacina |
| LIB_GlobalniModul | 786 | ⚪ | Global utility helpers |
| BBSys | 753 | ⚪ | Sistem utility |
| BBSQLModule | 741 | ⚪ | SQL Server linked-table helper |
| Uskladjivanje prodaje | 705 | 🟡 | Reconcile prodaje — finansija |
| BBHotKeys | 681 | ⚪ | Globalni hotkey-evi |
| StartUp | 680 | ⚪ | Boot (BBStart, AutoExec, Quit) |
| DodelaPLU | 673 | 🔴 | PLU (Price Look-Up) za POS — maloprodaja, mrtvo u Servoteh |
| ZR | 672 | 🔴 | Fiskalna kasa logika — maloprodaja, mrtvo u Servoteh |
| EXT_Import | 665 | 🟡 | EXT (BigBit) sync framework — kritičan integracioni sloj |
| POPDV_Module | 649 | 🟡 | PDV poreska prijava — koristi finansija |
| BBProdaja | ~? | 🔴 | Prodaja modul, naziv ukazuje na BigBit POS |
| Kafe | ~? | 🔴 | HoReCa POS za konobare/stolove — mrtvo u Servoteh |
| KafeKreiranjeDokumenata | ~? | 🔴 | Kafe dokumenti — mrtvo u Servoteh |
| KafeNaplata | ~? | 🔴 | Kafe naplata — mrtvo u Servoteh |
| KafeProdaja | ~? | 🔴 | Kafe prodaja — mrtvo u Servoteh |
| Konobari | ~? | 🔴 | Konobarske operacije — mrtvo u Servoteh |
| RasterModul | ~? | 🔴 | Raster fiskalni štampač — moguće mrtvo (Servoteh nema fisk.) |
| ZRXML | ~? | 🔴 | XML format za novu fiskalizaciju — moguće mrtvo |
| FX_HALCOM | 198 | 🟡 | Halcom banking utility — može biti živo ako se Halcom koristi za nabavke |
| BEOHOME | ~? | 🟡 | BEOHOME banking — proveriti da li se koristi |
| DecodeSopot | ~? | 🔴 | Sopot fiskalni dekoder — verovatno mrtvo |
| ImportIzBB_Module | ~? | 🟡 | **Master-data sync iz BigBit-a — KRITIČAN, mora ostati** |
| RunExtBigBit_Module | ~? | 🟡 | Pokretanje BigBit-a iz QMegaTeh-a — kritičan ako se GK i fakture rade u BigBit-u |
| RibbonModule | ~? | 🟡 | Office Ribbon UI — funkcionalan |
| RN_Modul, RN_Class, RN_BiranjePredmeta, RN_Calendar, RN_OpenFormModla, RN_RadSaDatumima, RN_SQLUpiti, RN_TouchPanel | razno | 🟢 | Sve RN_* moduli — Servoteh proizvodnja |
| PDM_Class, PDM_PDFCommon, PDM_Test, PDMXMLParser | razno | 🟢 | Svi PDM_* — Servoteh proizvodnja |
| MRP_Module | ~? | 🟢 | MRP — Servoteh proizvodnja |
| Proizvodnja | ~? | 🟢 | Proizvodnja core — Servoteh |
| modSyncMirrorTabele | ~? | 🟢 | Mirror sync za PDM/MRP — Servoteh |
| GlavnaKnjiga, GKEval, GKS, Kontiranje | razno | 🟡 | Kontiranje i GK — finansija |
| Komitenti, KomitentiUgovori, KomitentiCrnaListaModul | razno | 🟡 | Komitenti — sva poslovna |
| NKEPU, TK_KEPU_MP | razno | 🟡 | KEPU — finansija |
| Otvorene stavke | ~? | 🟡 | Otvorene stavke — finansija |
| PDV_Modul | ~? | 🟡 | PDV — finansija |
| UVOZ | ~? | 🟡 | Uvoz roba — finansija/magacin |
| BigBitXML | ~? | 🟡 | XML import iz BigBit-a |
| BBCMD_BigBit | ~? | 🟡 | BB framework varijanta za BigBit branding |
| ADO_ComboRecordset | ~? | ⚪ | UI helper |
| ADO_Synch | ~? | ⚪ | Sync helper |
| ODBC_Synch_Module, ODBC_Synch_NoviModul | razno | 🔴 | ODBC sync za MP dokumente — POS, mrtvo u Servoteh ako nema MP |
| modExportAllModules | ~? | ⚪ | Naš sopstveni izvoz alat (autor: ChatGPT & Negovan, 7.11.2025) — koristio se u izvozu koda |
| Modul1, Modul2 (ako postoje) | ~? | ⚪ | Default Access imena — verovatno prazni |
| Sve sa sufiksom `_OLD`, `_NETREBA`, `_TEST*`, `_NeKoristiSe` | razno | ⚫ | Eksplicitno označeni kao zastareli — sigurno mrtvi |

#### D.2 — Class moduli (.cls — bez Form_)

| Modul | LOC | Klasa | Beleška |
|---|---:|:---:|---|
| BBCFG_Class | 1713 | ⚪ | Centralni singleton — neophodan |
| BBTehn_Class | ~? | 🟢 | Tehnološki postupci state |
| RN_Class | ~? | 🟢 | Radni nalog state |
| PDM_Class | ~? | 🟢 | PDM state |
| IF_Class | ~? | 🟡 | Izlazna faktura state |
| UF_Class | ~? | 🟡 | Ulazna faktura state |
| USLF_Class | ~? | 🟡 | Usluga faktura state |
| Email_Class | ~? | ⚪ | SMTP setup |
| ComPortPar | ~? | 🔴 | COM port parametri (fiskal/vaga) — mrtvo u Servoteh |
| ODBC_Synch_Class | ~? | 🔴 | MP sync klasa — mrtvo u Servoteh |

#### D.3 — Forme (.cls / Form_*)

**🟢 QMegaTeh-native (Servoteh proizvodnja) — sigurno se koriste:**

```
Form_UnosRN, Form_RNPregled (8+ varijanti), Form_RNPregledPostupci,
Form_RNPregledPoRJ, Form_RNPregledPoRadniku, Form_RNLansiranStatus,
Form_RNSaglasanStatus, Form_PregledStavkiRN, Form_StavkeRNSlike,

Form_PDMTreeView, Form_PDMSklop, Form_PDMCrteziPregled, Form_PDMSklopReference,
Form_PDMPodSklopReference, Form_PDMPodPodSklopReference, Form_PDMPodPodPodSklopReference,
Form_PDMXMLImportLog, Form_GdeSeCrtezKoristi, Form_PregledSklopovaGdeSeCrtezKoristi,
Form_PotrebneKomponenteZaCrtez, Form_PotrebneTopLevelKomponenteZaCrtez,
Form_PotrebniGotoviDeloviZaCrtez, Form_PregledGotovihDelovaZaCrtez,
Form_PregledPotrebnihKomponentiZaCrtez, Form_frmPDMTreeView_Sub, Form_frmWhereUsed_Sub,

Form_MRP_Pregled, Form_MRP_DetaljanPregledSaZalihama, Form_MRP_DetaljanPregledSvihMRPPotreba,
Form_MRP_Potreba, Form_MRP_PotrebaStavke, Form_MRP_PregledRezervisano,
Form_MRP_PregledSaZalihama, Form_MRP_PregledSamoNabavku, Form_MRP_PregledPoDobavljacima,
Form_frmMRP_Akcija,

Form_Primopredaja, Form_PregledPrimopredaje, Form_NacrtPrimopredaje, Form_NacrtPrimopredajeStavke,
Form_PregledNacrtaPrimopredaje, Form_PregledStavkiPrimopredajaRN, Form_SpremiNacrtPrimopredaje,
Form_PrimopredajaUnosStavki* (6 varijanti),

Form_PregledPoPostupcima (5 varijanti), Form_PregledOperacijaPoPrioritetima,
Form_UnosOperacije, Form_PregledTehnoloskihPostupaka, Form_PregledPostupakaSaDokumentacijom,
Form_KarticaLokacijaDela, Form_LokacijaSvihNapravljenihDelovaPoRN, Form_LokacijaNapravljenihDelova,
Form_LokacijaNapravljenihDelovaZag, Form_PregledDelovaPoLokacijama,

Form_Predmeti, Form_T_Predmeti_Prilozi, Form_Pisarnica_PregledPredmeta, Form_Pisarnica_UnosPredmeta,
Form_PregledPoPredmetima, Form_KreirajNoveNalogeZaIDPredmet, Form_IzborNalogaZaPrepisivanje,
Form_IzborNalogaZaPrepisivanjeZaIDPredmet, Form_UnosPredmetaIspraviKomitenta,

Form_SpecifikacijaZaNabavku, Form_SpecifikacijaZahtevaZaNabavku, Form_SpecifikacijaUpitaZaNabavku,
Form_SpecifikacijaTrebovanjaZaNabavku, Form_SpecifikacijaNabavkeIUpiti, Form_ZahteviZaNabavku,
Form_UnosZahtevaZaNabavku, Form_BBMail_ZaNabavku, Form_PlaniranjeNabavke, Form_PlaniranjeNabavkeStavke,
Form_SpremiPlaniranjeNabavke, Form_PG_IzborNalogaZaPrepisivanje,

Form_Radnici, Form_RadniciPoMasinama, Form_AARadnika, Form_Masine, Form_PristupMasinama,
Form_VrsteRadnika, Form_UnosRadnihJedinica, Form_UnosRadnihCentara,
Form_IzborRadnikaZaDaljiRad, Form_IzborRadnikaZaDaljiRadZag,
Form_IzborPostupakaZaDaljiRad, Form_IzborPostupakaZaDaljiRadZag,
Form_IzborSpecifikacijeNabavkeZaPrepisivanje, Form_PlanerPopUp, Form_PlanerSingleSubForm,
Form_PlanerTabSubForm, Form_PlanerGrupeUsera,

Form_PPS, Form_PPS_PregledPoNalozima, Form_PPS_PregledPoOperacijama, Form_PS_TabeleZaImportIzPG,

Form_BarKod_Unos, Form_BarKod_Status, Form_BarKod_Ispravka,

Form_Kartica TehPostupka, Form_Kartica TehPostupka - Podforma, Form_KeyboardSaPostupkom,
Form_PlanSporneStavke, Form_PlanSporneStavkePodforma, Form_OdlukePredProvera, Form_OdlukePredProveraPodforma,
Form_RazlikeIzmedju_tRN_tTehPostupak, Form_AnalizaAktivnosti, Form_AA_LosUnosKomadaNula,
Form_AA_PoSatu, Form_dlgRokIzrade, Form_frmIzborTehnologa, Form_frmKriticniPostupci,
Form_frmSanacijatTehPostupak, Form_tTehPostupakDokumentacija, Form_tTehnPregled_Panel,
Form_zsfrmCalendar
```

**🟡 BigBit nasleđe — živo (računovodstvo, magacin, framework):**

```
Form_Pregled komitenata, Form_Unos komitenata, Form_Firme, Form_IzaberiFirmu,
Form_BB_UsersQuery (autorizacija pregleda), Form_Magacini, Form_Lager lista,
Form_B_ZaliheArtPoMag, Form_B_ZaliheArtPoMagPodforma, Form_Grupe artikala,

Form_Recnik, Form_SRPENG_*, Form_VrednostiZaKombo,
Form_Trebovanje - Podforma, Form_Digitron, Form_DigitronPodforma,
Form_KbdNum (numerička tastatura — koristi se i u proizvodnji za bar-kod),

Form_Intro (boot splash — neophodan), Form_Zastita, Form_Zakljucavanje,
Form_BBPravaPristupa, Form_BBInfo, Form_BBMsgBoxFrm, Form_BBMsgBoxFrm_BigBit,

Form_BBCFG, Form_CFGReadWrite, Form_CFG_DozvoljeneVrednosti, Form_CFG_Global,
Form_CFG_KatParPrip, Form_CFG_Lokal, Form_CFG_SviParametri_DEF, Form_CFG_Sys,

Form_Baze, Form_Baze_APL, Form_Baze_Firme, Form_Baze_Tipovi_APL,
Form_BazeITabele, Form_BazeITabele-Podforma, Form_BazeITabele_APL, Form_BazeITabele_Brisanje,
Form_CNN, Form_CNN_Access, Form_CNN_List, Form_CNN_SQL,

Form_BBAll, Form_BBExport, Form_BBImport, Form_BBBackup, Form_BBExtra, Form_BBTools,
Form_BBPravaPristupa, Form_BBQueryDef, Form_BBQueryDef_Pregled, Form_BBQueryParDef,
Form_BBT_BrojDokumenataPoGodinama,

Form_BBDetectIdleTime,

Form_Prva maska, Form_Prva maska_BB, Form_Prva maskaMagacin, Form_Prva maskaPregledi,
Form_QPrvaMaska, Form_LIB_Intro, Form_Form2 (verovatno mrtva),

Form_Izbor radnog fajla, Form_RadniFajlDetaljno,

Form_frmRibbonOnForm, Form_RibbonOnClickDetails, Form_frmUSysRibbons,
Form_frmDefParametriUnos, Form_frmGrupe, Form_frmPozicije,
Form_BarKod_Unos (deli sa proizvodnjom), Form_T_Predmeti_Prilozi (deli)
```

**🔴 BigBit nasleđe — verovatno mrtvo u Servoteh kontekstu (POS/HoReCa/maloprodaja):**

```
Form_PrvaMaskaKonobar — POS root za konobara
Form_IzborStolaPanel — biranje stola u kafiću/restoranu
Form_UnosPassworda — konobarski PIN dialog (možda se koristi i drugde, proveriti)

Form_ReklamniPanel (13 varijanti: ReklamniPanel, ReklamniPanel1, ReklamniPanel1_,
ReklamniPanel2, ReklamniPanel3, ReklamniPanelA, ReklamniPanelB, ReklamniPanelC, ReklamniPanelD,
ReklamniPanelE, ReklamniPanelPPS1, ReklamniPanelPPS2, ReklamniPanelPregled, ReklamniPanel_LogIn) —
najverovatnije ekrani za info-displeje (TV-i u radionici/kafiću sa rotacijom slika i poruka).
   PPS varijante (ReklamniPanelPPS1, PPS2) bi mogle biti živi za Servoteh proizvodni floor display.
   Standardni ReklamniPanel A/B/C/D/E su verovatno mrtvi.

Form_TestForm, Form_Form2, Form_Copy Of PDMTreeView, Form__AppRev — eksperimentalni / duplikati / mrtvi
```

**⚫ Eksplicitno označeni za uklanjanje (po imenu):**

```
Sve sa sufiksom _OLD, _TEST, _TEST1, _TEST_MOJ, _NETREBA, _NeKoristiSe,
PassTroughQueryMakeSQLTextFromTDef_NETREBA,
DX_PopraviNabavneCene_NE,
ForsirajNoveLinkoveZaTipBaze_NETREBA_20102021,
rRN_NovaKontrola_NeKoristiSe, rRN_SaSlikama_NovaKontrola_NeKoristiSe,
"_Copy Of rRN" report
```

#### D.4 — SQL upiti — klijent-specifično

Iz Dodatka B znamo prefikse klijent-specifičnih upita. Detaljnija klasifikacija:

| Prefiks | Broj | Klasa za Servoteh | Beleška |
|---|---:|:---:|---|
| `00_–15_` (ETL serija) | ~24 | 🟢/🟡 | Faze migracije; `*_SERVOTEH` varijante 🟢, ostale 🟡 (mogu se koristiti za reference) |
| `ODBC_*` | 55 | ⚪ | Pass-through queries — generic |
| `GR_*` | 30 | 🔴 | "GR" klijent — mrtvo |
| `DX_*` | 13 | 🔴 | "DX" klijent — mrtvo |
| `PSR_*` | 15 | 🔴 | "PSR" klijent — mrtvo |
| `PSF_*` | 4 | 🔴 | "PSF" klijent — mrtvo |
| `PS_*` | 6 | 🔴 | "PS" klijent — mrtvo |
| `VULEMARKET_*` / `VuleMarket_*` | 12 | 🔴 | Vule Market — mrtvo |
| `JUGOLEK_*` / `Jugolek_*` | 12 | 🔴 | Jugolek — mrtvo |
| `SERVOTEH_*` | 4 | 🟢 | Servoteh-specifični |
| `PG_*` | 4 | 🔴/🟡 | "PG" prepisivanje — moguće Servoteh ETL, proveriti |
| `BarKodUnos_*` | 8 | 🟢 | Bar-kod proizvodnja — Servoteh |
| `MRP_*`, `PDM_*` | razno | 🟢 | Proizvodnja |
| `Baze_*`, `BazeITabele_*` | 16 | ⚪ | Meta queries |
| `tmp_*` | 5 | ⚫ | Temporary scratch — sigurno mrtvi |
| `CFG_*` | 9 | ⚪ | Config queries |
| `Obrisi_*` | 6 | ⚪ | Cleanup queries — koristi se sporadično |
| `qry_*` | 3 | ? | Generičkih, proveriti pojedinačno |

#### D.5 — Procena ukupne mrtve mase

Gruba procena (nije precizna jer modul može biti mešavina živog i mrtvog koda):

- 🟢 QMegaTeh-native: **~30-35%** koda
- 🟡 BigBit nasleđe živo (računovodstvo + framework + master data sync): **~35-40%** koda
- 🔴 BigBit nasleđe mrtvo u Servoteh kontekstu (POS, HoReCa, fiskal, drugi klijenti): **~25-30%** koda
- ⚪ Sistemski/framework: **~5-10%** koda

To znači da bi **eliminacijom mrtvog koda Servoteh-ova realna baza padala sa 92.633 LOC na ~65.000-70.000 LOC** (smanjenje za ~25%). To nije zanemarljivo, ali nije ni transformativno — glavni gubici su u kompleksnosti razumevanja, ne u performansama.

**Napomena:** sledeća iteracija dokumentacije može raditi konkretnu **call-graph analizu** — tražiti po VBA kodu sve `Call X`, `X(...)` pozive funkcija i graditi orijentisani graf zavisnosti. Sve čvorove bez ulaznih ivica (osim formi i AutoExec) možemo sa visokom sigurnošću označiti za uklanjanje. To bi dalo precizan spisak "100% sigurno mrtav kod" — ali to nije obrađeno u ovoj iteraciji jer ti je rekao da je dovoljno za sada da znamo *šta je* mrtav, ne *da ga uklonimo*.

### Dodatak E: Master-data sync iz BigBit-a — operativna specifikacija

**Status:** ovo je trenutno **jedina kritična integraciona tačka** između QMegaTeh-a i BigBit-a koja se mora razumeti da bi se zamenjivao QMegaTeh proizvodni deo. Bilo koji novi sistem mora ovaj sync ili nasledjuje (zadržavajući BigBit) ili da ga zamenjuje (sync-uje iz drugog ERP-a koji bi zamenio BigBit).

**Sadržaj ovog dodatka:**
- E.1 — Inventar tabela koje se sync-uju (sa kolonama, primerima)
- E.2 — Mehanizam linkovanja (kako Access vidi BigBit bazu)
- E.3 — SQL pattern za inkrementalno povlačenje
- E.4 — Trigger sync-a (gde i kako se pokreće)
- E.5 — Konfiguracija (CFG flagovi)
- E.6 — Konflikt-rezolucija i tehnički dug
- E.7 — Specifikacija koju mora da zadovolji svaki budući zamenjivač

#### E.1 Inventar sync-ovanih tabela

Iz `EXT_Komitenti` linked tabele (preuzete iz BigBit-a) povlače se kolone u QMegaTeh-ovu lokalnu `Komitenti` tabelu. Iz koda `ImportIzBB_Module.DodajNoveKomitenteIzBigBita` vidimo precizan SELECT:

```sql
INSERT INTO Komitenti (
    Sifra, Naziv, Poslovnica, Mesto, Adresa, [Postanski broj],
    [Ziro racun_1], [Ziro racun_2], [Ziro racun_3], Telefon, Fax, Kontakt, Napomena,
    Drzava, Region, [Vrsta sifre], Email, Mobilni, [Datum rodjenja], [Web adresa],
    [Sifra prodavca], RabatKomitenta, ZastKodKupca, PIB, PDVStatus
)
SELECT
    EXT_Komitenti.Sifra, EXT_Komitenti.Naziv, EXT_Komitenti.Poslovnica, ...
    , 0 AS [Sifra prodavca]   -- <-- prodavac se postavlja na 0 (mora se kasnije popuniti)
    , IIf(Nz([EXT_Komitenti].[PIB], "")="",
          "XX_" & [EXT_Komitenti].[Sifra],     -- <-- ako PIB nedostaje, generiše se "XX_<sifra>" placeholder
          [EXT_Komitenti].[PIB]) AS PIB
    , EXT_Komitenti.PDVStatus
FROM EXT_Komitenti LEFT JOIN Komitenti ON EXT_Komitenti.Sifra = Komitenti.Sifra
WHERE Komitenti.Sifra IS NULL;
```

**Predmeti** (`DodajNovePredmeteIzBigBita`):

```sql
INSERT INTO Predmeti SELECT
    IDPredmet, BrojPredmeta, Opis, DatumOtvaranja,
    IDProdavac, IDKomitent, NextAction, DatumZakljucenja, Memo,
    Status, NasaRef, NasKontakt1, NasKontakt2, NasTel1, NasTel2,
    VasaRef, VasKontakt1, VasKontakt2, VasTel1, VasTel2,
    NabavnaVrednost, Carina, Spedicija, Prevoz, Ostalo,
    InoDobavljac, RJ, DevValuta, Kurs, NazivPredmeta,
    BrojUgovora, DatumUgovora, BrojNarudzbenice, DatumNarudzbenice
FROM EXT_Predmeti LEFT JOIN Predmeti ON EXT_Predmeti.IDPredmet = Predmeti.IDPredmet
WHERE Predmeti.IDPredmet IS NULL;
```

**Prodavci** (`DodajNoveProdavceIzBigBita`):

```sql
INSERT INTO Prodavci SELECT
    [Sifra prodavca], Prodavac, Region, ProcenatZaObracun, DeljivoUGrupi, ImeProdavca,
    BrLkProdavca, LogAcc,
    IIf(IsNull(EXT_Prodavci.[Password]),
        EXT_Prodavci.[Sifra prodavca],     -- <-- ako BigBit nema lozinku, postavi šifru prodavca kao default password
        EXT_Prodavci.[Password]) AS Password,
    Aktivan, NefiskalniRN, Storniranje, PotpisSlika,
    OznakaTima, Telefon, Email
FROM EXT_Prodavci LEFT JOIN Prodavci ON EXT_Prodavci.[Sifra prodavca] = Prodavci.[Sifra prodavca]
WHERE Prodavci.[Sifra prodavca] IS NULL;
```

**Artikli** (`DodajNoveArtikleIzBigBita`) — slični pattern (precizne kolone se mogu izvući direktno iz `ImportIzBB_Module.bas` ako bude potrebno).

**Vrste šifara komitenata** (`stSQL_Append_VrsteKomitentaIzBigBita`) — append SQL helper koji prosledjuje `UradiImportIzTabeleUTabelu(\"EXT_Vrste sifara\", \"Vrste sifara\", stSQL_Append_VrsteKomitentaIzBigBita)`.

**Read-only čitanje** (bez kopiranja u lokalnu tabelu, čitaju se direktno kroz EXT_*):

| EXT_ tabela | Korišćenje |
|---|---|
| `EXT_R_Tarife` | PDV tarife — čitaju se direktno za fakturisanje |
| `EXT_R_Grupa` | Grupe artikala |
| `EXT_Magacini` | Magacini |
| `EXT_T_Robna dokumenta` | Reference za istorijska dokumenta iz BigBit-a |
| `EXT_T_Robne stavke` | Reference |
| `EXT_T_Trebovanja` | Reference za stara trebovanja |
| `EXT_ZahteviZaNabavku` | Reference |
| `EXT_SpecifikacijaZahtevaNabavke` | Reference |
| `EXT_Radninalozi` | Reference za stare RN-ove (ako je BigBit imao osnovne RN-ove pre nego što je QMegaTeh proširio funkcionalnost) |
| `EXT_DobavljaciZaArtikal` | Mapping artikla → dobavljači |
| `EXT_BB_T_25` | Specijalna tabela vezana za eksterni magacin BB_T_25 |
| `EXT_KnjigaStatusa` | Statusi |

#### E.2 Mehanizam linkovanja

QMegaTeh `.mdb` ima **Access linked tables** sa prefiksom `EXT_*` koje fizički pokazuju na BigBit `.mdb` (preko ACE.OLEDB) ili BigBit SQL Server bazu (preko ODBC). Putanja/connection string se čita iz registry-ja konfiguracije `Baze` (tabela u `BB_CFG_Lokal.mdb` ili na SQL-u, zavisno od podešavanja).

Kako se linkovanje održava:
- Pri startu (`BBStart`) se pozivaju `RefreshDaoLink` i `LinkovaneTabele.RefreshujLinkoveZaTipBaze("BigBit_T")`
- Ako se BigBit baza premesti, `LinkovaneTabele.UpisiNoviCNNStringZaTipBaze("BigBit_T", NewCnnString)` ažurira sve EXT_ linkove
- `BazaZaTip("BigBit_T")` vraća putanju/CNN string ka BigBit-u
- `BazaZaTip("MasterDB")` — ako je definisana, koristi se umesto BigBit_T (postoji dvojnost: master = BigBit ako MasterDB nije eksplicitno definisana)

#### E.3 SQL pattern za inkrementalno povlačenje

Ovaj pattern je **uniforman za sve master entitete**:

```
INSERT INTO <lokalna_tabela> (<kolone>)
SELECT <kolone, sa eventualnim transformacijama>
FROM EXT_<tabela>
LEFT JOIN <lokalna_tabela>
    ON EXT_<tabela>.<PK> = <lokalna_tabela>.<PK>
WHERE <lokalna_tabela>.<PK> IS NULL;
```

**Karakteristike:**
- LEFT JOIN + WHERE NULL je klasičan SQL idiom za "samo novi" — pošto `WHERE IS NULL` filtrira na desnoj strani JOIN-a, vidiš samo redove koji nemaju match
- Primarni ključ je uvek poslovna šifra (`Sifra`, `IDPredmet`, `Sifra prodavca`, `IDArtikal`), ne autoincrement — što obezbedjuje stabilno mapiranje između sistema
- Update postojećih zapisa **nikad se ne radi** — to je svesna odluka da se izbegnu konflikti, ali stvara tehnički dug (drift)

#### E.4 Trigger sync-a (gde i kako se pokreće)

Sync nije automatski na promene u BigBit-u — pokreće se ručno. Trigger tačke u kodu:

1. **Ribbon dugme `btnPreuzmiIzBB`** — korisnik klikne dugme "Preuzmi iz BB" u Office ribbon-u
2. To okida `RibbonModule.PreuzmiIzBigBitaRibbon(control)` → `RibbonModule.PreuzmiIzBB()`
3. Funkcija `PreuzmiIzBB` redom poziva:
   ```vba
   UradiImportIzTabeleUTabelu("EXT_Vrste sifara", "Vrste sifara", stSQL_Append_VrsteKomitentaIzBigBita)
   DodajNoveProdavceIzBigBita
   DodajNoveKomitenteIzBigBita
   DodajNovePredmeteIzBigBita
   DodajNoveArtikleIzBigBita
   ```
4. Tokom rada, ako CFG flag `BBCFG.PrebaciKomitenteIzEXTBaze` ili `PrebaciPredmeteIzEXTBaze` je `True`, deo sync-a (npr. komitenata i predmeta) se može triger-ovati i automatski na startu sesije ili pri otvaranju određenih formi

#### E.5 Konfiguracija

| CFG parametar | Tabela | Tip | Šta kontroliše |
|---|---|---|---|
| `PrebaciKomitenteIzEXTBaze` | `CFG_Global` | Boolean | Da li se komitenti automatski sync-uju iz BigBit-a |
| `PrebaciPredmeteIzEXTBaze` | `CFG_Global` | Boolean | Da li se predmeti automatski sync-uju |
| `MSAccessProg` | `CFG_Lokal` ili `CFG_Global` | String (path) | Putanja do `MSACCESS.EXE` koja se koristi za pokretanje BigBit-a |
| `MasterDB` | (Baze tabela) | tip | Ako je definisan, koristi se kao master umesto `BigBit_T` |
| `BigBit_T` | (Baze tabela) | tip + path | Putanja do BigBit `.mdb` ili connection string ka BigBit SQL bazi |

Pristup ovim parametrima:
```vba
ReadParametar("CFG_Global", "PrebaciKomitenteIzEXTBaze")
BBCFG.PrebaciKomitenteIzEXTBaze   ' kao property
```

#### E.6 Konflikti, tehnički dug, ograničenja

Postoji više poznatih problema sa trenutnim sync mehanizmom — moraju se rešiti u svakom budućem sistemu:

**Problem 1: Update se nikada ne radi.**
Ako se u BigBit-u promeni adresa, telefon ili PIB komitenta, ta promena nikada ne stiže do QMegaTeh-a. Prvi sync je konačan. Workaround u praksi: korisnik ručno briše komitenta u QMegaTeh-u, sledeći sync ga povuče sa novim podacima. Loše.

**Problem 2: Brisanje u BigBit-u nije propagirano.**
Ako se komitent obriše u BigBit-u, ostaje u QMegaTeh-u zauvek. Ne postoji "soft-delete" flag. Tombstone tabele takođe ne postoje.

**Problem 3: Master ↔ slave drift.**
Posle više godina rada, QMegaTeh sadrži zastarele kopije podataka iz BigBit-a. Periodično bi trebalo raditi full reconciliation — ali u kodu nema te funkcije.

**Problem 4: PIB placeholder hack.**
Komitenti bez PIB-a u BigBit-u dobijaju `PIB = "XX_" & Sifra` u QMegaTeh-u (vidi E.1). To znači da se isti komitent može videti kao različiti PIB ako se u BigBit-u kasnije popuni pravi PIB.

**Problem 5: Default Password = Sifra prodavca.**
Prodavci bez password-a u BigBit-u dobijaju "password = sifra" u QMegaTeh-u (E.1). To znači da je predvidljivo i nesigurno — prvi POS prodavac bez svesne promene password-a ima password = svoja šifra.

**Problem 6: Lokalna tabela `[Sifra prodavca] = 0`.**
Pri sync-u komitenata, `[Sifra prodavca]` se postavlja na 0 — što znači "nepoznat prodavac". Ako se ne ručno popuni kasnije, izveštaji po prodavcu padaju na "nepoznat".

**Problem 7: Manuelan trigger.**
Ako korisnik zaboravi da klikne "Preuzmi iz BB" pre nego što počne da radi, radi sa zastarelim podacima.

#### E.7 Specifikacija koju mora da zadovolji svaki budući sistem

Bilo koji nov sistem koji bi zamenio QMegaTeh proizvodni deo (ili obe — i QMegaTeh i BigBit) **mora da implementira ovu funkcionalnost**, sa rešavanjem gornjih problema:

**Funkcionalni zahtevi:**

1. **Read-API (ili sync) za sve master entitete** koji su listovani u E.1, sa minimalno istim kolonama
2. **Inkrementalni transfer** — ne povlačiti svih milion zapisa svaki put
3. **Detekcija promena** — bilo polling po `LastModifiedTimestamp` koloni, bilo event-driven (Service Broker, CDC, ili applikativni event bus)
4. **Detekcija brisanja** — soft-delete flag na master strani + tombstone propagacija
5. **Konflikt rezolucija** — definisana strategija po polju (npr. "BigBit-ov PIB uvek pobeđuje", "lokalna izmena prodavca pobeđuje BigBit-ovu"). Upisuje se u sync log
6. **Audit log** — kada, ko, koji entitet, koliko zapisa, koje greške
7. **Idempotentnost** — sync-ovanje istog batch-a dva puta ne sme da pokvari ništa
8. **Retry / queueing** — ako BigBit nije dostupan, sync ide u queue i posle se ponavlja

**Tehnički zahtevi:**

- API ili sync mora da radi kroz mrežu (BigBit i novi sistem ne moraju biti na istoj mašini)
- Authentication/authorization (BigBit credentials u plain-text-u — ne kopirati taj antipattern)
- Performanse: full sync svih master entiteta < 5 minuta (trenutno traje desetinama minuta zbog Access overhead-a)
- Backward compat: prelazni period gde i QMegaTeh i nov sistem rade paralelno, oba sync-uju iz BigBit-a — u tom periodu nov sistem ne sme da kvari što stari radi

**Nefunkcionalni zahtevi:**

- Dokumentacija sync-a (per-entitet specifikacije sa primerima): mora postojati pre nego što se piše kod
- Test coverage: minimum 80% za sync logiku
- Monitoring: dashbord sa "vreme poslednjeg uspešnog sync-a po entitetu"
- Alerting: ako sync ne radi > 24h, alarm

### Dodatak F: Glossary srpskih domenskih termina

Pošto će budući developeri (uključujući AI asistenti kao Cursor/Claude) raditi sa kodom napisanim na srpskom, ovaj glossary objašnjava ključne pojmove. Termini su organizovani po domenu, ne abecedno. Engleski ekvivalenti su predloženi za potencijalno korišćenje u novom sistemu (po snake_case konvenciji).

#### F.1 Organizaciona struktura

| Termin | Skraćenica | Engleski ekvivalent | Šta znači |
|---|---|---|---|
| Firma | — | company / tenant | Pravno lice; sistem je multi-tenant kroz `IDFirma` |
| Organizaciona Jedinica | OJ | organizational_unit | Najveća pod-podela firme (npr. "Proizvodnja", "Komercijala", "Uprava"). Per-user default u `BBDefUser.DefaultOJ` |
| Organizacioni Deo | OD | organizational_division | Pod-jedinica unutar OJ. Per-user default u `BBDefUser.DefaultOD` |
| Radna Jedinica | RJ | work_unit | Pod-organizaciona jedinica koja izvršava radne naloge |
| Radni Centar | RC | work_center | Mašina ili grupa mašina koja izvodi tehnološki postupak |
| RJgrupaRC | — | work_unit_center_group | Kompozitni identifikator (RJ + grupa RC); koristi se kao FK u `tStavkeRN`, `tOperacije`, `tPristupMasini` |
| Pozicija | — | position | Stavka u predmetu (npr. "pozicija 1.2.3" — hijerarhijska) |

#### F.2 Proizvodnja

| Termin | Skraćenica | Engleski ekvivalent | Šta znači |
|---|---|---|---|
| Predmet | — | project / case | Najviši nivo poslovnog zadatka (ugovor, narudžba, projekat). Identifikuje se sa `IDPredmet` i `BrojPredmeta` |
| Radni Nalog | RN | work_order | Konkretan zadatak proizvodnje za jedan deo. `IDRN`, vezan za `IDPredmet` i `IDKomitent` |
| Stavka RN-a | — | work_order_item | Konkretan deo ili podsklop koji se proizvodi u okviru RN |
| Identbroj | — | part_number | String identifikator dela (kataloški broj, crtežni broj) |
| Varijanta | — | variant | Verzija dela (npr. "A", "B" za revizije) |
| Postupak | — | process / operation | Operacija koja se izvodi nad delom (struganje, brušenje, varenje, pranje, kontrola) |
| Operacija | — | sub_operation | Pod-korak unutar postupka |
| Tehnološki Postupak | TP | routing | Sekvenca operacija definisana za dati Identbroj — "kako se ovaj deo pravi" |
| Primopredaja | — | handover | Workflow tačka prenosa između tehnologa, proizvodnje i kontrole. Prati ko je predao, kome, kada, sa kojim brojem komada |
| Saglasan | — | approved | Status RN-a kad je tehnolog odobrio proizvodnju |
| Lansiran | — | released / launched | Status RN-a kad je proizvodnja zvanično pokrenuta |
| Skart | — | scrap | Defektni komadi koji se odbacuju |
| Dorada | — | rework | Komadi koji moraju da prođu dodatnu operaciju |
| Investitor | — | investor / customer | Komitent (kupac) za koga se RN pravi |
| Pisarnica | — | registry / case management | Modul za vođenje predmeta (registar svih ugovora i projekata) |

#### F.3 PDM — Konstrukciona dokumentacija

| Termin | Skraćenica | Engleski ekvivalent | Šta znači |
|---|---|---|---|
| Crtez | — | drawing | Konstrukcioni crtež dela (CAD output). Identifikuje se sa `IDCrtez`, `BrojCrteza`, `Revizija` |
| Sklop | — | assembly | Crtez koji ima komponente (BOM); top-level proizvod |
| PodSklop | — | sub_assembly | Sklop unutar sklopa |
| PodPodSklop / PodPodPodSklop | — | sub_sub_assembly / sub³_assembly | Niži nivoi sklopa (4 nivoa hardkodirano u QMegaTeh-u) |
| Komponenta | — | component / BOM_item | Stavka u BOM-u (Bill of Materials) — pokazuje na drugi crtež |
| TrebaIDCrtez | — | required_drawing_id | FK kolona koja kaže "ova komponenta je crtež X" |
| Sastavnica | — | bill_of_materials (BOM) | Lista svih komponenti potrebnih za sklop |
| Nabavni deo | — | purchased_part | Komponenta koja se kupuje, ne pravi (vidi MRP) |

#### F.4 MRP — Planiranje materijala

| Termin | Skraćenica | Engleski ekvivalent | Šta znači |
|---|---|---|---|
| Potreba | — | requirement / demand | Šta treba (po BOM-u + RN-ovima) |
| Zalihe | — | stock / inventory | Šta ima u magacinu |
| Rezervisano | — | reserved | Šta je već namenjeno drugim RN-ovima (nije slobodno) |
| Slobodne zalihe | — | available_stock | Zalihe minus rezervacije |
| Trebovanje | — | requisition | Interna narudžbenica iz proizvodnje za magacin (uzimanje materijala) |
| Zahtev za nabavku | — | purchase_request | Inicijalni zahtev iz proizvodnje za nabavku (preti dobavljačima) |
| Specifikacija nabavke | — | purchase_specification | Konsolidovana lista za jednog dobavljača |
| Upit za ponudu | — | request_for_quotation (RFQ) | Email/dokument poslat dobavljaču |
| Magacin | — | warehouse | Fizička lokacija za skladištenje |

#### F.5 Komitenti i komercijala

| Termin | Skraćenica | Engleski ekvivalent | Šta znači |
|---|---|---|---|
| Komitent | — | partner / contact / business_partner | Univerzalan termin: kupac ili dobavljač (po `Vrsta sifre` se raspoznaje) |
| Kupac | — | customer | Komitent kome prodajemo |
| Dobavljač | — | supplier / vendor | Komitent od koga kupujemo |
| Prodavac | — | salesperson | Interni nalog korisnika sistema (sa POS prošlosti — ima password, NefiskalniRN flag) |
| PIB | — | tax_id | Poreski identifikacioni broj (srpski standard) |
| Crna Lista | — | blacklist | Lista komitenata sa kojima se ne posluje |
| Cenovnik | — | price_list | Lista cena artikala za određenu kategoriju kupaca |
| Rabat | — | discount | Popust |
| Nivelacija | — | price_revaluation | Promena cena artikala (sa knjiženjem razlike) |

#### F.6 Knjigovodstvo i finansija

| Termin | Skraćenica | Engleski ekvivalent | Šta znači |
|---|---|---|---|
| Glavna Knjiga | GK | general_ledger | Sintetička evidencija svih knjiženja |
| Konto | — | account | Račun u kontnom planu (npr. 2010 - Dobavljači) |
| Kontni plan | — | chart_of_accounts | Lista svih konta |
| Kontiranje | — | accounting_entry / posting | Akt knjiženja (određivanje konto + iznos) |
| Šema za kontiranje | — | posting_scheme / posting_template | Pravila kako se određeni event automatski knjiži |
| Nalog GK | — | ledger_journal | Skup knjiženja sa istim datumom i opisom |
| Stavka GK | — | ledger_line / journal_line | Pojedinačno knjiženje (Duguje + Potražuje) |
| KEPU | KEPU | inventory_purchase_book | Knjiga Evidencije Prometa Usluga (i robe) — srpski poreski format |
| KEPU MP | KEPU_MP | retail_inventory_book | KEPU za maloprodaju |
| POPDV | POPDV | vat_evidence_form | Pregled obračuna PDV — srpski poreski obrazac |
| PPPDV | PPPDV | vat_return | Poreska prijava PDV-a |
| IF | IF | outgoing_invoice | Izlazna Faktura (mi izdajemo kupcu) |
| UF | UF | incoming_invoice | Ulazna Faktura (dobavljač nama) |
| USLF / USL | USLF | service_invoice | Usluga Faktura (faktura za usluge) |
| Profaktura | — | proforma_invoice | Predračun (nije konačna faktura) |
| MP | MP | retail | Maloprodaja |
| VP | VP | wholesale | Veleprodaja |
| Trgovačka knjiga | TK | trade_book | Srpska poreska evidencija prometa robe |
| Otvorena stavka | — | open_item | Faktura/nalog koji još nije plaćen / poravnat |
| IOS | IOS | balance_confirmation | Izvod Otvorenih Stavki (potvrda salda komitenta) |
| Saldo | — | balance | Razlika između duguje i potražuje |
| Kompenzacija | — | netting / setoff | Međusobno poravnanje dugovanja i potraživanja |
| Kamata | — | interest | Zatezna kamata na zakasnela plaćanja |
| Kurs | — | exchange_rate | Devizni kurs |
| Kurs deli | — | exchange_rate_division | Modalitet preračuna deviznih iznosa |
| Devizna razlika | — | fx_difference | Razlika usled promene kursa |

#### F.7 Magacin i robni promet

| Termin | Skraćenica | Engleski ekvivalent | Šta znači |
|---|---|---|---|
| Robno dokument | — | inventory_document / goods_movement | Dokument koji menja stanje magacina (ulaz/izlaz) |
| Stavka robne | — | line_item | Pojedinačna stavka u robnom dokumentu |
| Ulaz / Izlaz | — | receipt / issue | Smer kretanja robe |
| Artikal | — | item / SKU | Šifrovana stavka u katalogu robe |
| R_Artikli | — | items_master | Master tabela artikala |
| R_Tarife | — | tax_rates | Master tabela PDV stopa |
| R_Grupa | — | item_groups | Master tabela grupa artikala |
| Tarifa | — | tax_rate | Stopa PDV-a |
| KL Cena (klijentska) | KLC | customer_price | Cena specifična za kupca |
| VP Cena | VPC | wholesale_price | Veleprodajna cena |
| MP Cena | MPC | retail_price | Maloprodajna cena |
| NC / NCN | — | acquisition_cost | Nabavna cena |
| ZTS / ZTD | — | input_charges_supplier / dealer | Zavisni troškovi (carina, špedicija) |
| Popis | — | inventory_count / stocktake | Inventura |
| Nivelacija | — | revaluation | Promena cena postojećih zaliha |

#### F.8 Sistemski / aplikativni termini

| Termin | Skraćenica | Engleski ekvivalent | Šta znači |
|---|---|---|---|
| Dnevnik | — | audit_log | Aplikacijski log korisničkih akcija |
| Zaštita | — | hardware_lock | Vendor-ova hardware-locked licenca |
| Bliski susret | — | (modul, ne pojam) | Boot dispatch + global params modul (filmska referenca) |
| Prva maska | — | main_screen / main_menu | Glavna početna forma |
| Podforma | — | subform | Embedded forma unutar druge forme (Access koncept) |
| Reklamni Panel | — | info_display | TV ekran u radionici sa rotirajućim slikama/porukama |
| ULS | ULS | user_level_security | Stari Access workgroup security model (deprecated) |
| MDW | — | workgroup_file | Access workgroup definicioni fajl |

### Dodatak G: Pomoćni MDB fajlovi (BB_CFG_Lokal, BB_FIT, BB_TMP)

Pored glavnog `QBigTehn_APL.MDB` front-end-a i SQL Server backend-a, aplikacija koristi tri pomoćna `.mdb` fajla. Svi su Access bez ULS zaštite (otvoreni format), čitaju se kroz ACE.OLEDB provider, čuvaju se u istom folderu kao i front-end (`C:\SHARES\SERVOTEH\QBigTehn\`).

#### G.1 BB_CFG_Lokal.mdb — Lokalna konfiguracija

**Svrha:** parametri specifični za jednu radnu stanicu (per-machine), tako da svaka mašina može imati svoj setup bez uticaja na ostale.

**Glavne tabele koje se očekuju:**
- `CFG_Lokal` — kolone `Parametar`, `Vrednost`, `IDFirma` — primarna tabela parametara
- `CFG_TabStop` — redosled kontrola pri Tab pritiska na formama (per-machine UI customization)
- `BBDefUser` — default vrednosti per Windows korisnik (`UserName`, `DefaultOJ`, `DefaultOD`, `UnlockOJ`, `UnlockOD`)

**Tipični parametri u `CFG_Lokal`:**
- `StartFormName` — koja forma se otvara po startu aplikacije (npr. `Prva maska`, `RNPregled`, `PrvaMaskaKonobar`)
- `MSAccessProg` — putanja do `MSACCESS.EXE` (koristi `RunExtBigBit` za pokretanje BigBit-a)
- `KafeScenario` — POS varijanta (`Kelvin` ili druge) — irelevantno za Servoteh

**Upravljanje:** kroz `Form_CFG_Lokal` u Access UI, ili direktno preko `LIB_CFGRW.WriteParametar("CFG_Lokal", parname, value)` u VBA.

**Migracioni plan:** u Postgres bi ovo bila tabela `local_config` (ako je per-mašina) ili `user_preferences` (ako je per-korisnik). Bolje rešenje: izbaciti per-machine config, koristiti per-user preferences (jer u web/cloud svetu mašine nisu identitet).

#### G.2 BB_FIT.MDB — Konfiguracija konekcionih fajlova

**Svrha:** centralni registar svih baza i tabela koje aplikacija zna da koristi. Naziv "FIT" verovatno znači "**F**ajlovi **I** **T**abele". (Inicijalno sam pretpostavljao da je fiskalna baza, ali analiza pokazuje da nije — to je config registry za multi-baza setup.)

**Glavne tabele:**
- `BazeITabele` — mapiranje "ova tabela treba da se linkuje iz ove baze"
- `BazeITabele_APL` — aplikaciono-specifična varijanta (per QMegaTeh)
- `Baze_Tipovi` — katalog tipova baza (`BigBit_T`, `MasterDB`, `EXTBAZA`, `TMP`, `FIT`, itd.)
- `Baze_Tipovi_APL` — per-aplikacija
- `Baze_Firme` — koja baza pripada kojoj firmi

**Funkcija u kodu:** `F_CheckBBFIT(stBBFit, ForceNew)` proverava da li `BB_FIT.mdb` postoji i da li je `CNN_FIT` connection string ispravno upisan u `.mdb` properties. `SynchTabeluSaAPL(BazaZaTip("BB_FIT"), "BazeITabele", "BazeITabele_APL")` sinhronizuje BigBit-ovu master kopiju ka per-aplikaciji listama.

**Upravljanje:** kroz `Form_Baze`, `Form_BazeITabele`, `Form_BazeITabele_APL` admin forme. Ne dira se često — uglavnom samo kad se premesta baza ili dodaje nova.

**Migracioni plan:** u Postgres-u ovo postaje set tabela `connections`, `external_tables`, `external_table_mappings`. Ali za Servoteh, samo treba minimum: konfiguracija konekcije ka BigBit-u + lista `EXT_*` tabela koje sync-ujemo.

#### G.3 BB_TMP.mdb — Privremeni / scratch fajl

**Svrha:** privremene tabele koje se koriste za međurezultate, ne za perzistentnu evidenciju. Sadržaj se može u svakom trenutku obrisati bez gubitka poslovnih podataka.

**Tipične tabele (po referencama u kodu):**
- `tmp_T_KontroleNaFormi` — keš metadata o kontrolama na formama (za `BBPravaPristupa`)
- `tmp_PDM_KataloskiBrojevi` — privremena lista kataloških brojeva pri PDM operacijama
- `~tmp_T_Linked~` — interna Access notacija za temp linked tabele
- Sve `tmp_*` prefiksovane tabele iz upita (`tmp_*` query serija u Dodatku B)

**Funkcija u kodu:** `Postavi_Lokal_TMP()` linkuje sve `tmp_*` tabele iz `BB_TMP.mdb`. Aplikacija ih koristi za spool-ovanje međurezultata umesto da puni SQL Server temp tablicama.

**Upravljanje:** može se obrisati (`BB_TMP.mdb`) i aplikacija će je sama rekreirati sledeći put. Backup nije potreban.

**Migracioni plan:** u Postgres-u ovo nestaje. Sve što su privremene tabele zameniće se sa: (a) `TEMPORARY TABLE` sintaksom (tabela postoji samo za trajanje sesije), (b) Common Table Expressions (CTE) — `WITH tmp AS (...)`, ili (c) materialized views ako se podaci često ponavljaju. **Postoje 0 razloga da postoji `tmp_*.mdb` ekvivalent u modernom sistemu.**

#### G.4 Sažetak — bekap strategija za pomoćne MDB fajlove

| Fajl | Backup potreban? | Učestalost | Napomena |
|---|---|---|---|
| `BB_CFG_Lokal.mdb` | DA | Pri svakoj promeni config-a | Mali fajl (<10MB), može i nedeljno uz ostatak |
| `BB_FIT.MDB` | DA | Pri svakoj promeni baza/konekcija | Stabilan — backup mesečno je dovoljan |
| `BB_TMP.mdb` | NE | — | Sigurno za brisanje, aplikacija sama regeneriše |

---

*Kraj dokumentacije.*

*Ako se nešto u kodu ne slaže sa ovom dokumentacijom — kod je istina, dokumentacija je prikaz koji je možda zastareo. Update-ujte oba.*

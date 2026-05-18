# Kadrovska — Roadmap (post-C5)

> **Verzija**: 1.0 · **Datum**: 2026-05-18 · **Status**: aktivno
> Živ dokument. Po završetku stavke označi `[x]` i pomeri u sekciju **„Završeno"**.

---

## A. Trenutno stanje modula

### A.1 Brojke
| Metrika | Vrednost |
|---------|---------:|
| UI fajlovi (`src/ui/kadrovska/`) | **23** |
| UI LOC | **~13 680** |
| Servisi (kadr+employee+salary+vacation+…) | **~2 800 LOC** |
| Unit testovi | **319 ✓** (40 u `payrollCalc`, 32 u `gridUtils`, ostalo van modula) |
| SQL migracije kadr+kadrovska | **28** fajlova (samo 4 u CI listi — admin ručno pokreće ostatak) |
| TypeScript / JSDoc strict | **0%** (vanilla JS svuda) |

### A.2 Funkcionalno pokriveno (11 tabova)
- ✅ Pregled (Dashboard) — KPI + action stack sa rokovima + 3 mini grafikona
- ✅ Kalendar — mesečni grid odsustava + praznici + 🎂 + ⚠ ističe
- ✅ Mesečni grid — Excel-like batch unos sati (~1 200 LOC)
- ✅ Odsustva — Pregled + Listing; column sort
- ✅ Zaposleni — prošireni profili + soft-delete + audit + bulk + quick chips + column sort
- ✅ Godišnji odmor — entitlements + saldo + Gantt + PDF rešenje
- ✅ Zahtevi GO — approve/reject sa scope-om po pododeljenjima
- ✅ Sati (pojedinačno) — manual entry + queue payroll email; column sort
- ✅ Ugovori — status + bulk produženje + PDF rešenje; column sort + bulk
- ✅ Zarade (admin only) — Uslovi + Mesečni obračun + PDF + bulk PDF
- ✅ Notifikacije — queue + Edge dispatch + WhatsApp/email config
- ✅ Izveštaji — 11 pod-izveštaja (bolovanja, demografija, organogram, saldo GO, prekov., teren, lekarski, sertifikati, deca, **risk**, audit log)

### A.3 Cross-cutting infrastruktura (deli sa ostatkom app-a)
- ✅ `lib/dom.js` — toast stack, skeleton helper
- ✅ `lib/modalA11y.js` — ESC + body scroll lock
- ✅ `lib/keyboardShortcuts.js` — `/`, `n`, `r`, `?`
- ✅ `lib/columnSort.js` — reusable sort utility
- ✅ `lib/confirm.js` — askConfirm sa requireType
- ✅ `services/kadrOfflineQueue.js` — POST/PATCH/DELETE offline queue
- ✅ `state/kadrovska.js` — subscribe-based reset na logout (PII leak fix)

### A.4 Coverage matrica funkcionalnosti

| Feature | Zaposleni | Odsustva | Ugovori | Sati | GO | Zarade | Notif | Izveštaji |
|---------|:---------:|:--------:|:-------:|:----:|:--:|:------:|:-----:|:---------:|
| Column sort | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Quick chips | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Bulk select | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Empty CTA | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | — |
| Skeleton loader | — | — | — | — | — | — | — | parcijalno |
| Excel export | ✅ | ✅ | ✅ | — | ✅ | ✅ | — | ✅ |
| PDF export | ❌ | ❌ | ✅ | ❌ | ✅ | ✅ | — | ❌ |
| Audit log UI | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ | — | ✅ |

---

## B. Audit nalazi (sveže, post-C5)

### B.1 Tehnički dug

**B.1.1 `reportsTab.js` je 2 700 LOC** — najveći fajl u modulu.  
Sadrži 11 pod-izveštaja u jednoj funkciji `renderReportsTab()` i jednom monolitnom `wireReportsTab()`. Pri prvom mount-u parsiramo ~50KB HTML-a iako korisnik vidi samo jedan tab. Performance penalty na sporijim mašinama.

**B.1.2 Migracije nisu u CI** — 22 od 28 `add_kadr*.sql` nisu u `sql/ci/migrations.txt`. Admin ih ručno pokreće što stvara rizik: novi instance / fresh DB neće imati schema parity osim ako neko sledi `docs/Kadrovska_modul.md`.

**B.1.3 Nula TypeScript / JSDoc strict** — sav kadrovski kod je čist JS. `reportsTab.js` 2 700 LOC u JS-u je bug paradise.

**B.1.4 0% E2E coverage** — postoji samo unit testovi. Promene u event handler-ima / RLS politikama mogu prolaziti tiho.

**B.1.5 Konzole logovi nisu central** — ~30+ `console.warn/error` poziva. Ako pukne produkcija, nemamo Sentry/LogRocket da uhvati grešku.

### B.2 Nedostajuće funkcionalnosti

**B.2.1 Bulk select fali u 6/8 tabela** — postoji samo u Zaposleni i Ugovori. Korisni u Odsustvima (npr. odobri više po danu) i Sati.

**B.2.2 Quick filter chips fale u 7/8 tabela** — postoji samo u Zaposleni. Korisno svuda gde su filteri u dropdown-u (Odsustva: "Tekući mesec", Ugovori: "Ističu ovaj mesec").

**B.2.3 Auto-cron za weekly risk nije aktiviran** — SQL fajl je commit-ovan i (po prethodnoj sesiji) primenjen u Supabase MCP, `pg_cron` job zakazan. Ali sledeći ponedeljak mora da se proveri da li poslat email.

**B.2.4 Mobile / touch UX je minimalan** — samo 2 media queries u `kadrovska.css`, 9 u `legacy.css`. Mesečni grid se na mobilnom ne može razumno koristiti (28 kolona × 4 reda po radniku). Capacitor build postoji, ali UX-wise je desktop-first.

**B.2.5 Soft-delete proširenje** — postoji za Zaposlene. **Fali za Ugovore i Odsustva** (jednom obrisan zapis se ne može vratiti).

**B.2.6 Nema undo za toast** — kad se neka destruktivna akcija desi (npr. "Deaktiviran zaposleni"), nema "Vrati" dugmeta u toast-u. Korisnik mora ručno da vrati. Standardno GitHub/Linear pattern.

**B.2.7 Service worker nije optimizovan** — sve LS keš čistimo na logout, ali Capacitor offline mode ne testiran sa novim feature-ima (kalendar, bulk PDF, risk).

### B.3 UX / sitnice

**B.3.1 Nema "load more" / paginacije** — sve tabele učitavaju ALL i client-side filtruju. Sa 500+ zaposlenih, browser će usporiti pri sortiranju Zarada (svaki rerender 500 redova).

**B.3.2 Toast nema undo** — vidi B.2.6.

**B.3.3 Empty state slike** — sve empty states su tekstualne. Linear/Notion stil sa ilustracijama bi povećao "feel".

**B.3.4 Drag&drop import** — `employeesBulkModal` ima file picker, ali drag&drop nije eksplicitno testiran u FE-u.

**B.3.5 Date pickers su native** — `<input type="date">` daje različit UX u Safari vs Chrome vs Firefox vs mobile. Linear/Notion koriste custom picker. Nije akutni problem — radi svuda.

**B.3.6 Pretraga nije fuzzy** — `includes()` za pretragu znači da "Petrović" ne nađe "Petrovic" (bez dijakritike). Korisnik mora tačno da kuca.

### B.4 Security / RLS

**B.4.1 JMBG checksum je warn-only** — namerno, jer ima legacy unose sa lošim JMBG-em. Ali nemam dashboard koji prikazuje "imamo N zaposlenih sa nevalidnim JMBG-om" pa da admin vidi i postepeno popravlja.  
*(Postoji quick chip "Bez JMBG" — pokriva slučaj kad JMBG fali, ali ne i kad postoji ali je sa pogrešnom kontrolnom cifrom.)*

**B.4.2 RLS na vacation_requests delete** — TODO komentar u `vacationRequestsTab.js:259` ostaje od prethodnog sprinta.

**B.4.3 Audit log ne hvata sve tabele** — `kadr_holidays`, `vacation_requests`, `kadr_notification_log/config` nemaju trigger-e za audit. Ako admin promeni email primaoce, nema traga.

**B.4.4 Edge function secrets nisu verifikovani** — `hr-notify-dispatch` može da bude u DRY-RUN modu ako fali `RESEND_API_KEY`. UI ne pokazuje status (status: `queued` zauvek).

### B.5 Test pokrivenost

| Fajl | LOC | Pokrivenost |
|------|----:|-------------|
| `payrollCalc.js` | 568 | ✅ 40 testova (najveći skup) |
| `gridUtils.js` | 127 | ✅ 32 testa |
| `jmbg.js` | ~50 | ✅ 18 testova |
| `auditLog.js` | 80 | ❌ |
| `vacation.js` | 107 | ❌ |
| `salaryPayroll.js` | 368 | ❌ |
| `workHoursAbsenceReporting.js` | 241 | ❌ |
| `employees.js` (mapDbEmployee + buildPayload) | 171 | ❌ |
| `contracts.js`, `absences.js`, `workHours.js` mapper-i | ~60 svaki | ❌ |

**Kritični kandidati za testove**: `workHoursAbsenceReporting.js` (saldo GO logika), `salaryPayroll.js` (RPC mapper-i + compute context), `auditLog.diffAuditRow`.

---

## C. Plan po prioritetu

Estimacije: **XS** <2h · **S** 2-4h · **M** 4-8h · **L** 1-2 dana · **XL** 2-5 dana · **2XL** >1 nedelje.

### P0 — Hitno (sledeće na redu, blokeri za produkciju)

- [ ] **P0.1 Verifikuj weekly risk auto-cron** — `XS` · Proveri u `cron.job_run_details` da li je prvi ponedeljak okinuo job, da li je email stigao. Ako ne — pogledaj `kadr_notification_log` za failed redove i Edge function logs.
- [ ] **P0.2 Edge function secrets check** — `XS` · `supabase secrets list` da potvrdiš `RESEND_API_KEY` postoji. Ako nema, queue je beskoristan.
- [ ] **P0.3 CI registry za migracije** — `S` · Dodaj svih 22 `add_kadr*.sql` u `sql/ci/migrations.txt` ili dokumentuj zašto ne (npr. zavise od ručnih koraka). Bez ovoga, fresh DB neće raditi.

### P1 — Visok prioritet (vidljivi za korisnika, niskorizični)

- [ ] **P1.1 Quick chips za Odsustva, Ugovori, Sati** — `S` · Copy pattern iz Zaposleni. Predlog filtera:
  - Odsustva: "Tekući mesec", "Bolovanja samo", "Aktivni periodi (danas u toku)"
  - Ugovori: "Ističu <30d", "Istekli", "Bez datuma do"
  - Sati: "Tekući mesec", "Sa prekovremenim", "Bez napomene"
- [ ] **P1.2 Bulk select za Odsustva** — `M` · Akcije: bulk obriši (admin), bulk produži datum_do, eksport selektovanih.
- [ ] **P1.3 Toast undo dugme** — `S` · Posle "Zaposleni deaktiviran" toast pokaže "↶ Vrati" 5s. Klik vraća `is_active=true`. Pattern za Linear/Gmail.
- [ ] **P1.4 Saldo GO podaci u dashboard mini-graphu** — `S` · Trenutno mini graf prikazuje samo zaposlene po odeljenju. Dodaj "GO iskorišćeno vs preostalo" bar po odeljenju.
- [ ] **P1.5 Validate JMBG dashboard** — `XS` · Dodaj quick chip "JMBG nevalidan (checksum)" u Zaposleni. Klik → lista korisnika sa pogrešnom kontrolnom cifrom da admin postepeno popravi.
- [ ] **P1.6 Empty state ilustracije** — `S` · 3-4 SVG ilustracije (Inbox-style) u kadrovska/empty/, primeni svuda gde fali.
- [ ] **P1.7 Loading skeletons na ostalim tabovima** — `S` · Zaposleni, Odsustva, Ugovori, Zarade, Izveštaji — sada bljesnu "Učitavanje" ili prazno. Apliciraj `renderSkeleton()` na svih 11 tabela na prvi load.

### P2 — Srednji prioritet (poboljšanja, neki traže DB)

- [ ] **P2.1 Soft-delete za Ugovore i Odsustva** — `M` · Dodaj `archived_at` kolonu + UI toggle "Vrati"/"Trajno obriši". DB migracija + RLS update.
- [ ] **P2.2 Column sort za Zarade + Godišnji odmor** — `S` · Apliciraj utility na ostala 2 taba.
- [ ] **P2.3 Audit log proširenje** — `M` · Trigger za `kadr_holidays`, `vacation_requests`, `kadr_notification_config`. Bez ovoga, izmene u konfiguraciji notif su nevidljive.
- [ ] **P2.4 Fuzzy / latinično-čirilična pretraga** — `M` · Normalizuj dijakritike u `applyFilters` (`č` → `c`, `ć` → `c`, …). Pomaže kad korisnik kuca brzo bez dijakritike.
- [ ] **P2.5 Paginacija ili virtual scroll za Zarade** — `L` · Kad ima >200 redova, sortiranje je sporo. Virtual scroll daje 10× ubrzanje.
- [ ] **P2.6 Centralni `apiCall` wrapper** — `L` · Sad svaki servis ponovi `if (!getIsOnline() || ...) return null;` 2-3 puta. Apstrahuj retry/timeout/auth-refresh u jedan utility.
- [ ] **P2.7 Sentry / error tracking** — `M` · Centralni `logError(scope, err, meta)` koji u dev ide u console, u prod u Sentry. Postoji 30+ `console.error` poziva koje treba pohvatati.
- [ ] **P2.8 Unit testovi za kritične servise** — `L` (4×S):
  - `workHoursAbsenceReporting.js` — saldo GO + count agregacije
  - `salaryPayroll.js` — `computeDisplayTotals` mapping
  - `auditLog.diffAuditRow` — edge cases (null pre / null posle)
  - `employees.buildEmployeePayload` — JMBG sanitization, PII guard
- [ ] **P2.9 Print stylesheet globalno** — `S` · `@media print` za sve tabele (skupi padding, ukloni hover, page-break-inside: avoid na tr).

### P3 — Veće stvari (poseban sprint po stavci)

- [ ] **P3.1 Performance review (recenzije)** — `2XL` · Nov modul: DB tabele, RLS, UI tab, ciklus, ko ocenjuje koga. **Blokirano**: traži biz odluke od user-a.
- [ ] **P3.2 Compliance pack RS — M-4 / PIO / RFZO** — `XL` · Traži pouzdan format (od računovođe). **Blokirano**: rizik od pogrešnog izlaza.
- [ ] **P3.3 e-Potpis flow za ugovore** — `XL` · DocuSign API integracija ili SEAL.RS / e-Uprava. Treba auth + storage za potpisane PDF-ove. Trenutno se PDF generiše ali se ručno potpisuje na papiru.
- [ ] **P3.4 Mobile-first UX redizajn Mesečni grid** — `XL` · 28 kolona × 4 reda po radniku ne radi na telefonu. Redizajn: per-employee view, swipe između dana.
- [ ] **P3.5 E2E Playwright setup** — `L` · Setup + 3-4 zlatne staze: HR login → dodaj zaposlenog → unesi sate; admin → pripremi mesec → zaključaj; menadzment → samo svoje pododeljenje.
- [ ] **P3.6 TypeScript po fazama** — `2XL` · Počni sa `lib/*` (čiste funkcije), pa servisi, pa UI poslednji. JSDoc strict preko `// @ts-check` može da bude prelaz.
- [ ] **P3.7 Plate slips storage + auto-email** — `L` · Trenutno PDF živi samo u browser-u. Dodaj snimanje u `payslips/{employee_id}/{period}.pdf` bucket + auto-email kroz `hr-notify-dispatch`. Daje zaposlenom istoriju u `mojProfil`.
- [ ] **P3.8 Sastanci 1-on-1 modul** (možda u sastanci postoji?) — `XL` · Zaposleni i njegov manager imaju kalendar sastanaka sa zapisnikom. Ne sa kadrovskim radom direktno, ali je HR-related.

### P4 — Strateški (van okvira modula, ali HR-related)

- [ ] **P4.1 Onboarding / Off-boarding workflow** — `XL` · Checklista zadataka pri ulasku zaposlenog (lekarski, BZR, oprema, kartice) i izlasku (vraćanje opreme, audit reversa, izlazni intervju).
- [ ] **P4.2 Recruitment / kandidati** — `2XL` · Posebna sekcija za kandidate, pre nego što postanu zaposleni. Status pipeline, intervjui, ocene.
- [ ] **P4.3 Salary benchmarking** — `XL` · Anonimni statistički dashboard "prosečna plata po poziciji" za HR. Bez identifikacije pojedinaca, RLS-sigurno.
- [ ] **P4.4 Integracija sa BigTehn / proizvodnja** — `XL` · Već postoje `bigtehn_*` cache tabele. HR može da vidi "koje radnike treba obučiti na novu mašinu" kombinacijom sertifikata i mašina koje rade. Dual use.

---

## D. Strateški pravci (12-24 meseca)

1. **Servoteh HR Suite** — modul je dobar kandidat da postane samostalni proizvod (white-label za druge MES/proizvodne firme od 50-200 ljudi).
2. **Compliance-as-a-Service** — automatske M-4 prijave, PIO statistika, e-Uprava integracija → 80% manje rada za HR osobu.
3. **Predictive HR 2.0** — trenutno imamo risk skor po pravilima. Sledeća faza: ML model za predikciju otkaza (turnover risk), apsentizma, performansi.
4. **Mobile-first (Capacitor native build)** — već postoji setup, treba UX redizajn za prioritetne tokove (Moj profil, kalendar, GO zahtev).

---

## E. Rizici / ograničenja

| Rizik | Verovatnoća | Uticaj | Mitigacija |
|-------|:-----------:|:------:|------------|
| Zakon o radu se menja → obračun zarada | Sredna | Visok | `payrollCalc.js` ima 40 testova, ali biznis pravila treba revalidirati svaki Q1 |
| Resend / Edge function deprecation | Niska | Visok | hr-notify-dispatch je decoupled — može da pređe na SES / Mailgun u 1 dan |
| Velika firma (>200 ljudi) → klijent slow | Sredna | Sredan | P2.5 virtual scroll je prevencija |
| RLS regresija → korisnik vidi tuđe podatke | Niska | Vrlo visok | `rbacMatrix.test.js` postoji ali pokriva samo deo politika; treba E2E |
| BigTehn sync stane → praznine u kalendaru | Sredna | Sredan | Module je relativno nezavisan, prazna polja imaju fallback |
| Smart-quotes bug u Edit-u (vidi MEMORY.md) | Visoka | Visok (build break) | Edit-uj sa Read kontekstom; ako padne build na Unicode → vrati Read+rewrite |

---

## F. Završeno (referencija za poslednji audit)

Svrha: prepoznati da ne ponavljamo isto. Detalje vidi u git log.

- **B1-B4** (audit 1) · ssSet import, [D3] log, PII LS cache, module-state reset
- **C1** · modalA11y (ESC + scroll lock)
- **C2** · askConfirm sa requireType, soft-delete za Zaposlene, audit diff modal, action stack pill-ovi sa rokovima, vacationTab rename _selectedDepts → _hiddenDepts
- **C3.1** · PDF rešenje o zasnivanju radnog odnosa
- **C3.2** · mojProfil: kartice "Moji dokumenti" + "Kolege u odeljenju"
- **C3.3** · Kalendar tab (mesečni grid odsustava + heatmap)
- **C3.4** · Risk izveštaj + heatmap + mailto → RPC; SQL nacrt za weekly cron
- **C3.6** · Plate slips PDF (single + bulk konsolidovan)
- **C5 deo 1** · Toast stack, keyboard shortcuts (`/`, `n`, `r`, `?`), loading skeletons, column sort pilot
- **C5 deo 2** · Sort utility širenje, quick chips Zaposleni, empty CTA, bulk emp deactivate, +11 testova za payrollCalc (319/319 zelena)

---

## G. Kako koristiti ovaj dokument

1. **Pre svake nove sesije** — pregledaj P0 (mora) i P1 (vredi).
2. **Pri kraju sesije** — označi `[x]` završeno, pomeri u sekciju F (Završeno) sa kratkim opisom.
3. **Svaka 2-4 nedelje** — refresh audit (B sekcija) jer se kod menja.
4. **Promena prioriteta** — pomeri stavku između P0–P3 sa komentarom „premeštam jer …".

Format estimacije može da se prilagodi (XS/S/M/L/XL/2XL su per čovek-dan). Sprint je obično M+S+S ili L+S — ne nabijaj 3 XL-a u jedan dan.

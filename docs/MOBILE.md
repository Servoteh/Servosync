# Servoteh Lokacije — mobilna aplikacija

Mobilni shell za magacionere i viljuškariste. Radi u tri varijante iz
istog koda:

1. **PWA** u bilo kojem modernom mobilnom browseru (Chrome Android,
   Safari iOS, Samsung Internet) — korisnik otvori
   `https://<poddomen>.pages.dev/m`, ima opciju „Dodaj na početni ekran"
   i app se ponaša kao native (offline cache, fullscreen). **Radi
   odmah, bez ikakve instalacije.**
2. **Android APK** — isti web kod spakovan u Capacitor wrapper, plus
   native barcode scanner (Google ML Kit) koji je ~10× brži od web
   ZXing-a. Distribuira se manuelno (USB/Telegram) — **nije na Play
   Store-u**.
3. **iOS IPA** — isti web kod u Capacitor wrapperu, opet sa native ML
   Kit scannerom. **ALI**: instalacija na iPhone je mnogo komplikovanija
   od Androida. Imamo tri puta (vidi sekciju **6. iOS instalacija**).

---

## 1. Šta magacioner vidi

Home ekran (`/m`) ima samo 4 stvari:

- **📷 SKENIRAJ BARKOD** — otvara kameru, auto-parsiraj `NALOG/CRTEŽ` iz
  BigTehn nalepnice, prikaže formu za izbor lokacije i količine.
- **⌨ RUČNI UNOS** — isti flow, ali bez kamere (ako nalepnica fali ili je
  oštećena).
- **📋 MOJA ISTORIJA** — poslednjih 50 premeštanja koje je ovaj korisnik
  zabeležio (sa vremenom, lokacijama, količinom).
- **🗂 BATCH MOD** — skeniraj N komada zaredom, pa jednim klikom pošalji
  sve u istu lokaciju (npr. prebacivanje cele palete na policu K-A3).

Sve interakcije imaju min tap target 72px (dovoljno za prste sa
rukavicama) i dodatni vibrate feedback na uspeh/grešku.

## 2. Offline queue

Ako WiFi nestane usred skeniranja:
- skeniranje se **ne gubi** — upisuje se u lokalni queue (localStorage);
- home ekran pokazuje `⏳ N čeka` badge umesto `✓ sinhronizovano`;
- čim se WiFi vrati, queue se automatski flush-uje (ili korisnik može da
  klikne badge da forsira pokušaj).

Queue je ograničen na 500 zapisa (safety cap) — praktično nikad nećemo
doći blizu.

Source: `src/services/offlineQueue.js`.

## 3. Arhitektura — kako to sve radi

```
┌──────────────────────────────────┐
│ index.html (#app)                │
│                                  │
│  /                → ERP hub       │
│  /plan-montaze    → Plan modul    │
│  /m               → Mobilni home  │
│  /m/scan          → Kamera scan   │
│  /m/manual        → Ručni unos    │
│  /m/history       → Moja istorija │
│  /m/batch         → Batch skener  │
└──────────────────────────────────┘
         ↓ (svi path-ovi)
     src/ui/router.js

/m/* rute →  src/ui/mobile/*.js
                ↓
         reuse scanModal (lokacije)
                ↓
         Supabase REST / RPC
                ↓
          loc_create_movement
```

Samo na `/m/*` rutama se **registruje Service Worker** — glavni ERP
nema PWA cache da ne blokira brze deploy-eve. Vidi `src/lib/pwa.js`.

## 4. Kako instalirati APK na telefon

### Korak 1 — preuzmi APK

1. Otvori GitHub repo → **Actions** → **Build Android APK** → odaberi
   najnoviji uspešni run.
2. Dole pod **Artifacts** klikni `servoteh-lokacije-*.apk` da ga preuzmeš
   na računar.
3. Prebaci APK na telefon: Telegram (pošalji sebi), Google Drive, USB
   kabl, ili Bluetooth.

### Korak 2 — dozvoli instalaciju iz nepoznatih izvora

Android 8+: **Settings → Apps → Special access → Install unknown apps**,
izaberi browser ili Files aplikaciju preko koje ćeš otvoriti APK →
**Allow from this source**.

### Korak 3 — instaliraj i otvori

1. Na telefonu tap-ni preuzeti `.apk` fajl.
2. Android može prikazati upozorenje "Blocked by Play Protect" → **Install
   anyway** (APK je unsigned jer ne ide na Play Store).
3. Posle instalacije otvori app „Servoteh Lokacije".
4. Prva prijava: isti email + password kao na webu.

### Korak 4 — ažuriranje

Kad pošaljemo novi build, samo preuzmeš novi APK i ponovo ga instaliraš
— Android će ga merge-ovati preko postojećeg (sve podatke zadržava:
istoriju, queue, login).

## 5. PWA alternativa (bez instalacije APK-a)

Za telefone gde ne može APK, ili dok se iOS sideload ne podesi, otvoriš:

```
https://<cf-pages-poddomen>.pages.dev/m
```

Na Androidu (Chrome): `⋮ → Add to Home screen`. Na iPhone-u (Safari —
**mora biti Safari, ne Chrome za iOS!**): `Share ↑ → Add to Home Screen`.
Ikona se pojavi kao obična app.

Service Worker keš-uje CSS/JS da bude brzo i kad je WiFi slab.

Razlika od native-a:
- **PWA**: koristi web kameru preko ZXing-a (sporije, ali radi).
- **APK / IPA**: koristi Google ML Kit native scanner (brže i pouzdanije).

### iOS-specific PWA caveats

- iPhone briše PWA storage (localStorage, IndexedDB, offline queue)
  **posle 7 dana** ako korisnik ne otvori app. Magacionerima savetuj
  da app otvore makar jednom nedeljno.
- Kamera radi via `getUserMedia` samo na iOS 14.3+. Provera: Settings
  → Safari → Advanced → Experimental Features → `MediaRecorder` mora
  biti ON.
- Fullscreen „standalone" mode radi tek kad je app instaliran iz
  `Share → Add to Home Screen` — otvaranje linka direktno u Safari-ju
  prikazuje i Safari UI.
- Haptic feedback (vibrate) NE radi u PWA na iOS-u (Apple ograničenje).
  Radi samo u native IPA.

## 6. iOS instalacija — tri puta

Apple blokira sideload direktno instalacije APK-like fajlova. Imamo
**tri opcije**, u rastućem redu komfora i cene:

### Opcija A — Besplatno: PWA (preporučeno za prve testove)

Nije prava „app" ali izgleda kao — i za 90% flow-a magacioneru je
potpuno svejedno. Nula setup, nula trošak.

Koraci su gore u **sekciji 5**. Koristi ovo dok ne proceniš da ti treba
nativna kamera (obično zbog brzine skeniranja u lošem svetlu hale).

### Opcija B — $0/god: Sideloadly + Free Apple ID (za 1-3 telefona)

Za tim gde 1-2 čoveka imaju iPhone, ovo je najjeftinija varijanta, ali
mora se ponavljati svakih 7 dana.

**Šta ti treba:**
- Mac ili Windows PC sa iTunes/Apple Devices app instaliranim;
- [Sideloadly](https://sideloadly.io) (free app za potpisivanje IPA);
- iPhone od korisnika + njegov Apple ID (lični);
- Neobnovljivi USB-Lightning kabl.

**Workflow:**
1. Pokreni workflow `Build iOS IPA (unsigned)` u Actions tab-u GitHub-a
   (manual trigger ili auto na push).
2. Preuzmi `servoteh-lokacije-*-unsigned.ipa` iz Artifacts.
3. Povezi iPhone kablom na PC → otvori Sideloadly.
4. Drag-and-drop IPA u Sideloadly → popuni Apple ID (može i besplatan
   nalog iz iCloud-a).
5. Klik **Start** → Sideloadly potpisuje IPA sa korisnikovim Apple ID
   i instalira na telefon.
6. Na telefonu: Settings → General → VPN & Device Management → tap-ni
   Apple ID → **Trust**.

**Ograničenja (Apple-imposed):**
- Cert traje **7 dana** — posle čega app više neće da se otvori dok je
  opet ne potpišeš. Treba da ponoviš korake 3-5.
- Maksimalno **3 app-a** istovremeno potpisana besplatnim Apple ID-jem.
- `BackgroundFetch`, push notifikacije, Keychain sharing NE rade.

Ovo je OK za 1-3 telefona koji ionako svakog jutra dolaze u kancelariju
(možeš tada re-sign-ovati). Za 10+ telefona, opcija C je pogodnija.

### Opcija C — $99/god: Apple Developer + TestFlight (enterprise-grade)

Najbolji odnos cene i komfora za više od 3 telefona.

**Šta ti treba:**
- [Apple Developer Program](https://developer.apple.com/programs/)
  pretplatа — **$99 USD godišnje** (plaća firma, ne pojedinac).
- Nalog se otvara na 1-2 dana (Apple traži dokumenta o firmi).
- Mac (svoj ili iznajmljeni u cloud-u, npr. [MacStadium](https://macstadium.com)
  od $50/mes) za prvi setup. **Alternativno**: ceo setup radiš preko
  GitHub Actions macOS runner-a bez sopstvenog Mac-a.

**Šta dobijaš:**
- TestFlight distribucija: magacioner dobija email sa linkom →
  instalira TestFlight app iz App Store-a → klik i app se instalira.
- Cert traje **90 dana** (TestFlight build-ovi), ne 7. Build od 90
  dana ne treba refresh.
- Do **100 internal testera** bez App Store review-a.
- Production IPA ako nekad rešiš da odeš na App Store.

**Setup (one-time, 2-3h):**
1. Registruj App ID `com.servoteh.lokacije` na
   https://developer.apple.com/account/resources.
2. Kreiraj Distribution Certificate + App Store Provisioning Profile.
3. Export-uj kao `.p12` + `.mobileprovision`.
4. Dodaj u GitHub Secrets (vidi komentar na dnu
   `.github/workflows/ios-ipa.yml`):
   - `APPLE_ID_USERNAME`, `APPLE_ID_PASSWORD`, `APPLE_TEAM_ID`
   - `IOS_CERT_P12_BASE64`, `IOS_CERT_PASSWORD`
   - `IOS_PROFILE_BASE64`
5. Ažuriraj CI workflow da koristi ove secrete (kod u komentaru
   unutar workflow YAML-a).
6. `xcrun altool --upload-app` korak u CI šalje IPA direktno u
   TestFlight — email magacioneru automatski.

**Kad vredi:**
- 5+ iPhone uređaja u magacinu;
- dugoročno (1+ god) održavanje;
- želiš da magacioner sam pokrene update tap-om u TestFlight app-u.

**Kad NE vredi:**
- 1-2 iPhone-a;
- probni period < 3 meseca (opcija A/B rade);
- nema ko da održava Apple Developer nalog (gubiš $99 ako expire-uje).

### Koja opcija za Servoteh

Preporučeni plan:

1. **Sad**: koristi **Opciju A (PWA)** za iPhone korisnike. Magacioner
   otvori Safari, Add to Home Screen — odradi 1 min setup i ima app.
   Prihvati kompromis sporijeg ZXing scannera.
2. **Ako se pokaže da ZXing baš ne ide** (loše svetlo, habanje
   nalepnica): pređi na **Opciju B (Sideloadly)** za 1-2 testna
   iPhone-a da potvrdiš da native ML Kit rešava problem.
3. **Kad prođe produkcijski test**: ako tim ima 3+ iPhone-a, plati
   Apple Developer i pređi na **Opciju C (TestFlight)**.

## 7. Dev workflow

### Lokalni preview

```bash
npm run dev
# Otvori http://localhost:5173/m
```

Service Worker je **isključen u dev modu** (da ne ometa HMR). PWA-specific
testing radi na `npm run build && npm run preview`.

### Rebuild APK lokalno

```bash
npm run build
npx cap sync android
cd android
./gradlew assembleDebug
# APK u android/app/build/outputs/apk/debug/app-debug.apk
```

Potrebno:
- JDK 21 (Temurin)
- Android SDK (API 34 minimum — Capacitor 8 default)
- `ANDROID_HOME` env var postavljen

### Rebuild iz Android Studija

```bash
npx cap open android
```

Otvori projekat u Android Studio — tamo možeš ceo stack debugovati, plus
instant run na povezanom telefonu (USB debugging).

### Rebuild IPA lokalno (potreban Mac)

```bash
npm run build
npx cap sync ios
cd ios/App
pod install
# Otvori u Xcode:
open App.xcworkspace
# U Xcode: izaberi svoj Team (Signing & Capabilities) → Product → Archive.
```

Potrebno:
- Xcode 15.4+ (Mac App Store);
- Apple ID (free za 7-day sideload, $99/god za TestFlight);
- macOS 13+ (Xcode 15 zahtev).

### Rebuild iz Xcode-a

```bash
npx cap open ios
```

## 8. Troubleshooting

### „Kamera ne radi u APK-u"

Prvi put instaliran ML Kit plugin downloaduje Google Barcode Scanner
Module (~2MB) iz Google Play Services. Treba WiFi prvi put. Ako ne radi:
- proveri da telefon ima Google Play Services (Huawei bez HMS neće imati);
- app će automatski fall-back-ovati na web ZXing scanner (sporiji ali
  radi svuda).

### „Radim na WiFi-ju ali kaže `⏳ N čeka`"

Offline queue se flush-uje automatski na `online` event. Ali neki routeri
u hali imaju flaky konekciju (WiFi "je" tu, ali DNS ne radi). Fix:
tap-ni na badge → forsira retry.

### „Kada vratim na web, ne vidim skeniranja odmah"

Pre deploy-a je keš-ovan stari SW. Pravi problem:
1. Otvori web app (`/`);
2. F12 → Application → Service Workers → Unregister;
3. Hard reload.

Ovo se dešava samo magacionerima jer **ERP hub (`/`) nema SW**. U
produkciji: ne bi trebalo da se desi, ali eto ti steps.

### „iPhone: 'Untrusted Developer' posle instalacije"

Apple svaki sideloaded IPA tretira kao nepoverljivog dok korisnik ne
trust-uje njegov cert. Koraci (jednom):

1. Settings → General → **VPN & Device Management**;
2. pod sekcijom „Developer App" tap na svoj Apple ID;
3. **Trust "Apple Development: ..."** → **Trust**.

Posle toga app se otvara normalno. Za free Apple ID (Opcija B), ovo
mora da se radi svakih 7 dana posle re-sign-a.

### „iPhone: app prestala da radi posle 7 dana"

Free Apple ID cert je expired. Re-sign preko Sideloadly (Opcija B) i
re-install. Alternativa: upgrade na Opciju C (TestFlight) gde je cert
90 dana.

### „iPhone kamera crna nakon tap-a Skeniraj"

iOS 14.2 i stariji imaju bug gde `getUserMedia` baca grešku silently.
Update iOS-a je obavezan (14.3+). U native IPA-u (Opcija B/C) ovo ne
pogađa — ML Kit ne zavisi od WebKit permisija.

## 9. Mapiranje na repo

| Namena                              | Fajl                                      |
| ----------------------------------- | ----------------------------------------- |
| Mobilni shell home + navigacija     | `src/ui/mobile/mobileHome.js`             |
| Istorija „mojih premeštanja"        | `src/ui/mobile/mobileHistory.js`          |
| Batch skener                        | `src/ui/mobile/mobileBatch.js`            |
| Offline queue (LS-based)            | `src/services/offlineQueue.js`            |
| Native barcode (ML Kit) wrapper     | `src/services/nativeBarcode.js`           |
| Mobilni stilovi                     | `src/styles/mobile.css`                   |
| PWA registracija (scoped na `/m`)   | `src/lib/pwa.js`                          |
| Routing (`/m/*` grana)              | `src/ui/router.js`, `src/lib/appPaths.js` |
| Capacitor config                    | `capacitor.config.json`                   |
| Android Gradle projekat             | `android/`                                |
| iOS Xcode projekat                  | `ios/`                                    |
| CI workflow za APK                  | `.github/workflows/android-apk.yml`       |
| CI workflow za iOS unsigned IPA     | `.github/workflows/ios-ipa.yml`           |

## 10. Šta NIJE implementirano (i zašto)

- **Play Store distribucija** — APK je unsigned. Kad bi išlo na Store,
  treba Google Play keystore, `gradle signingConfig`, + `bundleRelease`
  (AAB umesto APK). To je 2-3h dodatnog posla; pitaj ako zatreba.
- **App Store / TestFlight auto-deploy** — `ios-ipa.yml` gradi unsigned
  IPA. Kod za signed TestFlight upload je u komentaru na dnu tog
  workflow-a — odblokiraš ga kad nabaviš Apple Developer nalog
  ($99/god).
- **Push notifikacije** — nema FCM/APNs setup-a (treba Firebase + Apple
  Push cert). Za sada magacioner otvara app manuelno.
- **Biometric login** — iz magacinskog konteksta nije tražen. Capacitor
  plugin `@capacitor/preferences` + `capacitor-biometric-auth` dodaju
  ovo ako zatreba (sačuvaj refresh token → unlock fingerprint/FaceID).

## 11. Sigurnost

- APK je **unsigned debug build**. Može se instalirati samo manuelno;
  Android sprečava svako Play Store ažuriranje bez istog keystore-a.
- WebView koristi `androidScheme: 'https'` — tretira se kao Secure
  Origin, što je preduslov za Camera/IndexedDB API.
- Supabase session tokeni su u WebView-ovom localStorage-u (isto kao na
  webu). Nisu accessible iz drugih aplikacija zahvaljujući Android
  sandbox-u.
- Ako je telefon izgubljen: admin može u Supabase dashboardu invalidovati
  sve sessionse za taj email (ili disable-ovati nalog).

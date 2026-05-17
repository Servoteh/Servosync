
# Cursor Instrukcija — Modul PODEŠAVANJA + Pravilo navigacije za celu aplikaciju

## 1. Kontekst

Trenutno modul **Podešavanja** ima horizontalni meni na vrhu sa ~10 stavki (Korisnici, Organizacija, Održ. profili, Podeš. predmeta, Matični podaci, Šifarnici, Tipovi predmeta, Statusi, Integracije, Sistem...) koji **horizontalno scroll-uje**. To je loše za UX — korisnik ne vidi sve opcije odjednom, ne zna gde je u hijerarhiji, i scroll na tab baru je anti-pattern.

Cilj: prebaciti Podešavanja na **levi sidebar sa grupama**, i utvrditi **jedinstveno pravilo navigacije** za sve module aplikacije.

---

## 2. PRAVILO NAVIGACIJE ZA CELU APLIKACIJU

Primeniti dosledno u svim modulima:

| Broj sibling stranica | Pattern | Primer modula |
|---|---|---|
| **1–4** | Horizontalni tabovi sa **coral underline** + ikonica + label | Reversi (2 taba), Lokacije delova (2–3) |
| **5–10** | Horizontalni tabovi sa underline-om, **bez scroll-a** — moraju svi da stanu | Plan Montaže, Kadrovska, Štampa nalepnica |
| **10+ ili grupisane sekcije** | **Levi sidebar** sa grupama (Generalno / Korisnici / Podaci / Sistem) | **Podešavanja** |

### Ključna pravila
1. **NIKAD horizontalni scroll na tab baru.** Ako tabovi ne staju → prebaci na sidebar.
2. **TopNav je uvek isti**: `← Moduli` + bojeni kvadrat sa ikonicom + naslov modula + (opcioni subtitle); desno: akcije + ADMIN badge + `Odjavi se`.
3. **Aktivan tab**: coral underline (`border-b-2 border-primary`) + coral text + bold; neaktivan: gray-600.
4. **Aktivan sidebar item**: coral pozadina (`bg-primary/10`) + coral text + leva coral traka (`border-l-2 border-primary`).
5. **Badge brojači** (npr. `Korisnici 12`) — uvek desno od labela, mali pill u coral-light boji.
6. **Ikone u navigaciji**: lucide-react, size 16, levo od labela, sa `mr-2`.

---

## 3. Implementacija — PODEŠAVANJA

### 3.1 Layout

```
┌─────────────────────────────────────────────────────────┐
│ TopNav (Settings ikona + "Podešavanja")                 │
├──────────────┬──────────────────────────────────────────┤
│              │                                          │
│  Sidebar     │   Page content (npr. Korisnici)          │
│  (256px)     │                                          │
│              │   - PageHeader                           │
│  Grupe:      │   - Stats cards                          │
│  • Generalno │   - Toolbar                              │
│  • Korisnici │   - Table                                │
│  • Podaci    │                                          │
│  • Sistem    │                                          │
└──────────────┴──────────────────────────────────────────┘
```

### 3.2 Komponente

**`components/SettingsSidebar.tsx`**
- Levi sidebar, fiksne širine 256px, `bg-white border-r`
- Grupe (uppercase label + lista stavki):
  - **GENERALNO**: Organizacija, Brending
  - **KORISNICI I PRISTUP**: Korisnici (badge 12), Uloge i dozvole, Održavanje profila
  - **PODACI**: Podešavanje predmeta, Matični podaci, Šifarnici, Tipovi predmeta, Statusi
  - **SISTEM**: Integracije, Logovi, Backup
- Svaka stavka: ikonica (16px) + label + opcioni badge brojač desno
- Active state: `bg-primary/10 text-primary border-l-2 border-primary`
- Hover: `hover:bg-gray-50`

**`components/KorisniciStats.tsx`**
- 4 mini kartice u grid-u: Ukupno korisnika, Aktivnih, ADMIN, Menadžment
- Format: ikona + UPPERCASE label + bold broj

**`components/KorisniciToolbar.tsx`**
- Jedna horizontalna linija: search input (flex-1) + Uloga select + Status select + Osveži button
- `bg-gray-50 rounded-lg p-3`

**`components/RoleBadge.tsx`**
- Boje po ulozi:
  - ADMIN → coral (`bg-primary/10 text-primary`)
  - LEAD PM / PM → blue (`bg-blue-100 text-blue-700`)
  - HR → green
  - MENADŽMENT → purple
  - VIEWER → gray
- Uppercase, mali font, rounded-md, px-2 py-0.5

**`components/KorisniciTable.tsx`**
- Kolone: Ime i prezime (sa avatar inicijalima) | Email | Uloga (RoleBadge) | Tim | Projekat | Status | Dodato | Akcije
- Status: green dot + "Aktivan" / gray dot + "Neaktivan"
- Akcije: edit + delete ikonice (delete = red)
- Zebra striping: `even:bg-gray-50/50`

### 3.3 Wire-up u `App.tsx`

```tsx
<TopNav title="Podešavanja" icon={SettingsIcon} />
<div className="flex">
  <SettingsSidebar activeKey="korisnici" />
  <main className="flex-1 p-6 space-y-4">
    <PageHeader title="Korisnici" subtitle="Upravljanje korisničkim nalozima i ulogama" />
    <KorisniciStats />
    <KorisniciToolbar />
    <KorisniciTable />
  </main>
</div>
```

### 3.4 Šta NE raditi
- ❌ Ne pravi horizontalne tabove sa scroll-om
- ❌ Ne stavljaj sve sekcije u jedan flat nivo — grupiši ih
- ❌ Ne koristi accordion u sidebar-u (sve grupe uvek vidljive)
- ❌ Ne menjaj TopNav — ostaje standardan

---

## 4. Migracija ostalih modula (provera usklađenosti)

| Modul | Trenutno | Akcija |
|---|---|---|
| Kadrovska | tabovi (5) | ✅ OK |
| Plan Montaže | tabovi (4) | ✅ OK |
| Projektovanje | tabovi | ✅ OK |
| Štampa nalepnica | full page | ✅ OK |
| Reversi | tabovi (2) | ✅ OK |
| Godišnji odmor | tabovi | ✅ OK |
| Lokacije delova | tabovi | ✅ OK |
| **Podešavanja** | **scroll tabovi** | **🔧 Promeni na sidebar** |

---

## 5. Acceptance kriterijumi

- [ ] Podešavanja koristi levi sidebar sa 4 grupe
- [ ] Nema horizontalnog scroll-a u navigaciji
- [ ] Aktivna stavka jasno označena (coral)
- [ ] Korisnici stranica ima: header + stats (4) + toolbar + tabela
- [ ] Role badge boje konzistentne
- [ ] TopNav identičan kao u drugim modulima
- [ ] Pravilo iz sekcije 2 dokumentovano u repo-u (npr. `docs/NAVIGATION.md`)

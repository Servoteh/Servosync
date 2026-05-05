# -*- coding: utf-8 -*-
"""
Generiše SQL UPDATE za public.employees prema listi (Ime Prezime, sektor).
Pokretanje: python scripts/build_employees_department_update_sql.py
Izlaz: sql/manual/employees_department_sync_2026_from_sheet.sql
"""
from __future__ import annotations

import json
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Ime Prezime — tačno kako na slici (jedan string), pa sektor.
# Kalum Krstić samo jednom (red 74), duplikat 136 preskočen.
# Ručno: tabela (Ime Prezime) -> id ( kada automatska logika pomeša Nkola, Jelenu, itd. )
PHOTO_OVERRIDES: dict[str, str] = {
    "Nikola Mišković": "1f9220a0-ba57-43bb-bb84-a251d9451810",  # Mrkajić (ne Ninković)
    "Miloš Pantić": "ff32e040-8628-4a05-ab5f-a1b0b8f4a1ee",  # Cvetković
    "Marko Mladenović": "b532450c-38d7-432e-b47e-4c0c64271a2b",  # Mladjenovic
    "Jovan Milojević": "45636c5b-bf43-4ac7-a57e-e0d674c92d17",  # Blagojevic
    "Miloš Đorđević": "0ea56445-2f85-4d72-9e14-6ee7c8100d6b",  # Oreščanin
    "Branimira Perišić": "0764e73d-fa40-4239-901e-a9a4c6586790",  # Pavlović Branislava
    "Mladen Mihajlo": "4719dc70-1df1-484c-b739-440874aee6e4",  # Mušicki Mihajlo
    "Miloš Orestijević": "c587743f-cb80-426f-9702-b78382b40734",  # Sretenović
    "Slobodan Trnavac": "4c3445ee-3d9c-4bc5-b3eb-60bc8aa17325",  # Travica
    "Nenad Nikolić": "1ba1eb34-72fe-4e65-a853-2c8901ba898c",  # Nikolić Nenad
    "Kalum Krstić": "2a9f6d9b-fb5c-4166-a997-9c78263d8c8b",
    "Ljubiša Simović": "fe3357f9-c3a5-4c89-8a3c-1f99c1ff6077",  # Simovic Ljubisa
    "Đorđe Jelić": "623601d1-9646-44e1-85ca-0a7391494b6a",  # Arsić Đorđe
    "Mladen Anđić": "969970e9-c8a5-46ff-8d65-c7fcdb13e7ee",  # Anđić Mladen
    # Ispitano (Supabase, employees): ista osoba, drugačije ime na slici / u bazi
    "Marija Stevanović": "c6b95b70-66e8-448d-9c69-e8359183cabc",  # DB: Samardzic Marija, Nabavka
    "Ivan Timotijević": "b85a3759-5f3c-4c7a-b140-5edc77d9ea4a",  # DB: Umićević Ivan, Održavanje
    "Nikola Perković": "489bdf18-36fe-4354-be55-76b1ae54851b",  # Ninković Nikola (pogrešno prezime na slici)
}

# Gde je tekst sa slike pogrešan, ne prepisivati imena u UPDATE — zadržati full_name iz snimka (employees_snapshot).
PHOTO_OVERRIDES_NAME_FROM_SNAPSHOT: frozenset[str] = frozenset(
    {
        "Marija Stevanović",
        "Ivan Timotijević",
        "Nikola Perković",
    }
)

# Bez matcha u employees (proveri kadrovsku / uvoz): "Dragan Ilić", "Nataša Lalić" (Održavanje).

ROWS: list[tuple[str, str]] = [
    ("Jelena Durutović", "Administracija"),
    ("Ana Gakašević", "Administracija"),
    ("Dragana Korkut", "Administracija"),
    ("Dragana Madžarčić", "Administracija"),
    ("Nikola Mišković", "Administracija"),
    ("Anđela Đorić", "Administracija"),
    ("Jelena Stanišić", "Administracija"),
    ("Vladimir Đelević", "Brušenje"),
    ("Stevan Birovljev", "Brušenje"),
    ("Lazar Glišić", "Brušenje"),
    ("Miloš Pantić", "Brušenje"),
    ("Živorad Stanković", "Brušenje"),
    ("Željko Terzić", "Brušenje"),
    ("Miloš Vujičić", "Brušenje"),
    ("Slobodan Živković", "Brušenje"),
    ("Veljko Dobromirović", "Čelične montaže"),
    ("Jovan Marić", "Čelične montaže"),
    ("Mladen Markić", "Čelične montaže"),
    ("Marko Mladenović", "Čelične montaže"),
    ("Dragan Dobromirović", "Čelično projektovanje"),
    # Nenad: u snimku jedan "Nikolic Nenad" (1ba1) — dva reda (Ilić / Nikolić) ne mogu oba; koristi se Menadžment
    ("Sonja Živković", "Čelično projektovanje"),
    ("Mihajlo Janković", "Praksa"),
    ("Uroš Radelić", "Praksa"),
    ("Jovan Milojević", "Inženjer prodaje"),
    ("Bojana Trifunović", "Inženjer prodaje"),
    ("Miloš Đorđević", "Kontrola kvaliteta"),
    ("Bogdan Krstić", "Kontrola kvaliteta"),
    ("Marina Marić", "Kontrola kvaliteta"),
    ("Dimitrije Uzurac", "Kontrola kvaliteta"),
    ("Slavko Lazić", "Logistika"),
    ("Sofija Šoškić", "Logistika"),
    ("Aleksandar Ilić", "Logistika"),
    ("Marijana Manojlović", "Logistika"),
    ("Branimira Perišić", "Logistika"),
    ("Nikola Savić", "Logistika"),
    ("Mladen Mihajlo", "Magacin"),  # Prezime Ime: Mihajlo Mladen
    ("Radislav Popović", "Magacin"),
    ("Slavko Đokić", "Mašinska montaža"),
    ("Jovan Bogdanović", "Mašinska montaža"),
    ("Mirko Cvijetinović", "Mašinska montaža"),
    ("Petar Dražić", "Mašinska montaža"),
    ("Mihajlo Marković", "Mašinska montaža"),
    ("Stefan Marić", "Mašinska montaža"),
    ("Dragan Milivojević", "Mašinska montaža"),
    ("Miloš Orestijević", "Mašinska montaža"),
    ("Vladan Radivojević", "Mašinska montaža"),
    ("Nedeljko Šabić", "Mašinska montaža"),
    ("Aleksa Šipovac", "Mašinska montaža"),
    ("Milan Brčko", "Mašinska obrada"),
    ("Dejan Janković", "Mašinska obrada"),
    ("Branko Kuzmić", "Mašinska obrada"),
    ("Marko Madžarević", "Mašinska obrada"),
    ("Nenad Milutinović", "Mašinska obrada"),
    ("Aleksandar Nikolić", "Mašinska obrada"),  # ispr. „Aleksandru”
    ("Slobodan Trnavac", "Mašinska obrada"),
    ("Predrag Živanić", "Mašinska obrada"),
    ("Dragoslav Đukić", "Mašinska obrada"),
    ("Goran Janković", "Menadžment"),
    ("Želimir Jevremović", "Menadžment"),
    ("Nemanja Knežević", "Menadžment"),
    ("Dušan Kostić", "Menadžment"),
    ("Nenad Ljubinković", "Menadžment"),
    ("Milan Milutinović", "Menadžment"),
    ("Nenad Nikolić", "Menadžment"),
    ("Nikola Perković", "Menadžment"),
    ("Marija Stevanović", "Nabavka"),
    ("Jovica Milošević", "Tehnologija"),
    ("Dragan Ilić", "Održavanje"),
    ("Nataša Lalić", "Održavanje"),
    ("Ivan Timotijević", "Održavanje"),
    ("Strahinja Perišić", "Površinska zaštita"),
    ("Mileta Cvijetinović", "Proizvodnja"),
    ("Kalum Krstić", "Proizvodnja"),
    ("Jovan Milovanović", "Proizvodnja"),
    ("Nenad Bukvić", "Proizvodnja"),
    ("Nikola Đajić", "Proizvodnja"),
    ("Goran Jevtić", "Proizvodnja"),
    ("Lazar Jovanović", "Proizvodnja"),
    ("Dijana Kastratović", "Priprema i planiranje"),
    ("Nikola Milojević", "Proizvodnja"),
    ("Mihajlo Nikolić", "Proizvodnja"),
    ("Nikola Nikolić", "Proizvodnja"),
    ("Milan Ružić", "Proizvodnja"),
    ("Stefan Simić", "Proizvodnja"),
    ("Jovan Srković", "Proizvodnja"),
    ("Miloš Stanojević", "Proizvodnja"),
    ("Luka Stanić", "Proizvodnja"),
    ("Darko Stjepanović", "Proizvodnja"),
    ("Nikola Stojanović", "Proizvodnja"),
    ("Đuro Trkulja", "Proizvodnja"),
    ("Marko Vasić", "Proizvodnja"),
    ("Dejan Vujatović", "Proizvodnja"),
    ("Ivan Zečević", "Proizvodnja"),
    ("Đorđe Jelić", "Projektant"),
    ("Dejan Ćirković", "Projektant"),
    ("Tatjana Gajčić", "Projektant"),
    ("Pavle Ilić", "Projektant"),
    ("Milena Jevtić", "Projektant"),
    ("Milan Milovanović", "Projektant"),
    ("Jovan Popić", "Projektant"),
    ("Vuk Predojević", "Projektant"),
    ("Slaviša Radisavljević", "Projektant"),
    ("Milan Stanimirović", "Projektant"),
    ("Marko Stojanović", "Projektant"),
    ("Luka Tešović", "Projektant"),
    ("Igor Votrić", "Projektant"),
    ("Nikola Aksentijević", "Projektant"),
    ("Mladen Anđić", "Serviser"),
    # Nikola Anđić: nema u snimku; fuzzy je pogađao Arsića — ne ažurirati dok nema 1:1 u bazi
    ("Jelena Đokić", "Administracija"),
    ("Anastasija-Petra Krtinić", "Proizvodnja"),
    ("Nikola Krvavac", "Proizvodnja"),
    ("Bojana Lalić", "Serviser"),
    ("Slobodan Martinović", "Proizvodnja"),
    ("Miloš Milisavljević", "Čelične montaže"),
    ("Andreja-Sava D. Mihajlovski", "Proizvodnja"),
    ("Nikola Mišić", "Proizvodnja"),
    ("Lazar Obradović", "Proizvodnja"),
    ("Vladan Perišić", "Projektant"),
    ("Luka Popović", "Održavanje"),
    ("Dejan Reljić", "Serviser"),
    ("Viktor Rocić", "Proizvodnja"),
    ("Dejan Stević", "Proizvodnja"),
    ("Luka Rocić", "Proizvodnja"),
    ("Dragan Đurić", "Tehnologija"),
    # Slobodan Savić: u bazi samo "Savić Nikola" (ist id kao Nikola Savić ispod)
    ("Stefan Spasić", "Proizvodnja"),
    ("Zoran Stanić", "Projektant"),
    ("Branislav Stojanović", "Priprema i planiranje"),
    ("Bojko Stojanović", "Mašinska montaža"),
    ("Vuk Stojković", "Proizvodnja"),
    ("Luka Tadić", "Projektant"),  # slika "Luki" → ispravka na Luka
    ("Milenko Tomić", "Logistika"),
    # Baki Trifunović: u bazi samo "Trifunovic Bojana" (isto id kao Bojana) — nije drugi sektor u istom redu
    # preskočen duplikat Kalum Krstić
    ("Lazar Andrić", "Sečenje"),
    ("Miloš Dugalić", "Sečenje"),
    ("Radovan Preradović", "Sečenje"),
    ("Miloš Radovanović", "Sečenje"),
    ("Dušan Stojanović", "Sečenje"),
    ("Stefan Đokić", "Tehnologija"),
    ("Veljko Milosović", "Tehnologija"),  # slika: Milosović
    ("Ljubiša Simović", "Priprema i planiranje"),
    ("Aleksandar Stanić", "Tehnologija"),
]


def strip_d(s: str) -> str:
    n = unicodedata.normalize("NFD", s)
    return "".join(c for c in n if unicodedata.category(c) != "Mn")


def key_from_im_prez(ime: str, prez: str) -> str:
    return (strip_d(ime) + " " + strip_d(prez)).lower().replace("  ", " ").strip()


def key_from_prez_ime(db_full: str) -> str:
    parts = db_full.split()
    if len(parts) < 2:
        return strip_d(db_full).lower()
    return key_from_im_prez(" ".join(parts[1:]), parts[0])


def split_ime_prez(photo: str) -> tuple[str, str]:
    """'Jelena Durutović' → ime, prezime (poslednja reč = prezime)."""
    t = photo.strip()
    m = t.rsplit(" ", 1)
    if len(m) != 2:
        return t, ""
    return m[0].strip(), m[1].strip()


def to_prez_ime(ime: str, prez: str) -> str:
    return f"{prez} {ime}".strip()


def esc(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def _prez_ime_from_db_full(fn: str) -> tuple[str, str] | None:
    parts = fn.split()
    if len(parts) < 2:
        return None
    return (parts[0], " ".join(parts[1:]))


def build_loose_index(
    emps: list[dict],
) -> dict[str, list[tuple[str, str, str, str]]]:
    """Kljuc = strip_d(ime), vrednost: (id, full, prez, first_full)."""
    from collections import defaultdict

    by_first: dict[str, list[tuple[str, str, str, str]]] = defaultdict(list)
    for e in emps:
        p = _prez_ime_from_db_full(e["full_name"])
        if not p:
            continue
        prez, first = p
        by_first[strip_d(first).lower()].append(
            (e["id"], e["full_name"], prez, first)
        )
    return by_first


def levenshtein(a: str, b: str) -> int:
    n, m = len(a), len(b)
    if n == 0 or m == 0:
        return n + m
    dp: list[list[int]] = [
        [0] * (m + 1) for _ in range(n + 1)
    ]
    for i in range(n + 1):
        dp[i][0] = i
    for j in range(m + 1):
        dp[0][j] = j
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            c = 0 if a[i - 1] == b[j - 1] else 1
            dp[i][j] = min(
                dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + c
            )
    return dp[n][m]


def resolve_employee(
    ime: str,
    prez: str,
    k: str,
    by_key: dict,
    by_first: dict,
    used_ids: set[str],
) -> tuple[str, str] | None:
    cands = by_key.get(k, [])
    nxt = next(((i, f) for i, f in cands if i not in used_ids), None)
    if nxt:
        return nxt
    sime = strip_d(ime).lower()
    s_prez = strip_d(prez).lower()
    loose = by_first.get(sime, [])
    free = [t for t in loose if t[0] not in used_ids]
    if not free:
        return None
    exact = [t for t in free if strip_d(t[2]).lower() == s_prez]
    if len(exact) == 1:
        return (exact[0][0], exact[0][1])
    if len(exact) > 1:
        return None
    if len(free) == 1:
        t = free[0]
        if levenshtein(strip_d(t[2]).lower(), s_prez) <= 1:
            return (t[0], t[1])
        return None
    fuzzy: list[tuple[str, str, int]] = []
    for t in free:
        d = levenshtein(strip_d(t[2]).lower(), s_prez)
        if d <= 1:
            fuzzy.append((t[0], t[1], d))
    if not fuzzy:
        return None
    min_d = min(f[2] for f in fuzzy)
    at_min = [f for f in fuzzy if f[2] == min_d]
    if len(at_min) == 1:
        return (at_min[0][0], at_min[0][1])
    return None


def _resolve_fuzzy_name(
    ime: str,
    prez: str,
    emps: list[dict],
    used_ids: set[str],
) -> tuple[str, str] | None:
    """Kad strip_d(ime) ne poklopi zapis (npr. Anđela vs Andjela)."""
    s_ime = strip_d(ime).lower()
    s_prez = strip_d(prez).lower()
    hits: list[dict] = []
    for e in emps:
        if e["id"] in used_ids:
            continue
        p = _prez_ime_from_db_full(e["full_name"])
        if not p:
            continue
        pz, fn = p
        di = levenshtein(s_ime, strip_d(fn).lower())
        dp = levenshtein(s_prez, strip_d(pz).lower())
        if di <= 2 and dp <= 1:
            hits.append((e, di + dp, di, dp))
    if not hits:
        return None
    hits.sort(key=lambda x: (x[1], x[2], x[3]))
    if len(hits) == 1 or hits[0][1] < hits[1][1]:
        h = hits[0][0]
        return (h["id"], h["full_name"])
    # isti zbir udaljenosti: lomi žiri tačnim prezimenom
    t2 = [
        t
        for t in hits
        if t[0]["full_name"]
        and (p2 := _prez_ime_from_db_full(t[0]["full_name"]))
        and strip_d(p2[0]).lower() == s_prez
    ]
    if len(t2) == 1:
        h = t2[0][0]
        return (h["id"], h["full_name"])
    t3 = [t for t in hits if t[1] == hits[0][1]]
    if len(t3) == 1:
        h = t3[0][0]
        return (h["id"], h["full_name"])
    return None


def load_employees() -> list[dict]:
    tsv = ROOT / "scripts" / "employees_snapshot.tsv"
    jpath = ROOT / "scripts" / "_employees_for_sync.json"
    if tsv.is_file():
        out: list[dict] = []
        for line in tsv.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            tab = line.find("\t")
            if tab < 0:
                continue
            eid, full = line[:tab], line[tab + 1 :]
            out.append({"id": eid.strip(), "full_name": full.strip()})
        return out
    if jpath.is_file():
        return json.loads(jpath.read_text(encoding="utf-8"))
    print("Nedostaje", tsv, "ili", jpath)
    raise SystemExit(1)


def main() -> None:
    emps: list[dict] = load_employees()

    # indeks: normalizovani ključ → lista (id, full_name) jer mogu duple
    from collections import defaultdict

    by_key: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for e in emps:
        by_key[key_from_prez_ime(e["full_name"])].append((e["id"], e["full_name"]))

    by_first = build_loose_index(emps)

    sql: list[str] = []
    sql.append(
        "-- Sinhronizacija odeljenja + ispravka imena (iz Excel/slike, 2026-04-29)\n"
        "BEGIN;\n"
        "SET statement_timeout = '300s';\n\n"
    )

    unmapped: list[str] = []
    used_ids: set[str] = set()

    for display_name, dept in ROWS:
        if display_name == "Mladen Mihajlo":
            prez, ime = "Mihajlo", "Mladen"  # već (Prezime, Ime) za pogan magacin
            full_new = f"{prez} {ime}"
        else:
            ime, prez = split_ime_prez(display_name)
            full_new = to_prez_ime(ime, prez)
        k = key_from_im_prez(ime, prez)
        row: tuple[str, str] | None = None
        eid2 = PHOTO_OVERRIDES.get(display_name)
        if eid2:
            old_fn2 = next((e["full_name"] for e in emps if e["id"] == eid2), None)
            if not old_fn2:
                unmapped.append(
                    f"{display_name} → override id {eid2} nije u snimku"
                )
                continue
            if eid2 in used_ids:
                unmapped.append(
                    f"{display_name} (override id već iskorišćen) → {dept}"
                )
                continue
            row = (eid2, old_fn2)
        if not row:
            row = resolve_employee(ime, prez, k, by_key, by_first, used_ids)
        if not row:
            row = _resolve_fuzzy_name(ime, prez, emps, used_ids)
        if not row:
            cands = by_key.get(k, [])
            o = (
                f"{display_name} (svi kandidati zauzeti)"
                if cands
                and not next(((i, f) for i, f in cands if i not in used_ids), None)
                else f"{display_name} → {full_new} / {dept} (nema 1:1 mapi)"
            )
            unmapped.append(o)
            continue
        eid, old_fn = row
        used_ids.add(eid)
        if display_name in PHOTO_OVERRIDES_NAME_FROM_SNAPSHOT:
            full_new = old_fn
        # last_name, first_name
        if " " in full_new:
            last_name = full_new.split(" ", 1)[0]
            first_name = full_new.split(" ", 1)[1]
        else:
            last_name, first_name = full_new, ""
        sql.append(
            f"UPDATE public.employees\n"
            f"SET\n"
            f"  full_name = {esc(full_new)},\n"
            f"  first_name = {esc(first_name) if first_name else 'NULL::text'},\n"
            f"  last_name = {esc(last_name)},\n"
            f"  department = {esc(dept)},\n"
            f"  updated_at = now()\n"
            f"WHERE id = {esc(eid)}::uuid\n"
            f"  AND is_active = true;\n\n"
        )

    sql.append("COMMIT;\n\n")
    if unmapped:
        sql.append("-- NEMA MAPIRANJA (ručno proveri):\n")
        for u in unmapped:
            sql.append(f"--   {u}\n")

    out = ROOT / "sql" / "manual" / "employees_department_sync_2026_from_sheet.sql"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("".join(sql), encoding="utf-8")
    print("Wrote", out)
    for u in unmapped[:20]:
        print("WARN:", u)
    if len(unmapped) > 20:
        print("...", len(unmapped) - 20, "more")


if __name__ == "__main__":
    main()

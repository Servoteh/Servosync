from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path


DEFAULT_SCHEMA_PATH = Path(r"c:\Users\nenad.jarakovic\Desktop\BigbitRaznoNenad\script.sql")


def read_sql(path: Path) -> str:
    raw = path.read_bytes()
    if raw.startswith(b"\xff\xfe") or raw[:200].count(b"\x00") > 20:
        return raw.decode("utf-16", errors="replace")
    if raw.startswith(b"\xef\xbb\xbf"):
        return raw.decode("utf-8-sig", errors="replace")
    return raw.decode("utf-8", errors="replace")


def classify_table(name: str) -> str:
    rules = [
        (
            "production_rn",
            {
                "tRN",
                "tStavkeRN",
                "tTehPostupak",
                "tSaglasanRN",
                "tLansiranRN",
                "tRNKomponente",
                "tRNNDKomponente",
                "tStavkeRNSlike",
                "tTehPostupakDokumentacija",
                "tPDM",
                "tPLP",
                "tPND",
            },
        ),
        (
            "pdm_bom",
            {
                "PDMCrtezi",
                "KomponentePDMCrteza",
                "SklopoviPDMCrteza",
                "PDM_PDFCrtezi",
                "PDM_Planiranje",
                "PDM_PlaniranjeStavke",
                "PDMXMLImportLog",
                "StatusiCrteza",
                "PrimopredajaCrteza",
                "PrimopredajaPDFCrteza",
                "NacrtPrimopredaje",
                "NacrtPrimopredajeStavke",
                "StatusiPrimopredaje",
                "StatusiNacrtaPrimopredaje",
            },
        ),
        (
            "mrp_inventory",
            {
                "MRP_Potrebe",
                "MRP_PotrebeStavke",
                "MRP_StanjeArtikala",
                "MRP_StanjeArtikala_TMP",
                "MRP_SyncStatus",
                "R_Artikli",
                "R_Grupa",
                "R_Podgrupa",
                "R_Poreklo",
                "R_Tarife",
                "R_Vrste dokumenata",
                "Magacini",
                "RobnaDokumentaMirror",
                "RobneStavkeMirror",
                "T_Robna dokumenta",
                "T_Robne stavke",
                "Cenovnik",
            },
        ),
        (
            "partners_cases",
            {
                "Predmeti",
                "Komitenti",
                "Prodavci",
                "PredmetiVrstaPosla",
                "UplatniRacuni",
                "Vrste sifara",
            },
        ),
        (
            "workers_operations",
            {
                "tRadnici",
                "tVrsteRadnika",
                "tOperacije",
                "tOperacijeFix",
                "tPristupMasini",
                "tRadneJedinice",
                "tVrsteKvalitetaDelova",
            },
        ),
        ("locations", {"tLokacijeDelova", "tPozicije", "Nalepnice"}),
        (
            "system_config_security",
            {
                "_Dnevnik",
                "_RegAccess",
                "_RegApps",
                "_RegAppsFiles",
                "_RegUsers",
                "_RegUsersApps",
                "_Rev",
                "BBDefUser",
                "BBOdeljenja",
                "BBOrgJedinice",
                "BBPravaPristupa",
                "CFG_Global",
                "CFG_Sys",
                "Info",
                "Parametri za rad",
                "Radni fajlovi",
                "VrednostiZaKombo",
                "tmp_T_KontroleNaFormi",
                "T_Planer",
                "T_PlanerGrupeUsera",
                "Vrsta naloga",
            },
        ),
    ]

    for domain, names in rules:
        if name in names:
            return domain
    return "needs_review"


def parse_columns(sql: str) -> dict[str, list[dict[str, str]]]:
    columns_by_table: dict[str, list[dict[str, str]]] = {}
    table_pattern = re.compile(
        r"CREATE TABLE \[dbo\]\.\[(?P<name>[^\]]+)\]\((?P<body>.*?)\n\)",
        re.DOTALL,
    )
    column_pattern = re.compile(
        r"^\s*\[(?P<name>[^\]]+)\]\s+\[?(?P<type>[a-zA-Z0-9_]+)\]?(?:\((?P<args>[^)]*)\))?",
        re.MULTILINE,
    )

    for table_match in table_pattern.finditer(sql):
        table_name = table_match.group("name")
        cols = []
        for column_match in column_pattern.finditer(table_match.group("body")):
            column_type = column_match.group("type").lower()
            if column_type in {"asc", "desc", "as"}:
                continue
            cols.append(
                {
                    "name": column_match.group("name"),
                    "type": column_type,
                    "args": column_match.group("args") or "",
                }
            )
        columns_by_table[table_name] = cols
    return columns_by_table


def main() -> int:
    schema_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SCHEMA_PATH
    sql = read_sql(schema_path)

    table_names = re.findall(r"^CREATE TABLE \[dbo\]\.\[([^\]]+)\]", sql, re.MULTILINE)
    columns_by_table = parse_columns(sql)

    domains: dict[str, list[str]] = defaultdict(list)
    for table_name in table_names:
        domains[classify_table(table_name)].append(table_name)

    type_counts: Counter[str] = Counter()
    problem_columns = []
    for table_name, columns in columns_by_table.items():
        for column in columns:
            type_counts[column["type"]] += 1
            column_name = column["name"]
            if " " in column_name or "-" in column_name or re.search(r"[A-Z]", column_name):
                problem_columns.append(
                    {
                        "table": table_name,
                        "column": column_name,
                        "type": column["type"],
                        "args": column["args"],
                    }
                )

    result = {
        "source": str(schema_path),
        "counts": {
            "tables": len(table_names),
            "functions": len(re.findall(r"^CREATE\s+FUNCTION", sql, re.MULTILINE)),
            "procedures": len(re.findall(r"^CREATE\s+(?:PROCEDURE|PROC)", sql, re.MULTILINE)),
            "views": len(re.findall(r"^CREATE\s+VIEW", sql, re.MULTILINE)),
            "triggers": len(re.findall(r"^CREATE\s+TRIGGER", sql, re.MULTILINE)),
            "foreign_keys": len(re.findall(r"FOREIGN KEY\(", sql)),
        },
        "domains": dict(sorted(domains.items())),
        "domain_counts": {domain: len(names) for domain, names in sorted(domains.items())},
        "problem_tables": [name for name in table_names if " " in name or "-" in name],
        "top_sqlserver_types": type_counts.most_common(24),
        "problem_columns_sample": problem_columns[:120],
    }

    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

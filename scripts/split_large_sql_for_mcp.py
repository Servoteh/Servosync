"""Podela velikog .sql fajla na 2 približno jednaka (na granici COMMIT;)."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
src = root / "supabase" / "migrations" / "20260428180000__employees_data_from_xlsx_b2_8.sql"
t = src.read_text(encoding="utf-8")
h = len(t) // 2
# poslednji pun COMMIT; pre sredine
i = t.rfind("COMMIT;\n", 0, h)
if i < 0:
    raise SystemExit("No COMMIT before half")
i = i + len("COMMIT;\n")
a = t[:i].rstrip() + "\n"
b = "BEGIN;\nSET statement_timeout = '120s';\n" + t[i:].lstrip()
out_a = root / "docs" / "reports" / "_apply_b2_8_part_a.sql"
out_b = root / "docs" / "reports" / "_apply_b2_8_part_b.sql"
out_a.write_text(a, encoding="utf-8")
out_b.write_text(b, encoding="utf-8")
print("a", out_a, len(a), "b", out_b, len(b))

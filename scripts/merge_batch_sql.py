"""Spaja q__apply_b2_8_*.sql u jedan fajl (po redu)."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
D = ROOT / "docs" / "reports" / "_batch_queries"
NAMES = [
    "q__apply_b2_8_part_a__c00.sql",
    "q__apply_b2_8_part_a__c01.sql",
    "q__apply_b2_8_part_a__c02.sql",
    "q__apply_b2_8_part_a__c03.sql",
    "q__apply_b2_8_part_b__c00.sql",
    "q__apply_b2_8_part_b__c01.sql",
    "q__apply_b2_8_part_b__c02.sql",
    "q__apply_b2_8_part_b__c03.sql",
]


def main() -> None:
    out = ROOT / "docs" / "reports" / "_apply_employees_b2_8_remaining_merged.sql"
    parts: list[str] = []
    for n in NAMES:
        p = D / n
        if not p.is_file():
            print("missing", p, file=sys.stderr)
            sys.exit(1)
        parts.append(p.read_text(encoding="utf-8").rstrip() + "\n")
    out.write_text("".join(parts), encoding="utf-8")
    print("wrote", out, "total_chars", out.stat().st_size)


if __name__ == "__main__":
    main()

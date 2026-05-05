"""Izvlači UPDATE blokove iz SQL fajla i pakuje u manje chunk fajlove za execute_sql."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def extract_updates(text: str) -> list[str]:
    pat = re.compile(
        r"UPDATE public\.employees\s+SET[\s\S]+?WHERE id = '[^']+'::uuid;",
        re.MULTILINE,
    )
    return pat.findall(text)


def main() -> None:
    per_chunk = 15
    src_name = "_apply_b2_8_part_a.sql"
    if len(sys.argv) > 1:
        per_chunk = int(sys.argv[1])
    if len(sys.argv) > 2:
        src_name = sys.argv[2]
    src = ROOT / "docs" / "reports" / src_name
    out_dir = ROOT / "docs" / "reports" / "_mcp_chunks"
    out_dir.mkdir(parents=True, exist_ok=True)
    text = src.read_text(encoding="utf-8")
    blocks = extract_updates(text)
    print("source", src.name, "updates", len(blocks))
    for i in range(0, len(blocks), per_chunk):
        chunk = blocks[i : i + per_chunk]
        body = "\n\n".join(chunk)
        sql = f"BEGIN;\nSET statement_timeout = '120s';\n\n{body}\n\nCOMMIT;\n"
        name = f"{src.stem}__c{i // per_chunk:02d}.sql"
        (out_dir / name).write_text(sql, encoding="utf-8")
        print(" wrote", name, "bytes", len(sql))


def minify_sql_to_one_line() -> None:
    src = ROOT / "docs" / "reports" / "_mcp_chunks" / "_apply_b2_8_part_a__c00.sql"
    out = ROOT / "docs" / "reports" / "_c00_oneline.sql"
    q = src.read_text(encoding="utf-8")
    import re

    q2 = re.sub(r"\s+", " ", q).strip()
    out.write_text(q2, encoding="utf-8")
    print("wrote", out, "len", len(q2), "newlines", q2.count("\n"))


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--minify-c00":
        minify_sql_to_one_line()
    else:
        main()

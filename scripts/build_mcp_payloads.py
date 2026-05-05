"""Generiše docs/reports/_mcp_payload_*.json za svaki chunk; query je iz UTF-8 fajla."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHUNKS = ROOT / "docs" / "reports" / "_mcp_chunks"
OUT = ROOT / "docs" / "reports"


def to_one_line(sql: str) -> str:
    return re.sub(r"\s+", " ", sql).strip()


def main() -> None:
    for p in sorted(CHUNKS.glob("*.sql")):
        q = p.read_text(encoding="utf-8")
        oneline = to_one_line(q)
        name = f"_mcp_payload_{p.stem}.json"
        (OUT / name).write_text(
            json.dumps({"query": oneline}, ensure_ascii=False), encoding="utf-8"
        )
        print("wrote", name, "query_len", len(oneline), "from", p.name)


if __name__ == "__main__":
    main()

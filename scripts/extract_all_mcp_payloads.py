import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAYLOADS = ROOT / "docs" / "reports"
OUT = PAYLOADS / "_batch_queries"
OUT.mkdir(parents=True, exist_ok=True)


def main() -> None:
    for p in sorted(PAYLOADS.glob("_mcp_payload_*.json")):
        d = json.loads(p.read_text(encoding="utf-8"))
        out = OUT / (p.stem.replace("_mcp_payload_", "q_") + ".sql")
        out.write_text(d["query"], encoding="utf-8")
        print("wrote", out.name, len(d["query"]))


if __name__ == "__main__":
    main()

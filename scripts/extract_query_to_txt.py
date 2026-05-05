import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    jpath = Path(sys.argv[1])
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else jpath.with_suffix(".query.txt")
    d = json.loads(jpath.read_text(encoding="utf-8"))
    q = d["query"]
    out.write_text(q, encoding="utf-8")
    print("wrote", out, "len", len(q))


if __name__ == "__main__":
    main()

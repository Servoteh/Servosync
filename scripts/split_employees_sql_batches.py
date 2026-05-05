import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
src = root / "docs" / "reports" / "_employees_apply_from_xlsx.sql"
s = src.read_text(encoding="utf-8")
u = re.findall(
    r"UPDATE public\.employees\nSET\n[\s\S]+?WHERE id = [^\n]+;",
    s,
)
out_dir = root / "docs" / "reports" / "_employees_batches"
out_dir.mkdir(exist_ok=True)
bs = 20
batches: list[str] = []
for i in range(0, len(u), bs):
    chunk = u[i : i + bs]
    body = "BEGIN;\nSET statement_timeout = '120s';\n" + "\n\n".join(chunk) + "\nCOMMIT;\n"
    batches.append(body)
    (out_dir / f"batch_{len(batches):02d}.sql").write_text(body, encoding="utf-8")
print("updates", len(u), "batches", len(batches), "dir", out_dir)

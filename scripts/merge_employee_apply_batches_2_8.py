from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = root / "docs" / "reports" / "_apply_batches_2_to_8.sql"
parts: list[str] = []
for i in range(2, 9):
    p = root / "docs" / "reports" / "_employees_batches" / f"batch_{i:02d}.sql"
    parts.append(p.read_text(encoding="utf-8").strip() + "\n")
out.write_text("\n".join(parts), encoding="utf-8")
print(out, len("".join(parts)))

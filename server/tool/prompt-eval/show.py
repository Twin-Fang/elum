"""결과 요약 출력: python3 show.py <variant> [--cases a,b]"""
import json, sys
from pathlib import Path
import lib
variant = sys.argv[1]
wanted = set(sys.argv[3].split(",")) if len(sys.argv) > 3 and sys.argv[2] == "--cases" else None
for path in sorted((lib.TOOL_DIR / "results" / variant / "text").glob("*.json")):
    if path.name.startswith("_"): continue
    r = json.loads(path.read_text(encoding="utf-8"))
    if wanted and r["id"] not in wanted: continue
    print(f"\n[{r['id']}|{r['category']}] {r['input'][:70]}")
    if "preprocessed" in r: print("  정리:", r["preprocessed"])
    if "error" in r: print("  ERROR", r["error"][:150]); continue
    print("  제목:", r["result"]["title"])
    for s in r["result"]["steps"]:
        extra = {k: v for k, v in s.items() if k not in ("order","title","description","pictogramId")}
        print(f"  {s['order']}. {s['title']} | {s['description']} | {s.get('pictogramId')}", extra or "")
    if r["metrics"]["violations"]: print("  ⚠", r["metrics"]["violations"])

"""design/lesson_v2 の書き直し本文を Resources/<exam>_lessons.json に反映する。

- 反映するのは summary・sections・estimatedMinutes（約400字/分）だけ。id・タイトル・分野・問題IDは変えない。
- check_lessons.py で NG のレッスンは反映しない（--force で反映）。
- 反映後に add_points.py を実行し、それでも本文に無い正解語を「出題ポイント」として付け直す。
- --web を付けると Web 版（beqd1106-web-/shikakunote/app/data）にも1行JSONで書き出す。
使い方: python design/apply_lessons.py [--apply] [--force] [--web]
"""
import json, sys, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RES = ROOT.parent / "Resources"
V2 = ROOT / "lesson_v2"
WEB = Path(r"C:\Users\user\Desktop\beqd1106-web-\shikakunote\app\data")
EXAMS = ["itp", "fe", "aws", "aip", "g", "mos", "vba", "wia", "pmos", "dify"]

sys.path.insert(0, str(ROOT))
from check_lessons import check  # noqa: E402


def main(apply, force, web):
    total = done = skipped = 0
    for k in EXAMS:
        lp = RES / f"{k}_lessons.json"
        L = json.loads(lp.read_text(encoding="utf-8"))
        changed = False
        for l in L:
            p = V2 / k / f"{l['id']}.json"
            if not p.exists():
                continue
            total += 1
            r = check(f"{k}/{l['id']}")
            if not r["ok"] and not force:
                skipped += 1
                print(f"保留 {k}/{l['id']}: {'；'.join(r['problems'])}")
                continue
            d = json.loads(p.read_text(encoding="utf-8"))
            l["summary"] = d["summary"]
            l["sections"] = [{"heading": s["heading"], "body": s["body"]} for s in d["sections"]]
            l["estimatedMinutes"] = max(5, round(r["chars"] / 400))
            changed = True; done += 1
        if apply and changed:
            with open(lp, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(json.dumps(L, ensure_ascii=False, indent=1) + "\n")
    print(f"書き直し {total}本中 反映{done}本・保留{skipped}本" + ("" if apply else "（--apply なしのため未保存）"))
    if apply:
        subprocess.run([sys.executable, str(ROOT / "add_points.py"), "--apply"], check=True)
        if web:
            for k in EXAMS:
                d = json.loads((RES / f"{k}_lessons.json").read_text(encoding="utf-8"))
                with open(WEB / f"{k}_lessons.json", "w", encoding="utf-8", newline="\n") as fh:
                    fh.write(json.dumps(d, ensure_ascii=False, separators=(",", ":")))
            print("Web版にも書き出しました")


if __name__ == "__main__":
    a = sys.argv[1:]
    main("--apply" in a, "--force" in a, "--web" in a)

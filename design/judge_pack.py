"""「本文だけで解けるか」テスト用のファイルを作る／採点する。

作る:  python design/judge_pack.py make <exam>/<lessonId> ... [--n 15]
  → design/judge/<exam>/<lessonId>.md （書き直した本文＋問題。正解は書かない。問題は均等に抜き出す）
採点:  python design/judge_pack.py score [<exam>/<lessonId> ...]
  → 解答 design/judge/<exam>/<lessonId>.answers.json（{"問題ID": {"choice": 1始まりの番号 or null, "quote": "根拠の本文"}}）を正解と照合
"""
import json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RES = ROOT.parent / "Resources"
V2 = ROOT / "lesson_v2"
OUT = ROOT / "judge"


def lesson_qids(k, lid):
    L = {l["id"]: l for l in json.loads((RES / f"{k}_lessons.json").read_text(encoding="utf-8"))}
    l = L[lid]; ids = []
    for f in ("basicQuizIds", "quizIds", "drillQuizIds", "challengeQuizIds"):
        ids += [i for i in (l.get(f) or []) if i not in ids]
    return ids


def questions(k):
    return {q["id"]: q for q in json.loads((RES / f"{k}_questions.json").read_text(encoding="utf-8"))}


def make(targets, n, old=False):
    """old=True なら書き直し前（Resources の現在の本文。出題ポイントの節は除く）で作る。"""
    for t in targets:
        k, lid = t.split("/")
        if old:
            d = next(l for l in json.loads((RES / f"{k}_lessons.json").read_text(encoding="utf-8")) if l["id"] == lid)
            d = {"summary": d["summary"], "sections": [s for s in d["sections"] if not s["heading"].startswith("出題ポイント")]}
        else:
            d = json.loads((V2 / k / f"{lid}.json").read_text(encoding="utf-8"))
        Q = questions(k)
        ids = [i for i in lesson_qids(k, lid) if i in Q and len(Q[i]["correctAnswers"]) == 1]
        step = max(1, len(ids) / n)
        pick = [ids[int(i * step)] for i in range(min(n, len(ids)))]
        lines = ["# 本文", f"要点: {d['summary']}", ""]
        for s in d["sections"]:
            lines += [f"## {s['heading']}", s["body"], ""]
        lines += ["# 問題", ""]
        for i in pick:
            q = Q[i]
            lines.append(f"## {i}")
            lines.append(q["question"])
            lines += [f"{j + 1}. {c}" for j, c in enumerate(q["choices"])]
            lines.append("")
        dst = OUT / ("_old_" + k if old else k)
        dst.mkdir(parents=True, exist_ok=True)
        (dst / f"{lid}.md").write_text("\n".join(lines), encoding="utf-8")
    print(len(targets), "本の問題ファイルを作りました")


def score(targets):
    if not targets:
        targets = [f"{p.parent.name}/{p.name.split('.')[0]}" for p in sorted(OUT.glob("*/*.answers.json"))]
    all_n = all_ok = all_none = 0
    for t in targets:
        k, lid = t.split("/")
        ap = OUT / k / f"{lid}.answers.json"
        k = k.replace("_old_", "")
        if not ap.exists():
            print("未解答", t); continue
        A = json.loads(ap.read_text(encoding="utf-8")); Q = questions(k)
        n = ok = none = 0; bad = []
        for qid, a in A.items():
            q = Q.get(qid)
            if not q:
                continue
            n += 1
            c = a.get("choice")
            if c is None:
                none += 1; bad.append(f"{qid}:根拠なし")
            elif c - 1 in q["correctAnswers"]:
                ok += 1
            else:
                bad.append(f"{qid}:誤答{c}")
        all_n += n; all_ok += ok; all_none += none
        print(f"{t:22} 本文で解けた {ok}/{n}  根拠なし{none}  {' '.join(bad)}")
    if all_n:
        print(f"--- 合計 本文で解けた {all_ok}/{all_n} = {all_ok / all_n * 100:.1f}%  根拠なし {all_none}")


if __name__ == "__main__":
    a = sys.argv[1:]
    if a and a[0] == "make":
        n = int(a[a.index("--n") + 1]) if "--n" in a else 15
        make([x for x in a[1:] if "/" in x], n, old="--old" in a)
    elif a and a[0] == "score":
        score(a[1:])
    else:
        print(__doc__)

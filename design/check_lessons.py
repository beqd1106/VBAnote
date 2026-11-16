"""書き直したレッスン（design/lesson_v2）を機械チェックする。

使い方:
  python design/check_lessons.py itp/l-sc1 wia/l-ft1   … 指定したレッスン
  python design/check_lessons.py all                   … lesson_v2 にある全部
各レッスンについて、正解語の掲載率・誤答語の掲載率・字数・節の数と、守れていない決まりを出す。
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RES = ROOT.parent / "Resources"
V2 = ROOT / "lesson_v2"
POINTS = "出題ポイント（問題で問われる言葉）"
_cache = {}


def key_of(s):
    return re.split(r"[（(：:、。]", s)[0].strip()


def countable(k):
    return 2 <= len(k) <= 30


def exam_data(k):
    if k not in _cache:
        L = {l["id"]: l for l in json.loads((RES / f"{k}_lessons.json").read_text(encoding="utf-8"))}
        Q = {q["id"]: q for q in json.loads((RES / f"{k}_questions.json").read_text(encoding="utf-8"))}
        _cache[k] = (L, Q)
    return _cache[k]


def check(target):
    k, lid = target.split("/")
    L, Q = exam_data(k)
    p = V2 / k / f"{lid}.json"
    problems = []
    try:
        d = json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:
        return {"target": target, "ok": False, "problems": [f"読めない: {e}"]}
    if d.get("id") != lid:
        problems.append("idが違う")
    secs = d.get("sections") or []
    if not (3 <= len(secs) <= 8):
        problems.append(f"節の数 {len(secs)}（3〜8）")
    if any(s.get("heading") == POINTS or "出題ポイント" in s.get("heading", "") for s in secs):
        problems.append("出題ポイントの節がある")
    if len(d.get("summary", "")) > 100:
        problems.append("summaryが長い")
    text = d.get("summary", "") + "".join(s.get("heading", "") + s.get("body", "") for s in secs)
    if re.search(r"\*\*|^#|\|", text, re.M):
        problems.append("Markdown記号がある")
    if any(re.search(r"まとめ直|言い回し", s.get("heading", "")) for s in secs):
        problems.append("まとめ直しの節がある")
    if re.search(r"正解は|問題で問われ", text):
        problems.append("メタな言い方がある")
    l = L[lid]
    ids = []
    for f in ("basicQuizIds", "quizIds", "drillQuizIds", "challengeQuizIds"):
        ids += [i for i in (l.get(f) or []) if i not in ids]
    ok_hit = ok_n = ng_hit = ng_n = 0
    missing = []
    for i in ids:
        q = Q.get(i)
        if not q:
            continue
        for ci, c in enumerate(q["choices"]):
            kk = key_of(c)
            if not countable(kk):
                continue
            if ci in q["correctAnswers"]:
                ok_n += 1
                if kk in text:
                    ok_hit += 1
                elif kk not in missing:
                    missing.append(kk)
            else:
                ng_n += 1
                ng_hit += kk in text
    rate = ok_hit / ok_n * 100 if ok_n else 100.0
    if rate < 85:
        problems.append(f"正解語の掲載率 {rate:.0f}%（85%以上）")
    return {"target": target, "ok": not problems, "chars": len(text), "sections": len(secs),
            "correct_rate": round(rate, 1), "wrong_rate": round(ng_hit / ng_n * 100, 1) if ng_n else 100.0,
            "missing": missing[:30], "problems": problems}


def main(args):
    if args == ["all"]:
        args = [f"{p.parent.name}/{p.stem}" for p in sorted(V2.glob("*/*.json"))]
    res = [check(t) for t in args]
    for r in res:
        head = "OK " if r["ok"] else "NG "
        if "chars" in r:
            print(f"{head}{r['target']:22} {r['chars']:5}字 節{r['sections']} 正解語{r['correct_rate']:5}% 誤答語{r['wrong_rate']:5}%  {'；'.join(r['problems'])}")
            if r["missing"] and r["correct_rate"] < 100:
                print("     本文に無い正解語:", "、".join(r["missing"]))
        else:
            print(head + r["target"], r["problems"])
    if len(res) > 1:
        rs = [r for r in res if "chars" in r]
        if rs:
            print(f"--- {len(rs)}本  OK {sum(r['ok'] for r in rs)}本  平均正解語 {sum(r['correct_rate'] for r in rs) / len(rs):.1f}%")


if __name__ == "__main__":
    main(sys.argv[1:])

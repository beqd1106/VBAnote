"""各レッスン末尾に「出題ポイント」節を作る（何度実行しても同じ結果）。

教材本文に正解語が載っていない問題について、正解語＋既存の解説の1文目を並べる。
新しい文章は書かず、確認済みの解説だけを使う。
使い方: python design/add_points.py [--apply]
"""
import json, re, sys
from pathlib import Path

RES = Path(__file__).resolve().parent.parent / "Resources"
HEADING = "出題ポイント（問題で問われる言葉）"
EXAMS = ["itp", "fe", "aws", "aip", "g", "mos", "vba", "wia", "pmos", "dify"]


def key_of(ans: str) -> str:
    return re.split(r"[（(：:、。]", ans)[0].strip()


BAD = ("正解は", "本文", "マニュアルに", "問題文", "選択肢")


def first_sentence(text: str) -> str:
    """解説から、正解の言い換えや出典の言及ではない最初の文を選ぶ。"""
    sents = [x.strip() for x in re.split(r"(?<=。)", text.strip()) if x.strip()]
    good = [x for x in sents if not any(b in x for b in BAD)]
    s = (good or sents or [""])[0]
    return s if len(s) <= 120 else s[:118] + "…"


def lesson_text(l):
    return l.get("summary", "") + "".join(
        s.get("heading", "") + s.get("body", "") for s in l.get("sections", []))


def run(apply: bool):
    for k in EXAMS:
        lp = RES / f"{k}_lessons.json"
        L = json.loads(lp.read_text(encoding="utf-8"))
        Q = {q["id"]: q for q in json.loads((RES / f"{k}_questions.json").read_text(encoding="utf-8"))}
        before = after = tot = 0
        for l in L:
            l["sections"] = [s for s in l.get("sections", []) if s.get("heading") != HEADING]
            txt = lesson_text(l)
            ids = []
            for f in ("basicQuizIds", "quizIds", "drillQuizIds", "challengeQuizIds"):
                ids += [i for i in (l.get(f) or []) if i not in ids]
            lines, seen = [], set()
            for i in ids:
                q = Q.get(i)
                if not q or not q.get("correctAnswers"):
                    continue
                key = key_of(q["choices"][q["correctAnswers"][0]])
                ok = len(key) >= 2 and key in txt
                tot += 1; before += ok
                if ok or len(key) < 2 or len(key) > 30:
                    after += ok
                    continue
                sent = first_sentence(q.get("explanation", ""))
                if sent and key not in seen:
                    seen.add(key)
                    lines.append(f"・{key}：{sent}")
                after += 1
            if lines:
                l["sections"].append({"heading": HEADING, "body": "\n".join(lines)})
        print(f"{k:5} {before / tot * 100:5.1f}% → {after / tot * 100:5.1f}%")
        if apply:
            with open(lp, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(json.dumps(L, ensure_ascii=False, indent=1) + "\n")


if __name__ == "__main__":
    run("--apply" in sys.argv)

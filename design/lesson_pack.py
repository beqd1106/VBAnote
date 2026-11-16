"""レッスン書き直し用の素材ファイルを作る。

design/lesson_pack/<exam>/<lessonId>.md に「現在の本文＋このレッスンの全問題（選択肢・正解・解説・誤答の理由・出典）」を書き出し、
design/lesson_pack/batches.json に、素材の量がおおよそ均等になるようレッスンを束ねた一覧を書く。
使い方: python design/lesson_pack.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RES = ROOT.parent / "Resources"
OUT = ROOT / "lesson_pack"
EXAMS = ["itp", "fe", "aws", "aip", "g", "mos", "vba", "wia", "pmos", "dify"]
POINTS = "出題ポイント（問題で問われる言葉）"
BATCH_CHARS = 110000  # 1束あたりの素材字数の目安


def lesson_ids(l):
    out = []
    for f in ("basicQuizIds", "quizIds", "drillQuizIds", "challengeQuizIds"):
        out += [i for i in (l.get(f) or []) if i not in out]
    return out


def main():
    exams = json.loads((RES / "exams.json").read_text(encoding="utf-8"))
    names = {e["key"]: e.get("examFullName") or e["key"] for e in exams}
    batches, cur, cur_n = [], [], 0
    for k in EXAMS:
        L = json.loads((RES / f"{k}_lessons.json").read_text(encoding="utf-8"))
        Q = {q["id"]: q for q in json.loads((RES / f"{k}_questions.json").read_text(encoding="utf-8"))}
        (OUT / k).mkdir(parents=True, exist_ok=True)
        if cur:  # 資格ごとに束を切る（1束に別の資格を混ぜない）
            batches.append(cur); cur, cur_n = [], 0
        for l in L:
            lines = [f"# {names.get(k, k)}／レッスン {l['id']}「{l['title']}」", "",
                     "## 現在の本文", f"要点: {l.get('summary', '')}", ""]
            for s in l.get("sections", []):
                if s.get("heading") == POINTS:
                    continue
                lines += [f"### {s['heading']}", s["body"], ""]
            qs = [Q[i] for i in lesson_ids(l) if i in Q]
            lines += [f"## このレッスンの問題（{len(qs)}問）", ""]
            for q in qs:
                lines.append(f"### {q['id']}")
                lines.append(f"問: {q['question']}")
                for i, c in enumerate(q["choices"]):
                    mark = "◎" if i in q["correctAnswers"] else "×"
                    lines.append(f"  {mark}{i + 1}. {c}")
                lines.append(f"解説: {q.get('explanation', '')}")
                for i, t in sorted((q.get("wrongChoiceExplanations") or {}).items(), key=lambda x: int(x[0])):
                    lines.append(f"  ×{int(i) + 1}の理由: {t}")
                if q.get("beginnerNote"):
                    lines.append(f"ひとこと: {q['beginnerNote']}")
                if q.get("source"):
                    lines.append(f"出典: {q['source']}")
                if q.get("manualExcerpt"):
                    lines.append(f"マニュアル抜粋: {q['manualExcerpt']}")
                lines.append("")
            text = "\n".join(lines)
            (OUT / k / f"{l['id']}.md").write_text(text, encoding="utf-8")
            if cur and cur_n + len(text) > BATCH_CHARS:
                batches.append(cur); cur, cur_n = [], 0
            cur.append(f"{k}/{l['id']}"); cur_n += len(text)
    if cur:
        batches.append(cur)
    (OUT / "batches.json").write_text(json.dumps(batches, ensure_ascii=False, indent=1), encoding="utf-8")
    print(len(batches), "束", sum(map(len, batches)), "レッスン")


if __name__ == "__main__":
    main()

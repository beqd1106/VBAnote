"""カード教材の道具。
  python -I design/card_tools.py pack <exam> <lessonId>...   入力 card_pack/<exam>/<id>.md を作る
  python -I design/card_tools.py check <exam>/<lessonId>...  cards_v1 の検査
  python -I design/card_tools.py judge <exam> <lessonId>     採点用 judge 入力（カードだけ＋全問題、正解は伏せる）
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "Resources"
D = ROOT / "design"
POINTS_HEADING = "出題ポイント（問題で問われる言葉）"
BODY_MAX, HEAD_MAX, EX_MAX, TITLE_MAX = 150, 16, 80, 14


def load(exam):
    ls = json.loads((RES / f"{exam}_lessons.json").read_text(encoding="utf-8"))
    ls = ls if isinstance(ls, list) else ls["lessons"]
    qs = json.loads((RES / f"{exam}_questions.json").read_text(encoding="utf-8"))
    qs = qs if isinstance(qs, list) else qs["questions"]
    return {l["id"]: l for l in ls}, {q["id"]: q for q in qs}


def all_qids(l):
    return (l.get("basicQuizIds") or []) + l["quizIds"] + (l.get("challengeQuizIds") or []) + (l.get("drillQuizIds") or [])


def q_md(q, reveal=True):
    out = [f"### {q['id']}", f"問: {q['question']}"]
    for i, c in enumerate(q["choices"]):
        mark = ("◎" if i in q["correctAnswers"] else "×") if reveal else ""
        out.append(f"  {mark}{i + 1}. {c}")
    if reveal:
        out.append(f"解説: {q['explanation']}")
        for k, v in (q.get("wrongChoiceExplanations") or {}).items():
            out.append(f"×{int(k) + 1}の理由: {v}")
    return "\n".join(out)


def inter_ids(l):
    """カードの間にはさむ問題。基礎問題(b-)があればそれを全部、無いレッスンは本問題(quizIds)から選ぶ。"""
    return l.get("basicQuizIds") or l["quizIds"]


def pack(exam, ids):
    L, Q = load(exam)
    od = D / "card_pack" / exam
    od.mkdir(parents=True, exist_ok=True)
    for lid in ids:
        l = L[lid]
        parts = [f"# レッスン {lid}「{l['title']}」", "", "## 今の本文（長文）", f"要点: {l['summary']}", ""]
        for s in l["sections"]:
            if s["heading"] == POINTS_HEADING:
                continue
            parts += [f"### {s['heading']}", s["body"], ""]
        b = inter_ids(l)
        if l.get("basicQuizIds"):
            parts += [f"## 基礎問題（b-・全{len(b)}問をカードの間にはさむ）", ""]
        else:
            parts += [f"## はさむ問題（このレッスンは基礎問題が無いので、この{len(b)}問から各区切りに1〜2問ずつはさむ。全部はさまなくてよい・各問1回まで）", ""]
        parts += [q_md(Q[i]) + "\n" for i in b if i in Q]
        rest = [i for i in all_qids(l) if i not in b and i in Q]
        parts += [f"## そのほかの問題（{len(rest)}問・はさまないが、カードだけで解けるようにする）", ""]
        parts += [q_md(Q[i]) + "\n" for i in rest]
        (od / f"{lid}.md").write_text("\n".join(parts), encoding="utf-8")
        print("pack", exam, lid, len(b), len(rest))


def check(target):
    exam, lid = target.split("/")
    L, Q = load(exam)
    l = L[lid]
    p = D / "cards_v1" / exam / f"{lid}.json"
    errs = []
    try:
        c = json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:  # noqa: BLE001 - 結果に理由を出す
        return [f"JSONが読めない: {e}"], {}
    if c.get("id") != lid:
        errs.append("idが違う")
    raw = p.read_text(encoding="utf-8")
    if "??" in raw or "�" in raw:
        errs.append("文字化け（??や置換文字）がある。日本語が失われているので、元の材料から書き直す")
    basic = inter_ids(l)
    must_all = bool(l.get("basicQuizIds"))
    seen, n_point, chars, unit_lens = [], 0, 0, []
    for ui, u in enumerate(c.get("units", [])):
        if len(u.get("title", "")) > TITLE_MAX:
            errs.append(f"区切り{ui + 1} title が長い")
        np_, nq = 0, 0
        first_quiz_at = None
        for ci, k in enumerate(u.get("cards", [])):
            if k.get("t") == "point":
                np_ += 1
                body = k.get("body", "")
                chars += len(body) + len(k.get("ex", ""))
                if len(body) > BODY_MAX:
                    errs.append(f"区切り{ui + 1}-{ci + 1} body {len(body)}字")
                if len(k.get("head", "")) > HEAD_MAX:
                    errs.append(f"区切り{ui + 1}-{ci + 1} head が長い")
                if len(k.get("ex", "")) > EX_MAX:
                    errs.append(f"区切り{ui + 1}-{ci + 1} ex が長い")
                for bad in ("**", "#", "|"):
                    if bad in body:
                        errs.append(f"区切り{ui + 1}-{ci + 1} 記号 {bad}")
            elif k.get("t") == "quiz":
                nq += 1
                qid = k.get("q")
                if first_quiz_at is None:
                    first_quiz_at = ci
                if qid not in basic:
                    errs.append(f"{qid} ははさめる問題でない（使えるのは {basic}）")
                if qid in seen:
                    errs.append(f"{qid} が重複")
                seen.append(qid)
            else:
                errs.append(f"区切り{ui + 1}-{ci + 1} 不明な t")
        if nq == 0:
            errs.append(f"units[{ui}]（{ui + 1}番目の区切り「{u.get('title', '')}」）に quiz が1つも無い。前後の区切りから問題を1つ移すか、はさめる問題から1つ足す（根拠カードより後に置く）か、前後の区切りとまとめる")
        n_point += np_
        unit_lens.append((np_, nq))
    missing = [i for i in basic if i not in seen]
    if missing and must_all:
        errs.append(f"はさんでいない基礎問題: {missing}")
    # 読む時間の目安：1分400字＋1問20秒
    mins = [round((0 + 0) / 1, 1) for _ in unit_lens]
    stat = {"units": len(unit_lens), "points": n_point, "quiz": len(seen), "chars": chars, "per_unit": unit_lens}
    return errs, stat


def judge(exam, lid):
    """カードだけを本文にした採点入力。正解は伏せる。"""
    L, Q = load(exam)
    l = L[lid]
    c = json.loads((D / "cards_v1" / exam / f"{lid}.json").read_text(encoding="utf-8"))
    parts = ["# 教材（カード）"]
    for u in c["units"]:
        parts.append(f"## {u['title']}")
        for k in u["cards"]:
            if k["t"] == "point":
                parts.append(f"【{k['head']}】{k['body']}" + (f"（例：{k['ex']}）" if k.get("ex") else ""))
    parts += ["", "# 問題（教材だけを根拠に答える）", ""]
    parts += [q_md(Q[i], reveal=False) + "\n" for i in all_qids(l) if i in Q]
    od = D / "card_judge" / exam
    od.mkdir(parents=True, exist_ok=True)
    (od / f"{lid}.md").write_text("\n".join(parts), encoding="utf-8")
    key = {i: Q[i]["correctAnswers"] for i in all_qids(l) if i in Q}
    (od / f"{lid}.key.json").write_text(json.dumps(key, ensure_ascii=False), encoding="utf-8")
    print("judge", od / f"{lid}.md", len(key))



def export(web_data_dir):
    """合格（status ok かつ 今の check も通る）のカードだけを Web の data/<exam>_cards.json に書き出す。"""
    st = json.loads((D / "card_run_status.json").read_text(encoding="utf-8"))
    out = Path(web_data_dir)
    for exam_dir in sorted((D / "cards_v1").iterdir()):
        if not exam_dir.is_dir():
            continue
        exam = exam_dir.name
        L, _ = load(exam)
        res = {}
        for lid in L:
            if not st.get(f"{exam}/{lid}", {}).get("ok"):
                continue
            errs, _ = check(f"{exam}/{lid}")
            if errs:
                print("skip(check NG)", exam, lid, errs[:1])
                continue
            c = json.loads((exam_dir / f"{lid}.json").read_text(encoding="utf-8"))
            res[lid] = {"units": c["units"]}
        if res:
            (out / f"{exam}_cards.json").write_text(json.dumps(res, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
            print("export", exam, len(res))


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "pack":
        pack(sys.argv[2], sys.argv[3:])
    elif cmd == "check":
        bad = 0
        for t in sys.argv[2:]:
            e, s = check(t)
            print(t, "OK" if not e else "NG", s)
            for x in e:
                print("  -", x)
            bad += bool(e)
        sys.exit(1 if bad else 0)
    elif cmd == "judge":
        judge(sys.argv[2], sys.argv[3])
    elif cmd == "export":
        export(sys.argv[2])

# -*- coding: utf-8 -*-
"""
Resources/*.json が Swift の Codable モデルどおりにデコードできるかを検証する。
Macが無くビルドで確かめられないため、モデル定義と同じ制約をここで機械チェックする。

  python design/validate_resources.py
"""
import json, os, sys, collections

RES = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Resources")
DOMAINS = {"concept", "syntax", "variable", "cell", "control", "book"}
errors, warns = [], []


def load(name):
    return json.load(open(os.path.join(RES, f"{name}.json"), encoding="utf-8"))


def need(obj, key, typ, where, optional=False):
    """Swift の非Optionalプロパティはキーが無いとデコードに失敗する"""
    if key not in obj or obj[key] is None:
        if not optional:
            errors.append(f"{where}: 必須キー {key} が無い（Swiftのデコードが失敗する）")
        return None
    if not isinstance(obj[key], typ):
        errors.append(f"{where}: {key} の型が違う（{type(obj[key]).__name__}）")
        return None
    return obj[key]


def check_questions():
    qs = load("questions")
    print(f"questions.json : {len(qs)}問")
    ids = collections.Counter()
    for q in qs:
        w = f"  問題 {q.get('id','?')}"
        need(q, "id", str, w); need(q, "question", str, w)
        ch = need(q, "choices", list, w)
        ca = need(q, "correctAnswers", list, w)
        need(q, "explanation", str, w)
        need(q, "service", str, w)
        need(q, "difficulty", int, w)
        need(q, "tags", list, w)
        # 非Optional辞書：キーが無いとデコード失敗
        we = need(q, "wrongChoiceExplanations", dict, w)
        need(q, "beginnerNote", str, w, optional=True)
        # AWS版に source は無い
        d = q.get("domain")
        if d not in DOMAINS:
            errors.append(f"{w}: domain が不正 '{d}'")
        if ch is not None and len(ch) != 4:
            warns.append(f"{w}: 選択肢が{len(ch)}個")
        if ca is not None:
            if not ca:
                errors.append(f"{w}: correctAnswers が空")
            for i in ca:
                if not isinstance(i, int) or ch is None or not (0 <= i < len(ch)):
                    errors.append(f"{w}: correctAnswers の値 {i} が選択肢範囲外")
        if we is not None and ch is not None:
            for k, v in we.items():
                if not k.isdigit() or not (0 <= int(k) < len(ch)):
                    errors.append(f"{w}: wrongChoiceExplanations のキー '{k}' が不正")
                elif ca and int(k) in ca:
                    errors.append(f"{w}: 正解 {k} に誤答解説が付いている")
                if not isinstance(v, str):
                    errors.append(f"{w}: wrongChoiceExplanations の値が文字列でない")
        ids[q.get("id")] += 1
    for i, n in ids.items():
        if n > 1:
            errors.append(f"  問題ID重複: {i} が{n}件")
    return {q["id"] for q in qs}, qs


def check_lessons(qids):
    ls = load("lessons")
    print(f"lessons.json   : {len(ls)}レッスン")
    for l in ls:
        w = f"  レッスン {l.get('id','?')}"
        need(l, "id", str, w); need(l, "title", str, w)
        need(l, "estimatedMinutes", int, w); need(l, "summary", str, w)
        secs = need(l, "sections", list, w)
        need(l, "quizIds", list, w)
        if l.get("domain") not in DOMAINS:
            errors.append(f"{w}: domain が不正")
        for s in secs or []:
            need(s, "heading", str, w); need(s, "body", str, w)
        for key in ("basicQuizIds", "quizIds", "challengeQuizIds", "drillQuizIds"):
            for qid in l.get(key) or []:
                if qid not in qids:
                    errors.append(f"{w}: {key} の参照先 {qid} が questions.json に無い")
        if not l.get("quizIds"):
            errors.append(f"{w}: 確認問題が空")
    return ls


def check_others():
    for name, keys in [("terms", ["id", "term", "shortDescription", "beginnerExplanation",
                                  "useCase", "examPoint", "relatedServices", "domain", "difficulty"]),
                       ("services", ["id", "name", "category", "oneLiner", "domain"])]:
        items = load(name)
        print(f"{name+'.json':<15}: {len(items)}件")
        for it in items:
            w = f"  {name} {it.get('id','?')}"
            for k in keys:
                if k not in it or it[k] is None:
                    errors.append(f"{w}: 必須キー {k} が無い")
            if it.get("domain") not in DOMAINS:
                errors.append(f"{w}: domain が不正 '{it.get('domain')}'")
    g = load("glossary")
    print(f"{'glossary.json':<15}: {len(g)}件")
    for e in g:
        if not isinstance(e.get("term"), str) or not isinstance(e.get("explanation"), str):
            errors.append(f"  用語集: 不正なエントリ {e}")


def main():
    qids, qs = check_questions()
    lessons = check_lessons(qids)
    check_others()

    used = set()
    for l in lessons:
        for key in ("basicQuizIds", "quizIds", "challengeQuizIds", "drillQuizIds"):
            used |= set(l.get(key) or [])
    print(f"\nレッスンから到達できる問題: {len(used)} / {len(qids)}")
    if len(used) < len(qids):
        warns.append(f"  どのレッスンからも辿れない問題が {len(qids)-len(used)}問ある")

    dom = collections.Counter(q["domain"] for q in qs)
    print("分野配分:", ", ".join(f"{k} {v}問" for k, v in dom.items()))

    if warns:
        print(f"\n警告 {len(warns)}件")
        for x in warns[:10]:
            print(" ", x)
    if errors:
        print(f"\nエラー {len(errors)}件")
        for x in errors[:25]:
            print(" ", x)
        sys.exit(1)
    print("\n検証OK：Swiftのモデル定義と矛盾なし")


if __name__ == "__main__":
    main()

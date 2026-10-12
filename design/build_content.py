# -*- coding: utf-8 -*-
"""design/src/*.json（レッスン原稿）→ Resources/*.json を組み立て、品質を測る。

  python build_content.py FE            # 書き出し＋品質レポート
  python build_content.py FE --check    # 書き出さずにレポートだけ

ID の付け方：基礎 b-<lesson>-NN（tag「基礎」）／確認 q-<lesson>-NN／ドリル d-<lesson>-NN（tag「ドリル」）
正解位置はアプリ全体で①②③④が均等になるよう、ここで並べ替える（誤答解説のキーも付け替える）。
"""
import json, os, sys, collections, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from configs import APPS

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
import itertools
PERMS = list(itertools.permutations(range(4)))
GROUPS = [("basic", "b", 15), ("confirm", "q", 15), ("drill", "d", 10)]


def stable_hash(s):
    h = 5381
    for ch in s.encode("utf-8"):
        h = (h * 33 + ch) & 0xFFFFFFFF
    return h


def place_correct(q, target):
    """正解を target 番目へ。誤答の相対順序は保つ。"""
    ch, ans = q["choices"], q["answer"]
    others = [i for i in range(4) if i != ans]
    order = others[:]
    order.insert(target, ans)           # order[new_index] = old_index
    new_choices = [ch[i] for i in order]
    old2new = {old: new for new, old in enumerate(order)}
    wrong = {str(old2new[int(k)]): v for k, v in q["wrong"].items()}
    return new_choices, target, wrong


def main(key, write=True):
    c = APPS[key]
    app = os.path.join(ROOT, c["app"])
    src = os.path.join(app, "design", "src")
    valid = {d[0] for d in c["domains"]}
    problems, questions, lessons = [], [], []
    missing = []
    seq = 0
    for lid, dom, title, _ in c["lessons"]:
        p = os.path.join(src, f"{lid}.json")
        if not os.path.exists(p):
            missing.append(lid); continue
        try:
            d = json.load(open(p, encoding="utf-8"))
        except Exception as e:
            problems.append(f"{lid}: JSONが壊れている {e}"); continue
        short = lid[2:]
        ids = {}
        for g, prefix, need in GROUPS:
            arr = d.get(g) or []
            if len(arr) != need:
                problems.append(f"{lid}: {g} が {len(arr)}問（期待 {need}）")
            ids[g] = []
            for n, q in enumerate(arr, 1):
                qid = f"{prefix}-{short}-{n:02d}"
                w = f"{qid}"
                ok = (isinstance(q.get("choices"), list) and len(q["choices"]) == 4
                      and isinstance(q.get("answer"), int) and 0 <= q["answer"] < 4
                      and isinstance(q.get("wrong"), dict))
                if not ok:
                    problems.append(f"{w}: 形式不正（choices/answer/wrong）"); continue
                wk = {k for k in q["wrong"]}
                expect = {str(i) for i in range(4) if i != q["answer"]}
                if wk != expect:
                    problems.append(f"{w}: wrong のキー {sorted(wk)} ≠ {sorted(expect)}")
                    q["wrong"] = {k: v for k, v in q["wrong"].items() if k in expect}
                    for k in expect - wk:
                        q["wrong"][k] = "この選択肢は設問の条件に合いません。解説の内容と照らし合わせて確認しましょう。"
                # 4問ごとに①〜④の並べ方を1つ選ぶ＝全体で均等、かつ周期で読まれない
                perm = PERMS[stable_hash(f"{c['app']}-{seq // 4}") % 24]
                target = perm[seq % 4]
                seq += 1
                choices, ans, wrong = place_correct(q, target)
                tags = [t for t in (q.get("tags") or []) if isinstance(t, str)][:3]
                if g == "basic":
                    tags.append("基礎")
                if g == "drill":
                    tags.append("ドリル")
                bn = q.get("beginnerNote")
                questions.append({
                    "id": qid, "question": q["question"].strip(), "choices": [x.strip() for x in choices],
                    "correctAnswers": [ans], "explanation": q["explanation"].strip(),
                    "wrongChoiceExplanations": wrong, "domain": dom,
                    "service": (q.get("service") or title).strip(),
                    "difficulty": 1 if g == "basic" else max(1, min(3, int(q.get("difficulty") or 2))),
                    "tags": tags, "beginnerNote": bn if isinstance(bn, str) and bn.strip() else None,
                })
                ids[g].append(qid)
        L = d.get("lesson") or {}
        secs = [s for s in (L.get("sections") or []) if s.get("heading") and s.get("body")]
        if len(secs) < 3:
            problems.append(f"{lid}: sections が {len(secs)}個")
        lessons.append({
            "id": lid, "title": title, "domain": dom,
            "estimatedMinutes": int(L.get("estimatedMinutes") or 12),
            "summary": (L.get("summary") or "").strip(),
            "sections": [{"heading": s["heading"].strip(), "body": s["body"].strip()} for s in secs],
            "basicQuizIds": ids["basic"], "quizIds": ids["confirm"],
            "challengeQuizIds": [], "drillQuizIds": ids["drill"],
        })

    # 用語系
    def loadsrc(name):
        p = os.path.join(src, f"{name}.json")
        if not os.path.exists(p):
            missing.append(name); return []
        return json.load(open(p, encoding="utf-8"))
    terms = loadsrc("terms")
    for t in terms:
        if t.get("domain") not in valid:
            problems.append(f"term {t.get('id')}: domain不正 {t.get('domain')}")
            t["domain"] = c["domains"][0][0]
        t["difficulty"] = max(1, min(3, int(t.get("difficulty") or 1)))
        t.setdefault("relatedServices", [])
    tid = collections.Counter(t["id"] for t in terms)
    problems += [f"term id重複 {k}" for k, v in tid.items() if v > 1]
    if terms and not all(f"t-key{i}" in tid for i in range(1, 7)):
        problems.append("terms に t-key1〜6 が揃っていない")
    gl, seen = [], set()
    for g in loadsrc("glossary"):
        if g.get("term") and g["term"] not in seen and len(g["term"]) >= 2:
            seen.add(g["term"]); gl.append({"term": g["term"], "explanation": g["explanation"]})
    gl.sort(key=lambda g: -len(g["term"]))      # 長い語を先にマッチさせる
    services = loadsrc("services")
    for s in services:
        if s.get("domain") not in valid:
            problems.append(f"service {s.get('id')}: domain不正"); s["domain"] = c["domains"][0][0]

    strip_filler(questions)
    report(c, questions, lessons, terms, gl, services, problems, missing)
    if write and not missing:
        res = os.path.join(app, "Resources")
        for name, data in [("questions", questions), ("lessons", lessons), ("terms", terms),
                           ("glossary", gl), ("services", services)]:
            json.dump(data, open(os.path.join(res, f"{name}.json"), "w", encoding="utf-8"),
                      ensure_ascii=False, indent=1)
        print("Resources を書き出しました")
    elif write:
        print(f"未完成のため書き出していません（未着: {', '.join(missing)}）")


def strip_filler(qs):
    """文字数合わせの定型文（アプリ内で4回以上出る同じ一文）を取り除く。中身のある文は残す。"""
    sc = collections.Counter()
    texts = lambda q: [q["explanation"]] + list(q["wrongChoiceExplanations"].values())
    for q in qs:
        for s in texts(q):
            for sent in set(x.strip() for x in s.split("。") if len(x.strip()) >= 8):
                sc[sent] += 1
    bad = {s for s, n in sc.items() if n >= 4}
    def clean(t):
        parts = [x for x in t.split("。")]
        kept = [x for x in parts if x.strip() not in bad]
        out = "。".join(kept).strip()
        if out and not out.endswith("。") and t.endswith("。"):
            out += "。"
        return out if len(out) >= 15 else t
    n = 0
    for q in qs:
        e = clean(q["explanation"]); n += e != q["explanation"]; q["explanation"] = e
        for k, v in list(q["wrongChoiceExplanations"].items()):
            w = clean(v); n += w != v; q["wrongChoiceExplanations"][k] = w
    if n:
        print(f"  定型文を除去: {n}箇所（{len(bad)}種）")


def report(c, qs, lessons, terms, gl, services, problems, missing):
    print(f"== {c['app']}  レッスン {len(lessons)}/{len(c['lessons'])}  問題 {len(qs)}  用語 {len(terms)}  用語集 {len(gl)}  一覧 {len(services)}")
    if not qs:
        return
    pos = collections.Counter(q["correctAnswers"][0] for q in qs)
    longest = shortest = 0.0
    strict_long = 0
    for q in qs:
        L = [len(x) for x in q["choices"]]
        a = q["correctAnswers"][0]
        mx, mn = max(L), min(L)
        if L[a] == mx:
            longest += 1 / L.count(mx)
            if L.count(mx) == 1 and sorted(L)[-2] + 8 <= mx:
                strict_long += 1
        if L[a] == mn:
            shortest += 1 / L.count(mn)
    n = len(qs)
    ex = [len(q["explanation"]) for q in qs]
    print(f"  正解位置 {dict(sorted(pos.items()))}")
    print(f"  最長を選ぶだけの正答率 {longest/n*100:.1f}% / 最短 {shortest/n*100:.1f}% / 目で分かるほど長い {strict_long/n*100:.1f}%")
    print(f"  解説 60字未満 {sum(x<60 for x in ex)} / 100字未満 {sum(x<100 for x in ex)} / 平均 {sum(ex)/n:.0f}字")
    dup = [k for k, v in collections.Counter(re.sub(r'\s', '', q['question']) for q in qs).items() if v > 1]
    leak = [q["id"] for q in qs if len(q["choices"][q["correctAnswers"][0]]) >= 4
            and q["choices"][q["correctAnswers"][0]] in q["question"]]
    fig = [q["id"] for q in qs if re.search(r"(次の|下の|上の)(図|表)|下図|下表|図\d|表\d", q["question"])]
    banned = [q["id"] for q in qs if any(re.search(r"上記|すべて正しい|いずれも|どれでもない", x) for x in q["choices"])]
    print(f"  設問文の重複 {len(dup)} / 設問に正解が入っている {len(leak)} {leak[:8]} / 図表参照 {len(fig)} {fig[:5]} / 位置依存の選択肢 {len(banned)} {banned[:5]}")
    # レッスンをまたいだ似た問題（サブエージェント単位では見つけられない）
    def grams(s):
        s = re.sub(r"\s", "", s)
        return {s[i:i + 2] for i in range(len(s) - 1)}
    G = [(q["id"], grams(q["question"] + q["choices"][q["correctAnswers"][0]])) for q in qs]
    near = []
    for i in range(len(G)):
        for j in range(i + 1, len(G)):
            a, b = G[i][1], G[j][1]
            if a and b and len(a & b) / len(a | b) >= 0.6:
                near.append(f"{G[i][0]}≒{G[j][0]}")
    print(f"  よく似た問題の組 {len(near)} {near[:10]}")
    # 文字数合わせの定型文（同じ一文がアプリ内で4回以上）
    sc = collections.Counter()
    for q in qs:
        for s in [q["explanation"]] + list(q["wrongChoiceExplanations"].values()):
            for sent in set(x.strip() for x in s.split("。") if len(x.strip()) >= 8):
                sc[sent] += 1
    filler = [(s, n) for s, n in sc.most_common() if n >= 4]
    print(f"  定型文（4回以上出る一文） {len(filler)}種 {sum(n for _, n in filler)}箇所 {filler[:4]}")
    dom = collections.Counter(q["domain"] for q in qs)
    print("  分野 " + ", ".join(f"{d[0]} {dom.get(d[0],0)}" for d in c["domains"]))
    if missing:
        print(f"  未着: {', '.join(missing)}")
    for p in problems[:30]:
        print("  問題:", p)
    if len(problems) > 30:
        print(f"  …ほか {len(problems)-30}件")


if __name__ == "__main__":
    main(sys.argv[1], write="--check" not in sys.argv)

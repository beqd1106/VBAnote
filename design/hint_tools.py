"""ヒント（1段目「考え方」）を全問ぶん書き直すための道具。

  pack   : 問題を約100問ずつの束にして design/hint_pack/<exam>/<nn>.md と hint_pack/batches.json を作る
  check  : design/hints_v2/<exam>/<nn>.json を検査する（全ID・長さ・答え漏れ・禁止語）
  apply  : 合格したヒントを Resources/<exam>_hints.json（{id: hint}）に書き出す。--web で Web 版 data/ にも

ヒントは問題JSONに入れず別ファイルにする（gen_multi.py で問題を作り直しても消えないように）。
使い方: python design/hint_tools.py pack | check [exam/nn ...] | apply [--web]
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RES = ROOT.parent / "Resources"
PACK = ROOT / "hint_pack"
OUT = ROOT / "hints_v2"
WEB = Path(r"C:\Users\user\Desktop\beqd1106-web-\shikakunote\app\data")
EXAMS = ["itp", "fe", "aws", "aip", "g", "mos", "vba", "wia", "pmos", "dify"]
SIZE = 100
MIN_LEN, MAX_LEN = 15, 90
BANNED = re.compile(r"正解は|答えは|正しいのは|が正解|選択肢[0-9０-９A-DＡ-Ｄア-エ]|[①②③④]|基本を思い出")


def load_q(k):
    return json.loads((RES / f"{k}_questions.json").read_text(encoding="utf-8"))


def core(a):
    """正解選択肢から、ヒントに出てはいけない「名前の芯」を取り出す（括弧の補足・AWS/Amazon の頭を外す）"""
    a = re.sub(r"[（(][^）)]*[)）]", "", a)
    a = re.sub(r"^(AWS|Amazon)\s*", "", a).strip()
    return a


def leak_terms(q):
    """ヒントに含めてはいけない語。正解の芯（3字以上）と、括弧内の補足（3字以上）"""
    terms = set()
    for i in q["correctAnswers"]:
        c = q["choices"][i]
        cc = core(c)
        if len(cc) >= 3:
            terms.add(cc)
        for m in re.findall(r"[（(]([^）)]+)[)）]", c):
            if len(m) >= 3:
                terms.add(m)
    # 不正解にも同じ語が入っているなら、それは正解を特定しない語なので外す
    wrong = [q["choices"][i] for i in range(len(q["choices"])) if i not in q["correctAnswers"]]
    return {t for t in terms if not any(t in w for w in wrong)}


def pack():
    batches = []
    for k in EXAMS:
        qs = load_q(k)
        (PACK / k).mkdir(parents=True, exist_ok=True)
        for n in range(0, len(qs), SIZE):
            part = qs[n:n + SIZE]
            name = f"{n // SIZE:02d}"
            lines = [f"# {k} 束{name}（{len(part)}問）\n"]
            for q in part:
                lines.append(f"## {q['id']}")
                lines.append(f"問題: {q['question']}")
                for i, c in enumerate(q["choices"]):
                    mark = "【正解】" if i in q["correctAnswers"] else ""
                    lines.append(f"- {mark}{c}")
                lines.append(f"解説: {q['explanation']}")
                if q.get("beginnerNote"):
                    lines.append(f"今のヒント: {q['beginnerNote']}")
                lt = leak_terms(q)
                if lt:
                    lines.append(f"使ってはいけない語: {' / '.join(sorted(lt))}")
                lines.append("")
            (PACK / k / f"{name}.md").write_text("\n".join(lines), encoding="utf-8", newline="\n")
            batches.append(f"{k}/{name}")
    (PACK / "batches.json").write_text(json.dumps(batches, ensure_ascii=False, indent=0), encoding="utf-8")
    print(f"{len(batches)}束を作りました")


def check_one(key):
    k, name = key.split("/")
    qs = load_q(k)
    n = int(name)
    part = qs[n * SIZE:(n + 1) * SIZE]
    p = OUT / k / f"{name}.json"
    if not p.exists():
        return False, ["出力なし"]
    try:
        d = json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:  # noqa: BLE001
        return False, [f"JSONが読めない: {e}"]
    probs = []
    for q in part:
        h = (d.get(q["id"]) or "").strip()
        if not h:
            probs.append(f"{q['id']}: ヒントなし"); continue
        if not (MIN_LEN <= len(h) <= MAX_LEN):
            probs.append(f"{q['id']}: 長さ{len(h)}字（{MIN_LEN}〜{MAX_LEN}）")
        if BANNED.search(h):
            probs.append(f"{q['id']}: 禁止の言い回し「{BANNED.search(h).group(0)}」")
        for t in leak_terms(q):
            if t in h:
                probs.append(f"{q['id']}: 正解の語「{t}」が入っている")
        if "\n" in h:
            probs.append(f"{q['id']}: 改行あり")
    extra = set(d) - {q["id"] for q in part}
    if extra:
        probs.append(f"担当外のID: {sorted(extra)[:3]}")
    return not probs, probs


def check(keys):
    if not keys:
        keys = json.loads((PACK / "batches.json").read_text(encoding="utf-8"))
    ok_n = 0
    for key in keys:
        ok, probs = check_one(key)
        if ok:
            ok_n += 1
            if len(keys) <= 5:
                print(f"OK {key}")
        elif probs != ["出力なし"] or len(keys) <= 5:
            print(f"NG {key}: " + "；".join(probs[:8]) + (f" ほか{len(probs) - 8}件" if len(probs) > 8 else ""))
    print(f"合格 {ok_n}/{len(keys)}束")


def apply(web):
    keys = json.loads((PACK / "batches.json").read_text(encoding="utf-8"))
    by = {k: {} for k in EXAMS}
    for key in keys:
        ok, _ = check_one(key)
        if not ok:
            continue
        k, name = key.split("/")
        by[k].update(json.loads((OUT / k / f"{name}.json").read_text(encoding="utf-8")))
    for k, d in by.items():
        if not d:
            continue
        ids = [q["id"] for q in load_q(k)]
        d = {i: d[i].strip() for i in ids if i in d}
        (RES / f"{k}_hints.json").write_text(json.dumps(d, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
        if web:
            (WEB / f"{k}_hints.json").write_text(json.dumps(d, ensure_ascii=False, separators=(",", ":")), encoding="utf-8", newline="\n")
        print(f"{k}: {len(d)}/{len(ids)}問")


if __name__ == "__main__":
    cmd, rest = sys.argv[1], sys.argv[2:]
    if cmd == "pack":
        pack()
    elif cmd == "check":
        check(rest)
    elif cmd == "apply":
        apply("--web" in rest)

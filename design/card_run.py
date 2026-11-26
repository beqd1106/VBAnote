"""カード教材の一括作成（変換 → 機械検査 → カードだけで全問解けるか採点 → 足りなければ直す）。
  python -I design/card_run.py [並列数=3] [exam ...]
済んだもの（card_judge/<exam>/<id>.result.json が score=1.0）は飛ばすので、止まっても再実行で続きから。
進み具合は design/card_run_status.json（合否・点数・やり直し回数）。
"""
import json
import os
import shutil
import subprocess
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
D = ROOT / "design"
sys.path.insert(0, str(D))
import card_tools as T  # noqa: E402

STATUS = D / "card_run_status.json"
LOCK = threading.Lock()
MAX_FIX = 2


CALL_TIMEOUT = 900  # 1回の Codex 呼び出しの上限（秒）。止まったら木ごと殺してやり直す
RETRY = 2


def kill_tree(pid: int):
    # Windows では subprocess の timeout だと codex.CMD だけが死に、中の codex.exe が残って待ち続ける
    subprocess.run(["taskkill", "/T", "/F", "/PID", str(pid)], capture_output=True)


def codex(prompt: str, out: Path, write: bool) -> str:
    out.parent.mkdir(parents=True, exist_ok=True)
    cmd = [shutil.which("codex") or "codex", "exec", "-s", "workspace-write" if write else "read-only", "--skip-git-repo-check", "-C", str(ROOT), "-o", str(out), "-"]
    log = out.with_suffix(".log")
    for attempt in range(RETRY + 1):
        if out.exists():
            out.unlink()
        with open(log, "wb") as lf:
            p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=lf, stderr=subprocess.STDOUT)
            p.stdin.write(prompt.encode("utf-8"))
            p.stdin.close()
            try:
                p.wait(timeout=CALL_TIMEOUT)
            except subprocess.TimeoutExpired:
                kill_tree(p.pid)
                p.wait()
                print(f"TIMEOUT {out.name} try{attempt}", flush=True)
                continue
        if out.exists() and out.stat().st_size:
            return out.read_text(encoding="utf-8")
        if b"hit your usage limit" in log.read_bytes():
            # 使用量の上限：続けても全部失敗するだけなので、ここで全体を止める（再実行で続きから）
            print(f"LIMIT {out.name} - Codex の使用量上限。全体を止めます", flush=True)
            os._exit(3)
        print(f"EMPTY {out.name} try{attempt} rc={p.returncode}", flush=True)
    return ""


def set_status(key, **kw):
    with LOCK:
        s = json.loads(STATUS.read_text(encoding="utf-8")) if STATUS.exists() else {}
        s.setdefault(key, {}).update(kw)
        STATUS.write_text(json.dumps(s, ensure_ascii=False, indent=1), encoding="utf-8")


CONVERT = """ファイルの書き込みは apply_patch（UTF-8）だけで行い、PowerShell の Set-Content・Out-File・リダイレクトでは書かないこと（日本語が ?? に化ける）。
作業：design/CARD_SPEC.md を読み、その仕様どおりに design/card_pack/{exam}/{lid}.md をカード教材に変換して design/cards_v1/{exam}/{lid}.json に書き出す。
python は使えない環境なので実行しないこと。字数（body 150字以内・head 16字以内・ex 80字以内・title 14字以内）、基礎問題(b-)を全部1回ずつはさむこと（基礎問題が無いレッスンは材料の「はさむ問題」から各区切りに1〜2問）、JSONとして正しいことは自分で数えて確かめる。
ほかのファイルは編集しない（_notes.md への追記は可）。最後に区切りの数とカード枚数だけ短く報告する。"""

FIX_CHECK = """ファイルの書き込みは apply_patch（UTF-8）だけで行い、PowerShell の Set-Content・Out-File・リダイレクトでは書かないこと（日本語が ?? に化ける）。
design/cards_v1/{exam}/{lid}.json が機械検査で不合格になった。下の指摘をすべて直して同じファイルに上書きする（仕様は design/CARD_SPEC.md、元の材料は design/card_pack/{exam}/{lid}.md）。python は実行しないこと。ほかのファイルは編集しない。
指摘：
{errs}"""

FIX_JUDGE = """ファイルの書き込みは apply_patch（UTF-8）だけで行い、PowerShell の Set-Content・Out-File・リダイレクトでは書かないこと（日本語が ?? に化ける）。
design/cards_v1/{exam}/{lid}.json のカードだけを読んだ採点係が、次の問題を解けなかった（または根拠が足りないと言った）。
元の材料 design/card_pack/{exam}/{lid}.md を見て、これらの問題を「カードだけで×を外して◎を選べる」ように、足りない事実・違いをカードに足す（新しいカードを足してよい。1枚 body 150字以内は守る。問題文や答えをそのまま書かない）。仕様は design/CARD_SPEC.md。python は実行しないこと。ほかのファイルは編集しない。
解けなかった問題：
{items}"""

JUDGE = """あなたは採点係です。ファイルは読まず、下の文面だけで答えてください。
前半の「教材（カード）」に書いてあることだけを根拠に、後半のすべての問題に答えてください。自分の知識は使わないこと。根拠が無い・足りない問題も推測で答えたうえで basis を none/partial にすること。
出力はJSONだけ（コードブロック不要）：
{{"answers": {{"<問題ID>": {{"choice": [選んだ番号(1始まり)], "basis": "ok|partial|none", "missing": "none/partialのとき、足りない情報を1文で"}}}}}}

{body}"""


def parse_json(text: str):
    a, b = text.find("{"), text.rfind("}")
    return json.loads(text[a:b + 1]) if a >= 0 and b > a else None


def judge(exam, lid):
    T.judge(exam, lid)
    jd = D / "card_judge" / exam
    body = (jd / f"{lid}.md").read_text(encoding="utf-8")
    key = json.loads((jd / f"{lid}.key.json").read_text(encoding="utf-8"))
    txt = codex(JUDGE.format(body=body), jd / f"{lid}.judge_out.md", write=False)
    try:
        ans = (parse_json(txt) or {}).get("answers", {})
    except Exception:  # noqa: BLE001 - 読めなければ全問不合格として扱う
        ans = {}
    bad = []
    for qid, correct in key.items():
        a = ans.get(qid) or {}
        got = sorted(int(x) - 1 for x in a.get("choice", []) if str(x).isdigit() or isinstance(x, int))
        if got != sorted(correct) or a.get("basis") == "none":
            bad.append({"id": qid, "got": [g + 1 for g in got], "basis": a.get("basis"), "missing": a.get("missing", "")})
    score = (len(key) - len(bad)) / max(1, len(key))
    (jd / f"{lid}.result.json").write_text(json.dumps({"score": score, "n": len(key), "bad": bad}, ensure_ascii=False, indent=1), encoding="utf-8")
    return score, bad


def one(exam, lid):
    key = f"{exam}/{lid}"
    res = D / "card_judge" / exam / f"{lid}.result.json"
    if res.exists() and json.loads(res.read_text(encoding="utf-8")).get("score") == 1.0:
        return
    out = D / "cards_v1" / exam / f"{lid}.json"
    logd = D / "card_pack" / "_runs" / exam
    T.pack(exam, [lid])
    if not out.exists():
        set_status(key, stage="convert")
        codex(CONVERT.format(exam=exam, lid=lid), logd / f"{lid}.convert.md", write=True)
    for n in range(MAX_FIX + 1):
        errs, stat = T.check(key)
        if not errs:
            break
        set_status(key, stage=f"fix_check{n}", errs=errs[:10])
        if n == MAX_FIX:
            set_status(key, stage="NG_check", ok=False)
            return
        codex(FIX_CHECK.format(exam=exam, lid=lid, errs="\n".join("- " + e for e in errs)), logd / f"{lid}.fixcheck{n}.md", write=True)
    L, Q = T.load(exam)
    for n in range(MAX_FIX + 1):
        set_status(key, stage=f"judge{n}", **stat)
        score, bad = judge(exam, lid)
        set_status(key, score=round(score, 3), bad=[b["id"] for b in bad])
        if not bad:
            set_status(key, stage="OK", ok=True, fixes=n)
            return
        if n == MAX_FIX:
            set_status(key, stage="NG_judge", ok=False)
            return
        items = "\n\n".join(T.q_md(Q[b["id"]]) + f"\n採点係の答え: {b['got']}・根拠: {b['basis']}・足りない: {b['missing']}" for b in bad if b["id"] in Q)
        codex(FIX_JUDGE.format(exam=exam, lid=lid, items=items), logd / f"{lid}.fixjudge{n}.md", write=True)
        errs, stat = T.check(key)
        if errs:
            codex(FIX_CHECK.format(exam=exam, lid=lid, errs="\n".join("- " + e for e in errs)), logd / f"{lid}.fixcheck_j{n}.md", write=True)
            errs, stat = T.check(key)


def main():
    par = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    exams = sys.argv[2:] or ["fe", "itp", "aws", "aip", "g", "mos", "vba", "wia", "pmos", "dify"]
    jobs = []
    for exam in exams:
        L, _ = T.load(exam)
        jobs += [(exam, lid) for lid in L]
    print("jobs", len(jobs), flush=True)
    with ThreadPoolExecutor(par) as ex:
        for f in [ex.submit(one, e, l) for e, l in jobs]:
            try:
                f.result()
            except Exception as e:  # noqa: BLE001 - 1本の失敗で全体を止めない
                print("ERR", e, flush=True)
    s = json.loads(STATUS.read_text(encoding="utf-8")) if STATUS.exists() else {}
    ok = sum(1 for v in s.values() if v.get("ok"))
    print(f"done OK {ok}/{len(jobs)}", flush=True)


if __name__ == "__main__":
    main()

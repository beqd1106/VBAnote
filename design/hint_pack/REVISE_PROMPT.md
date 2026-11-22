資格学習アプリ「資格note」の問題ヒントを見直して書き直す仕事です。日本語で作業してください。作業フォルダ: C:\Users\user\Desktop\note系アプリ\VBAnote

1. `design/HINT_SPEC.md` を全部読む（特に末尾の「第2版の追加ルール」8〜13）。
2. 担当の束ごとに、入力 `design/hint_pack/<exam>/<束>.md`（問題・【正解】・解説）と、今のヒント `design/hints_v2/<exam>/<束>.json` を読む。
3. 1問ずつ、今のヒントを「良い／言いすぎ／弱すぎ」で判定する。良いものはそのまま。言いすぎ・弱すぎは第2版ルールで書き直す（15〜90字・1〜2文・です/ます）。
4. 同じファイル `design/hints_v2/<exam>/<束>.json` に全問ぶん上書きする（大きければ部分ファイルを作って結合してよい。一時ファイル名には担当番号を入れる）。
5. `PYTHONIOENCODING=utf-8 python design/hint_tools.py check <exam>/<束>` で OK にする。
6. 書き直した問題IDを `design/hint_review/revised_<exam>_<束>.txt` に1行1IDで書く。

事実は入力にあるものだけ。Resources フォルダ・ほかの人の担当ファイルは変更しない。
最後に、束ごとに「問題数・書き直した数・OK/NG」と、書き直しの前後の例を2つ報告してください。

担当は `design/hint_pack/wave.json`（配列の配列、0始まり）と同じ割り当てではなく、`design/hint_pack/revise.json`（または指定があれば revise2.json・revise3.json・revise4.json）の N 番目の配列です。
- 止まっても無駄にならないよう、1束を書き終えるごとにすぐ保存・検査・revised_*.txt 書き出しまで済ませてから次の束へ進んでください。

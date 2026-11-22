#!/bin/bash
# 4本ずつ Codex で読み合わせ。済んだもの（out_*.md が空でない）は飛ばす
cd "$(dirname "$0")"
mapfile -t J < jobs.txt
i=0
for j in "${J[@]}"; do
  [ -s "out_$j.md" ] && continue
  codex exec -s read-only --skip-git-repo-check -o "out_$j.md" - < "req_$j.md" > "log_$j.txt" 2>&1 &
  i=$((i+1))
  if (( i % 4 == 0 )); then wait; fi
done
wait
echo "done $(ls out_*.md 2>/dev/null | wc -l)/${#J[@]}"

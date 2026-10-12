#!/bin/sh
# 使い方: sh design/rename_app.sh 旧名 新名   （例: Gnote FEnote）
OLD=$1; NEW=$2
old_l=$(echo "$OLD" | tr 'A-Z' 'a-z'); new_l=$(echo "$NEW" | tr 'A-Z' 'a-z')
[ -f "App/${OLD}App.swift" ] && mv "App/${OLD}App.swift" "App/${NEW}App.swift"
for f in project.yml codemagic.yaml .github/workflows/*.yml App/${NEW}App.swift Tests/LogicTests.swift; do
  sed -i -e "s/${OLD}/${NEW}/g" -e "s/${old_l}/${new_l}/g" -e "s/__APP__/${NEW}/g" "$f"
done

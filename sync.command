#!/bin/bash
cd "$(dirname "$0")"
find ~/Downloads -name "*.md" -newer '.last_sync' -exec cp {} . \;
if [ -n "$(git status --porcelain)" ]; then
    git add .
    git commit -m "Автосинхронизация $(date '+%Y-%m-%d %H:%M')"
    git push
    touch .last_sync
    echo "✅ Файлы синхронизированы"
else
    echo "📭 Новых файлов нет"
fi

#!/bin/bash
cd /Users/sergeypodvolotsky/Documents/BerrimorDialogs

# Проверяем, есть ли изменения
if [[ -n $(git status --porcelain) ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Изменения найдены" >> scripts/auto-git.log
    git add .
    git commit -m "Авто-сохранение $(date '+%Y-%m-%d %H:%M')"
    git push
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Отправлено на GitHub" >> scripts/auto-git.log
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Нет изменений" >> scripts/auto-git.log
fi

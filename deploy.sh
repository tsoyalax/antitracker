#!/usr/bin/env bash
# Двухшаговый деплой: сначала preview, потом push в main после утверждения.
#
#   ./deploy.sh preview [файл.html]  — (опц.) взять новую версию страницы, закоммитить
#                                      в ветку preview и открыть локальный предпросмотр
#   ./deploy.sh approve              — показать изменения, спросить подтверждение
#                                      и влить preview в main + git push (GitHub Pages)
#   ./deploy.sh discard              — отменить preview, вернуться на main
set -euo pipefail
cd "$(dirname "$0")"

PORT="${PORT:-8765}"
SITE="https://tsoyalax.github.io/antitracker/"

preview() {
  git fetch -q origin main
  if git show-ref -q --verify refs/heads/preview; then
    git checkout -q preview
  else
    git checkout -q -b preview origin/main
  fi
  if [ -n "${1:-}" ]; then cp "$1" index.html; fi
  if ! git diff --quiet -- index.html; then
    git add index.html
    git commit -q -m "Preview: $(date '+%Y-%m-%d %H:%M')"
  fi
  echo "Изменения относительно main:"
  git diff --stat origin/main..preview || true
  echo
  echo "Предпросмотр: http://localhost:$PORT/  (Ctrl+C — остановить)"
  echo "Если всё ок:   ./deploy.sh approve"
  (sleep 1 && open "http://localhost:$PORT/" 2>/dev/null) &
  python3 -m http.server "$PORT" --bind 127.0.0.1
}

approve() {
  git show-ref -q --verify refs/heads/preview || { echo "Нет ветки preview. Сначала ./deploy.sh preview"; exit 1; }
  git fetch -q origin main
  if [ -z "$(git log --oneline origin/main..preview)" ]; then
    echo "В preview нет новых изменений."; exit 0
  fi
  echo "Будет отправлено в main:"
  git log --oneline origin/main..preview
  git diff --stat origin/main..preview
  read -r -p "Утвердить и запушить в main? [y/N] " ans
  [[ "$ans" =~ ^[YyДд]$ ]] || { echo "Отменено. Ничего не отправлено."; exit 0; }
  git checkout -q main
  git merge -q --ff-only origin/main
  git merge -q --no-ff preview -m "Deploy: $(date '+%Y-%m-%d %H:%M')"
  git push -q origin main
  git branch -q -D preview
  echo "Готово. Сайт обновится через ~1 мин: $SITE"
}

discard() {
  git checkout -q main
  git branch -D preview 2>/dev/null && echo "Preview отменён." || echo "Ветки preview нет."
}

case "${1:-}" in
  preview) shift; preview "$@" ;;
  approve) approve ;;
  discard) discard ;;
  *) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac

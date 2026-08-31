#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

sha="$(git rev-parse --short HEAD)"
sed -i "s/__APP_VERSION__/${sha}/g" index.html

if ! git diff --quiet index.html; then
  git add index.html
  git commit -m "chore: app version -> ${sha}" >/dev/null
  git push origin main >/dev/null
fi

npx vercel --prod --yes

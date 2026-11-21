#!/usr/bin/env bash
# بيلد نسخة الويب (برانش web بس). الناتج في build/web
# الاستخدام: tool/build_web.sh [base-href]   مثال: tool/build_web.sh /bdgr-link/app/
set -euo pipefail
cd "$(dirname "$0")/.."
BASE="${1:-/}"
# مفاتيح عامة (anon/publishable) — مش أسرار، بتبقى جوه أي تطبيق موبايل أو ويب
SUPABASE_URL="${SUPABASE_URL:-https://xjorftvsuztxapdnceao.supabase.co}"
SUPABASE_KEY="${SUPABASE_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhqb3JmdHZzdXp0eGFwZG5jZWFvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk4OTk1MjcsImV4cCI6MjA5NTQ3NTUyN30.xY8alB0SRsA9sHWa1ipMx_h1hIjZDcF7cRQp0T6xpgQ}"
EXTRA=()
# LOCAL_RES=1: CanvasKit من نفس الموقع بدل CDN جوجل (للتجربة من غير نت)
[ "${LOCAL_RES:-0}" = 1 ] && EXTRA+=(--no-web-resources-cdn)
flutter build web --release "${EXTRA[@]}" --no-wasm-dry-run --pwa-strategy=none --base-href="$BASE" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_KEY="$SUPABASE_KEY" \
  --dart-define=APP_ID=com.bdgr.web \
  --dart-define=APP_NAME=BDGR \
  --dart-define=DEV_MODE=true

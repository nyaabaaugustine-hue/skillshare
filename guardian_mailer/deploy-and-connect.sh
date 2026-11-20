#!/usr/bin/env bash
# Deploy the tutor Worker and connect it to the website in one step.
#
# Run this AFTER authenticating wrangler. OAuth login is blocked while a
# CF_API_TOKEN / CF_ACCOUNT_ID pair is present in guardian_mailer/.env, and the
# token currently in that file has no Workers permissions — see README.
#
#   cd guardian_mailer && bash deploy-and-connect.sh
#
# It prints no secret values: the Neon Auth base URL is read from
# website/.env.local and piped straight into `wrangler secret put`.
set -euo pipefail
cd "$(dirname "$0")"

if [ -f .env ] && grep -q '^CF_API_TOKEN=' .env; then
  echo "!! guardian_mailer/.env defines CF_API_TOKEN, which shadows OAuth login."
  echo "   Comment those two lines out (CF_API_TOKEN, CF_ACCOUNT_ID) and run"
  echo "   'npx wrangler login', then run this script again."
  exit 1
fi

echo "== deploying skillbridge-tutor =="
output=$(npx wrangler deploy 2>&1 | tee /dev/stderr)
worker_url=$(printf '%s' "$output" | grep -oE 'https://[A-Za-z0-9._-]+\.workers\.dev' | head -1 || true)

if [ -z "$worker_url" ]; then
  echo "!! Deployed, but the workers.dev URL was not printed (custom domain only?)."
  echo "   Copy the URL from the Cloudflare dashboard and set TUTOR_WORKER_URL by hand."
  exit 1
fi
echo "== worker: $worker_url =="

echo "== setting NEON_AUTH_BASE_URL on the Worker =="
auth_base=$(grep -m1 '^NEON_AUTH_BASE_URL=' ../website/.env.local | cut -d= -f2- | tr -d '\r' || true)
if [ -z "$auth_base" ]; then
  echo "!! NEON_AUTH_BASE_URL missing from website/.env.local; set it with:"
  echo "   npx wrangler secret put NEON_AUTH_BASE_URL"
else
  printf '%s' "$auth_base" | npx wrangler secret put NEON_AUTH_BASE_URL >/dev/null
  echo "   set (value not printed)"
fi

echo "== health =="
curl -s --max-time 30 "$worker_url/health" || true
echo

echo "== wiring the website =="
if grep -q '^TUTOR_WORKER_URL=' ../website/.env.local 2>/dev/null; then
  python - "$worker_url" <<'PY'
import io, re, sys
path = '../website/.env.local'
value = sys.argv[1]
text = io.open(path, encoding='utf-8').read()
text = re.sub(r'^TUTOR_WORKER_URL=.*$', f'TUTOR_WORKER_URL={value}', text, flags=re.M)
io.open(path, 'w', encoding='utf-8').write(text)
print('   TUTOR_WORKER_URL updated in website/.env.local')
PY
else
  printf '\n# Cloudflare Worker that hosts the AI tutor.\nTUTOR_WORKER_URL=%s\n' "$worker_url" >> ../website/.env.local
  echo "   TUTOR_WORKER_URL appended to website/.env.local"
fi

echo
echo "Restart the website (npm run dev) and check:"
echo "  curl -s -X POST -H 'content-type: application/json' \\"
echo "       -d '{\"message\":\"hi\"}' http://localhost:3001/api/tutor/v1/tutor/chat"
echo "Expect 401 without a learner token — that means the proxy reached the Worker."

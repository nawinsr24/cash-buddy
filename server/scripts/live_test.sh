#!/bin/sh
# Starts the server on this machine with a throwaway database and runs the
# app's blocking code against it.
set -e
cd "$(dirname "$0")/.."
export PATH="$HOME/.nvm/versions/node/v22.23.5/bin:$PATH"
[ -f .dev.vars ] || node scripts/keys.js >/dev/null
STATE=$(mktemp -d)
PORT=8799
npx wrangler d1 execute cash-buddy --local --persist-to "$STATE" --file schema.sql >/dev/null 2>&1
npx wrangler dev --local --port $PORT --persist-to "$STATE" >"$STATE/server.log" 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null; rm -rf "$STATE"' EXIT
i=0
until curl -s -o /dev/null "http://localhost:$PORT/"; do
  i=$((i + 1)); [ $i -lt 60 ] || { tail -20 "$STATE/server.log"; exit 1; }
  sleep 1
done
LIVE_URL="http://localhost:$PORT" \
LIVE_KEY=$(sed -n 's/^PUBLIC_KEY="\(.*\)"/\1/p' .dev.vars) \
LIVE_TOKEN=$(sed -n 's/^ADMIN_TOKEN="\(.*\)"/\1/p' .dev.vars) \
  sh -c 'cd .. && flutter test test/data/access_live_test.dart'

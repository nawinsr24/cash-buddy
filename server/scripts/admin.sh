#!/bin/sh
# Usage: scripts/admin.sh devices | block <id or email> | unblock <id or email>
# SERVER defaults to the local one; the token is read from .dev.vars.
set -e
cd "$(dirname "$0")/.."
SERVER=${SERVER:-http://localhost:8787}
TOKEN=${ADMIN_TOKEN:-$(sed -n 's/^ADMIN_TOKEN="\(.*\)"/\1/p' .dev.vars)}
# The header goes through stdin so the token never shows in the process list.
call() { printf 'header = "authorization: Bearer %s"\n' "$TOKEN" | curl -sS -K - "$@"; echo; }
case "$1" in
  devices) call "$SERVER/admin/devices" ;;
  block|unblock)
    case "$2" in *@*) key=email ;; *) key=device ;; esac
    call -X POST -G --data-urlencode "$key=$2" "$SERVER/admin/$1" ;;
  *) echo "usage: $0 devices | block <id> | unblock <id>" >&2; exit 1 ;;
esac

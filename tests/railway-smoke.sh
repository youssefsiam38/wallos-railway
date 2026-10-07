#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016,SC2119
# Live end-to-end test against a deployed template, over HTTPS.
#
#   APP_URL=https://<domain> WALLOS_ADMIN_USERNAME=<ADMIN_USERNAME> WALLOS_ADMIN_PASSWORD_FILE=<file holding ADMIN_PASSWORD> \
#     STATE_FILE=/tmp/wallos-live.name tests/railway-smoke.sh       # full run; records the name of what it created
#   ... tests/railway-smoke.sh --verify                             # after a redeploy: is it all still there?
#
# Never prints the password or cookies.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
[ -n "${APP_URL:-}" ] || { echo "set APP_URL=https://<your-domain>" >&2; exit 2; }
[ -n "${WALLOS_ADMIN_PASSWORD_FILE:-}" ] && WALLOS_ADMIN_PASSWORD=$(cat "$WALLOS_ADMIN_PASSWORD_FILE")
[ -n "${WALLOS_ADMIN_PASSWORD:-}" ] || { echo "set WALLOS_ADMIN_PASSWORD_FILE" >&2; exit 2; }
APP_URL=${APP_URL%/}
: "${STATE_FILE:=$(mktemp)}"
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'rm -rf "$TEST_TMP"' EXIT

ADMIN=$TEST_TMP/admin.jar
MODE=${1:-full}

section "edge"
assert_eq "HTTPS health check" "200" "$(http_code "$APP_URL/health.php")"
assert_eq "HTTPS login page" "200" "$(http_code "$APP_URL/login.php")"
case "$APP_URL" in
  https://*) assert_eq "plain HTTP is redirected to HTTPS" "301" "$(http_code "http://${APP_URL#https://}/")" ;;
esac

section "security gates"
security_gates

section "admin"
if login "$WALLOS_ADMIN_USERNAME" "$WALLOS_ADMIN_PASSWORD" "$ADMIN"; then pass "admin signs in over HTTPS"; else fail "admin login: HTTP $CODE"; fi
admin_checks "$ADMIN"

if [ "$MODE" = "--verify" ]; then
  NAME=$(cat "$STATE_FILE")
  [ -n "$NAME" ] || die "no subscription name in $STATE_FILE"
  section "data survived"
  verify_subscription "$ADMIN" "$NAME"
else
  section "subscriptions"
  NAME="Live Test $(rand)"
  add_subscription "$ADMIN" "$NAME"
  printf '%s\n' "$NAME" >"$STATE_FILE"
  verify_subscription "$ADMIN" "$NAME"
fi

section "logout"
req "$ADMIN" GET /logout.php
req "$ADMIN" GET /subscriptions.php
assert_contains "the session is cleared" "login.php" "$LOCATION"

summary

#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016,SC2119
# Local end-to-end smoke test against a fresh compose stack (the image must already be built).
# Covers: admin bootstrap from env before the port opens, closed registration, auth gates, admin login, adding a
# subscription with a logo upload, one-volume layout, cron, and that the bootstrap does not run twice.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"

ADMIN=$TEST_TMP/admin.jar
cleanup() { [ "${KEEP_STACK:-0}" = 1 ] || compose down -v --remove-orphans >/dev/null 2>&1 || true; rm -rf "$TEST_TMP"; }
trap cleanup EXIT

section "fail closed"
img=$(compose config --format json | jq -r .services.wallos.image)
out=$(docker run --rm -e ADMIN_EMAIL= -e ADMIN_PASSWORD= "$img" 2>&1 || true)
assert_contains "without ADMIN_EMAIL/ADMIN_PASSWORD a fresh install refuses to start" "refusing to start with Wallos's open first-run" "$out"
assert_not_contains "...and never starts nginx" "Launching nginx" "$out"

section "start-up"
compose down -v --remove-orphans >/dev/null 2>&1 || true
compose up -d >/dev/null 2>&1 || die "compose up failed"
wait_for_app || { compose logs --tail 80 >&2; die "Wallos never became reachable"; }
pass "health.php answers 200"
logs=$(compose logs --no-color wallos 2>&1)
assert_contains "the admin account was created before the port opened" "admin account created (email $WALLOS_ADMIN_EMAIL)" "$logs"
assert_not_contains "the admin password never reaches the logs" "$WALLOS_ADMIN_PASSWORD" "$logs"
bootstrap_line=$(grep -n 'admin account created' <<<"$logs" | head -1 | cut -d: -f1)
nginx_line=$(grep -n 'Launching nginx' <<<"$logs" | head -1 | cut -d: -f1)
[ -n "$bootstrap_line" ] && [ -n "$nginx_line" ] && [ "$bootstrap_line" -lt "$nginx_line" ] \
  && pass "nginx starts only after the bootstrap" || fail "nginx started before the bootstrap finished"

section "container"
in_c() { compose exec -T wallos sh -c "$1" | tr -d '\r'; }
assert_eq "the database lives on the volume" "/data/db" "$(in_c 'readlink /var/www/html/db')"
assert_eq "uploaded logos live on the volume" "/data/logos" "$(in_c 'readlink /var/www/html/images/uploads/logos')"
assert_eq "the SQLite file exists on the volume" "yes" "$(in_c 'test -s /data/db/wallos.db && echo yes')"
assert_eq "exactly one account exists" "1" "$(in_c "php -r '\$d=new SQLite3(\"/data/db/wallos.db\"); echo \$d->querySingle(\"select count(*) from user\");'")"
assert_eq "registrations are closed in the admin settings" "0" "$(in_c "php -r '\$d=new SQLite3(\"/data/db/wallos.db\"); echo \$d->querySingle(\"select registrations_open from admin\");'")"
assert_eq "the bootstrap server is gone" "000" "$(in_c 'curl -s -o /dev/null -w %{http_code} --max-time 3 http://127.0.0.1:8079/health.php || true')"
assert_eq "cron is running" "yes" "$(in_c 'pgrep -x crond >/dev/null && echo yes')"
assert_contains "cron has Wallos's jobs" "updatenextpayment.php" "$(in_c 'cat /etc/cron.d/cronjobs')"

section "security gates"
security_gates

section "admin"
if login "$WALLOS_ADMIN_USERNAME" "$WALLOS_ADMIN_PASSWORD" "$ADMIN"; then pass "admin signs in"; else fail "admin login: HTTP $CODE"; fi
admin_checks "$ADMIN"

section "subscriptions"
NAME="Railway Test $(rand)"
add_subscription "$ADMIN" "$NAME"
verify_subscription "$ADMIN" "$NAME"
assert_eq "the logo file is on the volume" "1" "$(in_c "ls /data/logos/*-${NAME// /-}.png | wc -l")"

section "restart"
compose restart wallos >/dev/null 2>&1 || die "restart failed"
sleep 2
wait_for_app || die "Wallos never came back"
logs=$(compose logs --no-color wallos 2>&1 | tail -n 60)
assert_contains "the bootstrap does not run again" "accounts exist (1); admin bootstrap skipped" "$logs"
if login "$WALLOS_ADMIN_USERNAME" "$WALLOS_ADMIN_PASSWORD" "$ADMIN"; then pass "admin signs in after a restart"; else fail "admin login after restart: HTTP $CODE"; fi
verify_subscription "$ADMIN" "$NAME"

section "logout"
req "$ADMIN" GET /logout.php
req "$ADMIN" GET /subscriptions.php
assert_contains "the session is cleared" "login.php" "$LOCATION"

summary

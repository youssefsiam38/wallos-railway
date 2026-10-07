#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2119
# Persistence: a subscription and its uploaded logo written before `compose down` (volume kept) are still there
# after `compose up` on a NEW container, the admin can still sign in, and the bootstrap does not run again.
# Mirrors a Railway redeploy.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"

ADMIN=$TEST_TMP/admin.jar
cleanup() { [ "${KEEP_STACK:-0}" = 1 ] || compose down -v --remove-orphans >/dev/null 2>&1 || true; rm -rf "$TEST_TMP"; }
trap cleanup EXIT

section "write"
compose down -v --remove-orphans >/dev/null 2>&1 || true
compose up -d >/dev/null 2>&1 || die "compose up failed"
wait_for_app || die "Wallos never became reachable"
login "$WALLOS_ADMIN_USERNAME" "$WALLOS_ADMIN_PASSWORD" "$ADMIN" || die "admin login failed: HTTP $CODE"
NAME="Persist Test $(rand)"
add_subscription "$ADMIN" "$NAME"

section "new container, same volume"
compose down >/dev/null 2>&1
compose up -d >/dev/null 2>&1 || die "compose up failed"
wait_for_app || die "Wallos never came back"
pass "the container was recreated"
logs=$(compose logs --no-color wallos 2>&1)
assert_contains "the bootstrap is skipped on an existing database" "accounts exist (1); admin bootstrap skipped" "$logs"

section "verify"
if login "$WALLOS_ADMIN_USERNAME" "$WALLOS_ADMIN_PASSWORD" "$ADMIN"; then pass "admin still signs in"; else fail "admin login: HTTP $CODE"; fi
verify_subscription "$ADMIN" "$NAME"
security_gates

summary

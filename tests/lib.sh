#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2034,SC2120
# Shared helpers for wallos-railway tests. Source this file; do not execute it.
# Secrets are never echoed. Only names, counts, and pass/fail results are printed.

: "${APP_URL:=http://127.0.0.1:${WALLOS_TEST_PORT:-18282}}"
: "${TEST_TIMEOUT:=300}"
# Do not inherit a generic ADMIN_USERNAME/ADMIN_PASSWORD from the caller's shell; tests use their own names.
: "${WALLOS_ADMIN_USERNAME:=${WALLOS_TEST_ADMIN_USERNAME:-admin}}"
: "${WALLOS_ADMIN_EMAIL:=${WALLOS_TEST_ADMIN_EMAIL:-admin@example.com}}"
: "${WALLOS_ADMIN_PASSWORD:=${WALLOS_TEST_ADMIN_PASSWORD:-local-test-only-admin-password}}"

TEST_TMP="${TEST_TMP:-$(mktemp -d)}"
chmod 700 "$TEST_TMP"
export TEST_TMP
_PASS=0; _FAIL=0
CODE=""; BODY=""; LOCATION=""

pass() { _PASS=$((_PASS+1)); printf '  PASS  %s\n' "$*"; }
fail() { _FAIL=$((_FAIL+1)); printf '  FAIL  %s\n' "$*" >&2; }
die()  { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
section() { printf '\n== %s ==\n' "$*"; }
summary() { printf '\n%d passed, %d failed\n' "$_PASS" "$_FAIL"; [ "$_FAIL" -eq 0 ]; }

assert_eq() { if [ "$2" = "$3" ]; then pass "$1 ($3)"; else fail "$1: expected [$2] got [$3]"; fi; }
assert_contains() { if grep -q -- "$2" <<<"$3"; then pass "$1"; else fail "$1: missing [$2]"; fi; }
assert_not_contains() { if grep -qF -- "$2" <<<"$3"; then fail "$1: found forbidden value"; else pass "$1"; fi; }

http_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$@" || true; }

wait_for_code() {
  local url=$1 want=$2 timeout=${3:-$TEST_TIMEOUT} start code
  start=$(date +%s)
  while :; do
    code=$(http_code "$url")
    [ "$code" = "$want" ] && return 0
    if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then printf 'timed out waiting for %s -> %s (last %s)\n' "$url" "$want" "$code" >&2; return 1; fi
    sleep 3
  done
}

wait_for_app() { wait_for_code "$APP_URL/healthz/" 200 "${1:-$TEST_TIMEOUT}"; }

compose() { docker compose -f "$REPO_ROOT/compose.yaml" "$@"; }

rand() { head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n'; }

# req JAR METHOD PATH [curl args...] -> sets CODE, BODY, LOCATION. JAR may be "" (anonymous). Never follows redirects.
req() {
  local jar=$1 method=$2 path=$3 out
  shift 3
  local args=(-s -o "$TEST_TMP/body" -w '%{http_code} %{redirect_url}' --max-time 60 -X "$method" -H "Referer: $APP_URL/")
  [ -n "$jar" ] && args+=(-b "$jar" -c "$jar")
  out=$(curl "${args[@]}" "$@" "$APP_URL$path" || echo "000 ")
  CODE=${out%% *}; LOCATION=${out#* }
  BODY=$(tr -d '\000' <"$TEST_TMP/body" 2>/dev/null || true)
}

# login USERNAME PASSWORD JAR -> 0 when Wallos redirects to the app (form body from a private file, never argv).
login() {
  rm -f "$3"
  ( umask 077; printf 'username=%s&password=%s' "$(urlenc "$1")" "$(urlenc "$2")" >"$TEST_TMP/login.form" )
  req "$3" POST /login.php -H 'Content-Type: application/x-www-form-urlencoded' --data-binary "@$TEST_TMP/login.form"
  rm -f "$TEST_TMP/login.form"
  [ "$CODE" = "302" ] && [ "${LOCATION%/}" = "$APP_URL" ]
}

urlenc() { jq -rn --arg v "$1" '$v|@uri'; }

# csrf JAR -> prints the CSRF token of the signed-in session (from the subscriptions page).
csrf() {
  req "$1" GET /subscriptions.php
  grep -o 'csrfToken = "[^"]*"' <<<"$BODY" | head -1 | cut -d'"' -f2
}

# add_subscription JAR NAME -> adds a monthly USD subscription with a logo upload, asserting the response.
add_subscription() {
  local jar=$1 name=$2 token today
  token=$(csrf "$jar"); today=$(date -u +%F)
  [ -n "$token" ] && pass "CSRF token issued to the signed-in session" || fail "no CSRF token on the subscriptions page"
  req "$jar" POST /endpoints/subscription/add.php -F "csrf_token=$token" -F "name=$name" -F price=12.34 \
    -F currency_id=2 -F frequency=1 -F cycle=3 -F "next_payment=$today" -F "start_date=$today" \
    -F payment_method_id=2 -F payer_user_id=1 -F category_id=2 -F notes=railway-template-test \
    -F url=https://example.com -F logo-url= -F replacement_subscription_id=0 -F notify_days_before=-1 \
    -F "logo=@$REPO_ROOT/tests/fixtures/logo.png;type=image/png"
  assert_eq "add a subscription with a logo upload" "Success" "$(jq -r .status <<<"$BODY" 2>/dev/null)"
  assert_eq "the logo was accepted" "null" "$(jq -r .logo_warning <<<"$BODY" 2>/dev/null)"
}

# verify_subscription JAR NAME -> the subscription is listed with its price and its uploaded logo is served.
verify_subscription() {
  local jar=$1 name=$2 slug logo
  req "$jar" GET /subscriptions.php
  assert_eq "subscriptions page" "200" "$CODE"
  assert_contains "subscription '$name' is listed" "$name" "$BODY"
  assert_contains "its price is shown" '12\.34' "$BODY"
  slug=${name// /-}
  logo=$(grep -o "images/uploads/logos/[0-9]*-${slug}\.png" <<<"$BODY" | head -1)
  [ -n "$logo" ] && pass "the uploaded logo is referenced" || { fail "no uploaded logo for '$name'"; return; }
  req "" GET "/$logo"
  assert_eq "the uploaded logo is served" "200" "$CODE"
  assert_eq "the logo is a PNG" "PNG" "$(head -c 4 "$TEST_TMP/body" | tail -c 3)"
}

# security_gates -> anonymous access is refused, registration is closed, wrong passwords are rejected.
security_gates() {
  local intruder
  req "" GET /registration.php
  assert_eq "the registration page redirects away" "302" "$CODE"
  assert_contains "...to the login page" "login.php" "$LOCATION"
  intruder="intruder$(rand)"
  ( umask 077; printf 'username=%s&firstname=x&lastname=x&email=%s%%40example.com&password=intruder-pass-123&confirm_password=intruder-pass-123&main_currency=USD&language=en' \
      "$intruder" "$intruder" >"$TEST_TMP/reg.form" )
  req "" POST /registration.php -H 'Content-Type: application/x-www-form-urlencoded' --data-binary "@$TEST_TMP/reg.form"
  assert_contains "a registration POST is refused (redirect to login)" "login.php" "$LOCATION"
  assert_not_contains "...without creating an account" "registered=true" "$LOCATION"
  if login "$intruder" "intruder-pass-123" "$TEST_TMP/intruder.jar"; then
    fail "the would-be intruder can sign in"
  else
    pass "the would-be intruder cannot sign in"
  fi
  if login "$WALLOS_ADMIN_USERNAME" "not-the-password" "$TEST_TMP/wrong.jar"; then
    fail "a wrong admin password is accepted"
  else
    pass "a wrong admin password is rejected"
  fi
  req "" GET /subscriptions.php
  assert_contains "anonymous pages redirect to login" "login.php" "$LOCATION"
  req "" POST /endpoints/subscription/add.php --data name=x
  assert_contains "anonymous writes are refused" '"success":false' "$BODY"
  assert_eq "the SQLite database is not downloadable" "403" "$(http_code "$APP_URL/db/wallos.db")"
  assert_eq "the restore setup token is not downloadable" "403" "$(http_code "$APP_URL/db/setup_token.db")"
}

# admin_checks JAR -> the bootstrap account is Wallos's admin (user 1) and registrations are switched off.
admin_checks() {
  req "$1" GET /admin.php
  assert_eq "the admin page opens for the bootstrap account" "200" "$CODE"
  assert_contains "the 'enable user registrations' setting is off" 'id="registrations" */>' "$BODY"
}

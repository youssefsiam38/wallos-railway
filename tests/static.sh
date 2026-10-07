#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016,SC2119
# Static validation: syntax, shellcheck, compose shape, image pin and security defaults. No Docker build.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
cd "$REPO_ROOT"
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'rm -rf "$TEST_TMP"' EXIT

ST=images/wallos/railway-start.sh
DF=images/wallos/Dockerfile

section "syntax"
for f in tests/*.sh; do
  if bash -n "$f" 2>/dev/null; then pass "parses: $f"; else fail "syntax error: $f"; fi
done
if sh -n "$ST"; then pass "parses: $ST (POSIX sh)"; else fail "syntax error: $ST"; fi

section "shellcheck"
if command -v shellcheck >/dev/null; then
  if shellcheck -x -s bash tests/*.sh; then pass "shellcheck bash"; else fail "shellcheck bash"; fi
  if shellcheck -s sh "$ST"; then pass "shellcheck sh"; else fail "shellcheck sh"; fi
else
  echo "  SKIP  shellcheck not installed"
fi

section "compose"
if docker compose -f compose.yaml config -q; then pass "compose config"; else fail "compose config"; fi
cfg=$(docker compose -f compose.yaml config --format json)
assert_eq "one service" "wallos" "$(jq -r '[.services | keys[]] | join(" ")' <<<"$cfg")"
assert_eq "the port binds to loopback" "127.0.0.1" "$(jq -r '[.services.wallos.ports[]? | .host_ip] | join(" ")' <<<"$cfg")"
assert_eq "the published port is \$PORT (nginx :80)" "80" "$(jq -r '[.services.wallos.ports[]? | .target] | join(" ")' <<<"$cfg")"
assert_eq "PORT is 80" "80" "$(jq -r '.services.wallos.environment.PORT' <<<"$cfg")"
assert_eq "one volume, at /data" "/data" "$(jq -r '[.services.wallos.volumes[]? | .target] | join(" ")' <<<"$cfg")"
assert_contains "the compose admin password is a placeholder" 'local-test-only' "$(jq -r '.services.wallos.environment.ADMIN_PASSWORD' <<<"$cfg")"

section "image"
assert_contains "upstream pinned by tag and digest" '^ARG WALLOS_IMAGE=bellamy/wallos:[0-9.]*@sha256:[0-9a-f]\{64\}$' "$(grep '^ARG WALLOS_IMAGE=' "$DF")"
assert_contains "the database path links to the volume" 'ln -s /data/db /var/www/html/db' "$(cat "$DF")"
assert_contains "the logo path links to the volume" 'ln -s /data/logos /var/www/html/images/uploads/logos' "$(cat "$DF")"
assert_contains "upstream's dumb-init entrypoint is kept (CMD only)" '^CMD \["/opt/wallos-railway/railway-start.sh"\]' "$(cat "$DF")"
assert_contains "a dot-free health-check path exists (Railway rejects dots)" "/var/www/html/healthz/index.php" "$(cat "$DF")"
assert_not_contains "no ENTRYPOINT override" 'ENTRYPOINT' "$(grep -v '^#' "$DF")"

section "admin bootstrap"
assert_contains "the bootstrap server binds loopback only" 'php -S "127.0.0.1:${BOOTSTRAP_PORT}"' "$(cat "$ST")"
assert_contains "the bootstrap only runs on an empty user table" 'SELECT COUNT(\*) FROM user' "$(cat "$ST")"
assert_contains "the form body is sent from a file" '--data-binary "@$tmp/body"' "$(cat "$ST")"
assert_contains "the body file is private" 'umask 077' "$(cat "$ST")"
assert_contains "the umask is restored before the app starts" 'umask "$old_umask"' "$(cat "$ST")"
assert_contains "a fresh install without admin vars refuses to start" 'refusing to start' "$(cat "$ST")"
assert_contains "upstream startup.sh is exec'd last" '^exec "$WEBROOT/startup.sh"$' "$(cat "$ST")"
assert_not_contains "the password is never logged" 'log "$pw' "$(cat "$ST")"
assert_not_contains "the password is never on argv" '$ADMIN_PASSWORD"' "$(grep -v 'getenv' "$ST")"

section "secrets hygiene"
mapfile -t tracked < <(git ls-files 2>/dev/null | grep . || find . -type f -not -path './.git/*' -not -path './test-output/*')
if [ "${#tracked[@]}" -gt 0 ] && grep -lE '(sk-ant-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{32,}|ghp_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' "${tracked[@]}" 2>/dev/null; then
  fail "a credential-shaped string is in the repository"
else
  pass "no credential-shaped strings in ${#tracked[@]} files"
fi

summary

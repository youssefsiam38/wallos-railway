#!/bin/sh
# shellcheck disable=SC2016
# Wallos start-up for the Railway template.
#
# 1. One volume, two data paths. Wallos keeps its SQLite database in /var/www/html/db and uploaded logos/avatars
#    in /var/www/html/images/uploads/logos. Railway gives a service ONE volume, mounted at /data. The image links
#    both paths to /data/db and /data/logos; this script creates those directories and seeds db/ from the image.
#
# 2. No public first-run race. On an empty database Wallos shows an open "create the first account" page to
#    whoever visits first. Before nginx (the only public listener) starts, this script:
#      - creates/migrates the database with upstream's own scripts,
#      - starts PHP's built-in server on 127.0.0.1:$BOOTSTRAP_PORT only,
#      - POSTs ADMIN_USERNAME / ADMIN_EMAIL / ADMIN_PASSWORD to Wallos's own registration.php over loopback
#        (body in a mode-600 file, never on argv), stops it, and checks the account exists.
#    After the first account, Wallos itself closes registration (admin setting "open registrations", default off).
#    On later boots (users exist) nothing is changed.
#
# 3. exec upstream's unmodified startup.sh (php-fpm, nginx on :80, cron, migrations).
set -eu

log() { printf '[wallos-railway] %s\n' "$*"; }

WEBROOT=/var/www/html
DATA=/data
SEED=/opt/wallos-railway/seed
BOOTSTRAP_PORT=${BOOTSTRAP_PORT:-8079}

mkdir -p "$DATA/db" "$DATA/logos/avatars"
# Seed files the image ships in db/ (never overwrite existing data).
for f in "$SEED"/db/*; do
  if [ -e "$f" ] && [ ! -e "$DATA/db/${f##*/}" ]; then cp -a "$f" "$DATA/db/"; fi
done
chown -R www-data:www-data "$DATA/db" "$DATA/logos"
for p in "$WEBROOT/db" "$WEBROOT/images/uploads/logos"; do
  if [ ! -L "$p" ]; then log "$p is not linked to the volume; refusing to start"; exit 1; fi
done

cd "$WEBROOT"
php endpoints/cronjobs/createdatabase.php >/dev/null
php endpoints/db/migrate.php >/dev/null

user_count() {
  php -r '$db = new SQLite3("/var/www/html/db/wallos.db"); echo (int) $db->querySingle("SELECT COUNT(*) FROM user");'
}

count=$(user_count)
if [ "$count" = "0" ]; then
  pw=${ADMIN_PASSWORD:-}
  if [ -z "${ADMIN_EMAIL:-}" ] || [ "${#pw}" -lt 8 ]; then
    log "no account exists yet and ADMIN_EMAIL / ADMIN_PASSWORD (8+ characters) are not both set."
    log "refusing to start with Wallos's open first-run registration page on a public URL."
    exit 1
  fi
  case "${ADMIN_USERNAME:-}" in
    '' | *[!A-Za-z0-9._-]*) log "ADMIN_USERNAME must be letters, digits, '.', '_' or '-'"; exit 1 ;;
  esac
  if ! grep -q "'code' => '${ADMIN_CURRENCY:-}'" registration.php; then
    log "ADMIN_CURRENCY '${ADMIN_CURRENCY:-}' is not one of Wallos's currency codes (e.g. USD, EUR, GBP)"; exit 1
  fi
  case "${ADMIN_LANGUAGE:-}" in
    '' | *[!a-z_A-Z]*) log "ADMIN_LANGUAGE is invalid"; exit 1 ;;
  esac
  if [ ! -f "includes/i18n/${ADMIN_LANGUAGE}.php" ]; then log "ADMIN_LANGUAGE '${ADMIN_LANGUAGE}' is not available"; exit 1; fi

  log "no accounts yet: creating the admin account '${ADMIN_USERNAME}' over loopback"
  old_umask=$(umask)
  umask 077
  tmp=$(mktemp -d)
  php -S "127.0.0.1:${BOOTSTRAP_PORT}" -t "$WEBROOT" >"$tmp/server.log" 2>&1 &
  pid=$!
  i=0
  until curl -fsS -o /dev/null "http://127.0.0.1:${BOOTSTRAP_PORT}/health.php" 2>/dev/null; do
    i=$((i + 1))
    if ! kill -0 "$pid" 2>/dev/null || [ "$i" -ge 60 ]; then
      log "bootstrap server did not start"; kill "$pid" 2>/dev/null || true; rm -rf "$tmp"; exit 1
    fi
    sleep 0.5
  done
  # Form body built from the environment by PHP (never argv), written to a private file.
  php -r 'echo http_build_query([
      "username" => getenv("ADMIN_USERNAME"), "firstname" => getenv("ADMIN_USERNAME"), "lastname" => "",
      "email" => getenv("ADMIN_EMAIL"), "password" => getenv("ADMIN_PASSWORD"),
      "confirm_password" => getenv("ADMIN_PASSWORD"), "main_currency" => getenv("ADMIN_CURRENCY"),
      "language" => getenv("ADMIN_LANGUAGE")]);' >"$tmp/body"
  code=$(curl -sS -o /dev/null -w '%{http_code} %{redirect_url}' -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-binary "@$tmp/body" "http://127.0.0.1:${BOOTSTRAP_PORT}/registration.php" || echo 000)
  rm -f "$tmp/body"
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  count=$(user_count)
  case "$code" in
    302*registered=true*) ;;
    *) log "admin registration failed (HTTP ${code%% *})"; sed -n '1,20p' "$tmp/server.log" | grep -v 'Accepted\|Closing' || true ;;
  esac
  rm -rf "$tmp"
  umask "$old_umask"
  if [ "$count" != "1" ]; then log "expected exactly one account after bootstrap, found $count"; exit 1; fi
  log "admin account created (email ${ADMIN_EMAIL}); public registration stays closed"
else
  log "accounts exist ($count); admin bootstrap skipped"
fi

pw=
unset ADMIN_PASSWORD
chown -R www-data:www-data "$DATA/db" "$DATA/logos"
exec "$WEBROOT/startup.sh"

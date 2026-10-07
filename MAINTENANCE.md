# Maintenance

## Bumping Wallos

1. Resolve the new multi-arch digest (`UPSTREAM.md`) and update `ARG WALLOS_IMAGE=` in `images/wallos/Dockerfile`
   and `UPSTREAM.md`.
2. Check upstream's `Dockerfile`, `startup.sh`, `nginx.default.conf` and `registration.php` for changes: data paths,
   the registration form fields, and the `admin.registrations_open` default.
3. `tests/static.sh && docker compose build --pull && tests/smoke.sh && tests/persistence.sh`.
4. Commit, tag `vX.Y.Z`, push the tag. `publish-image.yml` re-runs the tests against the amd64 candidate and pushes
   amd64 + arm64 to GHCR.
5. Resolve the new wrapper digest, update `_audit/spec_wallos.py`, run `tplkit.patch_template` against the template
   id in `RAILWAY_TEMPLATE.md`, deploy a clean-room copy and run `tests/railway-smoke.sh` (full, redeploy,
   `--verify`).

## Rebuilding the template from scratch

`spec_wallos.py` + `tplkit.skeleton` → `railway templates create` → `tplkit.patch_template` → verify. Only the
skeleton sets volumes, domains and health checks.

## Gotchas specific to this template

- Busybox `cp -an src/. dst/` silently copies nothing; the seed step loops over files instead.
- The bootstrap must restore the umask before `exec startup.sh`: php-fpm inherits it, and with `077` uploaded logos
  become mode 600 and nginx (user `nginx`) serves them as 403.
- Upstream `startup.sh` runs `crontab -d -u root`; jobs still run because dcron reads `/etc/cron.d/cronjobs`.
- Login is by username, not email. `login.php` answers 302 to `.` on success and 200 (form again) on failure.
- Writes need the session's CSRF token (`window.csrfToken` on any signed-in page) as `csrf_token`.

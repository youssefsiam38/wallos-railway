# Railway template configuration

The template's exact configuration. Reproduce it from this file if it ever has to be rebuilt.

| | |
|---|---|
| Name | Wallos Subscription Manager |
| Code | `wallos-subscription-manager` |
| Template id | `01176edc-c2e6-48f7-9d5a-290b671cb04b` |
| Deploy URL | https://railway.com/deploy/wallos-subscription-manager |
| Category | Other |
| Card description | Self-hosted subscription tracker with secure first run and persistent data |
| Icon | `assets/icon.png` |
| Overview markdown | `marketplace/OVERVIEW.md` (Railway enforces its section headings) |

Generated values use Railway's `secret()` function: `hexN` is `${{secret(N, "abcdef0123456789")}}` and `alnumN` is
`${{secret(N, "a-zA-Z0-9")}}` spelled out. Alphanumeric passwords are used wherever a value is embedded in a
connection URL, so nothing needs percent-encoding. The image is pinned by tag and digest (`UPSTREAM.md`).

## Services

### `wallos`

| Field | Value |
|---|---|
| Source | `ghcr.io/youssefsiam38/wallos-railway:1.0.1@sha256:7fde5d33cd2bf0a90ce0393fa7fde85b70a114b24f9579d061c337fd84244352` |
| Public domain | target port 80 |
| Volume | `/data` |
| Healthcheck | `/healthz/`, timeout from `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` |
| Restart policy | on failure, 10 retries |

| Variable | Value |
|---|---|
| `ADMIN_EMAIL` | required input, no default |
| `ADMIN_PASSWORD` | generated, alnum24 |
| `ADMIN_USERNAME` | `admin` |
| `ADMIN_CURRENCY` | `USD` |
| `ADMIN_LANGUAGE` | `en` |
| `PORT` | `80` |
| `TZ` | `UTC` |
| `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` | `300` |
| `OIDC_ENABLED` | optional, unset |
| `OIDC_PROVIDER_NAME` | optional, unset |
| `OIDC_CLIENT_ID` | optional, unset |
| `OIDC_CLIENT_SECRET` | optional, unset |
| `OIDC_ISSUER` | optional, unset |
| `OIDC_REDIRECT_URL` | optional, unset |
| `OIDC_AUTO_CREATE_USER` | optional, unset |
| `SSRF_ALLOWLIST` | optional, unset |

## Notes

- One wrapper image (`publish-image.yml`, amd64 + arm64): `FROM bellamy/wallos:5.8.3@sha256:…`, unmodified, plus symlinks and a start-up script.
- One volume at `/data`: `/var/www/html/db` → `/data/db`, `/var/www/html/images/uploads/logos` → `/data/logos` (Railway allows one volume per service; Wallos needs both).
- `railway-start.sh`: on an empty `user` table, runs PHP's built-in server on `127.0.0.1:8079`, POSTs `ADMIN_*` to Wallos's own `registration.php` (body from a mode-600 file), stops it, then execs upstream `startup.sh`. nginx never starts before the admin exists; without `ADMIN_EMAIL`/`ADMIN_PASSWORD` a fresh install refuses to start. Wallos's `registrations_open` defaults to 0.
- Health check `/healthz/` (Railway rejects paths with a dot, so not `/health.php`); the wrapper adds `healthz/index.php` including `health.php`.
- Container runs as root (no `USER` upstream), so no `RAILWAY_RUN_UID` is needed.
- Live e2e (HTTPS): 26/26 full run (registration refused, admin login, subscription + logo upload), 23/23 `--verify` after a redeploy.

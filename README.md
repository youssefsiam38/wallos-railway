# Wallos on Railway

One-click [Railway](https://railway.com) template for [Wallos](https://github.com/ellite/Wallos), the self-hosted
subscription and recurring-expense tracker (PHP + SQLite): subscriptions with logos, multi-currency totals,
payment-due notifications, statistics, a calendar and household members.

Community-maintained; not affiliated with or endorsed by the Wallos project. The icon in `assets/` is a generic
card motif, not the Wallos logo.

## What you get

| Service  | Image | Public | Volume |
|----------|-------|--------|--------|
| `wallos` | `ghcr.io/youssefsiam38/wallos-railway` (official `bellamy/wallos` + a start-up script) | yes, port 80 | `/data` (database + uploaded logos) |

The image is pinned by digest (amd64 + arm64); versions are in `UPSTREAM.md`. Wallos is GPL-3.0 and runs unmodified.

Compared with a stock deploy:

- **No first-visitor race.** Stock Wallos shows "create the first account" to whoever opens the URL first. Here the
  admin account is created from `ADMIN_USERNAME` / `ADMIN_EMAIL` / a generated `ADMIN_PASSWORD` over loopback
  *before* nginx starts; after that Wallos keeps registration closed.
- **Everything persists.** Wallos writes to two paths (`db/` and `images/uploads/logos/`); Railway allows one volume
  per service. Both are linked onto the single `/data` volume, so the database *and* uploaded logos/avatars survive
  redeploys.
- **Fails closed.** A fresh install without `ADMIN_EMAIL`/`ADMIN_PASSWORD` refuses to start rather than exposing
  the open registration page.

## Deploy

1. Open https://railway.com/deploy/wallos-subscription-manager, click deploy and enter `ADMIN_EMAIL` (your email). Optionally change `ADMIN_USERNAME`
   (default `admin`), `ADMIN_CURRENCY` (default `USD`) and `TZ`.
2. Wait for the service to turn green (about a minute).
3. Open the `wallos` service → Variables → copy `ADMIN_PASSWORD`.
4. Open the service's domain and sign in with `ADMIN_USERNAME` and that password. Change it under Profile.

## Security

Registration is closed after the bootstrap (Wallos's admin setting "Enable user registrations" is off by default);
add people from Admin → Users. The SQLite file and the restore token are not served (upstream nginx rules, verified
by the tests). See `SECURITY.md`.

## Repository layout

| Path | Purpose |
|------|---------|
| `images/wallos/` | Wrapper: `Dockerfile` (volume links), `railway-start.sh` (volume seed + admin bootstrap) |
| `compose.yaml` | Local test topology mirroring the Railway service |
| `tests/` | `static.sh`, `smoke.sh`, `persistence.sh`, `railway-smoke.sh` (live, HTTPS), `fixtures/logo.png` |
| `.github/workflows/` | `test.yml` (every push), `publish-image.yml` (tag `vX.Y.Z` → GHCR, multi-arch) |
| `marketplace/OVERVIEW.md` | Railway Marketplace page |
| `RAILWAY_TEMPLATE.md` | The exact published template configuration |

## Local development

```bash
tests/static.sh                       # no build
docker compose build --pull
tests/smoke.sh                        # bootstrap, gates, login, subscription + logo upload, restart
tests/persistence.sh                  # data + logos survive a new container on the same volume
```

The local stack serves on `http://127.0.0.1:18282` (`WALLOS_TEST_PORT` to change it), admin `admin` with a
placeholder password from `compose.yaml`.

## Licence

Template files: MIT (`LICENSE`). Wallos: GPL-3.0 (`licenses/WALLOS-LICENSE`). See `THIRD_PARTY_NOTICES.md`.

# Marketplace audit — Wallos

| Item | Result |
|------|--------|
| Upstream | https://github.com/ellite/Wallos, active (v5.8.3, 2026-10-01) |
| Licence | GPL-3.0 (verified in `LICENSE.md`); run unmodified from the official image, source linked |
| Brand | Generic icon; "not affiliated" notice in README, OVERVIEW, notices |
| Prebuilt image | Yes, `bellamy/wallos` on Docker Hub, amd64/arm64/arm |
| External services | None required. SMTP, notification services, Fixer, OIDC optional and configured in-app |
| Marketplace | `gapscan.py wallos` → 4 existing templates (`wallos`, `wallos-1`, `wallos-railway`, `wallos-subscription-tracker`), best 4 deploys; none closes the first-run registration page or persists both data paths on one volume |

## Security review

| Risk in a stock deploy | Mitigation |
|------------------------|------------|
| First visitor creates the admin account (open first-run registration) | Admin created over loopback before nginx starts; fresh install without admin vars refuses to start |
| Open registration afterwards | Wallos default `registrations_open=0`; verified live (POST refused, account not created) |
| Two data paths, one Railway volume (logos or DB lost on redeploy) | Both symlinked onto `/data`; verified live across a redeploy |
| Root-owned volume | Upstream runs as root and chowns to `www-data`; no `RAILWAY_RUN_UID` needed |
| SQLite / restore token downloadable | Upstream nginx denies `*.db` (403, tested) |
| Admin password exposure | Generated; sent from a mode-600 file; unset before php-fpm (which keeps the environment) starts |

## Test inventory

| Script | Assertions |
|--------|-----------|
| `tests/static.sh` | 31 |
| `tests/smoke.sh` | 46 |
| `tests/persistence.sh` | 22 |
| `tests/railway-smoke.sh` | live, HTTPS: 26 full + 23 `--verify` after redeploy |

## Deploy-time inputs

- `ADMIN_EMAIL` (required). `ADMIN_PASSWORD` is generated; `ADMIN_USERNAME`, `ADMIN_CURRENCY`, `ADMIN_LANGUAGE`, `TZ`
  have defaults.

## Verdict

SHIPPABLE with one thin wrapper (one-volume layout, loopback admin bootstrap, dot-free health path).

Published 2026-10-07: https://railway.com/deploy/wallos-subscription-manager (template
`01176edc-c2e6-48f7-9d5a-290b671cb04b`). Live e2e over HTTPS: 26/26 full run; 23/23 after a redeploy.

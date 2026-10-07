# Architecture

```
             Railway edge (HTTPS)
                     │
                     ▼  PORT=80
┌──────────────────────────────────────────────┐
│ wallos  (ghcr.io/youssefsiam38/wallos-railway)│
│  dumb-init → railway-start.sh → startup.sh    │
│   nginx :80 ─► php-fpm (www-data) ─► SQLite  │
│   crond (Wallos's daily jobs, notifications) │
│                                              │
│  /var/www/html/db                  → /data/db│
│  /var/www/html/images/uploads/logos→ /data/logos
└───────────────────────┬──────────────────────┘
                        │
                 Railway volume /data
```

One service, one volume. Health check: `/health.php` (public, 200).

## Why a wrapper

Wallos's official image is used unmodified (`FROM bellamy/wallos:<tag>@sha256:…`); the wrapper only adds files and
symlinks. It exists for two reasons the stock image cannot cover with variables:

1. **Two data paths, one volume.** Wallos keeps `db/wallos.db` and uploaded logos/avatars in two directories under
   the web root. Railway attaches one volume per service. At build time the wrapper moves the image's `db/` aside
   (as a seed) and replaces both directories with symlinks to `/data/db` and `/data/logos`. At start the script
   creates those directories on the volume, seeds `db/` without overwriting, and `chown`s them to `www-data`.
   Outside the web root, nothing on the volume is reachable except through Wallos's own paths, where upstream's nginx
   rules still deny `*.db` and PHP under `logos/`.
2. **The first-run registration race.** On an empty database Wallos's `registration.php` lets the first visitor
   create the first account, which is the admin (user id 1). Before upstream's `startup.sh` starts nginx, the
   wrapper:
   - runs upstream's `createdatabase.php` and `migrate.php`;
   - if the `user` table is empty, starts PHP's built-in server on `127.0.0.1:8079`, POSTs the admin form
     (`ADMIN_USERNAME`, `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `ADMIN_CURRENCY`, `ADMIN_LANGUAGE`) to `registration.php`
     from a mode-600 file, stops the server and checks exactly one account exists;
   - then `exec`s upstream's unmodified `startup.sh` (php-fpm, crond, nginx, migrations, daily jobs).

   Wallos's `admin.registrations_open` defaults to 0, so from then on `registration.php` redirects to the login page.
   Driving Wallos's own form (rather than writing SQL) keeps the account identical to one made in the UI: household
   member, localized default categories, currencies and settings.

No Caddy front door: Wallos has a real login and a registration switch, so after the bootstrap there is nothing a
front door would add, and it would put a second password in front of Wallos's own (and break its API key access).

## Processes and users

The container starts as root (no `USER` in the upstream image), so the root-owned Railway volume is writable without
`RAILWAY_RUN_UID`. Upstream's `startup.sh` runs php-fpm workers as `www-data` and nginx workers as `nginx`; crond
(dcron) reads `/etc/cron.d/cronjobs` (next-payment roll-over, exchange rates, notifications, update check).

## Variables

| Variable | Default | Use |
|----------|---------|-----|
| `ADMIN_EMAIL` | (required) | Email of the admin account created on first start |
| `ADMIN_PASSWORD` | generated, 24 alphanumeric | Initial admin password |
| `ADMIN_USERNAME` | `admin` | Login name of the admin |
| `ADMIN_CURRENCY` | `USD` | Main currency of the admin (a Wallos currency code) |
| `ADMIN_LANGUAGE` | `en` | Language of the admin (a Wallos language code) |
| `PORT` | `80` | Railway routing + health-check port (nginx listens on 80) |
| `TZ` | `UTC` | Time zone for the daily jobs |

The `ADMIN_*` variables are read only while the database has no accounts.

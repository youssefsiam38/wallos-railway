# Deploy and Host Wallos on Railway

Wallos is an open-source, self-hosted subscription and recurring-expense tracker: see every subscription with its
logo, next payment date and cost, totals in your main currency, monthly budget, statistics and a calendar, and get
payment reminders by email, Telegram, Discord, ntfy, Gotify, Pushover or webhook. This template deploys it ready for
the internet: your admin account is created from the email you enter and a generated password before the app is
reachable, registration stays closed, and both the database and uploaded logos are kept on a volume. It is a
community-maintained template and is not affiliated with the Wallos project.

## About Hosting Wallos

Wallos is a single PHP application with an embedded SQLite database, served by nginx and php-fpm, with a cron
daemon for daily jobs (rolling payment dates forward, exchange rates, notifications). Everything runs in one
container with one Railway volume at `/data`.

A stock Wallos on a public URL shows a "create the first account" page to whoever visits first, and that account
becomes the admin. Wallos also writes to two separate directories (database and uploaded logos), while Railway
gives a service one volume, so a naive deploy loses either the logos or the data on redeploy. This template creates
your admin account over loopback before the web server starts, then leaves Wallos's own registration switch off,
and links both data directories onto the single volume.

## Common Use Cases

- Track streaming, software, cloud and utility subscriptions with logos, categories and payment methods
- See what you spend per month and year across currencies, against a monthly budget
- Get reminded before renewals and cancellation deadlines by email or chat notifications
- Share a household view of who pays for what

## Dependencies for Wallos Hosting

- None external: SQLite is embedded and stored on the service's volume
- Optional: an SMTP account for email notifications and password resets; notification service tokens; a Fixer API
  key for exchange rates; an OIDC provider for single sign-on (all configured inside Wallos)

### Deployment Dependencies

- Wallos (GPL-3.0): https://github.com/ellite/Wallos
- Template source, image and tests: https://github.com/youssefsiam38/wallos-railway

### Implementation Details

**First sign-in:** enter your email as `ADMIN_EMAIL` when deploying. After the deploy turns green, open the
service's Variables, copy `ADMIN_PASSWORD`, and sign in at the service's domain with `ADMIN_USERNAME` (default
`admin`). Change the password under Profile; the variables are only used to create the account on an empty
database. `ADMIN_CURRENCY` (default `USD`) and `TZ` can be set before deploying.

**What's configured for you:** the official Wallos image pinned by digest and used unmodified, plus a small start-up
script; the admin account created on loopback before nginx starts (a fresh install without admin variables refuses
to start instead of exposing the open registration page); the database and uploaded logos/avatars on one volume at
`/data`; Wallos's cron jobs running in the container; a health check on `/health.php`.

**Adding people:** Admin → Users, or turn on "Enable user registrations" in Admin while they sign up.

Tested on a live deployment of this template over HTTPS: refused registration and anonymous access, admin sign-in,
adding a subscription with an uploaded logo, and the subscription and logo surviving a redeploy.

## Why Deploy Wallos on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you
don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Wallos on Railway, you are one step closer to supporting a complete full-stack application with
minimal burden. Host your servers, databases, AI agents, and more on Railway.

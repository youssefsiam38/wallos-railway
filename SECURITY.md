# Security

## What the template enforces

- **No first-visitor race.** The admin account is created by the start-up script over loopback
  (`127.0.0.1:8079`, PHP's built-in server) before nginx, the only public listener, starts. The public URL never
  shows Wallos's open first-run registration page.
- **Registration closed.** After the first account Wallos redirects `registration.php` to the login page (its admin
  setting "Enable user registrations" defaults to off). The tests POST a registration anonymously and check it is
  refused and the would-be account cannot sign in.
- **Fails closed.** On an empty database without `ADMIN_EMAIL` and an 8+ character `ADMIN_PASSWORD` the container
  exits instead of starting nginx.
- **Generated password.** `ADMIN_PASSWORD` is generated per deploy by Railway. It is sent to the loopback server
  from a mode-600 file, never on a command line or in logs, and is removed from the environment before the app
  starts.
- **Data not served.** The SQLite database and the restore setup token (`db/*.db`) return 403 (upstream nginx
  rules; checked by the tests).

## What you should do

- Sign in and change the admin password (Profile); consider enabling two-factor authentication there.
- Add other people from Admin → Users, or enable registrations only while they sign up (and consider "max users").
- Back up the `/data` volume (Railway volume backups) or use Wallos's own Admin → Backup. It holds the database,
  including any notification credentials, API keys and SMTP settings you add.
- Wallos fetches logos and exchange rates from the internet and checks GitHub for updates; review Admin → Security
  (SSRF allow-list) if you use webhooks to private hosts.

## Notes

- Changing `ADMIN_PASSWORD` (or the other `ADMIN_*` variables) after the first deploy has no effect; the account
  already exists. Reset a forgotten password with SMTP configured, or from another admin.

## Reporting

Template issues: https://github.com/youssefsiam38/wallos-railway/issues. Wallos vulnerabilities: report to the
upstream project (https://github.com/ellite/Wallos/security).

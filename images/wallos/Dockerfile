# syntax=docker/dockerfile:1
#
# Wallos for the Railway template: the official upstream image, pinned by digest, used unmodified, plus
# railway-start.sh, which
#   - keeps the SQLite database AND the uploaded logos on ONE volume at /data (Railway allows one volume per
#     service; upstream needs two paths), via symlinks from the paths Wallos uses, and
#   - creates the first (admin) account from ADMIN_* variables over loopback before the public port opens, so the
#     open first-run registration page is never reachable from the internet.
# Railway rejects health-check paths containing a dot, so /healthz/ (index.php -> upstream's health.php) is added.
# It then execs upstream's own startup.sh (php-fpm + nginx + cron, migrations).
#
# Not affiliated with the Wallos project.
ARG WALLOS_IMAGE=bellamy/wallos:5.8.3@sha256:0006879778f31a962a3873f7682514b92a3c7665dcbc4764fcc241ad968eaccd

FROM ${WALLOS_IMAGE}
ARG WRAPPER_VERSION=0.0.0-dev
ARG VCS_REF=unknown

# Move the image's own db/ contents aside as a seed and point both data paths at the volume.
RUN set -eux; \
    mkdir -p /opt/wallos-railway/seed /data; \
    mv /var/www/html/db /opt/wallos-railway/seed/db; \
    mkdir -p /opt/wallos-railway/seed/logos/avatars; \
    rm -rf /var/www/html/images/uploads/logos; \
    ln -s /data/db /var/www/html/db; \
    ln -s /data/logos /var/www/html/images/uploads/logos; \
    mkdir -p /var/www/html/healthz; \
    printf '%s\n' '<?php' "require __DIR__ . '/../health.php';" > /var/www/html/healthz/index.php
COPY --chmod=0755 images/wallos/railway-start.sh /opt/wallos-railway/railway-start.sh

ENV BOOTSTRAP_PORT=8079 \
    ADMIN_USERNAME=admin \
    ADMIN_CURRENCY=USD \
    ADMIN_LANGUAGE=en \
    TZ=UTC

LABEL org.opencontainers.image.title="wallos-railway" \
      org.opencontainers.image.description="Wallos for the Railway template: the official image pinned by digest, admin created from env before the port opens, database and logos on one volume. Not affiliated with the Wallos project." \
      org.opencontainers.image.source="https://github.com/youssefsiam38/wallos-railway" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${WRAPPER_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}"

EXPOSE 80
# Upstream's ENTRYPOINT (dumb-init --) is kept.
CMD ["/opt/wallos-railway/railway-start.sh"]

# Third-party notices

This template packages and runs the following third-party software. Each keeps its own licence; the template's own
files are MIT (see `LICENSE`).

## Wallos

- Source: https://github.com/ellite/Wallos
- Licence: GNU GPL-3.0, full text in `licenses/WALLOS-LICENSE`
- Used unmodified from the official image `bellamy/wallos` (pinned in `UPSTREAM.md`). The wrapper image moves two
  data directories onto `/data` with symlinks and adds a start-up script; it changes no Wallos file. The
  corresponding source of the running app is the upstream repository at the pinned tag; the wrapper sources are
  this repository.

## Components inside the upstream image

PHP (PHP License), nginx (BSD-2-Clause), dcron (GPL-2.0), dumb-init (MIT) and Alpine Linux packages, as shipped
by the official Wallos image.

---

"Wallos" is the name of its project. This template is community-maintained and is not affiliated with, or endorsed
by, the Wallos project. The icon is a generic card motif made for this template.

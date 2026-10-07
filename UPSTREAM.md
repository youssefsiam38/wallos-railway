# Upstream

- Project: https://github.com/ellite/Wallos (GPL-3.0)
- Official image: `bellamy/wallos` on Docker Hub (linux/amd64, linux/arm64, linux/arm/v7)

## Pinned versions

| Component | Reference |
|-----------|-----------|
| Wallos | `bellamy/wallos:5.8.3@sha256:0006879778f31a962a3873f7682514b92a3c7665dcbc4764fcc241ad968eaccd` |
| Wrapper | `ghcr.io/youssefsiam38/wallos-railway:1.0.0@sha256:7d76a3f2876f58f183f5563415cc5a4838944c7774e3b75f1de06c17874778f1` |

## Refreshing a digest

```bash
docker buildx imagetools inspect bellamy/wallos:X.Y.Z --format '{{json .Manifest}}' | jq -r .digest
# or: curl -s https://hub.docker.com/v2/repositories/bellamy/wallos/tags/X.Y.Z/ | jq -r .digest
```

Use the numbered tag (`5.8.3`), not `v5_8_3` (a different build) or `latest`.

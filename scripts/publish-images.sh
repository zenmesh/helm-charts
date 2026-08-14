#!/usr/bin/env bash
# publish-images.sh — Push the zenmesh/* container images referenced by the charts.
#
# zen-lock images are built from source (private repo, vendored deps):
#   zenmesh/zen-lock:0.1.0-alpha              (webhook + controller)
#   zenmesh/zen-lock-csi-provider:0.1.0-alpha (CSI provider DaemonSet)
# The remaining components are mirrored tag-for-tag from the legacy public
# kubezen/* Docker Hub repositories until CI publishes them natively.
#
# Requires: docker login with an account that has push access to the
# zenmesh Docker Hub org. Verify with: docker pull zenmesh/push-test (should 401/404)
set -euo pipefail

ZEN_LOCK_REPO="${ZEN_LOCK_REPO:-../zen-lock}"
VERSION="${VERSION:-0.1.0-alpha}"

# Legacy image -> tag pairs exactly as referenced by chart defaults.
MIRROR=(
  "zen-agent:0.1.1"
  "zen-flow-controller:0.0.1-alpha"
  "gc-controller:0.0.1-alpha"
  "zen-watcher:1.2.1"
)

push_one() {
  local ref="$1"
  if docker image inspect "$ref" >/dev/null 2>&1; then
    echo ">>> docker push $ref"
    docker push "$ref"
  else
    echo "!!! $ref not present locally — skipped (build/pull it first)" >&2
    return 1
  fi
}

FAIL=0

# 1. Build zen-lock images from the committed tree (clean worktree).
if [ -d "$ZEN_LOCK_REPO" ]; then
  WT="$(mktemp -d)"
  git -C "$ZEN_LOCK_REPO" worktree add "$WT" HEAD >/dev/null
  trap 'git -C "$ZEN_LOCK_REPO" worktree remove "$WT" --force >/dev/null 2>&1 || true' EXIT
  COMMIT="$(git -C "$ZEN_LOCK_REPO" rev-parse --short HEAD)"
  BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "=== Building zenmesh/zen-lock:$VERSION (commit $COMMIT) ==="
  (cd "$WT" && DOCKER_BUILDKIT=1 docker build \
    --build-arg VERSION="$VERSION" --build-arg COMMIT="$COMMIT" --build-arg BUILD_DATE="$BUILD_DATE" \
    -t "zenmesh/zen-lock:$VERSION" .)
  echo "=== Building zenmesh/zen-lock-csi-provider:$VERSION ==="
  (cd "$WT" && docker buildx build --load \
    --build-arg VERSION="$VERSION" --build-arg COMMIT="$COMMIT" --build-arg BUILD_DATE="$BUILD_DATE" \
    -f Dockerfile.csi-provider -t "zenmesh/zen-lock-csi-provider:$VERSION" .)
  push_one "zenmesh/zen-lock:$VERSION" || FAIL=1
  push_one "zenmesh/zen-lock-csi-provider:$VERSION" || FAIL=1
else
  echo "!!! zen-lock repo not found at $ZEN_LOCK_REPO — building only mirrors" >&2
fi

# 2. Mirror legacy public images tag-for-tag.
for pair in "${MIRROR[@]}"; do
  img="${pair%%:*}"; tag="${pair##*:}"
  if ! docker image inspect "zenmesh/$img:$tag" >/dev/null 2>&1; then
    echo "=== Mirroring kubezen/$img:$tag -> zenmesh/$img:$tag ==="
    docker pull "kubezen/$img:$tag"
    docker tag "kubezen/$img:$tag" "zenmesh/$img:$tag"
  fi
  push_one "zenmesh/$img:$tag" || FAIL=1
done

# NOTE (2026-08): not mirrorable yet — no public source images exist:
#   zenmesh/zen-ingester:1.0.0-b311, zenmesh/zen-egress:1.0.0 (kubezen repos empty)
#   zenmesh/zen-lead:0.1.0 (only 0.1.0-alpha exists upstream)
# These need native CI builds; zen-cluster/zen-lead installs stay blocked until then.

[ "$FAIL" -eq 0 ] && echo "Done — all images pushed." || { echo "Some pushes failed." >&2; exit 1; }

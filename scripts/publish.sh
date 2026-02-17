#!/usr/bin/env bash
# P235: Deterministic helm-charts publishing — package charts and regenerate index.yaml.
# Produces .tgz + index.yaml for GitHub Pages. Run from helm-charts repo root.
# Usage: ./scripts/publish.sh [chart...]
#   If no args: publish zen-cluster (and any other charts present).
#   With args: helm package + index only for given charts (e.g. zen-cluster zen-agent).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
REPO_URL="${HELM_REPO_URL:-https://kube-zen.github.io/helm-charts}"

CHARTS=("${@:-zen-cluster}")
# If zen-cluster was requested but missing, try to sync from zen-platform first
if [[ "${CHARTS[*]}" == *zen-cluster* ]] && [[ ! -d "charts/zen-cluster" ]]; then
  SYNC_SCRIPT=""
  for d in ../zen-platform ../../zen-platform; do
    if [[ -f "${d}/scripts/release/sync-zen-cluster-to-helm-charts.sh" ]]; then
      SYNC_SCRIPT="${d}/scripts/release/sync-zen-cluster-to-helm-charts.sh"
      break
    fi
  done
  if [[ -n "$SYNC_SCRIPT" ]]; then
    echo "zen-cluster not found; running sync from zen-platform..."
    HELM_CHARTS_DIR="$REPO_ROOT" bash "$SYNC_SCRIPT" || true
  fi
fi

for chart in "${CHARTS[@]}"; do
  path="charts/$chart"
  if [[ ! -d "$path" ]]; then
    echo "Skip $chart (not found: $path)" >&2
    continue
  fi
  echo "=== Lint $chart ==="
  helm lint "$path"
  echo "=== Package $chart ==="
  helm package "$path" -d .
done

echo "=== Regenerate index.yaml ==="
helm repo index . --url "$REPO_URL" --merge index.yaml

echo "Done. Commit zen-cluster-*.tgz (if new) and index.yaml"

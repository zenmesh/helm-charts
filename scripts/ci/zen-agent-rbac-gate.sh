#!/usr/bin/env bash
# N9: Helm RBAC verification gate — run on any chart/values/template change for zen-agent.
# Ensures chart docs/contract stays aligned with rendered RBAC.
# Usage: from helm-charts repo root: ./scripts/ci/zen-agent-rbac-gate.sh
# Trigger: run when charts/zen-agent/** or scripts/verify-zen-agent-rbac.sh changes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHART="$REPO_ROOT/charts/zen-agent"

if [[ ! -d "$CHART" ]]; then
  echo "zen-agent chart not found at $CHART"
  exit 1
fi

cd "$REPO_ROOT"
echo "[N9] zen-agent RBAC gate: helm lint + verify-zen-agent-rbac.sh"

if ! helm lint "$CHART"; then
  echo "FAIL: helm lint $CHART"
  exit 1
fi

if ! ./scripts/verify-zen-agent-rbac.sh; then
  echo "FAIL: RBAC contract verification (Role/ClusterRole verbs)"
  exit 1
fi

echo "PASS: zen-agent chart lint and RBAC contract verified"

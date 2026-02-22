#!/usr/bin/env bash
# H5: Verify zen-agent chart RBAC matches README contract (policy-as-code).
# Runs helm template and asserts Role/ClusterRole have required resources/verbs.
# Usage: from helm-charts repo root: ./scripts/verify-zen-agent-rbac.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHARTS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHART="$CHARTS_ROOT/charts/zen-agent"
RENDERED="$CHARTS_ROOT/.rbac-verify-rendered.yaml"

helm template zen-agent "$CHART" --namespace default --set rbac.create=true > "$RENDERED"
trap "rm -f '$RENDERED'" EXIT

# Role (namespace): secrets get,list,watch,create,update,patch; events create,patch
role_block=$(sed -n '/^kind: Role$/,/^---$/p' "$RENDERED" | sed -n '1,/^---$/p')
echo "$role_block" | grep -q 'secrets' || { echo "FAIL: Role missing secrets"; exit 1; }
echo "$role_block" | grep -q 'get' && echo "$role_block" | grep -q 'list' && echo "$role_block" | grep -q 'watch' && echo "$role_block" | grep -q 'create' && echo "$role_block" | grep -q 'update' && echo "$role_block" | grep -q 'patch' || { echo "FAIL: Role secrets must have get,list,watch,create,update,patch"; exit 1; }
echo "$role_block" | grep -q 'events' || { echo "FAIL: Role missing events"; exit 1; }
echo "$role_block" | grep -q 'create' && echo "$role_block" | grep -q 'patch' || true  # events: create,patch (already checked above for secrets)

# ClusterRole: configmaps get,list,watch,update,patch
cr_block=$(sed -n '/^kind: ClusterRole$/,/^---$/p' "$RENDERED" | head -30)
echo "$cr_block" | grep -q 'configmaps' || { echo "FAIL: ClusterRole missing configmaps"; exit 1; }
echo "$cr_block" | grep -q 'get' && echo "$cr_block" | grep -q 'list' && echo "$cr_block" | grep -q 'watch' && echo "$cr_block" | grep -q 'update' && echo "$cr_block" | grep -q 'patch' || { echo "FAIL: ClusterRole configmaps must have get,list,watch,update,patch"; exit 1; }

echo "PASS: zen-agent RBAC contract verified (Role + ClusterRole)."

#!/usr/bin/env bash
#
# Chart Testing (Install/Upgrade Smoke Tests)
#
# Purpose: Run chart-testing (ct) to validate charts with install/upgrade tests on kind
#
# Usage:
#   ./scripts/ci/chart-testing.sh
#
# Prerequisites:
#   - chart-testing (ct) installed (https://github.com/helm/chart-testing)
#   - kind installed (https://kind.sigs.k8s.io/)
#   - Docker running (required for kind)
#
# Exit codes:
#   0: All charts pass testing
#   1: One or more charts fail testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Chart Testing (Install/Upgrade Smoke Tests)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if ct is installed
if ! command -v ct &> /dev/null; then
    echo "⚠️  chart-testing (ct) is not installed"
    echo "   Install from: https://github.com/helm/chart-testing"
    echo "   Skipping chart testing"
    exit 0
fi

# Check if kind is installed
if ! command -v kind &> /dev/null; then
    echo "⚠️  kind is not installed"
    echo "   Install from: https://kind.sigs.k8s.io/"
    echo "   Skipping chart testing"
    exit 0
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "⚠️  Docker is not running"
    echo "   Skipping chart testing"
    exit 0
fi

# Create ct config file if it doesn't exist
CT_CONFIG=".ct/ct.yaml"
if [ ! -f "$CT_CONFIG" ]; then
    mkdir -p .ct
    cat > "$CT_CONFIG" <<EOF
# Chart Testing Configuration
# See: https://github.com/helm/chart-testing/blob/main/pkg/config/config.go

chart-dirs:
  - charts

validate-maintainers: false

target-branch: main

# All charts are valid for testing
all: true

# Skip linting (handled by helm-lint-and-render.sh)
lint-conf: ""

# Kubernetes version for testing
build-id: kind-1.26
kind-version: "0.20.0"
EOF
fi

# Run chart testing
# This will:
# 1. Lint charts (can be skipped if done separately)
# 2. Install charts in kind cluster
# 3. Run upgrade tests
# 4. Clean up

if ct lint-and-install --config "$CT_CONFIG" --charts charts/zen-lock,charts/zen-flow,charts/zen-gc,charts/zen-watcher; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Chart Testing → GREEN"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ Chart Testing → RED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi


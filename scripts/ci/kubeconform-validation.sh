#!/usr/bin/env bash
#
# Kubeconform Validation
#
# Purpose: Validate rendered Helm manifests against Kubernetes schemas using kubeconform
#
# Usage:
#   ./scripts/ci/kubeconform-validation.sh
#
# Prerequisites:
#   - kubeconform installed (https://github.com/yannh/kubeconform)
#   - kubeconform will download Kubernetes schemas automatically
#
# Exit codes:
#   0: All rendered manifests are valid
#   1: One or more manifests fail validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Kubeconform Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "❌ Helm is not installed"
    exit 1
fi

# Check if kubeconform is installed
if ! command -v kubeconform &> /dev/null; then
    echo "⚠️  kubeconform is not installed"
    echo "   Install from: https://github.com/yannh/kubeconform"
    echo "   Skipping kubeconform validation"
    exit 0
fi

CHARTS=(
    "charts/zen-lock"
    "charts/zen-flow"
    "charts/zen-gc"
    "charts/zen-watcher"
    "charts/zen-suite"
)

FAILED=0
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

for chart in "${CHARTS[@]}"; do
    if [ ! -d "$chart" ]; then
        echo "⚠️  Chart not found: $chart (skipping)"
        continue
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Validating: $chart"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Build dependencies for zen-suite
    if [[ "$chart" == *"zen-suite"* ]]; then
        echo "  Building dependencies..."
        if ! helm dependency build "$chart" > /dev/null 2>&1; then
            echo "❌ Failed to build dependencies for $chart"
            FAILED=$((FAILED + 1))
            continue
        fi
    fi

    # Render chart templates
    rendered_file="$TEMP_DIR/$(basename $chart).yaml"
    if helm template test-release "$chart" > "$rendered_file" 2>&1; then
        echo "  Rendered templates successfully"
    else
        echo "❌ Failed to render templates for $chart"
        FAILED=$((FAILED + 1))
        continue
    fi

    # Validate with kubeconform
    # Skip CRDs (they have different validation rules)
    # Use Kubernetes 1.26 schema (compatible with most clusters)
    if kubeconform -skip "CustomResourceDefinition" -kubernetes-version 1.26.0 "$rendered_file" > /dev/null 2>&1; then
        echo "✅ Kubeconform validation passed for $chart"
    else
        echo "❌ Kubeconform validation failed for $chart"
        # Show errors
        kubeconform -skip "CustomResourceDefinition" -kubernetes-version 1.26.0 "$rendered_file" || true
        FAILED=$((FAILED + 1))
    fi
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAILED -eq 0 ]; then
    echo "✅ Kubeconform Validation → GREEN"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    echo "❌ Kubeconform Validation → RED ($FAILED failures)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi


#!/usr/bin/env bash
#
# Helm Schema Validation
#
# Purpose: Validate Helm chart values against values.schema.json (if present)
#
# Usage:
#   ./scripts/ci/helm-schema-validation.sh
#
# Exit codes:
#   0: All charts with schemas pass validation
#   1: One or more charts fail schema validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Helm Schema Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "❌ Helm is not installed"
    exit 1
fi

CHARTS=(
    "charts/zen-lock"
    "charts/zen-flow"
    "charts/zen-gc"
    "charts/zen-watcher"
    "charts/zen-suite"
)

FAILED=0

for chart in "${CHARTS[@]}"; do
    if [ ! -d "$chart" ]; then
        echo "⚠️  Chart not found: $chart (skipping)"
        continue
    fi

    schema_file="$chart/values.schema.json"
    
    if [ ! -f "$schema_file" ]; then
        echo "⏭️  Skipping $chart (no values.schema.json)"
        continue
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Validating schema: $chart"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Build dependencies for zen-suite before validation
    if [[ "$chart" == *"zen-suite"* ]]; then
        echo "  Building dependencies..."
        if ! helm dependency build "$chart" > /dev/null 2>&1; then
            echo "❌ Failed to build dependencies for $chart"
            FAILED=$((FAILED + 1))
            continue
        fi
    fi

    # Validate schema file syntax
    if ! python3 -m json.tool "$schema_file" > /dev/null 2>&1; then
        echo "❌ Schema file is not valid JSON: $schema_file"
        FAILED=$((FAILED + 1))
        continue
    fi

    # Helm will validate values against schema during template render
    # Test with default values
    if helm template test-release "$chart" > /dev/null 2>&1; then
        echo "✅ Schema validation passed for $chart"
    else
        echo "❌ Schema validation failed for $chart"
        FAILED=$((FAILED + 1))
    fi
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAILED -eq 0 ]; then
    echo "✅ Helm Schema Validation → GREEN"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    echo "❌ Helm Schema Validation → RED ($FAILED failures)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi


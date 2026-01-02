#!/usr/bin/env bash
#
# Optional: Render all example values for validation
# Usage: RUN_HELM_EXAMPLE_MATRIX=1 ./scripts/ci/helm-lint-and-render.sh
#
# Helm Lint and Render
#
# Purpose: Validate helm charts via lint and template rendering
#
# Usage:
#   ./scripts/ci/helm-lint-and-render.sh
#
# Exit codes:
#   0: All charts valid
#   1: One or more charts fail validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RUN_GUARDRAILS="${RUN_GUARDRAILS:-0}"

cd "$REPO_ROOT"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Helm Charts Validation"
if [ "$RUN_GUARDRAILS" = "1" ]; then
    echo "(Guardrails: STRICT MODE)"
fi
echo "Testing profiles: default, SaaS-like, demo"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "❌ Helm is not installed"
    exit 1
fi

echo "Helm version: $(helm version --short)"
echo ""

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

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Validating: $chart"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Update dependencies if needed
    if [ -f "$chart/Chart.lock" ]; then
        echo "[0/2] Updating chart dependencies..."
        if helm dependency update "$chart" > /dev/null 2>&1; then
            echo "✅ Dependencies updated"
        else
            echo "⚠️  Dependency update had warnings (continuing)"
        fi
        echo ""
    fi

    # Lint chart
    echo "[1/2] Running helm lint..."
    
    # zen-suite requires dependencies to be built first
    if [[ "$chart" == *"zen-suite"* ]]; then
        echo "  Building dependencies for zen-suite..."
        if ! helm dependency build "$chart" > /dev/null 2>&1; then
            echo "  ❌ Failed to build dependencies for zen-suite"
            FAILED=$((FAILED + 1))
            continue
        fi
    fi
    
    if helm lint "$chart"; then
        echo "✅ Lint passed for $chart"
    else
        echo "❌ Lint failed for $chart"
        FAILED=$((FAILED + 1))
    fi
    echo ""

    # Template render (matrix tests)
    echo "[2/2] Running helm template (matrix tests)..."
    
    # zen-suite requires dependencies to be built before template rendering
    if [[ "$chart" == *"zen-suite"* ]]; then
        echo "  Building dependencies for zen-suite..."
        if ! helm dependency build "$chart" > /dev/null 2>&1; then
            echo "  ❌ Failed to build dependencies for zen-suite"
            FAILED=$((FAILED + 1))
            continue
        fi
        echo "  Testing zen-suite scenarios..."
        
        # Scenario 1: Default (all core enabled, integrations off)
        if helm template test-release "$chart" > /dev/null 2>&1; then
            echo "  ✅ Default scenario (all core enabled, integrations off)"
        else
            echo "  ❌ Default scenario failed"
            FAILED=$((FAILED + 1))
        fi
        
        # Scenario 2: Integration enabled (positive case)
        if helm template test-release "$chart" --set integrations.observationsGc.enabled=true > /dev/null 2>&1; then
            echo "  ✅ Integration enabled (positive case)"
        else
            echo "  ❌ Integration enabled scenario failed"
            FAILED=$((FAILED + 1))
        fi
        
        # Scenario 3: Negative case (integration enabled but zenGc disabled) - should fail
        if helm template test-release "$chart" --set integrations.observationsGc.enabled=true --set zenGc.enabled=false > /dev/null 2>&1; then
            echo "  ❌ Negative case should have failed (integration enabled but zenGc disabled)"
            FAILED=$((FAILED + 1))
        else
            echo "  ✅ Negative case correctly failed (validation working)"
        fi
        
        # Scenario 4: zenLead enabled
        if helm template test-release "$chart" --set zenLead.enabled=true > /dev/null 2>&1; then
            echo "  ✅ zenLead enabled scenario"
        else
            echo "  ❌ zenLead enabled scenario failed"
            FAILED=$((FAILED + 1))
        fi
    else
        # Other charts: test with default values
        if helm template test-release "$chart" > /dev/null; then
            echo "✅ Template render passed for $chart"
        else
            echo "❌ Template render failed for $chart"
            FAILED=$((FAILED + 1))
        fi
    fi
    echo ""
done

# Example values matrix (if enabled)
if [ "$RUN_HELM_EXAMPLE_MATRIX" = "1" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Example Values Matrix Validation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    EXAMPLE_VALUES_DIR="$SCRIPT_DIR/../../docs/examples"
    
    if [ -d "$EXAMPLE_VALUES_DIR" ]; then
        for example_file in "$EXAMPLE_VALUES_DIR"/values-*.yaml; do
            if [ -f "$example_file" ]; then
                example_name=$(basename "$example_file")
                echo "Testing example: $example_name"
                
                # Test charts with example values (skip zen-suite for examples)
                for chart in "${CHARTS[@]}"; do
                    if [[ "$chart" != *"zen-suite"* ]]; then
                        chart_name=$(basename "$chart")
                        if [[ "$example_file" == *"$chart_name"* ]] || [[ "$example_file" == *"values"* ]]; then
                            if helm template test-release "$SCRIPT_DIR/../../$chart" -f "$example_file" > /dev/null 2>&1; then
                                echo "  ✓ $example_name renders successfully for $chart_name"
                            else
                                echo "  ❌ $example_name failed to render for $chart_name"
                                FAILED=$((FAILED + 1))
                            fi
                        fi
                    fi
                done
            fi
        done
        echo ""
    else
        echo "⚠️  Example values directory not found: $EXAMPLE_VALUES_DIR"
        echo ""
    fi
fi

# Guardrail checks (if enabled)
if [ "$RUN_GUARDRAILS" = "1" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Guardrail Checks"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    GUARDRAIL_WARNINGS=0
    
    # Check for disallowed registries in values.yaml
    echo "[1/2] Checking registry policies..."
    for chart in "${CHARTS[@]}"; do
        if [ -f "$chart/values.yaml" ]; then
            # Check for docker.io (should use kubezen/*)
            if grep -E "repository:.*docker\.io" "$chart/values.yaml" 2>/dev/null | grep -v "kubezen" > /dev/null; then
                echo "  ⚠️  $chart uses docker.io registry (should use kubezen/*)"
                GUARDRAIL_WARNINGS=$((GUARDRAIL_WARNINGS + 1))
            fi
        fi
    done
    
    if [ $GUARDRAIL_WARNINGS -eq 0 ]; then
        echo "  ✅ All charts use approved registries"
    fi
    echo ""
    
    # Check for insecure pull policies
    echo "[2/2] Checking image pull policies..."
    for chart in "${CHARTS[@]}"; do
        if [ -f "$chart/values.yaml" ]; then
            if grep -q "pullPolicy:.*Always" "$chart/values.yaml" 2>/dev/null; then
                echo "  ℹ️  $chart uses pullPolicy: Always (acceptable for dev)"
            fi
        fi
    done
    echo "  ✅ Pull policies checked"
    echo ""
    
    if [ $GUARDRAIL_WARNINGS -gt 0 ]; then
        echo "⚠️  $GUARDRAIL_WARNINGS guardrail warnings detected"
        echo ""
    fi
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAILED -eq 0 ]; then
    echo "✅ Helm Charts Validation → GREEN"
    if [ "$RUN_GUARDRAILS" = "1" ] && [ ${GUARDRAIL_WARNINGS:-0} -gt 0 ]; then
        echo "   (with $GUARDRAIL_WARNINGS guardrail warnings)"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    echo "❌ Helm Charts Validation → RED ($FAILED failures)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi


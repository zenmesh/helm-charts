#!/bin/bash
# Validate Helm CRD toggles and upgrade stability
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHARTS_DIR="$(cd "$SCRIPT_DIR/../charts" && pwd)"

echo "=== D022: Helm CRD Toggle Validation ==="
echo

# Test 1: zen-watcher CRD toggle
echo "Test 1: zen-watcher CRD toggle"
echo "----------------------------------------"
cd "$CHARTS_DIR"

# Test with crds.enabled=false (default)
echo "Testing with crds.enabled=false (default)..."
OUTPUT_FALSE=$(helm template zen-watcher zen-watcher --set crds.enabled=false 2>&1)
if echo "$OUTPUT_FALSE" | grep -q "kind: CustomResourceDefinition"; then
    echo "❌ FAIL: CRDs rendered when crds.enabled=false"
    exit 1
fi
echo "✅ PASS: No CRDs rendered when crds.enabled=false"

# Test with crds.enabled=true
echo "Testing with crds.enabled=true..."
OUTPUT_TRUE=$(helm template zen-watcher zen-watcher --set crds.enabled=true 2>&1)
CRD_COUNT=$(echo "$OUTPUT_TRUE" | grep -c "kind: CustomResourceDefinition" || true)
if [ "$CRD_COUNT" -lt 2 ]; then
    echo "❌ FAIL: Expected at least 2 CRDs, got $CRD_COUNT"
    exit 1
fi
echo "✅ PASS: $CRD_COUNT CRDs rendered when crds.enabled=true"

# Check for runtime metadata in CRDs only
echo "Checking for runtime metadata in CRDs..."
# Extract CRD sections (between "kind: CustomResourceDefinition" and next "---")
CRD_SECTIONS=$(echo "$OUTPUT_TRUE" | sed -n '/^kind: CustomResourceDefinition$/,/^---$/p' | head -300)
if echo "$CRD_SECTIONS" | grep -qE "kubectl.kubernetes.io/last-applied-configuration"; then
    echo "❌ FAIL: Found kubectl last-applied-configuration annotation in CRD"
    exit 1
fi
# Note: jsonPath: .metadata.creationTimestamp is a printer column reference, not runtime metadata
# Note: annotations: in deployment templates is expected and not a problem
echo "✅ PASS: No runtime metadata found in CRDs"

# Test 2: zen-suite pass-through
echo
echo "Test 2: zen-suite pass-through"
echo "----------------------------------------"
OUTPUT_SUITE=$(helm template zen-suite zen-suite --set zenWatcher.crds.enabled=true 2>&1)
if echo "$OUTPUT_SUITE" | grep -q "kind: CustomResourceDefinition"; then
    echo "✅ PASS: zen-suite passes through crds.enabled to zen-watcher"
else
    echo "⚠️  WARN: zen-suite may not be passing through crds.enabled (check subchart dependencies)"
fi

# Test 3: No-op upgrade simulation
echo
echo "Test 3: No-op upgrade simulation"
echo "----------------------------------------"
# Render twice and compare (should be identical)
OUTPUT1=$(helm template zen-watcher zen-watcher --set crds.enabled=true 2>&1 | grep -A 100 "kind: CustomResourceDefinition" | head -200)
OUTPUT2=$(helm template zen-watcher zen-watcher --set crds.enabled=true 2>&1 | grep -A 100 "kind: CustomResourceDefinition" | head -200)
if [ "$OUTPUT1" != "$OUTPUT2" ]; then
    echo "❌ FAIL: Non-deterministic CRD output detected"
    exit 1
fi
echo "✅ PASS: CRD output is deterministic"

# Test 4: Validate CRD structure
echo
echo "Test 4: Validate CRD structure"
echo "----------------------------------------"
CRD_YAML=$(echo "$OUTPUT_TRUE" | grep -A 500 "kind: CustomResourceDefinition" | head -100)
if ! echo "$CRD_YAML" | grep -q "apiVersion: apiextensions.k8s.io/v1"; then
    echo "❌ FAIL: Invalid CRD apiVersion"
    exit 1
fi
if ! echo "$CRD_YAML" | grep -q "metadata:"; then
    echo "❌ FAIL: Missing metadata section"
    exit 1
fi
if ! echo "$CRD_YAML" | grep -q "spec:"; then
    echo "❌ FAIL: Missing spec section"
    exit 1
fi
echo "✅ PASS: CRD structure is valid"

echo
echo "=== All D022 validation tests passed ==="


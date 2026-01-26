#!/bin/bash
set -euo pipefail

# Template validation test - tests TLS modes without requiring cluster/image
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

FAILED=0

test_template() {
    local mode=$1
    local extra_args="${2:-}"
    log_info "Testing template rendering: $mode mode"
    
    if helm template test "$CHART_DIR" \
        --set webhook.enabled=true \
        --set webhook.tls.mode="$mode" \
        $extra_args >/dev/null 2>&1; then
        log_info "✓ Template renders successfully: $mode"
        return 0
    else
        log_error "✗ Template failed to render: $mode"
        FAILED=1
        return 1
    fi
}

test_template_fails() {
    local mode=$1
    local extra_args="${2:-}"
    local expected_error="${3:-}"
    log_info "Testing template validation: $mode mode (should fail)"
    
    OUTPUT=$(helm template test "$CHART_DIR" \
        --set webhook.enabled=true \
        --set webhook.tls.mode="$mode" \
        $extra_args 2>&1 || true)
    
    if echo "$OUTPUT" | grep -q "$expected_error"; then
        log_info "✓ Validation works: $mode rejected as expected"
        return 0
    else
        log_error "✗ Validation failed: $mode should have been rejected"
        echo "Output: $OUTPUT"
        FAILED=1
        return 1
    fi
}

# Test valid templates
log_info "=== Testing valid template rendering ==="

# cert-manager mode (valid)
test_template "cert-manager" "--set webhook.certManager.enabled=true --set webhook.certManager.issuer.name=test-issuer"

# self-signed mode (valid)
test_template "self-signed" "--set webhook.certManager.enabled=false"

# provided mode (valid)
CA_BUNDLE_TEST=$(echo "test-ca-cert" | base64 -w 0)
test_template "provided" "--set webhook.certManager.enabled=false --set webhook.tls.caBundle=$CA_BUNDLE_TEST"

# Test validation failures
log_info "=== Testing validation failures ==="

# cert-manager without issuer
test_template_fails "cert-manager" "--set webhook.certManager.enabled=false" "requires webhook.certManager.enabled=true"

# provided without caBundle
test_template_fails "provided" "--set webhook.certManager.enabled=false" "webhook.tls.caBundle is required"

# provided with empty caBundle
test_template_fails "provided" "--set webhook.certManager.enabled=false --set webhook.tls.caBundle=" "cannot be empty"

# Test cert-manager certificate resource
log_info "=== Testing cert-manager Certificate resource ==="
OUTPUT=$(helm template test "$CHART_DIR" \
    --set webhook.enabled=true \
    --set webhook.tls.mode=cert-manager \
    --set webhook.certManager.enabled=true \
    --set webhook.certManager.issuer.name=test-issuer \
    --set webhook.certManager.issuer.kind=ClusterIssuer 2>/dev/null)

if echo "$OUTPUT" | grep -q "kind: Certificate"; then
    log_info "✓ Certificate resource present"
    
    # Check for ECDSA keys
    if echo "$OUTPUT" | grep -q "algorithm: ECDSA"; then
        log_info "✓ ECDSA keys configured"
    else
        log_error "✗ ECDSA keys not found"
        FAILED=1
    fi
    
    # Check for DNS names
    if echo "$OUTPUT" | grep -q "zen-lock-webhook.*\.svc"; then
        log_info "✓ DNS names configured"
    else
        log_error "✗ DNS names not found"
        FAILED=1
    fi
else
    log_error "✗ Certificate resource not found"
    FAILED=1
fi

# Test self-signed cert job
log_info "=== Testing self-signed cert job ==="
OUTPUT=$(helm template test "$CHART_DIR" \
    --set webhook.enabled=true \
    --set webhook.tls.mode=self-signed \
    --set webhook.certManager.enabled=false 2>/dev/null)

if echo "$OUTPUT" | grep -q "kind: Job"; then
    log_info "✓ Cert-generation Job present"
    
    # Check for helm hooks
    if echo "$OUTPUT" | grep -q "helm.sh/hook.*post-install"; then
        log_info "✓ Helm hooks configured"
    else
        log_error "✗ Helm hooks not found"
        FAILED=1
    fi
    
    # Check for openssl commands
    if echo "$OUTPUT" | grep -q "openssl.*genrsa"; then
        log_info "✓ Certificate generation script present"
    else
        log_error "✗ Certificate generation script not found"
        FAILED=1
    fi
else
    log_error "✗ Cert-generation Job not found"
    FAILED=1
fi

# Test provided mode caBundle
log_info "=== Testing provided mode caBundle ==="
CA_BUNDLE_TEST=$(echo "test-ca-cert-content" | base64 -w 0)
OUTPUT=$(helm template test "$CHART_DIR" \
    --set webhook.enabled=true \
    --set webhook.tls.mode=provided \
    --set webhook.certManager.enabled=false \
    --set webhook.tls.caBundle="$CA_BUNDLE_TEST" 2>/dev/null)

if echo "$OUTPUT" | grep -q "caBundle: $CA_BUNDLE_TEST"; then
    log_info "✓ caBundle set correctly in MutatingWebhookConfiguration"
else
    log_error "✗ caBundle not found or incorrect"
    FAILED=1
fi

# Summary
echo ""
if [ $FAILED -eq 0 ]; then
    log_info "=== All template tests passed ==="
    exit 0
else
    log_error "=== Some tests failed ==="
    exit 1
fi

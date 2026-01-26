#!/bin/bash
set -euo pipefail

# TLS Matrix Test Script for zen-lock
# Tests all three TLS modes: cert-manager, self-signed, provided

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_MODE="${1:-all}"

CLUSTER_NAME="zen-lock-tls-test"
NAMESPACE="zen-lock-system"
TEST_NS="test-ns"
KUBECTL_CONTEXT="kind-$CLUSTER_NAME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

cleanup() {
    log_info "Cleaning up test cluster..."
    kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
    rm -f /tmp/zen-lock-test-*.{key,crt,csr,srl} 2>/dev/null || true
}

trap cleanup EXIT

# Check prerequisites
command -v kind >/dev/null 2>&1 || { log_error "kind is required but not installed. Aborting."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { log_error "kubectl is required but not installed. Aborting."; exit 1; }
command -v helm >/dev/null 2>&1 || { log_error "helm is required but not installed. Aborting."; exit 1; }
command -v openssl >/dev/null 2>&1 || { log_error "openssl is required but not installed. Aborting."; exit 1; }

# Create kind cluster
create_cluster() {
    log_info "Creating kind cluster: $CLUSTER_NAME"
    kind create cluster --name "$CLUSTER_NAME" --wait 60s
    
    # Wait for cluster to be ready
    kubectl wait --for=condition=ready node --all --timeout=120s --context "$KUBECTL_CONTEXT"
    log_info "Cluster is ready"
    
    # Set kubectl context for subsequent commands
    export KUBECONFIG=""
    kubectl config use-context "$KUBECTL_CONTEXT"
}

# Test cert-manager mode
test_cert_manager() {
    log_info "=== Testing cert-manager mode ==="
    
    # Install cert-manager
    log_info "Installing cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    
    # Wait for cert-manager to be ready
    log_info "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s || {
        log_error "cert-manager failed to become ready"
        return 1
    }
    
    # Create test ClusterIssuer
    log_info "Creating test ClusterIssuer..."
    kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: test-selfsigned-issuer
spec:
  selfSigned: {}
EOF
    
    # Install zen-lock with cert-manager
    log_info "Installing zen-lock with cert-manager mode..."
    helm install zen-lock "$CHART_DIR" \
        --namespace "$NAMESPACE" --create-namespace \
        --set webhook.enabled=true \
        --set webhook.certManager.enabled=true \
        --set webhook.certManager.issuer.name=test-selfsigned-issuer \
        --set webhook.certManager.issuer.kind=ClusterIssuer \
        --set image.tag=0.0.2-alpha \
        --wait --timeout 5m || {
        log_error "Helm install failed"
        return 1
    }
    
    # Verify Certificate resource
    log_info "Verifying Certificate resource..."
    kubectl wait --for=condition=ready certificate -n "$NAMESPACE" zen-lock-webhook-cert --timeout=300s || {
        log_error "Certificate not ready"
        return 1
    }
    
    # Verify TLS secret exists
    kubectl get secret zen-lock-webhook-cert -n "$NAMESPACE" >/dev/null || {
        log_error "TLS secret not found"
        return 1
    }
    
    # Verify webhook annotation
    kubectl get mutatingwebhookconfiguration zen-lock-mutating-webhook -o yaml | grep -q "cert-manager.io/inject-ca-from" || {
        log_error "cert-manager annotation missing"
        return 1
    }
    
    # Wait for webhook pods
    log_info "Waiting for webhook pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=webhook -n "$NAMESPACE" --timeout=300s || {
        log_error "Webhook pods not ready"
        return 1
    }
    
    # Verify caBundle (may take a moment for cert-manager to inject)
    log_info "Waiting for caBundle injection..."
    for i in {1..30}; do
        CA_BUNDLE=$(kubectl get mutatingwebhookconfiguration zen-lock-mutating-webhook -o jsonpath='{.webhooks[0].clientConfig.caBundle}' 2>/dev/null || echo "")
        if [ -n "$CA_BUNDLE" ] && [ ${#CA_BUNDLE} -gt 100 ]; then
            log_info "✓ caBundle injected (length: ${#CA_BUNDLE})"
            break
        fi
        sleep 2
    done
    
    if [ -z "$CA_BUNDLE" ] || [ ${#CA_BUNDLE} -lt 100 ]; then
        log_error "caBundle not injected or too short"
        return 1
    fi
    
    log_info "✓ cert-manager mode test passed"
    
    # Cleanup
    helm uninstall zen-lock -n "$NAMESPACE" || true
    kubectl delete namespace "$NAMESPACE" --wait=false || true
    sleep 5
}

# Test self-signed mode
test_self_signed() {
    log_info "=== Testing self-signed mode ==="
    
    # Install zen-lock with self-signed mode
    log_info "Installing zen-lock with self-signed mode..."
    helm install zen-lock "$CHART_DIR" \
        --namespace "$NAMESPACE" --create-namespace \
        --set webhook.enabled=true \
        --set webhook.certManager.enabled=false \
        --set webhook.tls.mode=self-signed \
        --set image.tag=0.0.2-alpha \
        --wait --timeout 5m || {
        log_error "Helm install failed"
        return 1
    }
    
    # Wait for cert-generation Job
    log_info "Waiting for cert-generation Job to complete..."
    kubectl wait --for=condition=complete job/zen-lock-webhook-cert-setup -n "$NAMESPACE" --timeout=300s || {
        log_error "Cert-generation Job failed"
        kubectl logs job/zen-lock-webhook-cert-setup -n "$NAMESPACE" || true
        return 1
    }
    
    # Verify TLS secret exists
    kubectl get secret zen-lock-webhook-cert -n "$NAMESPACE" >/dev/null || {
        log_error "TLS secret not found"
        return 1
    }
    
    # Verify secret contains valid cert
    log_info "Verifying certificate SANs..."
    SERVICE_DNS="zen-lock-webhook.zen-lock-system.svc"
    CERT_SANS=$(kubectl get secret zen-lock-webhook-cert -n "$NAMESPACE" -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" || echo "")
    if echo "$CERT_SANS" | grep -q "$SERVICE_DNS"; then
        log_info "✓ Certificate SANs match service DNS"
    else
        log_error "Certificate SANs mismatch"
        echo "$CERT_SANS"
        return 1
    fi
    
    # Verify caBundle is patched
    log_info "Verifying caBundle in MutatingWebhookConfiguration..."
    CA_BUNDLE=$(kubectl get mutatingwebhookconfiguration zen-lock-mutating-webhook -o jsonpath='{.webhooks[0].clientConfig.caBundle}' 2>/dev/null || echo "")
    if [ -z "$CA_BUNDLE" ] || [ ${#CA_BUNDLE} -lt 100 ]; then
        log_error "caBundle not patched or too short"
        return 1
    fi
    log_info "✓ caBundle patched (length: ${#CA_BUNDLE})"
    
    # Wait for webhook pods
    log_info "Waiting for webhook pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=webhook -n "$NAMESPACE" --timeout=300s || {
        log_error "Webhook pods not ready"
        return 1
    }
    
    log_info "✓ self-signed mode test passed"
    
    # Cleanup
    helm uninstall zen-lock -n "$NAMESPACE" || true
    kubectl delete namespace "$NAMESPACE" --wait=false || true
    sleep 5
}

# Test provided mode
test_provided() {
    log_info "=== Testing provided mode ==="
    
    # Generate test certificates
    log_info "Generating test certificates..."
    cd /tmp
    openssl genrsa -out zen-lock-test-ca.key 4096 2>/dev/null
    openssl req -new -x509 -days 365 -key zen-lock-test-ca.key -out zen-lock-test-ca.crt -subj "/CN=test-ca" 2>/dev/null
    openssl ecparam -genkey -name prime256v1 -out zen-lock-test-server.key 2>/dev/null
    openssl req -new -key zen-lock-test-server.key -out zen-lock-test-server.csr -subj "/CN=zen-lock-webhook.zen-lock-system.svc" \
        -addext "subjectAltName=DNS:zen-lock-webhook.zen-lock-system.svc,DNS:zen-lock-webhook.zen-lock-system.svc.cluster.local" 2>/dev/null
    openssl x509 -req -in zen-lock-test-server.csr -CA zen-lock-test-ca.crt -CAkey zen-lock-test-ca.key -CAcreateserial \
        -out zen-lock-test-server.crt -days 365 \
        -extensions v3_ext -extfile <(echo "[v3_ext]"; echo "subjectAltName=DNS:zen-lock-webhook.zen-lock-system.svc,DNS:zen-lock-webhook.zen-lock-system.svc.cluster.local") 2>/dev/null
    
    # Create TLS secret
    log_info "Creating TLS secret..."
    kubectl create namespace "$NAMESPACE" 2>/dev/null || true
    kubectl create secret tls zen-lock-webhook-cert \
        --cert=zen-lock-test-server.crt \
        --key=zen-lock-test-server.key \
        -n "$NAMESPACE" || {
        log_error "Failed to create TLS secret"
        return 1
    }
    
    # Get CA bundle
    CA_BUNDLE=$(cat zen-lock-test-ca.crt | base64 -w 0)
    
    # Install zen-lock with provided mode
    log_info "Installing zen-lock with provided mode..."
    helm install zen-lock "$CHART_DIR" \
        --namespace "$NAMESPACE" \
        --set webhook.enabled=true \
        --set webhook.certManager.enabled=false \
        --set webhook.tls.mode=provided \
        --set webhook.tls.caBundle="$CA_BUNDLE" \
        --set image.tag=0.0.2-alpha \
        --wait --timeout 5m || {
        log_error "Helm install failed"
        return 1
    }
    
    # Verify caBundle matches
    log_info "Verifying caBundle matches provided value..."
    CA_BUNDLE_CHECK=$(kubectl get mutatingwebhookconfiguration zen-lock-mutating-webhook -o jsonpath='{.webhooks[0].clientConfig.caBundle}' 2>/dev/null || echo "")
    if [ "$CA_BUNDLE_CHECK" != "$CA_BUNDLE" ]; then
        log_error "caBundle mismatch"
        return 1
    fi
    log_info "✓ caBundle matches provided value"
    
    # Wait for webhook pods
    log_info "Waiting for webhook pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=webhook -n "$NAMESPACE" --timeout=300s || {
        log_error "Webhook pods not ready"
        return 1
    }
    
    log_info "✓ provided mode test passed"
    
    # Cleanup
    helm uninstall zen-lock -n "$NAMESPACE" || true
    kubectl delete namespace "$NAMESPACE" --wait=false || true
    rm -f /tmp/zen-lock-test-*.{key,crt,csr,srl} 2>/dev/null || true
    sleep 5
}

# Test validation failures
test_validation_failures() {
    log_info "=== Testing validation failures ==="
    
    # Test: cert-manager mode without issuer
    log_info "Testing: cert-manager mode without issuer (should fail)..."
    OUTPUT=$(helm template zen-lock-test "$CHART_DIR" \
        --namespace "$NAMESPACE" \
        --set webhook.enabled=true \
        --set webhook.tls.mode=cert-manager \
        --set webhook.certManager.enabled=false 2>&1 || true)
    if echo "$OUTPUT" | grep -q "requires webhook.certManager.enabled=true"; then
        log_info "✓ Validation works: cert-manager mode without issuer rejected"
    else
        log_error "Validation failed: should reject cert-manager mode without issuer"
        echo "Output: $OUTPUT"
        return 1
    fi
    
    # Test: provided mode without caBundle
    log_info "Testing: provided mode without caBundle (should fail)..."
    OUTPUT=$(helm template zen-lock-test2 "$CHART_DIR" \
        --namespace "$NAMESPACE" \
        --set webhook.enabled=true \
        --set webhook.tls.mode=provided 2>&1 || true)
    if echo "$OUTPUT" | grep -q "webhook.tls.caBundle is required"; then
        log_info "✓ Validation works: provided mode without caBundle rejected"
    else
        log_error "Validation failed: should reject provided mode without caBundle"
        echo "Output: $OUTPUT"
        return 1
    fi
    
    # Test: provided mode with empty caBundle
    log_info "Testing: provided mode with empty caBundle (should fail)..."
    OUTPUT=$(helm template zen-lock-test3 "$CHART_DIR" \
        --namespace "$NAMESPACE" \
        --set webhook.enabled=true \
        --set webhook.tls.mode=provided \
        --set webhook.tls.caBundle="" 2>&1 || true)
    if echo "$OUTPUT" | grep -q "cannot be empty"; then
        log_info "✓ Validation works: provided mode with empty caBundle rejected"
    else
        log_error "Validation failed: should reject empty caBundle"
        echo "Output: $OUTPUT"
        return 1
    fi
    
    log_info "✓ All validation failure tests passed"
}

# Main execution
main() {
    log_info "Starting TLS matrix tests for zen-lock"
    log_info "Test mode: $TEST_MODE"
    
    create_cluster
    
    case "$TEST_MODE" in
        cert-manager)
            test_cert_manager
            ;;
        self-signed)
            test_self_signed
            ;;
        provided)
            test_provided
            ;;
        validation)
            test_validation_failures
            ;;
        all)
            test_cert_manager
            test_self_signed
            test_provided
            test_validation_failures
            ;;
        *)
            log_error "Unknown test mode: $TEST_MODE"
            log_info "Usage: $0 [cert-manager|self-signed|provided|validation|all]"
            exit 1
            ;;
    esac
    
    log_info "=== All tests completed successfully ==="
}

main "$@"

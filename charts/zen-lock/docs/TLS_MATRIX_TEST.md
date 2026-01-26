# TLS Configuration Matrix Test Runbook

This document describes the test matrix for validating zen-lock webhook TLS configuration across all supported modes.

## Test Scenarios

### Prerequisites

- Kubernetes cluster (kind/minikube/GKE/EKS)
- kubectl configured
- Helm 3.x installed
- (Optional) cert-manager installed for cert-manager mode tests

### Test Matrix

| Mode | Description | Prerequisites | Expected Outcome |
|------|-------------|---------------|------------------|
| **cert-manager** | Uses cert-manager to issue certificates | cert-manager installed, ClusterIssuer/Issuer configured | Certificate issued, caBundle auto-injected |
| **self-signed** | Generates self-signed certificates via Job | None (zero-dependency) | CA + serving cert generated, caBundle patched |
| **provided** | User provides TLS secret and caBundle | TLS secret exists, caBundle provided | Uses provided cert, validates caBundle present |

## Test 1: cert-manager Mode

### Setup

```bash
# Install cert-manager (if not already installed)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

# Create a test ClusterIssuer (self-signed for testing)
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: test-selfsigned-issuer
spec:
  selfSigned: {}
EOF
```

### Install

```bash
helm install zen-lock ./charts/zen-lock \
  --namespace zen-lock-system --create-namespace \
  --set webhook.enabled=true \
  --set webhook.certManager.enabled=true \
  --set webhook.certManager.issuer.name=test-selfsigned-issuer \
  --set webhook.certManager.issuer.kind=ClusterIssuer
```

### Validation

```bash
# 1. Verify Certificate resource created
kubectl get certificate -n zen-lock-system

# 2. Verify Certificate is Ready
kubectl wait --for=condition=ready certificate -n zen-lock-system zen-lock-webhook-cert --timeout=300s

# 3. Verify TLS secret exists
kubectl get secret zen-lock-webhook-cert -n zen-lock-system

# 4. Verify MutatingWebhookConfiguration has cert-manager annotation
kubectl get mutatingwebhookconfiguration zen-lock-mutating-webhook -o yaml | grep cert-manager.io/inject-ca-from

# 5. Verify webhook pods become Ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=webhook -n zen-lock-system --timeout=300s

# 6. Verify caBundle is present (after cert-manager injects it)
kubectl get mutatingwebhookconfiguration zen-lock-mutating-webhook -o jsonpath='{.webhooks[0].clientConfig.caBundle}' | wc -c
# Should output > 0 (non-empty)

# 7. Test injection canary
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: test-ns
  labels:
    zen-lock: enabled
---
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: test-ns
  annotations:
    zen-lock/inject: test-zenlock
spec:
  containers:
  - name: test
    image: busybox
    command: ["sleep", "3600"]
EOF

# Verify pod is created (webhook should allow it, even if ZenLock doesn't exist)
# The webhook will deny with a clear error if ZenLock is missing, but TLS should work
```

### Cleanup

```bash
helm uninstall zen-lock -n zen-lock-system
kubectl delete namespace test-ns
```

## Test 2: self-signed Mode

### Install

```bash
helm install zen-lock ./charts/zen-lock \
  --namespace zen-lock-system --create-namespace \
  --set webhook.enabled=true \
  --set webhook.certManager.enabled=false \
  --set webhook.tls.mode=self-signed
```

### Validation

```bash
# 1. Verify cert-generation Job is created
kubectl get job -n zen-lock-system | grep webhook-cert-setup

# 2. Wait for Job to complete
kubectl wait --for=condition=complete job/zen-lock-webhook-cert-setup -n zen-lock-system --timeout=300s

# 3. Verify TLS secret exists
kubectl get secret zen-lock-webhook-cert -n zen-lock-system

# 4. Verify secret contains tls.crt and tls.key
kubectl get secret zen-lock-webhook-cert -n zen-lock-system -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text
kubectl get secret zen-lock-webhook-cert -n zen-lock-system -o jsonpath='{.data.tls\.key}' | base64 -d | head -1

# 5. Verify MutatingWebhookConfiguration has caBundle
CA_BUNDLE=$(kubectl get mutatingwebhookconfiguration zen-lock-mutating-webhook -o jsonpath='{.webhooks[0].clientConfig.caBundle}')
if [ -z "$CA_BUNDLE" ]; then
  echo "ERROR: caBundle is missing from MutatingWebhookConfiguration"
  exit 1
fi
echo "✓ caBundle present (length: ${#CA_BUNDLE})"

# 6. Verify webhook pods become Ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=webhook -n zen-lock-system --timeout=300s

# 7. Verify certificate SANs match service DNS
SERVICE_DNS="zen-lock-webhook.zen-lock-system.svc"
kubectl get secret zen-lock-webhook-cert -n zen-lock-system -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text | grep -q "$SERVICE_DNS" && echo "✓ SAN matches service DNS" || echo "✗ SAN mismatch"

# 8. Test injection canary (same as cert-manager test)
```

### Cleanup

```bash
helm uninstall zen-lock -n zen-lock-system
kubectl delete namespace test-ns
```

## Test 3: provided Mode

### Setup

```bash
# Generate a test CA and certificate
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 365 -key ca.key -out ca.crt -subj "/CN=test-ca"
openssl ecparam -genkey -name prime256v1 -out server.key
openssl req -new -key server.key -out server.csr -subj "/CN=zen-lock-webhook.zen-lock-system.svc" \
  -addext "subjectAltName=DNS:zen-lock-webhook.zen-lock-system.svc,DNS:zen-lock-webhook.zen-lock-system.svc.cluster.local"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 \
  -extensions v3_ext -extfile <(echo "[v3_ext]"; echo "subjectAltName=DNS:zen-lock-webhook.zen-lock-system.svc,DNS:zen-lock-webhook.zen-lock-system.svc.cluster.local")

# Create TLS secret
kubectl create namespace zen-lock-system
kubectl create secret tls zen-lock-webhook-cert \
  --cert=server.crt \
  --key=server.key \
  -n zen-lock-system

# Get CA bundle (base64 encoded)
CA_BUNDLE=$(cat ca.crt | base64 -w 0)
```

### Install

```bash
helm install zen-lock ./charts/zen-lock \
  --namespace zen-lock-system \
  --set webhook.enabled=true \
  --set webhook.certManager.enabled=false \
  --set webhook.tls.mode=provided \
  --set webhook.tls.caBundle="$CA_BUNDLE"
```

### Validation

```bash
# 1. Verify installation succeeds (should not fail validation)
helm status zen-lock -n zen-lock-system

# 2. Verify MutatingWebhookConfiguration has caBundle
CA_BUNDLE_CHECK=$(kubectl get mutatingwebhookconfiguration zen-lock-mutating-webhook -o jsonpath='{.webhooks[0].clientConfig.caBundle}')
if [ "$CA_BUNDLE_CHECK" != "$CA_BUNDLE" ]; then
  echo "ERROR: caBundle mismatch"
  exit 1
fi
echo "✓ caBundle matches provided value"

# 3. Verify webhook pods become Ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=webhook -n zen-lock-system --timeout=300s

# 4. Test injection canary
```

### Cleanup

```bash
helm uninstall zen-lock -n zen-lock-system
rm -f ca.key ca.crt server.key server.crt server.csr ca.srl
kubectl delete namespace test-ns
```

## Test 4: Validation Failures (Negative Tests)

### Test: cert-manager mode without issuer

```bash
# Should fail with clear error
helm install zen-lock ./charts/zen-lock \
  --namespace zen-lock-system --create-namespace \
  --set webhook.enabled=true \
  --set webhook.tls.mode=cert-manager \
  --set webhook.certManager.enabled=false 2>&1 | grep -q "requires webhook.certManager.enabled=true" && echo "✓ Validation works" || echo "✗ Validation failed"
```

### Test: provided mode without caBundle

```bash
# Should fail with clear error
helm install zen-lock ./charts/zen-lock \
  --namespace zen-lock-system --create-namespace \
  --set webhook.enabled=true \
  --set webhook.tls.mode=provided 2>&1 | grep -q "webhook.tls.caBundle is required" && echo "✓ Validation works" || echo "✗ Validation failed"
```

### Test: provided mode with empty caBundle

```bash
# Should fail with clear error
helm install zen-lock ./charts/zen-lock \
  --namespace zen-lock-system --create-namespace \
  --set webhook.enabled=true \
  --set webhook.tls.mode=provided \
  --set webhook.tls.caBundle="" 2>&1 | grep -q "cannot be empty" && echo "✓ Validation works" || echo "✗ Validation failed"
```

## CI Integration

Add to `.github/workflows/ci.yml`:

```yaml
- name: Test TLS Matrix
  run: |
    # Run each test scenario
    ./scripts/test-tls-matrix.sh cert-manager
    ./scripts/test-tls-matrix.sh self-signed
    ./scripts/test-tls-matrix.sh provided
```

## Acceptance Criteria

All tests must pass:

- [ ] Webhook pods become Ready in all modes
- [ ] TLS secret exists and contains valid certificates
- [ ] MutatingWebhookConfiguration contains caBundle
- [ ] Certificate SANs match service DNS names
- [ ] Injection canary passes (webhook responds to pod creation)
- [ ] Validation failures provide clear error messages
- [ ] Self-signed cert job is idempotent (can run multiple times)

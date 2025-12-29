# Installation Guide

This guide covers installing Kube-Zen components using Helm charts.

## Quick Start (zen-suite)

The fastest way to get started is using the zen-suite chart, which installs all components:

```bash
# Add repository
helm repo add kube-zen https://kube-zen.github.io/helm-charts
helm repo update

# Install all components
helm install zen-suite kube-zen/zen-suite \
  --namespace zen-system \
  --create-namespace
```

**Note**: The suite chart is recommended for reference installations and fast onboarding. For production, we recommend installing components individually (see below).

## Individual Component Installation (Recommended for Production)

### Prerequisites

- Kubernetes 1.20+ (1.26+ for zen-watcher)
- Helm 3.8+
- kubectl configured to access your cluster

### zen-lock

```bash
# Add repository
helm repo add kube-zen https://kube-zen.github.io/helm-charts
helm repo update

# Install zen-lock
helm install zen-lock kube-zen/zen-lock \
  --namespace zen-lock-system \
  --create-namespace
```

### zen-flow

```bash
helm install zen-flow kube-zen/zen-flow \
  --namespace zen-flow-system \
  --create-namespace
```

### zen-gc

```bash
helm install zen-gc kube-zen/zen-gc \
  --namespace zen-gc-system \
  --create-namespace
```

### zen-watcher

```bash
helm install zen-watcher kube-zen/zen-watcher \
  --namespace zen-watcher-system \
  --create-namespace
```

## Production Installation Guidelines

### 1. Separate Namespaces

Install each component in its own namespace for better isolation:

```bash
# Create namespaces
kubectl create namespace zen-lock-system
kubectl create namespace zen-flow-system
kubectl create namespace zen-gc-system
kubectl create namespace zen-watcher-system

# Install components
helm install zen-lock kube-zen/zen-lock --namespace zen-lock-system
helm install zen-flow kube-zen/zen-flow --namespace zen-flow-system
helm install zen-gc kube-zen/zen-gc --namespace zen-gc-system
helm install zen-watcher kube-zen/zen-watcher --namespace zen-watcher-system
```

### 2. Custom Values

Use custom values files for production configuration:

```bash
# Create values file
cat > zen-lock-prod-values.yaml <<EOF
replicaCount: 3
image:
  tag: "0.0.1-alpha"
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
EOF

# Install with custom values
helm install zen-lock kube-zen/zen-lock \
  --namespace zen-lock-system \
  --values zen-lock-prod-values.yaml
```

### 3. RBAC Configuration

Review and configure RBAC based on your security requirements:

```yaml
# values.yaml
rbac:
  create: true
  # Custom ClusterRole if needed
  # Custom ClusterRoleBinding if needed
```

### 4. Network Policies

Create NetworkPolicies to restrict inter-component communication:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: zen-lock-policy
  namespace: zen-lock-system
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: zen-lock
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: zen-lock-system
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: zen-lock-system
```

### 5. Resource Limits

Set appropriate resource requests and limits:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### 6. High Availability

For production, enable multiple replicas:

```yaml
replicaCount: 3
```

### 7. Pod Disruption Budgets

Create PodDisruptionBudgets for availability:

```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 2
```

## Verification

After installation, verify components are running:

```bash
# Check pods
kubectl get pods -n zen-lock-system
kubectl get pods -n zen-flow-system
kubectl get pods -n zen-gc-system
kubectl get pods -n zen-watcher-system

# Check CRDs
kubectl get crds | grep kube-zen.io

# Check services
kubectl get svc -n zen-lock-system
kubectl get svc -n zen-flow-system
kubectl get svc -n zen-gc-system
kubectl get svc -n zen-watcher-system
```

## Uninstallation

To uninstall components:

```bash
# Uninstall suite
helm uninstall zen-suite --namespace zen-system

# Or uninstall individually
helm uninstall zen-lock --namespace zen-lock-system
helm uninstall zen-flow --namespace zen-flow-system
helm uninstall zen-gc --namespace zen-gc-system
helm uninstall zen-watcher --namespace zen-watcher-system

# Note: CRDs are not automatically removed (by design)
# To remove CRDs manually:
kubectl delete crd zenlocks.security.kube-zen.io
kubectl delete crd jobflows.workflow.kube-zen.io
kubectl delete crd garbagecollectionpolicies.gc.kube-zen.io
kubectl delete crd observations.zen.kube-zen.io
kubectl delete crd ingesters.zen.kube-zen.io
```

## Troubleshooting

### Pods Not Starting

Check pod logs:

```bash
kubectl logs -n zen-lock-system deployment/zen-lock
```

Check events:

```bash
kubectl describe pod -n zen-lock-system -l app.kubernetes.io/name=zen-lock
```

### CRD Issues

Verify CRDs are installed:

```bash
kubectl get crds | grep kube-zen.io
```

If CRDs are missing, they are typically installed automatically by Helm. Check the chart's `crds/` directory.

### RBAC Issues

Check service account permissions:

```bash
kubectl get clusterrolebinding -l app.kubernetes.io/name=zen-lock
kubectl describe clusterrole -l app.kubernetes.io/name=zen-lock
```

## Next Steps

- See [UPGRADES.md](UPGRADES.md) for upgrade procedures
- See [COMPATIBILITY.md](COMPATIBILITY.md) for version compatibility
- See [SECURITY_MODEL.md](SECURITY_MODEL.md) for security considerations


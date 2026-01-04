# zen-watcher

Universal Kubernetes Event Aggregator - Secure, Extensible Event Collection

## Introduction

zen-watcher is a Kubernetes operator that aggregates structured signals from security, compliance, and infrastructure tools into unified `Observation` CRDs.

## Prerequisites

- Kubernetes 1.26+
- Helm 3.8+

## Quick Start

After installing zen-watcher, you need to create an Ingester resource to start collecting events. Here's the fastest way to get started:

### Option 1: Enable Default Ingester (Automatic)

Install with the default Kubernetes Events Ingester enabled:

```bash
helm install zen-watcher kube-zen/zen-watcher \
  --namespace zen-system \
  --create-namespace \
  --set ingester.createDefaultK8sEvents=true
```

This automatically creates a minimal Ingester that watches Kubernetes Events across all namespaces.

### Option 2: Manual Ingester (Recommended for Production)

Install the chart, then manually create an Ingester:

```bash
# 1. Install zen-watcher (CRDs are installed by default)
helm install zen-watcher kube-zen/zen-watcher \
  --namespace zen-system \
  --create-namespace

# 2. Apply a minimal Kubernetes Events Ingester
cat <<EOF | kubectl apply -f -
apiVersion: zen.kube-zen.io/v1alpha1
kind: Ingester
metadata:
  name: k8s-events-demo
  namespace: zen-system
spec:
  source: kubernetes-events
  ingester: informer
  informer:
    gvr:
      group: ""
      version: "v1"
      resource: "events"
    namespace: ""  # Empty = watch all namespaces
  destinations:
    - type: crd
      value: observations
EOF

# 3. Generate a test event to verify it's working
kubectl run test-pod --image=nginx --restart=Never
kubectl delete pod test-pod

# 4. Check for Observations (should appear within a few seconds)
kubectl get observations -n zen-system
```

## Installing the Chart

To install the chart with the release name `zen-watcher`:

```bash
helm install zen-watcher kube-zen/zen-watcher \
  --namespace zen-system \
  --create-namespace
```

## Uninstalling the Chart

To uninstall/delete the `zen-watcher` deployment:

```bash
helm uninstall zen-watcher --namespace zen-watcher-system
```

## CRD Installation and Lifecycle

### CRD Installation (Default Behavior)

By default, CRDs are **installed automatically** with the chart (`crds.enabled=true`). This chart includes both:
- **Observation CRD** (`observations.zen.kube-zen.io`) - stores aggregated events
- **Ingester CRD** (`ingesters.zen.kube-zen.io`) - configures event sources

This provides the fastest path to a working installation - no manual CRD installation required.

### ⚠️ CRD Lifecycle Risk (Production Consideration)

**IMPORTANT**: CRDs installed via Helm are treated as normal Helm-managed resources. This means:
- CRDs will be **DELETED** on `helm uninstall`
- CRDs may be affected by `helm rollback` operations
- This can cause **data loss** if Observation CRDs exist when CRDs are removed

**Recommended approach for production/GitOps**:

```bash
# 1. Install CRDs separately (outside Helm lifecycle)
kubectl apply -f https://raw.githubusercontent.com/kube-zen/zen-watcher/main/deployments/crds/observation_crd.yaml
kubectl apply -f https://raw.githubusercontent.com/kube-zen/zen-watcher/main/deployments/crds/ingester_crd.yaml

# 2. Install zen-watcher with CRDs disabled
helm install zen-watcher kube-zen/zen-watcher \
  --namespace zen-system \
  --create-namespace \
  --set crds.enabled=false \
  --set ingester.createDefaultK8sEvents=true
```

**When to disable (`crds.enabled=false`):**
- ✅ Production deployments (recommended)
- ✅ GitOps workflows (ArgoCD, Flux) where CRDs are managed in a separate Git repository
- ✅ Multi-cluster deployments where CRDs are installed once globally
- ✅ Enterprise environments with strict CRD lifecycle management policies

**When default (`crds.enabled=true`) is acceptable:**
- 🧪 Testing/development environments
- 📦 Quick demos and POCs
- 🔧 Single-use clusters where uninstall/rollback risk is acceptable

### CRD Upgrade Notes

⚠️ **Enterprise Clusters**: Some clusters enforce strict CRD mutation rules. If CRD upgrades fail during Helm upgrade, you may need to:

1. Apply CRD updates manually: `kubectl apply -f deployments/crds/*.yaml`
2. Then upgrade the Helm release: `helm upgrade zen-watcher ...`

### ArgoCD Compatibility

The CRD templates are designed to be **idempotent** and **deterministic**:
- No runtime metadata (no `last-applied-configuration` annotations)
- Consistent YAML formatting
- No non-deterministic ordering

This ensures ArgoCD diffs converge and don't cause perpetual drift.

## Configuration

The following table lists the configurable parameters and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `2` |
| `image.repository` | Image repository | `kubezen/zen-watcher` |
| `image.tag` | Image tag (defaults to appVersion) | `""` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `serviceAccount.create` | Create service account | `true` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `8080` |
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `512Mi` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |
| `crds.enabled` | Install CRDs with chart (Observation + Ingester). **⚠️ Production: Set to false** (see CRD Lifecycle Risk below) | `true` |
| `rbac.create` | Create RBAC resources | `true` |
| `rbac.namespaceOnlyMode` | Use namespace-scoped RBAC (Role/RoleBinding) | `false` |
| `ingester.createDefaultK8sEvents` | Create default Kubernetes Events Ingester. **⚠️ Recommended: Set to true** for first install | `false` |

---

## Deployment Blockers & Production Considerations

### 1. CRD Lifecycle Risk (Production)

**⚠️ IMPORTANT**: CRDs installed via Helm are treated as normal Helm-managed resources. This means:
- CRDs will be **DELETED** on `helm uninstall`
- CRDs may be affected by `helm rollback` operations
- This can cause **data loss** if Observation CRDs exist when CRDs are removed

**Recommended approach for production/GitOps**:

```bash
# 1. Install CRDs separately (outside Helm lifecycle)
kubectl apply -f https://raw.githubusercontent.com/kube-zen/zen-watcher/main/deployments/crds/observation_crd.yaml
kubectl apply -f https://raw.githubusercontent.com/kube-zen/zen-watcher/main/deployments/crds/ingester_crd.yaml

# 2. Install zen-watcher with CRDs disabled
helm install zen-watcher kube-zen/zen-watcher \
  --namespace zen-system \
  --create-namespace \
  --set crds.enabled=false
```

**When to disable (`crds.enabled=false`):**
- ✅ Production deployments (recommended)
- ✅ GitOps workflows (ArgoCD, Flux) where CRDs are managed in a separate Git repository
- ✅ Multi-cluster deployments where CRDs are installed once globally
- ✅ Enterprise environments with strict CRD lifecycle management policies

### 2. NetworkPolicy Validation Required

**⚠️ WARNING**: NetworkPolicy is enabled by default (`networkPolicy.enabled=true`), but it may block controller access to the Kubernetes API if not properly configured for your CNI.

**Before production deployment:**

1. **Validate NetworkPolicy on your CNI**: Test that the NetworkPolicy doesn't block zen-watcher from accessing the Kubernetes API server
2. **Configure Kubernetes API CIDR**: Update `networkPolicy.egress.kubernetesAPICIDR` to match your cluster's API server CIDR range
3. **Adjust metrics namespace**: Update `networkPolicy.ingress.metricsNamespaces` if Prometheus is in a different namespace than `monitoring`

**For first launch (if not validated):**

```yaml
networkPolicy:
  enabled: false  # Disable until validated on your CNI
```

**Finding your Kubernetes API CIDR:**

```bash
# Method 1: Check API server endpoint
kubectl get endpoints kubernetes -o jsonpath='{.subsets[0].addresses[0].ip}'

# Method 2: Check cluster CIDR (varies by provider)
# EKS: Check VPC CIDR
# GKE: Check cluster CIDR in GCP Console
# On-prem: Check cluster network configuration
```

### 3. RBAC Extension Required for Informer-Based Sources

The default RBAC in this chart covers:
- ✅ Kubernetes Events
- ✅ Observations and Ingesters CRDs
- ✅ ConfigMaps (for filter config)
- ✅ Leases (for leader election)

**If you use informer-based sources (Trivy, Kyverno, etc.), you must extend RBAC:**

```bash
# Example: Add Trivy permissions
kubectl patch clusterrole zen-watcher --type='json' \
  -p='[{"op": "add", "path": "/rules/-", "value": {
    "apiGroups": ["aquasecurity.github.io"],
    "resources": ["vulnerabilityreports", "clustervulnerabilityreports"],
    "verbs": ["get", "list", "watch"]
  }}]'

# Example: Add Kyverno permissions
kubectl patch clusterrole zen-watcher --type='json' \
  -p='[{"op": "add", "path": "/rules/-", "value": {
    "apiGroups": ["wgpolicyk8s.io"],
    "resources": ["policyreports", "clusterpolicyreports"],
    "verbs": ["get", "list", "watch"]
  }}]'
```

**See documentation for complete RBAC requirements:**
- [RBAC Security Documentation](https://github.com/kube-zen/zen-watcher/blob/main/docs/SECURITY_RBAC.md)
- Example Ingesters: [Trivy](https://github.com/kube-zen/zen-watcher/blob/main/examples/ingesters/trivy-informer.yaml), [Kyverno](https://github.com/kube-zen/zen-watcher/blob/main/examples/ingesters/kyverno-informer.yaml)

### 4. Webhook Reachability & Authentication

**Default service type**: `ClusterIP` (internal cluster access only)

**For external webhook sources** (e.g., Falco, external tools calling `/ingest/...`), configure Ingress or LoadBalancer:

```yaml
# values.yaml
service:
  type: LoadBalancer  # Or use Ingress controller
```

**Production webhook authentication**:

1. **Enable per-Ingester authentication** (recommended):
   ```yaml
   # Ingester CRD spec
   spec:
     webhook:
       auth:
         type: bearer  # or basic
         secretRef: webhook-auth-secret
   ```

2. **Configure trusted proxy CIDRs** (if behind load balancer):
   ```yaml
   server:
     trustedProxyCIDRs:
       - "10.0.0.0/8"  # Your load balancer/proxy CIDR
   ```

**Documentation:**
- [Webhook Authentication](https://github.com/kube-zen/zen-watcher/blob/main/docs/SOURCE_ADAPTERS.md#authentication-configuration)
- [Ingester API](https://github.com/kube-zen/zen-watcher/blob/main/docs/INGESTER_API.md#webhook-ingester)

### 5. Ensure Ingestion is Enabled

**⚠️ WARNING**: Without an Ingester, zen-watcher will run but produce zero Observations.

**On first install**, either:

**Option A**: Enable default Kubernetes Events Ingester
```bash
helm install zen-watcher kube-zen/zen-watcher \
  --set ingester.createDefaultK8sEvents=true
```

**Option B**: Manually apply an Ingester after install (see Quick Start above)

**Verify ingestion is working:**
```bash
# Generate a test event
kubectl run test-pod --image=nginx --restart=Never
kubectl delete pod test-pod

# Check for Observations (should appear within seconds)
kubectl get observations -A
```

---

## Production Hardening Checklist

Before deploying to production with real traffic, complete these hardening steps:

### 1. Supply Chain Controls

**Pin image tags** (never use `latest`):
```yaml
image:
  tag: "1.0.19"  # Use specific version tag
```

**Vulnerability scanning and SBOM**:
- Run Trivy scan: `trivy image kubezen/zen-watcher:1.0.19`
- Generate SBOM: `syft kubezen/zen-watcher:1.0.19 -o spdx-json`
- Review scan results before deployment

**Image signing and verification**:
- Sign images with Cosign: See [COSIGN.md](https://github.com/kube-zen/zen-watcher/blob/main/docs/COSIGN.md)
- Verify signatures in CI/CD pipeline
- Configure admission controllers to reject unsigned images

**Documentation:**
- [Image and Registry Guide](https://github.com/kube-zen/zen-watcher/blob/main/docs/IMAGE_AND_REGISTRY_GUIDE.md)
- [Cosign Signing Guide](https://github.com/kube-zen/zen-watcher/blob/main/docs/COSIGN.md)

### 2. Retention/etcd Safety

**Confirm TTL/GC defaults are acceptable:**

Default values:
- `OBSERVATION_TTL_SECONDS`: 604800 (7 days)
- `GC_INTERVAL`: 1h (1 hour)
- `GC_TIMEOUT`: 5m (5 minutes)

**For high-volume deployments**, configure:

```yaml
# values.yaml
extraEnv:
  - name: OBSERVATION_TTL_SECONDS
    value: "2592000"  # 30 days (adjust based on retention requirements)
  - name: GC_INTERVAL
    value: "30m"      # More frequent GC for high volume
  - name: GC_TIMEOUT
    value: "10m"      # Longer timeout for large cleanup operations
```

**Capacity planning:**
- Estimate etcd storage: ~2-5KB per Observation × expected volume × retention days
- Plan noise filtering: Configure filters in Ingester CRDs to reduce volume
- Set resource quotas: Limit Observation CRD creation rate if needed

**Documentation:**
- [Configuration Guide](https://github.com/kube-zen/zen-watcher/blob/main/docs/CONFIGURATION.md#ttl-configuration)
- [Performance Tuning](https://github.com/kube-zen/zen-watcher/blob/main/docs/PERFORMANCE.md)

### 3. Observability

**Ensure metrics scraping works with NetworkPolicy:**

If NetworkPolicy is enabled, verify Prometheus can scrape metrics:

```yaml
# values.yaml
networkPolicy:
  ingress:
    metricsNamespaces:
      kubernetes.io/metadata.name: monitoring  # Adjust to your Prometheus namespace
```

**Import dashboards:**
- Grafana dashboards: `config/dashboards/*.json`
- Import via Grafana UI or ConfigMap
- Verify all panels show data after deployment

**Wire alert rules:**
- Prometheus alert rules: `config/monitoring/prometheus-rules.yaml`
- AlertManager configuration: `config/alertmanager/alertmanager.yml`
- Review alert thresholds with production data (adjust as needed)

**Verify metrics endpoint:**
```bash
# Test metrics endpoint
kubectl port-forward -n zen-system svc/zen-watcher-metrics 8080:8080
curl http://localhost:8080/metrics | grep zen_watcher
```

**Documentation:**
- [Observability Guide](https://github.com/kube-zen/zen-watcher/blob/main/docs/OBSERVABILITY.md)
- [Dashboard Guide](https://github.com/kube-zen/zen-watcher/blob/main/docs/DASHBOARD_GUIDE.md)
- [Alerting Integration Guide](https://github.com/kube-zen/zen-watcher/blob/main/docs/alerting/ALERTING-INTEGRATION-GUIDE.md)

### 4. Operational Readiness

**Runbook and rollback plan:**

- **Runbook**: See [OPERATIONAL_EXCELLENCE.md](https://github.com/kube-zen/zen-watcher/blob/main/docs/OPERATIONAL_EXCELLENCE.md)
- **Rollback procedure**: See [STABILITY.md](https://github.com/kube-zen/zen-watcher/blob/main/docs/STABILITY.md#upgrade--migration)

**Key operational procedures:**
1. **Upgrade procedure**: Zero-downtime upgrades with multiple replicas
2. **Rollback procedure**: `helm rollback zen-watcher -n zen-system`
3. **Troubleshooting**: Health checks, log analysis, metrics review
4. **Capacity planning**: Resource sizing, etcd impact estimation

**Documentation:**
- [Operational Excellence](https://github.com/kube-zen/zen-watcher/blob/main/docs/OPERATIONAL_EXCELLENCE.md)
- [Stability and Reliability](https://github.com/kube-zen/zen-watcher/blob/main/docs/STABILITY.md)
- [Troubleshooting Guide](https://github.com/kube-zen/zen-watcher/blob/main/docs/TROUBLESHOOTING.md)

---

## More Information

- [zen-watcher Documentation](https://github.com/kube-zen/zen-watcher)
- [zen-watcher Source Code](https://github.com/kube-zen/zen-watcher)


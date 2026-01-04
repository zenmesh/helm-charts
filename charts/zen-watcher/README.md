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

### GitOps Exception (Advanced)

For GitOps workflows (ArgoCD, Flux, etc.) where you want to manage CRDs separately:

```bash
# Disable CRD installation in the chart
helm install zen-watcher kube-zen/zen-watcher \
  --namespace zen-system \
  --create-namespace \
  --set crds.enabled=false

# Apply CRDs separately via GitOps or manually
kubectl apply -f https://raw.githubusercontent.com/kube-zen/zen-watcher/main/deployments/crds/observation_crd.yaml
kubectl apply -f https://raw.githubusercontent.com/kube-zen/zen-watcher/main/deployments/crds/ingester_crd.yaml
```

**When to disable:**
- GitOps workflows where CRDs are managed in a separate Git repository
- Multi-cluster deployments where CRDs are installed once globally
- Enterprise environments with strict CRD lifecycle management policies

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
| `crds.enabled` | Install CRDs with chart (Observation + Ingester) | `true` |
| `rbac.create` | Create RBAC resources | `true` |
| `rbac.namespaceOnlyMode` | Use namespace-scoped RBAC (Role/RoleBinding) | `false` |
| `ingester.createDefaultK8sEvents` | Create default Kubernetes Events Ingester | `false` |

## More Information

- [zen-watcher Documentation](https://github.com/kube-zen/zen-watcher)
- [zen-watcher Source Code](https://github.com/kube-zen/zen-watcher)


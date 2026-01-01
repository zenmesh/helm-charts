# zen-watcher

Universal Kubernetes Event Aggregator - Secure, Extensible Event Collection

## Introduction

zen-watcher is a Kubernetes operator that aggregates structured signals from security, compliance, and infrastructure tools into unified `Observation` CRDs.

## Prerequisites

- Kubernetes 1.26+
- Helm 3.8+

## Installing the Chart

To install the chart with the release name `zen-watcher`:

```bash
helm install zen-watcher kube-zen/zen-watcher \
  --namespace zen-watcher-system \
  --create-namespace
```

## Uninstalling the Chart

To uninstall/delete the `zen-watcher` deployment:

```bash
helm uninstall zen-watcher --namespace zen-watcher-system
```

## CRD Installation and Lifecycle

### CRD Installation Toggle

By default, CRDs are **not installed** by the Helm chart (`crds.enabled=false`). This allows CRDs to be managed separately via GitOps or other tooling.

To install CRDs with the chart:

```bash
helm install zen-watcher kube-zen/zen-watcher \
  --namespace zen-watcher-system \
  --create-namespace \
  --set crds.enabled=true
```

### Recommended Workflow

**For Production (GitOps):**
1. Install CRDs once via `crds.enabled=true` or apply manually
2. Set `crds.enabled=false` for subsequent upgrades
3. Manage CRD updates separately via GitOps (ArgoCD, Flux, etc.)

**For Development:**
- Keep `crds.enabled=true` for convenience

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
| `replicaCount` | Number of replicas | `1` |
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

## More Information

- [zen-watcher Documentation](https://github.com/kube-zen/zen-watcher)
- [zen-watcher Source Code](https://github.com/kube-zen/zen-watcher)


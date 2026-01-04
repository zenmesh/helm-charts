# zen-suite

Umbrella Helm chart for Kube-Zen platform components. This chart provides a convenient way to install and manage multiple Kube-Zen components together.

## Overview

The zen-suite chart is a reference installation that bundles:
- **zen-lock**: Zero-Knowledge secret manager for Kubernetes
- **zen-flow**: Kubernetes-native job orchestration controller
- **zen-gc**: Generic Garbage Collection Controller
- **zen-watcher**: Universal Kubernetes Event Aggregator

## Installation

### Quick Start (Install All)

```bash
# Add repository
helm repo add kube-zen https://kube-zen.github.io/helm-charts
helm repo update

# Install all components
helm install zen-suite kube-zen/zen-suite \
  --namespace zen-system \
  --create-namespace
```

### Install with zen-lead (Optional)

Enable zen-lead for network-only leader election (Profile A):

```bash
helm install zen-suite kube-zen/zen-suite \
  --namespace zen-system \
  --create-namespace \
  --set zenLead.enabled=true
```

### Install with Observation GC Integration

Enable automatic pruning of zen-watcher Observations via zen-gc:

```bash
helm install zen-suite kube-zen/zen-suite \
  --namespace zen-system \
  --create-namespace \
  --set integrations.observationsGc.enabled=true
```

**Prerequisites**: `zenGc.enabled=true` and `zenWatcher.enabled=true` (enabled by default)

### Install with Observation CRD

Enable Observation CRD installation (suite-managed):

```bash
helm install zen-suite kube-zen/zen-suite \
  --namespace zen-system \
  --create-namespace
```

**Note**: The Observation CRD is automatically installed by the `zen-watcher` chart. No separate CRD installation is needed.

### Selective Installation

Enable only the components you need:

```bash
helm install zen-suite kube-zen/zen-suite \
  --namespace zen-system \
  --create-namespace \
  --set zenLock.enabled=true \
  --set zenFlow.enabled=false \
  --set zenGc.enabled=true \
  --set zenWatcher.enabled=true
```

## Configuration

Each component's configuration can be passed through to its respective subchart:

```yaml
zenLock:
  enabled: true
  # zen-lock specific values
  replicaCount: 1
  image:
    repository: kubezen/zen-lock
    tag: "0.0.1-alpha"

zenFlow:
  enabled: true
  # zen-flow specific values

zenGc:
  enabled: true
  # zen-gc specific values

zenWatcher:
  enabled: true
  # zen-watcher specific values

zenLead:
  enabled: false  # Enable zen-lead for network-only leader election

integrations:
  observationsGc:
    enabled: false  # Enable Observation GC integration (zen-watcher → zen-gc)
    targetNamespace: ""  # Empty = cluster-wide
    ttl:
      fieldPath: "spec.ttlSecondsAfterCreation"
      defaultSeconds: 604800  # 7 days
    behavior:
      dryRun: false
      batchSize: 200
      maxDeletionsPerSecond: 5
      propagationPolicy: Background
```

See individual component charts for detailed configuration options:
- [zen-lock](../zen-lock/README.md)
- [zen-flow](../zen-flow/README.md)
- [zen-gc](../zen-gc/README.md)
- [zen-watcher](../zen-watcher/README.md)

## CRD Handling

Each component chart manages its own CRDs. The suite chart does not duplicate CRDs - they are installed as part of each component's chart.

**Observation CRD**: The Observation CRD is automatically installed by the `zen-watcher` chart.

CRDs are installed in the following order:
1. zen-lock CRDs
2. zen-flow CRDs
3. zen-gc CRDs
4. zen-watcher CRDs (includes Observation CRD)

## Production Recommendations

For production deployments, we recommend:
1. **Install components individually** rather than using the suite chart
2. This provides better control over versions, namespaces, and resource allocation
3. Allows for staged rollouts and independent upgrades

See [INSTALL.md](../../docs/INSTALL.md) for production guidance.

## Upgrades

See [UPGRADES.md](../../docs/UPGRADES.md) for upgrade procedures and CRD upgrade expectations.

## Version Compatibility

See [COMPATIBILITY.md](../../docs/COMPATIBILITY.md) for the compatibility matrix between suite versions and component chart versions.


# zen-suite

Umbrella Helm chart for Kube-Zen platform components. This chart provides a convenient way to install and manage multiple Kube-Zen components together.

## Overview

The zen-suite chart is a reference installation that bundles:
- **zen-lock**: Zero-Knowledge secret manager for Kubernetes
- **zen-flow**: Kubernetes-native job orchestration controller
- **zen-gc**: Generic Garbage Collection Controller
- **zen-watcher**: Universal Kubernetes Event Aggregator

## Installation

### Quick Start (All Components)

```bash
# Add repository
helm repo add kube-zen https://kube-zen.github.io/helm-charts
helm repo update

# Install all components
helm install zen-suite kube-zen/zen-suite \
  --namespace zen-system \
  --create-namespace
```

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
```

See individual component charts for detailed configuration options:
- [zen-lock](../zen-lock/README.md)
- [zen-flow](../zen-flow/README.md)
- [zen-gc](../zen-gc/README.md)
- [zen-watcher](../zen-watcher/README.md)

## CRD Handling

Each component chart manages its own CRDs. The suite chart does not duplicate CRDs - they are installed as part of each component's chart.

CRDs are installed in the following order:
1. zen-lock CRDs
2. zen-flow CRDs
3. zen-gc CRDs
4. zen-watcher CRDs

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


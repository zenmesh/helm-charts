# zen-suite

Umbrella Helm chart that installs the standalone Zen Mesh component charts together in one release.

## What it installs

- **zen-lock**: zero-knowledge secret manager for Kubernetes
- **zen-flow**: Kubernetes-native job orchestration controller
- **zen-gc**: generic garbage-collection controller

Each component can be enabled or disabled on its own.

## Installation

```bash
helm repo add zenmesh https://zenmesh.github.io/helm-charts
helm repo update

helm install zen-suite zenmesh/zen-suite \
  --namespace zen-system \
  --create-namespace
```

Only the components you need:

```bash
helm install zen-suite zenmesh/zen-suite \
  --namespace zen-system \
  --create-namespace \
  --set zenLock.enabled=true \
  --set zenFlow.enabled=false \
  --set zenGc.enabled=true
```

## Configuration

Each component's values are passed through to its subchart:

```yaml
zenLock:
  enabled: true
  # zen-lock values — see charts/zen-lock/README.md

zenFlow:
  enabled: true
  # zen-flow values — see charts/zen-flow/README.md

zenGc:
  enabled: true
  # zen-gc values — see charts/zen-gc/README.md
```

The guides for the subcharts:

- [zen-lock](../zen-lock/README.md)
- [zen-flow](../zen-flow/README.md)
- [zen-gc](../zen-gc/README.md)

## Changes in 0.0.3-alpha

`zen-watcher` and `zen-lead` are no longer part of this chart. Both products are proprietary and are no longer published. The Observation garbage-collection integration, which depended on `zen-watcher`, was removed with it.

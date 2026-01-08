# zen-agent

Kube-ZEN Cluster Agent for SaaS connectivity.

## Description

zen-agent is the cluster-side component that connects your Kubernetes cluster to the Kube-ZEN SaaS platform. It handles:

- Initial cluster enrollment using bootstrap tokens
- Secret management for cluster credentials
- Adapter registration and synchronization
- Health reporting and heartbeat

## Installation

```bash
helm repo add kube-zen https://kube-zen.github.io/helm-charts
helm repo update

helm upgrade --install zen-agent kube-zen/zen-agent \
  --namespace zen-system \
  --create-namespace \
  --set saas.endpoint="https://api.kube-zen.io" \
  --set saas.clusterToken="YOUR_BOOTSTRAP_TOKEN" \
  --set tenant.id="YOUR_TENANT_ID" \
  --set cluster.id="YOUR_CLUSTER_ID"
```

## Configuration

### Required Values

- `saas.endpoint`: SaaS API endpoint URL
- `saas.clusterToken` or `bootstrap.token`: Bootstrap token for initial enrollment
- `tenant.id`: Tenant ID
- `cluster.id`: Cluster ID

### Optional Values

See `values.yaml` for all available configuration options.

## License

Copyright 2025 Kube-ZEN Contributors

Licensed under the Apache License, Version 2.0


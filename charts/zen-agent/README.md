# zen-agent

Kube-ZEN Cluster Agent for SaaS connectivity.

## Description

zen-agent is the cluster-side component that connects your Kubernetes cluster to the Kube-ZEN SaaS platform. It handles:

- Initial cluster enrollment using bootstrap tokens
- Secret management for cluster credentials
- Adapter registration and synchronization
- Health reporting and heartbeat

## Installation

Use the install bundle (base64-encoded age bundle) from the SaaS UI. Same-cluster: use the in-cluster back URL for `saas.endpoint`.

```bash
helm repo add kube-zen https://kube-zen.github.io/helm-charts
helm repo update

helm upgrade --install zen-agent kube-zen/zen-agent \
  --namespace zen-mesh \
  --create-namespace \
  --set saas.endpoint="https://api.kube-zen.io" \
  --set-string enrollment.bundle='<BASE64_ENROLLMENT_BUNDLE_FROM_UI>'
```

Same k3d cluster (in-cluster URL):

```bash
--set saas.endpoint="http://zen-saas-back.zen-apps.svc.cluster.local:8080"
```

## Configuration

### Required Values

- `saas.endpoint`: SaaS API base URL (e.g. `https://api.kube-zen.io` or in-cluster `http://zen-saas-back.zen-apps.svc.cluster.local:8080`)
- `enrollment.bundle`: Base64-encoded enrollment bundle from the SaaS UI (install-bundle). Pass with `--set-string enrollment.bundle='...'`

### Optional Values

See `values.yaml` for all available configuration options.

## License

Copyright 2025 Kube-ZEN Contributors

Licensed under the Apache License, Version 2.0


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
  --set agent.enrollment.bundle='<BASE64_BUNDLE>'
```

Same k3d cluster (in-cluster URL):

```bash
--set saas.endpoint="http://zen-saas-back.zen-apps.svc.cluster.local:8080"
```

## Configuration

**Contract:** Only `agent.saasBaseURL` (or `saas.endpoint`) and `agent.enrollment.bundle`. No `tenantID`/`clusterID`, no SecretRef, no files. Identity comes from the bundle (server derives it at bootstrap).

### Required Values

- `saas.endpoint` or `agent.saasBaseURL`: SaaS API base URL (e.g. `https://api.kube-zen.io` or in-cluster `http://zen-saas-back.zen-apps.svc.cluster.local:8080`)
- `agent.enrollment.bundle`: Base64 enrollment bundle from install-bundle. Required when `agent.enrollment.enabled=true`. Pass with `--set agent.enrollment.bundle="<BASE64_BUNDLE>"`

### Optional Values

See `values.yaml` for all available configuration options.

## RBAC contract

zen-agent must run with a ServiceAccount that has the following permissions so adapter sync and enrollment work. The chart creates these when `rbac.create: true` (default).

- **Secrets (namespace-scoped)**  
  The SA must be able to **get**, **list**, **watch**, **create**, **update**, and **patch** Secrets in the same namespace as the agent (e.g. `zen-mesh`).  
  - **Cluster credential:** zen-agent reads the cluster key from a Secret named `zen-cluster-cred-<cluster_id>` (cluster_id sanitized: `/` → `-`). Exactly one such Secret must exist in the namespace after bootstrap.  
  - **Adapter credentials:** zen-agent writes Secrets named `zen-adapter-cred-<adapter_id>` (adapter_id sanitized) in the same or target namespace.  
  If the SA cannot list/get Secrets, bulk sync fails with "forbidden" or "not found"; fix RBAC in the agent namespace before debugging further.

- **ConfigMaps (cluster-wide for adapter discovery)**  
  The chart grants the SA a ClusterRole to **get**, **list**, **watch**, **update**, and **patch** ConfigMaps so it can discover ZenAdapter ConfigMaps (label `zen.kubezen.io/adapter=true`).

- **Events**  
  The SA can **create** and **patch** Events in its namespace for observability.

**Quick check:**  
`kubectl auth can-i get,list secrets --as=system:serviceaccount:<namespace>:zen-agent -n <namespace>`

## License

Copyright 2025 Kube-ZEN Contributors

Licensed under the Apache License, Version 2.0


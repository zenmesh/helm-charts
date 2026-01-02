# zen-lead Helm Chart

A Helm chart for deploying zen-lead - Non-invasive leader election for Kubernetes workloads.

## Introduction

zen-lead provides **network-level single-active routing** via a selector-less Service and controller-managed EndpointSlice. It enables high availability for any Kubernetes workload without requiring application code changes or mutating workload pods.

## Key Features

- ✅ **Non-invasive**: No pod mutation, no changes to user resources
- ✅ **Service-first opt-in**: Annotate any Service with `zen-lead.io/enabled: "true"`
- ✅ **Zero code changes**: Applications don't need to know about leader election
- ✅ **Automatic failover**: Controller-driven leader selection based on pod readiness
- ✅ **Secure defaults**: Minimal RBAC, always-on leader election for HA

## Prerequisites

- Kubernetes 1.24+
- kubectl configured to access your cluster
- Helm 3.0+

## Installation

### Add the Helm Repository

```bash
helm repo add zen-lead https://kube-zen.github.io/zen-lead/charts
helm repo update
```

### Install the Chart

To install the chart with the release name `zen-lead`:

```bash
helm install zen-lead zen-lead/zen-lead \
  --namespace zen-lead-system \
  --create-namespace
```

### Install with Custom Values

```bash
helm install zen-lead zen-lead/zen-lead \
  --namespace zen-lead-system \
  --create-namespace \
  --set image.tag=0.1.0 \
  --set replicaCount=2
```

### Install with Custom Cache Size

For large clusters with many Services per namespace, increase the cache size:

```bash
helm install zen-lead zen-lead/zen-lead \
  --namespace zen-lead-system \
  --create-namespace \
  --set controller.maxCacheSizePerNamespace=5000
```

**Tuning guidance:**
- Small clusters (<100 Services/namespace): Default (1000) is sufficient
- Medium clusters (100-1000 Services): Default (1000) works well
- Large clusters (>1000 Services): Increase to 2000-5000
- Very large clusters (>5000 Services): Consider 10000

Monitor `zen_lead_cache_size`, `zen_lead_cache_hits_total`, and `zen_lead_cache_misses_total` metrics to tune.

### Install from Local Chart

```bash
helm install zen-lead ./charts/zen-lead \
  --namespace zen-lead-system \
  --create-namespace
```

## Configuration

The following table lists the configurable parameters and their default values:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of controller replicas | `2` |
| `image.repository` | Controller image repository | `kubezen/zen-lead` |
| `image.tag` | Controller image tag | `0.1.0` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `serviceAccount.create` | Create service account | `true` |
| `serviceAccount.name` | Service account name | `""` |
| `leaderElectionID` | Leader election ID (must be unique per instance) | `""` (defaults to release-name-based) |
| `controller.maxCacheSizePerNamespace` | Maximum cached Services per namespace (LRU eviction) | `1000` |
| `controller.maxConcurrentReconciles` | Maximum concurrent reconciliations | `10` |
| `controller.cacheUpdateTimeoutSeconds` | Timeout for cache update operations (seconds) | `10` |
| `controller.metricsCollectionTimeoutSeconds` | Timeout for metrics collection operations (seconds) | `5` |
| `controller.qps` | Kubernetes API client QPS (queries per second) | `50` |
| `controller.burst` | Kubernetes API client burst limit | `100` |
| `rbac.clusterScoped` | Use ClusterRole/ClusterRoleBinding | `true` |
| `namespace.create` | Create namespace | `true` |
| `namespace.name` | Namespace name | `zen-lead-system` |

## Usage

### Step 1: Install zen-lead

```bash
helm install zen-lead zen-lead/zen-lead \
  --namespace zen-lead-system \
  --create-namespace
```

### Step 2: Opt-in a Service

Annotate your Service with `zen-lead.io/enabled: "true"`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  annotations:
    zen-lead.io/enabled: "true"
    zen-lead.io/leader-service-name: "my-app-leader"  # optional
spec:
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
```

### Step 3: Use the Leader Service

zen-lead automatically creates `my-app-leader` Service that routes to exactly one Ready pod:

```yaml
# Your application config
env:
- name: SERVICE_NAME
  value: my-app-leader  # Points only to current leader
```

## How It Works

1. **Opt-in**: User annotates a Service with `zen-lead.io/enabled: "true"`
2. **Leader Selection**: Controller selects leader pod (oldest Ready pod, sticky)
3. **Leader Service**: Controller creates selector-less `<service-name>-leader` Service
4. **EndpointSlice**: Controller manages EndpointSlice pointing to leader pod IP
5. **Failover**: When leader becomes unhealthy, controller selects new leader and updates EndpointSlice

## Non-Invasive Guarantees

- ✅ **No pod mutation**: Workload pods are never patched or labeled
- ✅ **No webhook**: No admission webhooks (removed for day-0)
- ✅ **No Service changes**: Original Service continues working normally
- ✅ **Clear ownership**: All generated resources are labeled and owned

## Limitations

- **Network-level routing only**: Does not guarantee application-level correctness
- **Failover latency**: Bounded by readiness transition + controller reconcile + kube-proxy update (~2-3 seconds)
- **Long-lived connections**: May survive failover until reconnection

## Examples

### Deployment + Service

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
---
apiVersion: v1
kind: Service
metadata:
  name: my-app
  annotations:
    zen-lead.io/enabled: "true"
spec:
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
```

Result: `my-app-leader` Service routes to exactly one Ready pod.

### Multi-Port Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  annotations:
    zen-lead.io/enabled: "true"
spec:
  selector:
    app: my-app
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: metrics
    port: 9090
    targetPort: 9090
```

Result: Leader Service mirrors all ports from source Service.

## Uninstallation

```bash
helm uninstall zen-lead --namespace zen-lead-system
```

**Note**: Uninstalling zen-lead does NOT delete leader Services or EndpointSlices. They will be garbage-collected when the source Service is deleted (via ownerReferences).

## Troubleshooting

### Check Controller Status

```bash
kubectl get pods -n zen-lead-system
kubectl logs -n zen-lead-system deployment/zen-lead
```

### Check Leader Service

```bash
# List leader Services
kubectl get svc -A -l app.kubernetes.io/managed-by=zen-lead

# Check EndpointSlice
kubectl get endpointslice -A -l endpointslice.kubernetes.io/managed-by=zen-lead
```

### Verify Opt-in

```bash
# Check Service annotations
kubectl get svc my-app -o jsonpath='{.metadata.annotations.zen-lead\.io/enabled}'
```

## Support

- **Documentation**: https://github.com/kube-zen/zen-lead/blob/main/README.md
- **Issues**: https://github.com/kube-zen/zen-lead/issues
- **Source**: https://github.com/kube-zen/zen-lead


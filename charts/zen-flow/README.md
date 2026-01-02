# zen-flow Helm Chart

A Helm chart for deploying zen-flow - Kubernetes-native job orchestration controller.

## Introduction

zen-flow is a Kubernetes-native job orchestration controller that provides declarative, sequential execution of Kubernetes Jobs using standard CRDs. It addresses the critical gap between isolated Kubernetes Jobs and heavyweight workflow engines like Argo Workflows.

## Prerequisites

- Kubernetes 1.24+
- kubectl configured to access your cluster
- Helm 3.0+

## Installation

### Add the Helm Repository

```bash
helm repo add zen-flow https://kube-zen.github.io/zen-flow/charts
helm repo update
```

### Install the Chart

To install the chart with the release name `zen-flow`:

```bash
helm install zen-flow zen-flow/zen-flow \
  --namespace zen-flow-system \
  --create-namespace
```

### Install with Custom Values

```bash
helm install zen-flow zen-flow/zen-flow \
  --namespace zen-flow-system \
  --create-namespace \
  --set image.tag=0.0.1-alpha \
  --set replicaCount=2 \
  --set webhook.enabled=true
```

### Install from Local Chart

```bash
helm install zen-flow ./charts/zen-flow \
  --namespace zen-flow-system \
  --create-namespace
```

## Configuration

The following table lists the configurable parameters and their default values:

### Basic Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of controller replicas | `2` |
| `image.repository` | Controller image repository | `kubezen/zen-flow-controller` |
| `image.tag` | Controller image tag | `0.0.1-alpha` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `serviceAccount.create` | Create service account | `true` |
| `serviceAccount.name` | Service account name | `""` |
| `webhook.enabled` | Enable webhooks | `false` |
| `webhook.certManager.enabled` | Use cert-manager for certificates | `false` |
| `leaderElection.mode` | Leader election mode | `builtin` |
| `leaderElection.electionID` | Leader election ID | `""` (auto-generated) |
| `controller.maxConcurrentReconciles` | Max concurrent reconciles | `10` |

### Controller Configuration

All configuration values are optional and have sensible defaults. See `docs/CONFIGURATION.md` for detailed documentation.

#### Resource Limits

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.defaultTTLSeconds` | Default TTL for completed JobFlows (seconds) | `86400` (24 hours) |
| `config.configMapSizeLimit` | Maximum size for ConfigMap artifacts (bytes) | `1048576` (1MB) |
| `config.uidTruncateLength` | Length to truncate UIDs in resource names | `8` |

#### Retry and Backoff

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.defaultBackoffLimit` | Default backoff limit for Jobs | `6` |
| `config.defaultRetryLimit` | Default retry limit | `3` |
| `config.defaultBackoffBase` | Base duration for exponential backoff | `"1s"` |
| `config.defaultBackoffFactor` | Multiplier for exponential backoff | `2.0` |

#### File Permissions

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.defaultDirPerm` | Default directory permissions (octal) | `"0755"` |
| `config.defaultFilePerm` | Default file permissions (octal) | `"0644"` |

#### Default Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.defaultConfigMapKey` | Default key name for ConfigMap values | `"value"` |
| `config.defaultContainerName` | Default container name in Job templates | `"main"` |
| `config.defaultConcurrencyPolicy` | Default concurrency policy | `"Forbid"` |
| `config.defaultContentType` | Default content type for artifacts | `"application/octet-stream"` |
| `config.defaultArchiveFormat` | Default archive format (tar or zip) | `"tar"` |
| `config.defaultCompression` | Default compression (none or gzip) | `"none"` |
| `metrics.enabled` | Enable metrics | `true` |
| `metrics.serviceMonitor.enabled` | Create ServiceMonitor for Prometheus | `false` |
| `prometheus.rules.enabled` | Install Prometheus rules | `false` |
| `grafana.dashboard.enabled` | Install Grafana dashboard | `false` |
| `crd.install` | Install CRDs as part of Helm install | `true` |
| `namespace.create` | Create namespace | `true` |
| `namespace.name` | Namespace name | `zen-flow-system` |
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `256Mi` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `64Mi` |

## Webhook Configuration

### Using cert-manager

If you have cert-manager installed, you can enable automatic certificate management:

```yaml
webhook:
  enabled: true
  certManager:
    enabled: true
    issuer:
      name: letsencrypt-prod
      kind: ClusterIssuer
```

### Manual Certificate Management

If not using cert-manager, you need to manually create the certificate secret:

```bash
kubectl create secret tls zen-flow-webhook-cert \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n zen-flow-system
```

## Uninstallation

To uninstall/delete the `zen-flow` deployment:

```bash
helm uninstall zen-flow --namespace zen-flow-system
```

**Note:** CRDs are not removed by default. To remove CRDs:

```bash
kubectl delete crd jobflows.workflow.kube-zen.io
```

## Examples

### High Availability Deployment

```yaml
replicaCount: 3
leaderElection:
  enabled: true
resources:
  requests:
    cpu: 200m
    memory: 128Mi
  limits:
    cpu: 1000m
    memory: 512Mi
```

### Development Deployment

```yaml
replicaCount: 1
webhook:
  enabled: false
leaderElection:
  enabled: false
resources:
  requests:
    cpu: 50m
    memory: 32Mi
  limits:
    cpu: 200m
    memory: 128Mi
```

### Production Deployment with Monitoring

```yaml
replicaCount: 2
webhook:
  enabled: true
  certManager:
    enabled: true
    issuer:
      name: letsencrypt-prod
      kind: ClusterIssuer
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
prometheus:
  rules:
    enabled: true
grafana:
  dashboard:
    enabled: true
```

## Troubleshooting

### Webhook Certificate Issues

If webhooks are failing, check the certificate:

```bash
kubectl get secret zen-flow-webhook-cert -n zen-flow-system
kubectl describe validatingwebhookconfiguration zen-flow-validating-webhook
```

### Controller Not Starting

Check controller logs:

```bash
kubectl logs -n zen-flow-system deployment/zen-flow-controller
```

### CRD Not Found

Ensure CRDs are installed:

```bash
kubectl get crd jobflows.workflow.kube-zen.io
```

If missing, install manually:

```bash
kubectl apply -f deploy/crds/
```

## Support

- **Issues**: [GitHub Issues](https://github.com/kube-zen/zen-flow/issues)
- **Documentation**: [GitHub Wiki](https://github.com/kube-zen/zen-flow/wiki)

## License

Licensed under the Apache License, Version 2.0.


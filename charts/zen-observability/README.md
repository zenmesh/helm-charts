# Zen Observability Stack

Helm chart for deploying VictoriaMetrics and Grafana observability stack for Zen Platform.

## Overview

This chart deploys:
- **VictoriaMetrics**: High-performance metrics storage (Prometheus-compatible)
- **Grafana**: Visualization and dashboards
- **Alert Rules**: Pre-configured Prometheus alert rules
- **Service/Pod Monitors**: Auto-discovery configuration

## Prerequisites

- Kubernetes 1.24+
- Helm 3.8+
- PersistentVolume support (for metrics and dashboard storage)

## Installation

### Basic Installation

```bash
# Add VictoriaMetrics Helm repo
helm repo add vm https://victoriametrics.github.io/helm-charts/
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install the observability stack
helm install zen-observability ./helm-charts/charts/zen-observability \
  --namespace zen-monitoring \
  --create-namespace \
  --set grafana.adminPassword=<YOUR_PASSWORD>
```

### Production Installation

```bash
# Create namespace
kubectl create namespace zen-monitoring

# Create Grafana admin password secret
kubectl create secret generic grafana-admin \
  --from-literal=admin-password=<YOUR_PASSWORD> \
  -n zen-monitoring

# Install with production values
helm install zen-observability ./helm-charts/charts/zen-observability \
  --namespace zen-monitoring \
  --values values-production.yaml \
  --set grafana.adminPassword=<YOUR_PASSWORD>
```

## Configuration

### VictoriaMetrics

Key configuration options:

```yaml
victoriametrics:
  enabled: true
  cluster:
    replicas: 3  # For HA
    retentionPeriod: "12"  # months
    storage:
      size: 100Gi  # Adjust based on retention
```

### Grafana

Key configuration options:

```yaml
grafana:
  enabled: true
  adminUser: admin
  adminPassword: ""  # Set via secret
  persistence:
    enabled: true
    size: 10Gi
```

### Ingress (Optional)

```yaml
grafana:
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: grafana.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana.example.com
```

## Accessing Grafana

### Port Forward

```bash
kubectl port-forward -n zen-monitoring svc/zen-observability-grafana 3000:80
```

Then access at: http://localhost:3000

### Ingress

If ingress is enabled, access via the configured hostname.

Default credentials:
- Username: `admin`
- Password: Set during installation

## Metrics Collection

### ServiceMonitor

Services can expose metrics by creating a ServiceMonitor:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: zen-back
  namespace: zen-saas
  labels:
    app: zen-observability
    component: servicemonitor
spec:
  selector:
    matchLabels:
      app: zen-back
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

### PodMonitor

For pod-level metrics:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: zen-watcher
  namespace: zen-saas
  labels:
    app: zen-observability
    component: podmonitor
spec:
  selector:
    matchLabels:
      app: zen-watcher
  podMetricsEndpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

## Alert Rules

Alert rules are automatically discovered from ConfigMaps with label `app=zen-observability,component=alertrules`.

See `templates/alert-rules.yaml` for pre-configured alerts.

## Dashboards

Dashboards are auto-provisioned from ConfigMaps with label `grafana_dashboard=1`.

Pre-configured dashboards:
- Zen Platform Overview
- Zen Platform Services
- Zen Platform Alerts

## Metrics Endpoints

All Zen Platform services expose Prometheus-compatible metrics:

| Service | Port | Endpoint |
|---------|------|----------|
| zen-back | 8080 | /metrics |
| zen-bff | 8080 | /metrics |
| zen-websocket | 9090 | /metrics |
| zen-watcher | 8080 | /metrics |
| zen-flow | 8080 | /metrics |
| zen-gc | 8080 | /metrics |
| zen-lock | 8080 | /metrics |
| zen-lead | 8080 | /metrics |

## Troubleshooting

### Check VictoriaMetrics Status

```bash
kubectl get pods -n zen-monitoring -l app.kubernetes.io/name=victoria-metrics-k8s-stack
kubectl logs -n zen-monitoring -l app.kubernetes.io/name=victoria-metrics-k8s-stack
```

### Check Grafana Status

```bash
kubectl get pods -n zen-monitoring -l app.kubernetes.io/name=grafana
kubectl logs -n zen-monitoring -l app.kubernetes.io/name=grafana
```

### Test Metrics Ingestion

```bash
# Port forward VictoriaMetrics
kubectl port-forward -n zen-monitoring svc/vmsingle-zen-observability-victoria-metrics-k8s-stack 8429:8429

# Query metrics
curl 'http://localhost:8429/api/v1/query?query=up'
```

### Check Service Discovery

```bash
# List ServiceMonitors
kubectl get servicemonitors -A

# List PodMonitors
kubectl get podmonitors -A

# Check discovered targets
kubectl port-forward -n zen-monitoring svc/vmsingle-zen-observability-victoria-metrics-k8s-stack 8429:8429
curl 'http://localhost:8429/targets'
```

## Uninstallation

```bash
helm uninstall zen-observability -n zen-monitoring
```

**Note**: This will delete all metrics data unless persistent volumes are retained.

## Storage Considerations

### VictoriaMetrics Storage

Storage requirements depend on:
- Retention period (default: 12 months)
- Number of metrics
- Scrape interval
- Number of labels

Estimate: ~1-2GB per 1M active time series per month

### Grafana Storage

Grafana storage is minimal (~100MB) unless storing dashboards/reports locally.

## Security

### Grafana Admin Password

Always set via Kubernetes Secret:

```bash
kubectl create secret generic grafana-admin \
  --from-literal=admin-password=<SECURE_PASSWORD> \
  -n zen-monitoring
```

Then reference in values:

```yaml
grafana:
  adminPassword:
    existingSecret: grafana-admin
    secretKey: admin-password
```

### Network Policies

Consider adding NetworkPolicies to restrict access to VictoriaMetrics and Grafana.

## Support

For issues or questions, see:
- [VictoriaMetrics Documentation](https://docs.victoriametrics.com/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)

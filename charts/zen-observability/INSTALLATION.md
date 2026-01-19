# Zen Observability Stack - Installation Guide

## Quick Start

```bash
# 1. Add Helm repositories
helm repo add vm https://victoriametrics.github.io/helm-charts/
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 2. Create namespace
kubectl create namespace zen-monitoring

# 3. Install observability stack
helm install zen-observability ./helm-charts/charts/zen-observability \
  --namespace zen-monitoring \
  --set grafana.adminPassword=<YOUR_SECURE_PASSWORD>
```

## Production Installation

### 1. Create Grafana Admin Secret

```bash
# Generate secure password
GRAFANA_PASSWORD=$(openssl rand -base64 32)

# Create secret
kubectl create secret generic grafana-admin \
  --from-literal=admin-password=$GRAFANA_PASSWORD \
  -n zen-monitoring
```

### 2. Install with Production Values

```bash
helm install zen-observability ./helm-charts/charts/zen-observability \
  --namespace zen-monitoring \
  --values values-production.yaml \
  --set grafana.adminPassword=$GRAFANA_PASSWORD
```

### 3. Configure Ingress (Optional)

Edit `values-production.yaml` and set:
- `grafana.ingress.enabled: true`
- `grafana.ingress.hosts[0].host: grafana.yourdomain.com`
- `grafana.ingress.tls[0].hosts[0]: grafana.yourdomain.com`

Then upgrade:

```bash
helm upgrade zen-observability ./helm-charts/charts/zen-observability \
  --namespace zen-monitoring \
  --values values-production.yaml
```

## Verification

### Check Pods

```bash
kubectl get pods -n zen-monitoring
```

Expected output:
```
NAME                                                      READY   STATUS    RESTARTS   AGE
zen-observability-victoria-metrics-k8s-stack-0           1/1     Running   0          2m
zen-observability-grafana-0                              1/1     Running   0          2m
```

### Check Services

```bash
kubectl get svc -n zen-monitoring
```

### Test VictoriaMetrics

```bash
# Port forward
kubectl port-forward -n zen-monitoring svc/vmsingle-zen-observability-victoria-metrics-k8s-stack 8429:8429

# Query metrics
curl 'http://localhost:8429/api/v1/query?query=up'
```

### Access Grafana

```bash
# Port forward
kubectl port-forward -n zen-monitoring svc/zen-observability-grafana 3000:80

# Open browser
open http://localhost:3000
# Login: admin / <YOUR_PASSWORD>
```

## Service Discovery Setup

To enable automatic metrics collection, add labels to your services:

### ServiceMonitor Example

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

### Service Labels

Add to your Service:

```yaml
metadata:
  labels:
    monitoring: enabled
spec:
  ports:
    - name: metrics
      port: 8080
      targetPort: 8080
```

## Uninstallation

```bash
helm uninstall zen-observability -n zen-monitoring
```

**Warning**: This will delete all metrics data unless you retain the PersistentVolumes.

## Troubleshooting

### VictoriaMetrics Not Starting

```bash
# Check logs
kubectl logs -n zen-monitoring -l app.kubernetes.io/name=victoria-metrics-k8s-stack

# Check PVC
kubectl get pvc -n zen-monitoring

# Check events
kubectl get events -n zen-monitoring --sort-by='.lastTimestamp'
```

### Grafana Not Starting

```bash
# Check logs
kubectl logs -n zen-monitoring -l app.kubernetes.io/name=grafana

# Check secret
kubectl get secret grafana-admin -n zen-monitoring
```

### No Metrics Being Collected

1. Check ServiceMonitor/PodMonitor labels match selector
2. Verify metrics endpoint is accessible:
   ```bash
   kubectl port-forward svc/zen-back 8080:8080
   curl http://localhost:8080/metrics
   ```
3. Check discovered targets:
   ```bash
   kubectl port-forward -n zen-monitoring svc/vmsingle-zen-observability-victoria-metrics-k8s-stack 8429:8429
   curl 'http://localhost:8429/targets'
   ```

## Next Steps

1. Configure ServiceMonitors for your services
2. Import/configure dashboards in Grafana
3. Set up alert notification channels (Slack, PagerDuty, etc.)
4. Review and adjust alert thresholds
5. Set up backup for Grafana dashboards

# KEDA Autoscaling for zen-cluster

## Overview

The `zen-cluster` Helm chart includes KEDA (Kubernetes Event-Driven Autoscaling) for intelligent, event-driven scaling of `zen-ingester` and `zen-egress` components.

## Quick Start

KEDA is **enabled by default** and will automatically install when you deploy the chart:

```bash
helm install zen-cluster charts/zen-cluster \
  --namespace zen-mesh \
  --create-namespace
```

## Configuration

### Enable/Disable KEDA

```yaml
# values.yaml
keda:
  enabled: true  # Install KEDA operator (default: true)
```

### Configure zen-ingester Autoscaling

```yaml
ingester:
  enabled: true
  keda:
    enabled: true  # Enable KEDA autoscaling for ingester
    minReplicas: 1
    maxReplicas: 50
    triggers:
      queueDepth: true   # Scale based on queue depth
      eventRate: true     # Scale based on event rate
      cpu: false         # CPU-based scaling (fallback)
    queueDepthThreshold: "1000"  # Scale up if queue > 1000
    eventRateThreshold: "100"    # Scale up if > 100 events/s
```

### Configure zen-egress Autoscaling

```yaml
egress:
  enabled: true
  keda:
    enabled: true  # Enable KEDA autoscaling for egress
    minReplicas: 1
    maxReplicas: 40
    triggers:
      queueDepth: true   # Scale based on queue depth
      eventRate: true     # Scale based on dispatch rate
      cpu: false         # CPU-based scaling (fallback)
    queueDepthThreshold: "500"  # Scale up if queue > 500
    eventRateThreshold: "80"    # Scale up if > 80 events/s
```

## Scaling Triggers

### Queue Depth Trigger

Scales based on the number of pending events in the queue:

```yaml
triggers:
  queueDepth: true
queueDepthThreshold: "1000"  # Scale up when queue exceeds this value
```

**Metrics Required:**
- `ingester_queue_depth` (for ingester)
- `egress_queue_depth` (for egress)

### Event Rate Trigger

Scales based on events processed per second:

```yaml
triggers:
  eventRate: true
eventRateThreshold: "100"  # Scale up when rate exceeds this value
```

**Metrics Required:**
- `ingester_events_total` (for ingester)
- `egress_events_total` (for egress)

### CPU Trigger (Fallback)

Traditional CPU-based scaling (can be used as fallback):

```yaml
triggers:
  cpu: true
cpuThreshold: "70"  # Scale up when CPU > 70%
```

## Prometheus Configuration

KEDA requires Prometheus for Prometheus-based triggers. Configure the Prometheus server address:

```yaml
ingester:
  keda:
    prometheusServer: "http://prometheus:9090"  # Default
```

## Verification

### Check KEDA Installation

```bash
# Check KEDA operator
kubectl get pods -n keda-system

# Check ScaledObjects
kubectl get scaledobjects -n zen-mesh

# Check HPA created by KEDA
kubectl get hpa -n zen-mesh | grep keda
```

### Monitor Scaling

```bash
# Watch pod count
kubectl get pods -n zen-mesh -w

# Check scaling events
kubectl get events -n zen-mesh --field-selector involvedObject.kind=ScaledObject

# Describe ScaledObject
kubectl describe scaledobject zen-cluster-ingester -n zen-mesh
```

## Migration from HPA

If you were using HPA before:

1. **Disable HPA:**
   ```yaml
   egress:
     autoscaling:
       enabled: false  # Disable legacy HPA
   ```

2. **Enable KEDA:**
   ```yaml
   egress:
     keda:
       enabled: true
   ```

3. **Upgrade:**
   ```bash
   helm upgrade zen-cluster charts/zen-cluster
   ```

## Troubleshooting

### ScaledObject Not Scaling

1. **Check KEDA operator logs:**
   ```bash
   kubectl logs -n keda-system -l app=keda-operator
   ```

2. **Verify metrics exist:**
   ```bash
   curl http://prometheus:9090/api/v1/query?query=ingester_queue_depth
   ```

3. **Check ScaledObject status:**
   ```bash
   kubectl describe scaledobject zen-cluster-ingester -n zen-mesh
   ```

### Metrics Not Available

If Prometheus metrics are not available:
- Ensure Prometheus is installed and accessible
- Verify service discovery is configured
- Check metric names match exactly (case-sensitive)

### Scaling Too Aggressively

- Increase `cooldownPeriod` (default: 300s)
- Adjust trigger thresholds
- Review `pollingInterval` (default: 30s)

## Best Practices

1. **Start Conservative**: Begin with higher thresholds and lower max replicas
2. **Monitor Metrics**: Ensure Prometheus metrics are accurate
3. **Test Scaling**: Load test to verify scaling behavior
4. **Review Logs**: Check KEDA operator logs regularly
5. **Gradual Rollout**: Enable KEDA on one component at a time

## License

KEDA is licensed under Apache License 2.0, which allows commercial use and distribution. See `src/shared/scaling/keda/LICENSING.md` for details.


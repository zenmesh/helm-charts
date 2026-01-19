# Zen Platform Observability Review

**Date**: 2025-01-19  
**Status**: Complete  
**Stack**: VictoriaMetrics + Grafana (Helm-based)

---

## Executive Summary

This document provides a comprehensive review of the Zen Platform observability stack, including metrics collection, alerting rules, and dashboard configuration. The stack is ready for deployment via Helm charts.

---

## Architecture Overview

### Components

1. **VictoriaMetrics**
   - High-performance metrics storage (Prometheus-compatible)
   - Single-node deployment (can scale to cluster)
   - 12-month retention by default
   - Auto-discovery via ServiceMonitor/PodMonitor

2. **Grafana**
   - Visualization and dashboards
   - Pre-configured datasource (VictoriaMetrics)
   - Auto-provisioned dashboards
   - Persistent storage for dashboards/config

3. **Alert Rules**
   - PrometheusRule CRDs for alerting
   - Auto-discovered by VictoriaMetrics Operator
   - Organized by component/severity

4. **Service Discovery**
   - ServiceMonitor for service-level metrics
   - PodMonitor for pod-level metrics
   - Automatic target discovery

---

## Metrics Collection

### Metrics Endpoints

All Zen Platform services expose Prometheus-compatible metrics:

| Service | Port | Endpoint | Component |
|---------|------|----------|-----------|
| zen-back | 8080 | /metrics | Backend API |
| zen-bff | 8080 | /metrics | BFF API |
| zen-websocket | 9090 | /metrics | WebSocket service |
| zen-watcher | 8080 | /metrics | Watcher controller |
| zen-flow | 8080 | /metrics | Flow controller |
| zen-gc | 8080 | /metrics | GC controller |
| zen-lock | 8080 | /metrics | Lock controller |
| zen-lead | 8080 | /metrics | Lead controller |

### Metrics Categories

#### 1. HTTP Service Metrics

**Metrics:**
- `zen_http_requests_total{component, endpoint, method, status}` - Request counter
- `zen_http_request_duration_seconds{component, endpoint, method}` - Request latency histogram
- `zen_http_requests_inflight{component, endpoint}` - In-flight requests gauge

**Use Cases:**
- Request rate monitoring
- Error rate tracking
- Latency analysis (p50, p95, p99)
- Throughput monitoring

#### 2. Controller Reconciliation Metrics

**Metrics:**
- `zen_reconciliations_total{component, result}` - Reconciliation counter
- `zen_reconciliation_duration_seconds{component, result}` - Reconciliation duration histogram
- `zen_errors_total{component, type}` - Error counter

**Components:**
- zen-watcher
- zen-flow
- zen-gc
- zen-lock
- zen-lead

**Use Cases:**
- Controller health monitoring
- Reconciliation performance
- Error rate tracking

#### 3. Delivery Flow Metrics

**Metrics:**
- `zen_delivery_flow_deliveries_total{flow_name, tenant_id, status}` - Delivery counter
- `zen_delivery_flow_latency_seconds{flow_name, tenant_id}` - Delivery latency histogram
- `zen_delivery_flow_bytes_total{flow_name, tenant_id}` - Bytes delivered counter

**Use Cases:**
- Path delivery monitoring
- Delivery success rate
- Throughput analysis

#### 4. Ingester Metrics

**Metrics:**
- `zen_watcher_observations_created_total{ingester_name, source}` - Observations created
- `zen_watcher_observations_filtered_total{ingester_name, reason}` - Observations filtered
- `zen_watcher_ingester_errors_total{ingester_name, error_type}` - Ingester errors

**Use Cases:**
- Source connector monitoring
- Event processing rate
- Filter effectiveness

#### 5. Database Metrics

**Metrics:**
- `zen_database_query_duration_seconds{operation, table}` - Query latency histogram
- `zen_database_connections_active{pool}` - Active connections gauge
- `zen_database_connections_max{pool}` - Max connections gauge
- `zen_database_queries_total{operation, status}` - Query counter

**Use Cases:**
- Query performance monitoring
- Connection pool management
- Database health tracking

#### 6. Resource Metrics

**Metrics:**
- `container_memory_usage_bytes{container, pod}` - Memory usage
- `container_cpu_usage_seconds_total{container, pod}` - CPU usage
- `container_spec_memory_limit_bytes{container, pod}` - Memory limits

**Use Cases:**
- Resource utilization
- Capacity planning
- OOM prevention

---

## Alert Rules

### Alert Categories

#### 1. Platform Availability

**Alerts:**
- `PlatformServiceDown` - Service is down (critical, 5m)
- `PlatformServiceUnhealthy` - Service unhealthy (warning, 2m)

**Coverage:**
- All platform services (zen-back, zen-bff, zen-websocket, etc.)

#### 2. HTTP Services

**Alerts:**
- `HighHTTPErrorRate` - Error rate > 5% (warning, 5m)
- `CriticalHTTPErrorRate` - Error rate > 10% (critical, 2m)
- `HighHTTPLatency` - P95 latency > 1s (warning, 10m)

#### 3. Controller Reconciliation

**Alerts:**
- `HighReconciliationErrorRate` - Error rate > 10% (warning, 5m)
- `SlowReconciliation` - P95 duration > 30s (warning, 10m)

#### 4. Delivery Flows

**Alerts:**
- `DeliveryFlowFailureRateHigh` - Failure rate > 5% (warning, 5m)
- `DeliveryFlowLatencyHigh` - P95 latency > 5s (warning, 10m)

#### 5. Ingesters

**Alerts:**
- `IngesterDown` - Ingester is down (critical, 5m)
- `IngesterHighErrorRate` - Error rate > 10/sec (warning, 5m)

#### 6. Database

**Alerts:**
- `DatabaseSlowQueries` - P95 latency > 500ms (warning, 10m)
- `DatabaseConnectionPoolExhausted` - Pool usage > 90% (warning, 5m)

#### 7. Resource Usage

**Alerts:**
- `HighMemoryUsage` - Memory usage > 90% (warning, 10m)
- `HighCPUUsage` - CPU usage > 90% (warning, 10m)

#### 8. VictoriaMetrics

**Alerts:**
- `VictoriaMetricsDown` - VM is down (critical, 1m)
- `VictoriaMetricsHighIngestionRate` - Ingestion > 1M rows/sec (warning, 5m)
- `VictoriaMetricsHighMemoryUsage` - Memory usage > 90% (warning, 10m)

### Alert Severity Levels

- **Critical**: Immediate action required (service down, data loss risk)
- **Warning**: Attention needed (degraded performance, potential issues)
- **Info**: Informational (trends, capacity planning)

---

## Dashboards

### Pre-configured Dashboards

#### 1. Zen Platform Overview

**Panels:**
- Service health status
- Request rate (all services)
- Error rate (all services)
- P95 latency (all services)
- Active connections
- Resource usage

**Refresh**: 30s

#### 2. Zen Platform Services

**Panels:**
- Per-service metrics
- Request breakdown by endpoint
- Error breakdown by status code
- Latency percentiles (p50, p95, p99)
- Throughput trends

**Refresh**: 30s

#### 3. Delivery Flows

**Panels:**
- Flow delivery rate
- Delivery success rate
- Delivery latency
- Bytes delivered
- Failed deliveries

**Refresh**: 30s

#### 4. Controllers

**Panels:**
- Reconciliation rate
- Reconciliation duration
- Error rate by controller
- Queue depth
- Processing rate

**Refresh**: 30s

#### 5. Database

**Panels:**
- Query rate
- Query latency (p50, p95, p99)
- Connection pool usage
- Slow queries
- Error rate

**Refresh**: 30s

#### 6. Resources

**Panels:**
- CPU usage by pod
- Memory usage by pod
- Network I/O
- Disk I/O
- Resource limits/requests

**Refresh**: 1m

---

## Deployment

### Prerequisites

- Kubernetes 1.24+
- Helm 3.8+
- PersistentVolume support
- VictoriaMetrics Operator (installed via chart dependency)

### Installation

```bash
# Add Helm repos
helm repo add vm https://victoriametrics.github.io/helm-charts/
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install observability stack
helm install zen-observability ./helm-charts/charts/zen-observability \
  --namespace zen-monitoring \
  --create-namespace \
  --set grafana.adminPassword=<YOUR_PASSWORD>
```

### Configuration

Key configuration options in `values.yaml`:

- **VictoriaMetrics**:
  - Retention period (default: 12 months)
  - Storage size (default: 50Gi)
  - Replicas (default: 1, can scale to 3 for HA)

- **Grafana**:
  - Admin password (set via secret)
  - Persistence size (default: 10Gi)
  - Ingress configuration (optional)

- **Alert Rules**:
  - Enabled by default
  - Auto-discovered via labels

### Service Discovery

Services expose metrics via ServiceMonitor:

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

---

## Metrics Best Practices

### Labeling

- Use consistent label names across services
- Keep label cardinality reasonable (< 100 unique combinations)
- Include tenant_id for multi-tenant metrics
- Include component/service name for aggregation

### Retention

- Default: 12 months
- Adjust based on storage capacity
- Consider downsampling for long-term retention

### Scrape Intervals

- Default: 30s
- Adjust based on metric update frequency
- Use 15s for high-frequency metrics
- Use 60s for low-frequency metrics

---

## Troubleshooting

### VictoriaMetrics Not Collecting Metrics

1. Check ServiceMonitor/PodMonitor labels match selector
2. Verify metrics endpoint is accessible
3. Check VictoriaMetrics logs: `kubectl logs -n zen-monitoring -l app=victoriametrics`
4. Query targets: `curl http://victoriametrics:8428/targets`

### Grafana Not Showing Data

1. Verify datasource configuration
2. Check VictoriaMetrics connectivity
3. Verify metrics exist: `curl 'http://victoriametrics:8428/api/v1/query?query=up'`
4. Check dashboard queries

### Alerts Not Firing

1. Verify PrometheusRule CRD exists
2. Check alert rule expressions
3. Verify metrics exist for alert queries
4. Check VictoriaMetrics alerting configuration

---

## Future Enhancements

### Short-term

- [ ] Add more service-specific dashboards
- [ ] Implement SLO dashboards
- [ ] Add cost tracking metrics
- [ ] Enhance alert runbooks

### Long-term

- [ ] Distributed tracing (Jaeger/Tempo)
- [ ] Log aggregation (Loki)
- [ ] APM integration
- [ ] Custom metrics exporters

---

## References

- [VictoriaMetrics Documentation](https://docs.victoriametrics.com/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Prometheus Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [ServiceMonitor CRD](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#servicemonitor)

---

## Support

For issues or questions:
- Check logs: `kubectl logs -n zen-monitoring`
- Query metrics: `curl http://victoriametrics:8428/api/v1/query?query=up`
- Review dashboards in Grafana UI
- Check alert rules: `kubectl get prometheusrules -n zen-monitoring`

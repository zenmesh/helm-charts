# H083 — Observability Baseline for Leadership

**Status**: ✅ Complete  
**Date**: 2025-01-XX

## Objective

Make leadership diagnosable in 5 minutes during incident response. Standardize metrics/log fields across all components, ensure events/annotations are consistent, and provide alert recommendations.

## Standardized Metrics

### Leader State Gauge (0/1)

**Metric Name**: `{component}_leader_state`  
**Type**: Gauge  
**Labels**: `namespace`, `election_id`  
**Values**: `0` (non-leader), `1` (leader)

**Example**:
```prometheus
zen_flow_leader_state{namespace="zen-flow-system",election_id="zen-flow-leader-election"} 1
zen_gc_leader_state{namespace="zen-gc-system",election_id="zen-gc-leader-election"} 0
```

### Leadership Transition Counter

**Metric Name**: `{component}_leadership_transitions_total`  
**Type**: Counter  
**Labels**: `namespace`, `election_id`, `direction` (`acquired` or `lost`)

**Example**:
```prometheus
zen_flow_leadership_transitions_total{namespace="zen-flow-system",election_id="zen-flow-leader-election",direction="acquired"} 5
zen_flow_leadership_transitions_total{namespace="zen-flow-system",election_id="zen-flow-leader-election",direction="lost"} 4
```

### Reconcile Blocked/Non-Leader Reason

**Metric Name**: `{component}_reconcile_blocked_total`  
**Type**: Counter  
**Labels**: `namespace`, `reason` (`not_leader`, `election_failed`, `lease_unavailable`)

**Example**:
```prometheus
zen_flow_reconcile_blocked_total{namespace="zen-flow-system",reason="not_leader"} 150
zen_gc_reconcile_blocked_total{namespace="zen-gc-system",reason="lease_unavailable"} 2
```

### Additional Standard Metrics

| Metric Name | Type | Labels | Description |
|------------|------|--------|-------------|
| `{component}_reconcile_duration_seconds` | Histogram | `namespace`, `result` (`success`, `error`) | Reconciliation duration |
| `{component}_reconcile_errors_total` | Counter | `namespace`, `error_type` | Reconciliation errors |
| `{component}_lease_renewal_duration_seconds` | Histogram | `namespace`, `election_id` | Lease renewal duration |
| `{component}_lease_renewal_failures_total` | Counter | `namespace`, `election_id` | Lease renewal failures |

## Standardized Log Fields

### Structured Logging Format

All components MUST use structured logging with consistent fields:

```go
// Leader acquired
logger.Info("Leader election acquired",
    "namespace", namespace,
    "election_id", electionID,
    "pod_name", podName,
    "lease_name", leaseName,
)

// Leader lost
logger.Info("Leader election lost",
    "namespace", namespace,
    "election_id", electionID,
    "pod_name", podName,
    "reason", reason, // "lease_expired", "pod_terminating", etc.
)

// Reconcile blocked (non-leader)
logger.V(4).Info("Reconciliation skipped (not leader)",
    "namespace", namespace,
    "election_id", electionID,
    "current_leader", currentLeader,
    "pod_name", podName,
)

// Reconcile error
logger.Error(err, "Reconciliation failed",
    "namespace", namespace,
    "election_id", electionID,
    "error_type", errorType,
)
```

### Log Levels

- **Info**: Leadership transitions, significant events
- **V(4)**: Non-leader reconciliation skips (verbose)
- **Error**: Reconciliation failures, lease renewal failures

## Events and Annotations

### Kubernetes Events

All components MUST emit events for leadership transitions:

```yaml
# Leader acquired
reason: LeaderElection
type: Normal
message: "Pod zen-flow-controller-abc123 acquired leadership for election zen-flow-leader-election"

# Leader lost
reason: LeaderElection
type: Normal
message: "Pod zen-flow-controller-abc123 lost leadership for election zen-flow-leader-election (reason: lease_expired)"

# Reconcile blocked
reason: ReconcileBlocked
type: Normal
message: "Reconciliation skipped (not leader, current leader: zen-flow-controller-def456)"
```

### Service/Lease Annotations

For components using Profile A (zen-lead) or exposing leadership status:

```yaml
# Leader Service annotations (zen-lead)
metadata:
  annotations:
    zen-lead.io/leader-pod-name: "zen-flow-controller-abc123"
    zen-lead.io/leader-pod-uid: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
    zen-lead.io/leader-last-switch-time: "2025-01-15T10:30:00Z"

# Lease annotations (Profile B/C)
metadata:
  annotations:
    leadership.kube-zen.io/leader-pod-name: "zen-flow-controller-abc123"
    leadership.kube-zen.io/leader-pod-uid: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
    leadership.kube-zen.io/last-transition-time: "2025-01-15T10:30:00Z"
```

## Alert Recommendations

### Critical Alerts

#### No Leader Elected

```yaml
- alert: {Component}NoLeaderElected
  expr: |
    {component}_leader_state == 0
    and
    count({component}_leader_state) >= 2  # At least 2 replicas
  for: 2m
  labels:
    severity: critical
    component: leadership
  annotations:
    summary: "No leader elected for {{ $labels.election_id }}"
    description: "{{ $labels.namespace }}/{{ $labels.election_id }} has no active leader despite {{ $value }} replicas running."
```

**Runbook**:
1. Check pod logs for lease renewal failures
2. Verify etcd connectivity
3. Check for API server issues
4. Review Lease resource status

#### Leadership Flapping

```yaml
- alert: {Component}LeadershipFlapping
  expr: |
    rate({component}_leadership_transitions_total{direction="acquired"}[5m]) > 0.1
  for: 10m
  labels:
    severity: critical
    component: leadership
  annotations:
    summary: "Leadership flapping detected for {{ $labels.election_id }}"
    description: "{{ $labels.namespace }}/{{ $labels.election_id }} is experiencing {{ $value }} leadership transitions/sec."
```

**Runbook**:
1. Check pod health (liveness/readiness probes)
2. Review resource constraints (CPU/memory)
3. Check network connectivity to etcd
4. Review Lease renewal duration settings

### Warning Alerts

#### High Reconcile Block Rate

```yaml
- alert: {Component}HighReconcileBlockRate
  expr: |
    rate({component}_reconcile_blocked_total[5m]) > 1
  for: 5m
  labels:
    severity: warning
    component: leadership
  annotations:
    summary: "High reconcile block rate for {{ $labels.election_id }}"
    description: "{{ $labels.namespace }}/{{ $labels.election_id }} has {{ $value }} blocked reconciliations/sec (reason: {{ $labels.reason }})."
```

#### Lease Renewal Failures

```yaml
- alert: {Component}LeaseRenewalFailures
  expr: |
    rate({component}_lease_renewal_failures_total[5m]) > 0.01
  for: 5m
  labels:
    severity: warning
    component: leadership
  annotations:
    summary: "Lease renewal failures for {{ $labels.election_id }}"
    description: "{{ $labels.namespace }}/{{ $labels.election_id }} has {{ $value }} lease renewal failures/sec."
```

## Component-Specific Metrics

### zen-flow

- `zen_flow_jobflow_reconcile_duration_seconds` - JobFlow reconciliation duration
- `zen_flow_jobflow_reconcile_errors_total` - JobFlow reconciliation errors
- `zen_flow_jobflow_active_total` - Active JobFlows count

### zen-gc

- `zen_gc_policy_reconcile_duration_seconds` - GC policy reconciliation duration
- `zen_gc_policy_reconcile_errors_total` - GC policy reconciliation errors
- `zen_gc_deletions_total` - Total deletions performed
- `zen_gc_deletion_errors_total` - Deletion errors

### zen-watcher

- `zen_watcher_watch_reconcile_duration_seconds` - Watch reconciliation duration
- `zen_watcher_watch_reconcile_errors_total` - Watch reconciliation errors
- `zen_watcher_watches_active_total` - Active watches count

### zen-lead

- `zen_lead_leader_duration_seconds` - How long a pod has been leader
- `zen_lead_failover_count_total` - Total number of failovers
- `zen_lead_reconciliation_duration_seconds` - Reconciliation duration
- `zen_lead_pods_available` - Ready pods count
- `zen_lead_port_resolution_failures_total` - Port resolution failures

## Sample Prometheus Alert Rules

See `zen-lead/deploy/prometheus/prometheus-rules.yaml` for a complete example.

## 5-Minute Incident Response Checklist

### Step 1: Check Leader State (30 seconds)

```bash
# Check metrics
curl -s http://localhost:8080/metrics | grep "{component}_leader_state"

# Check Lease
kubectl get lease -n <namespace> <election-id> -o yaml

# Check events
kubectl get events -n <namespace> --field-selector reason=LeaderElection --sort-by='.lastTimestamp' | tail -10
```

### Step 2: Check Leadership Transitions (30 seconds)

```bash
# Check transition counter
curl -s http://localhost:8080/metrics | grep "{component}_leadership_transitions_total"

# Check logs for transitions
kubectl logs -n <namespace> -l app.kubernetes.io/name=<component> | grep -i "leader.*acquired\|leader.*lost"
```

### Step 3: Check Reconcile Block Reasons (1 minute)

```bash
# Check blocked reconciles
curl -s http://localhost:8080/metrics | grep "{component}_reconcile_blocked_total"

# Check logs for blocked reconciles
kubectl logs -n <namespace> -l app.kubernetes.io/name=<component> | grep -i "reconciliation skipped\|not leader"
```

### Step 4: Check Lease Renewal Status (1 minute)

```bash
# Check lease renewal metrics
curl -s http://localhost:8080/metrics | grep "{component}_lease_renewal"

# Check Lease resource
kubectl describe lease -n <namespace> <election-id>

# Check pod status
kubectl get pods -n <namespace> -l app.kubernetes.io/name=<component>
```

### Step 5: Review Recent Events and Logs (2 minutes)

```bash
# All events
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20

# Controller logs
kubectl logs -n <namespace> -l app.kubernetes.io/name=<component> --tail=100 | grep -E "leader|reconcile|error"
```

## Exit Criteria Met

✅ Metrics standardized across all components  
✅ Log fields consistent and structured  
✅ Events/annotations show leadership transitions  
✅ Alert recommendations provided  
✅ 5-minute incident response checklist documented


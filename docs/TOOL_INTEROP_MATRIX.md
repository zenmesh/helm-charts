# Tool Interop Matrix

**Last Updated**: 2015-12-31  
**Purpose**: Document how Kube-ZEN projects consume each other's functionality through Kubernetes resources and contracts

**Canonical Location**: This file is the authoritative source for tool-to-tool interoperability patterns.

---

## Overview

Kube-ZEN components interact through **Kubernetes-native mechanisms** (CRDs, APIs, controller-runtime) and **shared libraries** (zen-sdk). This matrix documents the producer → consumer relationships and their configuration surfaces.

**Key Principle**: Composition happens via CRDs/APIs or zen-sdk libraries. **Do not import repo-to-repo code** (no zen-watcher importing zen-gc packages directly).

---

## Interop Matrix

| Producer | Consumer | Mechanism | Config Surface | Notes |
|----------|----------|-----------|----------------|-------|
| `zen-sdk/pkg/zenlead` | All controllers (zen-flow, zen-gc, zen-watcher, zen-lock) | controller-runtime leader election | `leaderElection.*` (Helm values) | Standardized leadership via zen-sdk wrapper |
| `zen-watcher` | `zen-gc` | Observation CRs pruned by GarbageCollectionPolicy | `integrations.observationsGc.*` (zen-suite) | Suite-managed GC policy for Observations |
| `zen-flow` | `zen-lock` | Concurrency/serialization via locks/leases | Chart values (zen-lock integration) | Current contract: zen-flow uses zen-lock for step serialization |
| `zen-flow` / `zen-watcher` | `zen-gc` | Generic retention policies for any GVK | `GarbageCollectionPolicy` CRD | Any component can create GC policies for any resource type |
| `zen-lead` | All controllers | Network-only leader election (Profile A) | `zenLead.enabled` (zen-suite) | Optional: enables zen-lead managed leader election |

---

## Detailed Interop Patterns

### 1. zen-sdk/pkg/zenlead → All Controllers

**Producer**: `zen-sdk/pkg/zenlead`  
**Consumers**: zen-flow, zen-gc, zen-watcher, zen-lock  
**Mechanism**: controller-runtime leader election (Lease-based)  
**Config Surface**: Helm `leaderElection.*` values

**Helm Configuration**:
```yaml
leaderElection:
  mode: "builtin"  # or "zenlead" or "disabled"
  electionID: "zen-flow-controller-leader-election"  # required for builtin
  leaseName: "zen-flow-leader-group"  # required for zenlead
```

**Implementation**: All controllers use `zenlead.PrepareManagerOptions()` and `zenlead.EnforceSafeHA()` for consistent leadership behavior.

**Contract**: See [zen-sdk/docs/LEADERSHIP_CONTRACT.md](../../zen-sdk/docs/LEADERSHIP_CONTRACT.md)

---

### 2. zen-watcher → zen-gc (Observation Pruning)

**Producer**: `zen-watcher` (creates Observation CRs)  
**Consumer**: `zen-gc` (prunes Observations via GarbageCollectionPolicy)  
**Mechanism**: GarbageCollectionPolicy CRD targeting Observation resources  
**Config Surface**: `integrations.observationsGc.*` in zen-suite

**Helm Configuration**:
```yaml
integrations:
  observationsGc:
    enabled: true
    targetNamespace: ""  # empty = cluster-wide
    labelSelector: {}  # optional
    ttl:
      fieldPath: "spec.ttlSecondsAfterCreation"
      defaultSeconds: 604800  # 7 days
    behavior:
      dryRun: false
      batchSize: 200
      maxDeletionsPerSecond: 5
      propagationPolicy: Background
```

**Implementation**: zen-suite creates a GarbageCollectionPolicy CRD that targets `zen.kube-zen.io/v1, Kind=Observation`.

**Prerequisites**:
- `zenWatcher.enabled: true`
- `zenGc.enabled: true`
- `integrations.observationsGc.enabled: true`

---

### 3. zen-flow → zen-lock (Concurrency Control)

**Producer**: `zen-flow` (JobFlow execution)  
**Consumer**: `zen-lock` (provides locking/lease mechanism)  
**Mechanism**: zen-lock CRDs for step serialization  
**Config Surface**: Chart values (zen-lock integration)

**Current Contract**: zen-flow uses zen-lock to serialize JobFlow step execution when concurrency policies require it.

**Implementation**: zen-flow controller creates/uses zen-lock resources to coordinate step execution.

---

### 4. Generic GC Policies (Any Component → zen-gc)

**Producer**: Any component (zen-flow, zen-watcher, etc.)  
**Consumer**: `zen-gc`  
**Mechanism**: GarbageCollectionPolicy CRD for any GVK  
**Config Surface**: GarbageCollectionPolicy CRD spec

**Example**: A component can create a GarbageCollectionPolicy to prune its own resources:

```yaml
apiVersion: gc.kube-zen.io/v1alpha1
kind: GarbageCollectionPolicy
metadata:
  name: prune-old-jobflows
spec:
  targetResource:
    apiVersion: flow.kube-zen.io/v1alpha1
    kind: JobFlow
  ttl:
    secondsAfterCreation: 86400  # 1 day
  behavior:
    maxDeletionsPerSecond: 10
```

**Implementation**: zen-gc controller watches GarbageCollectionPolicy CRDs and applies them to matching resources.

---

### 5. zen-lead → All Controllers (Optional)

**Producer**: `zen-lead` (network-only leader election)  
**Consumers**: All controllers (optional)  
**Mechanism**: LeaderGroup CRD + network-based leader election  
**Config Surface**: `zenLead.enabled` in zen-suite

**Helm Configuration**:
```yaml
zenLead:
  enabled: true  # default: false
```

**Implementation**: When enabled, controllers use `leaderElection.mode: "zenlead"` and reference a LeaderGroup CRD.

**Contract**: Network-only (Profile A) - no pod mutation, no annotations.

---

## Anti-Patterns

### ❌ Do NOT: Import Repo-to-Repo Code

**Bad**:
```go
// In zen-watcher
import "github.com/kube-zen/zen-gc/pkg/controller"  // ❌ DON'T DO THIS
```

**Why**: Creates tight coupling, version conflicts, and circular dependencies.

**Correct**: Use zen-sdk shared libraries or Kubernetes CRDs/APIs.

### ❌ Do NOT: Direct Package Imports Between Components

**Bad**:
```go
// In zen-flow
import "github.com/kube-zen/zen-lock/pkg/lock"  // ❌ DON'T DO THIS
```

**Correct**: Use CRDs/APIs for inter-component communication.

### ✅ DO: Use zen-sdk for Shared Primitives

**Good**:
```go
// In any component
import "github.com/kube-zen/zen-sdk/pkg/zenlead"
import "github.com/kube-zen/zen-sdk/pkg/gc/ratelimiter"
```

**Why**: zen-sdk is designed for shared primitives, versioned, and tested.

### ✅ DO: Use CRDs/APIs for Component Interop

**Good**:
- zen-watcher creates Observation CRs
- zen-gc watches Observations via GarbageCollectionPolicy
- No direct code dependency

**Why**: Loose coupling, version independence, Kubernetes-native.

---

## Configuration Reference

### Helm Values Mapping

| Interop Pattern | Helm Value Path | Default | Required Components |
|----------------|-----------------|---------|-------------------|
| Leadership | `leaderElection.*` | Varies by component | All controllers |
| Observation GC | `integrations.observationsGc.*` | `enabled: false` | zen-watcher + zen-gc |
| zen-lead | `zenLead.enabled` | `false` | zen-lead (optional) |
| Generic GC | `GarbageCollectionPolicy` CRD | N/A | zen-gc |

---

## Version Compatibility

Interop patterns are version-independent when using CRDs/APIs. When using zen-sdk, components must pin to compatible versions (see [RELEASE_VERSION_MATRIX.md](./RELEASE_VERSION_MATRIX.md)).

---

## Related

- [RELEASE_VERSION_MATRIX.md](./RELEASE_VERSION_MATRIX.md) - Component version compatibility
- [zen-sdk/docs/LEADERSHIP_CONTRACT.md](../../zen-sdk/docs/LEADERSHIP_CONTRACT.md) - Leadership contract
- [zen-sdk/docs/SHARED_CODE_EXTRACTION.md](../../zen-sdk/docs/SHARED_CODE_EXTRACTION.md) - Shared code extraction model


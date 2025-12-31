# zen-lock Helm Values Structure Exception

**Status**: Documented Exception  
**Date**: 2015-12-31

## Overview

zen-lock uses a different Helm values structure than other components due to its controller/webhook split architecture.

## Standard Structure (Other Components)

Most components use top-level keys:

```yaml
replicaCount: 2
leaderElection:
  mode: builtin
  electionID: ""
  leaseName: ""
```

## zen-lock Structure (Exception)

zen-lock uses nested `controller.*` keys:

```yaml
replicaCount: 1  # Legacy, ignored
controller:
  enabled: true
  replicaCount: 2
  leaderElection:
    mode: builtin
    electionID: ""
    leaseName: ""
```

## Rationale

zen-lock has a split architecture:
- **Controller**: Handles reconciliation (uses leader election)
- **Webhook**: Handles admission (does not use leader election)

The nested structure allows:
1. Independent configuration of controller and webhook
2. Clear separation of concerns
3. Future extensibility for additional components

## Contract Deviation

This is a **deliberate contract deviation** documented here. The leadership contract's "identical Helm values" claim applies to the `leaderElection.*` structure within the appropriate scope:

- **Standard components**: `leaderElection.*` at top level
- **zen-lock**: `controller.leaderElection.*` (nested under controller)

The semantics are identical; only the path differs.

## Migration Consideration

If zen-lock is refactored in the future to match the standard structure, this exception will be removed. For now, it remains as a documented deviation.


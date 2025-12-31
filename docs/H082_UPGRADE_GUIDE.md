# H082 — Upgrade + Backward-Compatibility Guardrails

**Status**: ✅ Complete  
**Date**: 2025-01-XX

## Objective

Prevent silent behavior changes for existing users upgrading charts/components. Define deprecation behavior, timeline for removal, and provide explicit migration paths.

## Legacy Fields Identification

### Deprecated Patterns (Removed/Prohibited)

The following patterns are **FORBIDDEN** and MUST NOT be used:

1. **Pod annotation watcher** (`zen-lead/role` annotation)
   - **Status**: ❌ Removed
   - **Replacement**: Use Profile B (built-in Lease) or Profile C (zen-lead managed Lease)
   - **Migration**: No migration needed (never supported in production)

2. **External HA modes** (`ha-mode=external`, `ha-mode=zenlead`)
   - **Status**: ❌ Removed
   - **Replacement**: Use `leaderElection.mode=builtin` or `leaderElection.mode=zenlead`
   - **Migration**: See migration table below

3. **NewWatcher pattern**
   - **Status**: ❌ Removed
   - **Replacement**: Use controller-runtime Manager with `zen-sdk/pkg/zenlead`
   - **Migration**: See migration table below

### Legacy Helm Values (If Any)

Currently, no legacy Helm values exist. All charts use the standardized leadership contract from day one.

## Migration Table

### Old → New Configuration Mapping

| Old Pattern | New Pattern | Expected Runtime Outcome | Breaking Change |
|------------|-------------|-------------------------|-----------------|
| `ha-mode=external` | `leaderElection.mode=builtin` | Same: Built-in Lease-based leader election | ❌ No (if migrated correctly) |
| `ha-mode=zenlead` | `leaderElection.mode=zenlead` + `leaderElection.leaseName=<name>` | Same: zen-lead managed Lease | ❌ No (if migrated correctly) |
| `zen-lead/role` pod annotation | Profile B or C via `zen-sdk/pkg/zenlead` | Same: Only one leader reconciles | ❌ No (if migrated correctly) |
| `NewWatcher()` pattern | `zen-sdk/pkg/zenlead.PrepareManagerOptions()` | Same: Manager configured with leader election | ❌ No (if migrated correctly) |
| Manual Lease management | `zen-sdk/pkg/zenlead` wrapper | Same: Automatic Lease management | ❌ No (if migrated correctly) |

## Deprecation Timeline

### Phase 1: Current (v0.1.0+)
- ✅ All components use standardized leadership contract
- ✅ Legacy patterns are prohibited via CI denylist
- ✅ No legacy fields in active code paths

### Phase 2: Future (v1.0.0+)
- ⚠️ Contract locked with version header
- ⚠️ Breaking changes require major version bump
- ⚠️ Deprecation warnings (if any) will be added 2 releases before removal

## Upgrade Paths

### Scenario 1: Upgrading from Pre-Standardization

If you have components deployed before the leadership standardization (H071-H076):

1. **Identify current configuration**:
   ```bash
   helm get values <release-name> -n <namespace>
   ```

2. **Check for legacy patterns**:
   ```bash
   # Check for deprecated values
   helm get values <release-name> -n <namespace> | grep -E "ha-mode|zen-lead/role"
   ```

3. **Migrate to new format**:
   ```bash
   # Example: Migrate from ha-mode=external to leaderElection.mode=builtin
   helm upgrade <release-name> ./helm-charts/charts/<component> \
     --namespace <namespace> \
     --set leaderElection.mode=builtin \
     --set leaderElection.electionID=<component>-leader-election
   ```

### Scenario 2: Upgrading Chart Versions

When upgrading chart versions:

1. **Review release notes** for breaking changes
2. **Test in non-production** first
3. **Use Helm diff** to preview changes:
   ```bash
   helm diff upgrade <release-name> ./helm-charts/charts/<component> \
     --namespace <namespace>
   ```

## Backward Compatibility Guarantees

### What We Guarantee

- ✅ **API Stability**: Leadership contract API remains stable within major versions
- ✅ **Behavior Preservation**: Valid configurations continue to work across minor/patch upgrades
- ✅ **Clear Errors**: Invalid configurations fail fast with actionable error messages
- ✅ **Migration Path**: Explicit migration steps for any breaking changes

### What We Don't Guarantee

- ❌ **Silent Behavior Changes**: Invalid configurations may fail where they previously succeeded
- ❌ **Legacy Pattern Support**: Deprecated patterns are not supported and will fail CI

## Validation

### Pre-Upgrade Checklist

Before upgrading, verify:

1. ✅ No legacy patterns in your configuration
2. ✅ Helm values use new format (`leaderElection.mode`, not `ha-mode`)
3. ✅ CI denylist passes (if running custom builds)
4. ✅ Test upgrade in non-production environment

### Post-Upgrade Validation

After upgrading, verify:

1. ✅ Pods are running and ready
2. ✅ Leader election is working (if HA enabled)
3. ✅ No errors in controller logs
4. ✅ Reconciliation is functioning

## Chart NOTES Updates

Helm charts include NOTES.txt with upgrade guidance:

```yaml
# Example: helm-charts/charts/zen-flow/templates/NOTES.txt
{{- if .Values.leaderElection }}
{{- if eq .Values.leaderElection.mode "disabled" }}
WARNING: Leader election is disabled. This is unsafe for HA deployments.
{{- end }}
{{- end }}

To upgrade from previous versions:
1. Review migration guide: docs/H082_UPGRADE_GUIDE.md
2. Check for deprecated values: helm get values <release-name>
3. Test upgrade in non-production first
```

## Exit Criteria Met

✅ Legacy fields identified (none exist, all prohibited)  
✅ Deprecation behavior defined (fail fast, no silent changes)  
✅ Migration table provided (old → new mappings)  
✅ Upgrade path is explicit and scripted  
✅ Chart NOTES updated (if applicable)

## Future Considerations

If legacy fields are introduced in the future:

1. **Deprecation Notice**: Add deprecation warning 2 releases before removal
2. **Migration Guide**: Provide explicit migration steps
3. **Validation**: Add Helm template validation to detect legacy values
4. **Timeline**: Document removal timeline in release notes


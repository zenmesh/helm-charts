# H088 — Post-Merge Cleanup + Deprecation Closeout

**Status**: ✅ Complete  
**Date**: 2025-01-XX

## Objective

Reduce long-term maintenance burden and avoid dual-path drift. Remove dead code paths, ensure old docs don't instruct legacy configs, and lock the contract with a version header.

## Dead Code Removal

### Identified Dead Code

1. **Legacy guard code** (`zen-sdk/pkg/controller/guard.go`)
   - **Status**: Marked as DEPRECATED, kept for compatibility
   - **Action**: Documented as deprecated, will be removed in v1.0.0

2. **Old leadership patterns** (if any)
   - **Status**: Already removed via denylist enforcement
   - **Action**: None needed (prevented by CI)

### Code Cleanup Checklist

- ✅ All components use `zen-sdk/pkg/zenlead`
- ✅ No `NewWatcher` patterns in runtime code
- ✅ No `zen-lead/role` annotations in runtime code
- ✅ No `ha-mode=external` in runtime code
- ✅ Deprecated code marked with `DEPRECATED` comments

## Documentation Cleanup

### Updated Documentation

1. **README files**: Updated to reference new leadership contract
2. **Migration guides**: Created explicit migration paths
3. **Examples**: Updated to use new patterns
4. **Troubleshooting**: Updated to reference new observability metrics

### Removed/Updated Legacy Instructions

- ❌ Removed references to `NewWatcher` pattern
- ❌ Removed references to `zen-lead/role` annotation
- ❌ Removed references to `ha-mode=external`
- ✅ Updated all examples to use `zen-sdk/pkg/zenlead`

## Contract Versioning

### Version Header

Added version header to `zen-sdk/docs/LEADERSHIP_CONTRACT.md`:

```markdown
# Leadership Contract

**Version**: 1.0.0  
**Last Updated**: 2015-12-31  
**Stability**: Stable (v1.0.0+)

## Change Process

- **Major version bump**: Breaking changes to API or behavior
- **Minor version bump**: New features, backward-compatible
- **Patch version bump**: Bug fixes, documentation updates

## Version History

- **v1.0.0** (2015-12-31): Initial stable release
  - Standardized leadership profiles (A, B, C)
  - CI denylist enforcement
  - Helm chart safety guards
```

### Contract Locking

The contract is locked at v1.0.0 with the following guarantees:

1. **API Stability**: Leadership contract API remains stable within major versions
2. **Behavior Preservation**: Valid configurations continue to work across minor/patch upgrades
3. **Breaking Changes**: Breaking changes require major version bump and migration guide

## Single Source of Truth

### Leadership Contract

**Location**: `zen-sdk/docs/LEADERSHIP_CONTRACT.md`

All components reference this single source of truth:
- ✅ zen-flow: References contract in README
- ✅ zen-gc: References contract in README
- ✅ zen-watcher: References contract in README
- ✅ zen-lead: References contract in README

### No Parallel Paths

- ❌ No "old leadership" path
- ❌ No "new leadership" path
- ✅ Single standardized path via `zen-sdk/pkg/zenlead`

## Cleanup Summary

### Files Removed

None (all legacy code is marked as DEPRECATED, not removed yet)

### Files Updated

1. `zen-sdk/docs/LEADERSHIP_CONTRACT.md` - Added version header
2. All component READMEs - Updated to reference contract
3. Migration guides - Created explicit migration paths
4. CI scripts - Enhanced with explain mode and better scoping

### Documentation Created

1. `docs/H080_E2E_MATRIX.md` - E2E regression matrix
2. `docs/H081_HELM_CONFORMANCE.md` - Helm conformance guide
3. `docs/H082_UPGRADE_GUIDE.md` - Upgrade and migration guide
4. `docs/H083_OBSERVABILITY.md` - Observability baseline
5. `docs/H084_DENYLIST_POLICY.md` - Denylist policy
6. `docs/H085_SUPPLY_CHAIN.md` - Supply chain controls
7. `docs/H086_POLICY_GATES.md` - Policy-as-code
8. `docs/H087_CANARY_CHAOS_REPORT.md` - Canary and chaos validation
9. `docs/H088_CLEANUP.md` - This document

## Exit Criteria Met

✅ Dead code paths identified and documented  
✅ Old docs updated to reference new contract  
✅ Contract locked with version header  
✅ Single source of truth maintained  
✅ No parallel "old leadership" path

## Future Maintenance

### Regular Reviews

1. **Quarterly**: Review deprecated code for removal eligibility
2. **Per Release**: Update contract version if changes made
3. **As Needed**: Update documentation for new patterns

### Deprecation Timeline

- **v1.0.0** (current): Contract locked, deprecated code marked
- **v1.1.0** (future): Remove deprecated code if safe
- **v2.0.0** (future): Major version bump if breaking changes needed


# Release Version Matrix

**Last Updated**: 2025-01-15  
**Purpose**: Single source of truth for chart versions, component versions, and zen-sdk dependency versions

## Version Mapping

| Chart | Chart Version | App Version | Component Git Tag | zen-sdk Tag | Notes |
|-------|--------------|-------------|-------------------|-------------|-------|
| zen-flow | 0.0.2-alpha | 0.0.1-alpha | v0.0.1-alpha | v0.1.0-alpha | Schema added in 0.0.2-alpha |
| zen-gc | 0.0.2-alpha | 0.0.1-alpha | v0.0.1-alpha | v0.1.0-alpha | Schema added in 0.0.2-alpha |
| zen-watcher | 1.0.1 | 1.0.19 | v1.0.19 | v0.1.0-alpha | Schema added in 1.0.1 |
| zen-lock | 0.0.2-alpha | 0.0.1-alpha | v0.0.1-alpha | v0.1.0-alpha | Schema added in 0.0.2-alpha |
| zen-lead | 0.1.0 | 0.1.0 | v0.1.0 | N/A | Network-only (Profile A) |

## Version Policy

### Chart Version Bumping

- **Patch (0.0.1 → 0.0.2)**: Non-trivial changes (schema additions, template improvements)
- **Minor (0.0.x → 0.1.x)**: New features, backward-compatible changes
- **Major (0.x.x → 1.x.x)**: Breaking changes

### App Version

- **App Version** = Component image tag
- Must match component git tag for releases
- Updated when component releases new version

### zen-sdk Dependency

- **All components** pin to `zen-sdk v0.1.0-alpha` (H104)
- No pseudo-versions allowed in production
- Components must update go.mod to reference tagged version

## Upgrade Path

### Deterministic Upgrades

Operators can upgrade deterministically using this matrix:

1. **Check current versions**: `helm list -A`
2. **Reference matrix**: Find current chart version
3. **Check dependencies**: Verify zen-sdk tag matches
4. **Upgrade**: `helm upgrade <release> <chart> --version <new-version>`

### Example Upgrade

```bash
# Current: zen-flow 0.0.1-alpha
# Target: zen-flow 0.0.2-alpha (adds schema validation)

# 1. Verify zen-sdk dependency
kubectl get deployment zen-flow -o yaml | grep ZEN_SDK_VERSION
# Should show: v0.1.0-alpha

# 2. Upgrade chart
helm upgrade zen-flow helm-charts/charts/zen-flow --version 0.0.2-alpha

# 3. Verify
helm list | grep zen-flow
# Should show: zen-flow 0.0.2-alpha
```

## Component Git Tags

### zen-flow
- **v0.0.1-alpha**: Initial release
- **Latest**: `v0.0.1-alpha`

### zen-gc
- **v0.0.1-alpha**: Initial release
- **Latest**: `v0.0.1-alpha`

### zen-watcher
- **v1.0.19**: Current release
- **Latest**: `v1.0.19`

### zen-lock
- **v0.0.1-alpha**: Initial release
- **Latest**: `v0.0.1-alpha`

### zen-sdk
- **v0.1.0-alpha**: Leadership contract v1.0.0, Model A denylist (H104)
- **Latest**: `v0.1.0-alpha`

## Schema Addition (H091)

Charts updated with `values.schema.json`:
- **zen-flow**: 0.0.1-alpha → 0.0.2-alpha (schema added)
- **zen-gc**: 0.0.1-alpha → 0.0.2-alpha (schema added)
- **zen-watcher**: 1.0.1 (schema added, version already bumped)
- **zen-lock**: 0.0.1-alpha → 0.0.2-alpha (schema added)

## Dependency Pinning (H104)

All components now pin to stable zen-sdk version:
- **Before**: Pseudo-versions (`v0.0.0-20251231020410-f6e4bc8c2fc3`)
- **After**: Tagged version (`v0.1.0-alpha`)
- **Benefit**: Eliminates "works on my commit" risk

## Maintenance

This matrix must be updated when:
1. Chart versions are bumped
2. Component versions are released
3. zen-sdk versions are tagged
4. Dependencies change

**Update Process**:
1. Update this file
2. Commit with message: "Update RELEASE_VERSION_MATRIX.md for <release>"
3. Tag component/zen-sdk if applicable


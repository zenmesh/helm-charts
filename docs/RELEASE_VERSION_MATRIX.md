# Release Version Matrix

**Last Updated**: 2025-01-05  
**Purpose**: Single source of truth for chart versions, component versions, and zen-sdk dependency versions

## Version Mapping

| Chart | Chart Version | App Version | Component Git Tag | zen-sdk Tag | Notes |
|-------|--------------|-------------|-------------------|-------------|-------|
| zen-flow | 0.0.2-alpha | 0.0.1-alpha | v0.0.1-alpha | v0.1.0-alpha | Schema added in 0.0.2-alpha |
| zen-gc | 0.0.2-alpha | 0.0.1-alpha | v0.0.1-alpha | v0.1.1-alpha | Schema added in 0.0.2-alpha; GC primitives migrated (H115) |
| zen-watcher | 1.0.3 | 1.0.3 | v1.0.3 | v0.2.9-alpha | Version aligned (G010) - git tag v1.0.3 ↔ image 1.0.3 ↔ chart 1.0.3 ↔ app 1.0.3 |
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

- **zen-watcher**: Pin to `zen-sdk v0.2.9-alpha` (RWMutex fix, deduplication improvements)
- **zen-gc**: Pin to `zen-sdk v0.1.1-alpha` (H115: GC primitives migration)
- **Other components**: Pin to `zen-sdk v0.1.0-alpha` (H104)
- No pseudo-versions allowed in production
- Components must update go.mod to reference tagged version

**Migration Notes**:
- **v0.2.9-alpha**: Fixed RWMutex unlock bug in deduplication (zen-watcher v1.2.1)
- **v0.1.1-alpha**: GC backoff/ratelimiter now sourced from zen-sdk. See [VERSION_MATRIX.md](../../docs/VERSION_MATRIX.md) for details.

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
- **v1.2.1**: Current release (RWMutex fix, dependency updates)
- **v1.2.0**: Previous release (G010 - version alignment)
- **Latest**: `v1.2.1`

### zen-lock
- **v0.0.1-alpha**: Initial release
- **Latest**: `v0.0.1-alpha`

### zen-sdk
- **v0.2.9-alpha**: RWMutex fix in deduplication (zen-watcher v1.2.1)
- **v0.1.1-alpha**: GC primitives migration (H115)
- **v0.1.0-alpha**: Leadership contract v1.0.0, Model A denylist (H104)
- **Latest**: `v0.2.9-alpha`

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


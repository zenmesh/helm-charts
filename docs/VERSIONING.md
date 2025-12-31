# Versioning Strategy

This document describes the versioning strategy for Kube-Zen Helm charts.

## Overview

Kube-Zen charts use **independent versioning** - each component chart has its own version that can be updated independently. The zen-suite umbrella chart versions are tied to dependency changes and suite configuration changes.

## Component Chart Versioning

### Version Format

All charts follow [Semantic Versioning](https://semver.org/) (SemVer):
- **MAJOR**: Breaking changes (API changes, incompatible CRD changes)
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Version Examples

- `0.0.1-alpha`: Initial alpha release
- `0.1.0`: First minor release with new features
- `0.1.1`: Patch release with bug fixes
- `1.0.0`: First stable release
- `1.1.0`: Minor release with new features
- `2.0.0`: Major release with breaking changes

### Independent Versioning

Each component chart maintains its own version:

- **zen-lock**: `0.0.1-alpha`
- **zen-flow**: `0.0.1-alpha`
- **zen-gc**: `0.0.1-alpha`
- **zen-watcher**: `1.0.1` (independent versioning)

Components can be upgraded independently. There is no lockstep versioning requirement.

## Suite Chart Versioning

The `zen-suite` chart versions are determined by:

1. **Dependency version changes**: When dependency versions are updated
2. **Suite configuration changes**: When suite defaults or structure changes
3. **Component additions/removals**: When components are added or removed from the suite

### Suite Version Examples

- `0.0.1-alpha`: Initial suite release
- `0.0.2-alpha`: Updated dependency versions
- `0.1.0-alpha`: Added new component or significant suite configuration change
- `1.0.0`: First stable suite release

### Dependency Version Constraints

The suite chart uses flexible version constraints in `Chart.yaml`:

```yaml
dependencies:
  - name: zen-lock
    version: ">=0.0.1-alpha"
    repository: "@"
```

This allows users to get compatible versions while allowing components to evolve independently.

## Compatibility Matrix

See [COMPATIBILITY.md](COMPATIBILITY.md) for the compatibility matrix showing:
- Suite version → Component chart versions
- Component chart version history
- Kubernetes version compatibility

## Versioning Best Practices

### For Component Charts

1. **Increment PATCH** for:
   - Bug fixes
   - Documentation updates
   - Non-functional changes

2. **Increment MINOR** for:
   - New features (backward compatible)
   - New configuration options
   - Enhanced functionality

3. **Increment MAJOR** for:
   - Breaking API changes
   - Incompatible CRD schema changes
   - Removal of deprecated features
   - Major architectural changes

### For Suite Chart

1. **Increment PATCH** for:
   - Dependency version bumps (patch/minor)
   - Documentation updates

2. **Increment MINOR** for:
   - New component added
   - Significant suite configuration changes
   - Dependency version bumps (major, if compatible)

3. **Increment MAJOR** for:
   - Component removed
   - Breaking suite configuration changes
   - Incompatible dependency changes

## Version Updates

### Updating Component Chart Versions

1. Update `version` in `Chart.yaml`
2. Update `appVersion` if the container image version changed
3. Update changelog/release notes
4. Commit and tag release

### Updating Suite Chart Versions

1. Review dependency version changes
2. Update suite `version` in `Chart.yaml` if needed
3. Update dependency constraints if necessary
4. Update [COMPATIBILITY.md](COMPATIBILITY.md) with new version matrix
5. Update changelog/release notes
6. Commit and tag release

## Release Process

### Component Chart Release

```bash
# 1. Update version in Chart.yaml
# 2. Update appVersion if needed
# 3. Test locally
helm lint charts/zen-lock
helm template test charts/zen-lock

# 4. Package and test
helm package charts/zen-lock

# 5. Commit and tag
git add charts/zen-lock/Chart.yaml
git commit -m "chore(zen-lock): bump version to 0.0.2-alpha"
git tag zen-lock-0.0.2-alpha
git push origin main --tags
```

### Suite Chart Release

```bash
# 1. Review and update dependency versions if needed
# 2. Update suite version in Chart.yaml
# 3. Update COMPATIBILITY.md
# 4. Test locally
helm dependency update charts/zen-suite
helm lint charts/zen-suite
helm template test charts/zen-suite

# 5. Package and test
helm package charts/zen-suite

# 6. Commit and tag
git add charts/zen-suite/Chart.yaml docs/COMPATIBILITY.md
git commit -m "chore(zen-suite): bump version to 0.0.2-alpha"
git tag zen-suite-0.0.2-alpha
git push origin main --tags
```

## Version Tagging

### Component Charts

Use chart name and version: `zen-lock-0.0.2-alpha`, `zen-flow-0.1.0`

### Suite Chart

Use suite name and version: `zen-suite-0.0.2-alpha`

### Git Tags

Git tags follow the pattern: `<chart-name>-<version>`

Examples:
- `zen-lock-0.0.1-alpha`
- `zen-flow-0.1.0`
- `zen-gc-0.0.2-alpha`
- `zen-watcher-1.0.2`
- `zen-suite-0.0.1-alpha`

## Avoiding Lockstep Versioning

**Recommendation**: Do NOT use lockstep versioning (same version for all components) unless:
- All components must be released together
- There are tight coupling requirements
- Coordinated releases are necessary for operational reasons

**Benefits of independent versioning:**
- Components can evolve at their own pace
- Users can upgrade components independently
- Reduces coordination overhead
- Better aligns with component development cycles

## Version Compatibility

See [COMPATIBILITY.md](COMPATIBILITY.md) for detailed compatibility information.

## Changelog Management

Consider using:
- Changelog files (`CHANGELOG.md`) in each chart directory
- Conventional commits for automated changelog generation
- Release notes in GitHub releases

Example changelog entry:

```markdown
## [0.0.2-alpha] - 2015-12-31

### Added
- New configuration option for custom namespaces

### Changed
- Updated default resource limits

### Fixed
- Fixed issue with RBAC permissions
```


# Version Compatibility Matrix

This document provides the compatibility matrix between zen-suite versions and component chart versions.

## Suite Version → Component Chart Versions

| zen-suite Version | zen-lock | zen-flow | zen-gc | zen-watcher | Notes |
|-------------------|----------|----------|--------|-------------|-------|
| 0.0.1-alpha       | >=0.0.1-alpha | >=0.0.1-alpha | >=0.0.1-alpha | >=1.0.1 | Initial release |

## Component Chart Versions (Independent)

Each component chart follows independent versioning. This allows components to be upgraded independently.

### zen-lock

| Chart Version | App Version | Kubernetes | Notes |
|---------------|-------------|------------|-------|
| 0.0.1-alpha   | 0.0.1-alpha | 1.20+      | Initial release |

### zen-flow

| Chart Version | App Version | Kubernetes | Notes |
|---------------|-------------|------------|-------|
| 0.0.1-alpha   | 0.0.1-alpha | 1.20+      | Initial release |

### zen-gc

| Chart Version | App Version | Kubernetes | Notes |
|---------------|-------------|------------|-------|
| 0.0.1-alpha   | 0.0.1-alpha | 1.20+      | Initial release |

### zen-watcher

| Chart Version | App Version | Kubernetes | Notes |
|---------------|-------------|------------|-------|
| 1.2.0         | 1.2.0       | 1.26+      | Current stable |
| 1.2.1         | 1.2.1       | 1.26+      | Current stable |
| 1.0.0         | 1.0.0       | 1.26+      | Initial release |

## Versioning Strategy

- **Component charts**: Use independent semantic versioning (MAJOR.MINOR.PATCH)
- **zen-suite chart**: Version bumps when:
  - Dependency version pins change
  - Suite defaults change
  - New components are added/removed
  - Breaking changes in suite configuration

## Upgrade Planning

When upgrading components independently:

1. Check this compatibility matrix
2. Review component release notes for breaking changes
3. Test upgrades in a non-production environment
4. Consider CRD upgrade requirements (see [UPGRADES.md](UPGRADES.md))

## Component Dependencies

Components are designed to work independently. However:

- **zen-watcher** provides observability that can be used by other components
- **zen-gc** can clean up resources created by other components
- **zen-lock** and **zen-flow** are independent and can be used standalone

No hard runtime dependencies exist between components.


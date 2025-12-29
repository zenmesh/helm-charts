# Upgrade Guide

This guide covers upgrading Kube-Zen components and managing CRD upgrades.

## Upgrade Strategy

Components use independent versioning. You can upgrade components independently or together using the suite chart.

## Component Upgrades

### Upgrading Individual Components

```bash
# Check current version
helm list -n zen-lock-system

# Upgrade to latest
helm upgrade zen-lock kube-zen/zen-lock \
  --namespace zen-lock-system

# Upgrade to specific version
helm upgrade zen-lock kube-zen/zen-lock \
  --namespace zen-lock-system \
  --version 0.0.2
```

### Upgrading Suite Chart

```bash
# Upgrade suite
helm upgrade zen-suite kube-zen/zen-suite \
  --namespace zen-system

# Check component versions after upgrade
helm list -n zen-system
```

## CRD Upgrade Expectations

### CRD Installation

CRDs are installed automatically by Helm charts. Each chart includes its CRDs in the `crds/` directory.

**Important**: Helm installs CRDs **before** templates are rendered. This ensures CRDs exist before resources that reference them are created.

### CRD Upgrade Behavior

- **Minor/Patch versions**: CRD upgrades are typically non-breaking and safe to apply
- **Major versions**: May include breaking changes; review release notes carefully

### CRD Upgrade Process

1. **Review release notes** for CRD changes
2. **Backup existing CRDs** (optional but recommended):

```bash
kubectl get crd zenlocks.security.kube-zen.io -o yaml > zenlocks-crd-backup.yaml
```

3. **Upgrade the chart** (CRDs are updated automatically):

```bash
helm upgrade zen-lock kube-zen/zen-lock --namespace zen-lock-system
```

4. **Verify CRD upgrade**:

```bash
kubectl get crd zenlocks.security.kube-zen.io -o yaml | grep version
```

### CRD Schema Changes

When CRD schemas change:

- **Additive changes** (new optional fields): Safe, backward compatible
- **Removing fields**: May cause validation errors if resources use removed fields
- **Changing field types**: Breaking change; requires resource migration

### Handling Breaking CRD Changes

If a CRD upgrade includes breaking changes:

1. **Do NOT upgrade immediately** in production
2. **Test in non-production** environment first
3. **Migrate existing resources** if necessary:

```bash
# Export existing resources
kubectl get zenlocks -A -o yaml > zenlocks-backup.yaml

# Upgrade chart (CRDs will be updated)
helm upgrade zen-lock kube-zen/zen-lock --namespace zen-lock-system

# If resources need migration, apply updated resources
kubectl apply -f zenlocks-migrated.yaml
```

## Rollback Procedures

### Rollback Chart Upgrade

```bash
# List release history
helm history zen-lock -n zen-lock-system

# Rollback to previous version
helm rollback zen-lock -n zen-lock-system

# Rollback to specific revision
helm rollback zen-lock 3 -n zen-lock-system
```

### Rollback CRD Changes

**Important**: Rolling back CRDs is **not automatically handled** by Helm rollback. CRDs are cluster-scoped and persist across Helm releases.

To rollback CRDs manually:

```bash
# Restore from backup
kubectl apply -f zenlocks-crd-backup.yaml

# Or delete and reinstall from previous chart version
kubectl delete crd zenlocks.security.kube-zen.io
helm install zen-lock kube-zen/zen-lock --version 0.0.1 -n zen-lock-system --dry-run | grep -A 1000 "kind: CustomResourceDefinition" | kubectl apply -f -
```

**Warning**: Rolling back CRDs may cause issues if:
- Resources were created with newer schema
- Resources reference fields that don't exist in older schema

## Upgrade Checklist

Before upgrading in production:

- [ ] Review release notes for breaking changes
- [ ] Test upgrade in non-production environment
- [ ] Backup CRDs (optional but recommended)
- [ ] Backup existing resources (if CRD schema changes expected)
- [ ] Review component compatibility (see [COMPATIBILITY.md](COMPATIBILITY.md))
- [ ] Plan rollback procedure
- [ ] Schedule maintenance window (if needed)
- [ ] Notify stakeholders

During upgrade:

- [ ] Verify chart version compatibility
- [ ] Monitor pod startup and health
- [ ] Verify CRDs are upgraded correctly
- [ ] Check for validation errors
- [ ] Verify component functionality

After upgrade:

- [ ] Verify all pods are running
- [ ] Verify CRDs are correct version
- [ ] Test component functionality
- [ ] Monitor for errors in logs
- [ ] Update documentation (if needed)

## Version Compatibility

See [COMPATIBILITY.md](COMPATIBILITY.md) for version compatibility matrix and upgrade planning guidance.

## Troubleshooting Upgrades

### Upgrade Fails Due to CRD Validation

If upgrade fails because existing resources don't match new CRD schema:

```bash
# Check validation errors
kubectl get zenlocks -A

# Review resource structure
kubectl get zenlock <name> -n <namespace> -o yaml

# Fix resources to match new schema, then retry upgrade
```

### Pods Not Starting After Upgrade

Check pod logs and events:

```bash
kubectl logs -n zen-lock-system deployment/zen-lock
kubectl describe pod -n zen-lock-system -l app.kubernetes.io/name=zen-lock
```

### CRD Version Mismatch

If CRD version doesn't match expected version:

```bash
# Check current CRD version
kubectl get crd zenlocks.security.kube-zen.io -o jsonpath='{.spec.versions[*].name}'

# Compare with chart version
helm template zen-lock kube-zen/zen-lock | grep -A 20 "kind: CustomResourceDefinition"
```

## Support

For upgrade issues, see:
- Component-specific documentation
- [GitHub Issues](https://github.com/kube-zen/helm-charts/issues)
- Component repositories for component-specific upgrade notes


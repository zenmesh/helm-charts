# zen-protect Helm Chart

**H601: Dedicated zen-protect chart for single-command installation**

This chart installs only zen-protect (not the full zen-cluster). The agent auto-enrolls on startup using an enrollment bundle from a Kubernetes Secret.

## Prerequisites

- Kubernetes 1.24+
- Helm 3.8+
- Enrollment bundle Secret created in the target namespace

## Installation

### Step 1: Create Enrollment Bundle Secret

**H601 Policy:** Enrollment bundle must come from a Secret, never from Helm values.

```bash
# Create secret from file (recommended)
kubectl create secret generic enrollment-bundle \
  --namespace zen-mesh \
  --from-file=enrollment_bundle=/path/to/enrollment-bundle.txt

# Or from literal (less secure, but acceptable for dev)
kubectl create secret generic enrollment-bundle \
  --namespace zen-mesh \
  --from-literal=enrollment_bundle="<age-encrypted-bundle>"
```

### Step 2: Install zen-protect

```bash
helm repo add kube-zen https://charts.kube-zen.io
helm repo update

helm upgrade --install zen-protect kube-zen/zen-protect \
  --namespace zen-mesh \
  --create-namespace \
  --set agent.saasBaseURL="https://api.kube-zen.io" \
  --set agent.tenantID="<tenant-uuid>" \
  --set agent.clusterID="<cluster-uuid>" \
  --set agent.enrollment.secretRef.name=enrollment-bundle \
  --set agent.enrollment.secretRef.key=enrollment_bundle
```

## Configuration

### Required Values

| Parameter | Description | Example |
|-----------|-------------|---------|
| `agent.saasBaseURL` | SaaS API endpoint | `https://api.kube-zen.io` |
| `agent.tenantID` | Tenant UUID | `00000000-0000-0000-0000-000000000001` |
| `agent.clusterID` | Cluster UUID | `00000000-0000-0000-0000-000000000002` |
| `agent.enrollment.secretRef.name` | Secret name containing enrollment bundle | `enrollment-bundle` |
| `agent.enrollment.secretRef.key` | Key in secret | `enrollment_bundle` |

### Optional Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace` | Namespace for agent | `zen-mesh` |
| `agent.replicaCount` | Number of replicas | `1` |
| `agent.logLevel` | Log level | `info` |
| `agent.resources.requests.cpu` | CPU request | `50m` |
| `agent.resources.requests.memory` | Memory request | `128Mi` |

## Auto-Enrollment

**H601:** Agent automatically enrolls on startup if `ENROLLMENT_BUNDLE` environment variable is set (from Secret).

The agent will:
1. Read enrollment bundle from Secret
2. Decrypt and validate bundle
3. Call SaaS bootstrap endpoint
4. Store cluster credential in `zen-cluster-cred-<clusterID>` Secret
5. Continue normal operation

If enrollment fails, the agent will log an error but continue running (bootstrap endpoint remains available for manual retry).

## Security

**H601 + H607 Policy:**
- ✅ Enrollment bundle comes from Secret (never Helm values)
- ✅ No secrets in Helm `--set` flags
- ✅ Credential material stored in K8s Secrets only
- ✅ Agent runs with least-privilege RBAC

## Troubleshooting

### Agent Not Enrolling

1. Check enrollment bundle Secret exists:
   ```bash
   kubectl get secret enrollment-bundle -n zen-mesh
   ```

2. Check agent logs:
   ```bash
   kubectl logs -n zen-mesh -l app.kubernetes.io/name=zen-protect
   ```

3. Verify enrollment bundle is valid (not expired)

### Cluster Credential Not Created

1. Check agent has RBAC permissions:
   ```bash
   kubectl auth can-i create secrets --as=system:serviceaccount:zen-mesh:zen-protect -n zen-mesh
   ```

2. Check agent logs for bootstrap errors

## Related Documentation

- [Enrollment Guide](../../docs/03-onboarding/ENROLLMENT_GUIDE.md)
- [North Star Architecture](../../docs/02-governance/NORTH_STAR_ARCHITECTURE.md)

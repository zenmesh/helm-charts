# Zen Cluster Helm Chart

Zen Cluster provides cluster-side components for the Zen platform, including the Ingester and Egress components.

## Components

- **Ingester**: Processes and routes observations from cluster components
- **Egress**: Delivers events to external destinations (connectors), controlled by policy from back/control
- **Bootstrap Job** (optional): Automated cluster onboarding via GitOps

## Features

### KEDA Autoscaling

The chart includes KEDA (Kubernetes Event-Driven Autoscaling) for intelligent, event-driven scaling:

- **Automatic Installation**: KEDA installs automatically with the chart (Apache 2.0 license)
- **Event-Driven Scaling**: Scales based on queue depth and event rate (not just CPU/memory)
- **zen-ingester**: Scales based on ingestion queue depth and event rate
- **zen-egress**: Scales based on dispatch queue depth and event rate
- **Configurable**: All scaling parameters configurable via `values.yaml`

See [docs/KEDA_AUTOSCALING.md](docs/KEDA_AUTOSCALING.md) for detailed configuration.

## Installation

```bash
helm install zen-cluster ./charts/zen-cluster \
  --namespace zen-mesh \
  --create-namespace \
  --set ingester.clusterID="your-cluster-id" \
  --set ingester.tenantID.secretName="zen-cluster-secrets" \
  --set ingester.tenantID.secretKey="tenant-id"
```

### Production Deployment

For production deployments, configure the `ENVIRONMENT` variable to enforce security requirements:

```bash
helm install zen-cluster ./charts/zen-cluster \
  --namespace zen-mesh \
  --create-namespace \
  --set ingester.clusterID="your-cluster-id" \
  --set ingester.tenantID.secretName="zen-cluster-secrets" \
  --set ingester.tenantID.secretKey="tenant-id" \
  --set ingester.env[0].name="ENVIRONMENT" \
  --set ingester.env[0].value="production"
```

**Environment Variables:**
- `ENVIRONMENT=production` - Enforces TLS requirements for gRPC, requires Kubernetes Secrets for tenant secrets
- `GRPC_INSECURE_ALLOWED=true` - Development only: Explicit opt-in for insecure gRPC connections (ignored in production)
- `ALLOW_K8S_SECRETS_FALLBACK=true` - Development only: Explicit opt-in for K8s Secrets fallback (ignored in production)

See [gRPC TLS Implementation](../../docs/04-operations/GRPC_TLS_IMPLEMENTATION.md) for details.

## TLS/mTLS Configuration

### zen-egress TLS with zen-lock Bundles

zen-egress supports using zen-lock bundles for TLS certificates instead of Kubernetes Secrets:

```yaml
egress:
  tls:
    enabled: true
    zenLockBundle: "egress-tls"  # ZenLock CRD name (bundle keys: tls.crt, tls.key, ca.crt)
    # secretName: ""  # Mutually exclusive with zenLockBundle
```

**Benefits:**
- ✅ **GitOps-friendly** - TLS certificates encrypted in Git (zen-lock CRDs)
- ✅ **Zero-knowledge** - API server cannot read encrypted certificates
- ✅ **Automatic injection** - zen-lock webhook mounts certificates at runtime

**Example ZenLock CRD for egress TLS:**
```yaml
apiVersion: security.kube-zen.io/v1alpha1
kind: ZenLock
metadata:
  name: egress-tls
  namespace: zen-mesh
spec:
  encryptedData:
    tls.crt: <zen-lock-encrypted-certificate>
    tls.key: <zen-lock-encrypted-private-key>
    ca.crt: <zen-lock-encrypted-ca-certificate>
  allowedSubjects:
  - kind: ServiceAccount
    name: zen-egress
    namespace: zen-mesh
```

**Note:** Requires zen-lock operator installed in cluster and Pod annotations for injection:
```yaml
annotations:
  zen-lock/inject: "egress-tls"
  zen-lock/mount-path: "/etc/egress-tls"
```

## Bootstrap Configuration

The bootstrap Job enables automated cluster onboarding via GitOps. When enabled, it:

1. Waits for zen-agent service to be ready
2. Reads enrollment bundle from a Kubernetes Secret (provided via external secret management)
3. Calls zen-agent HTTP endpoint `POST /v1/agents/bootstrap` with tenant_id, cluster_id, enrollment_bundle
4. zen-agent validates bundle, derives HMAC key deterministically using HKDF, and creates/updates the cluster HMAC Secret
5. Job exits idempotently if secret already exists (no bundle reuse - replay protection via nonce)

**Note:** zen-agent must be deployed and available before the bootstrap job runs. The job includes an init container that waits for zen-agent to be ready.

### Enabling Bootstrap

```yaml
bootstrap:
  enabled: true
  enrollmentBundleSecretRef:
    name: "enrollment-bundle"  # Secret from External Secrets Operator, Sealed Secrets, etc.
    key: "enrollment_bundle"
  targetNamespace: "zen-mesh"  # Optional, defaults to chart namespace
  hmacSecretName: "hmac-my-cluster"  # Optional, defaults to hmac-{cluster-id}
  agentServiceName: "zen-agent"  # zen-agent service name (defaults to zen-agent)
```

### GitOps Integration

The enrollment bundle should be provided via external secret management:

**Example with External Secrets Operator:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: enrollment-bundle
  namespace: zen-mesh
spec:
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: enrollment-bundle
    creationPolicy: Owner
  data:
  - secretKey: enrollment_bundle
    remoteRef:
      key: zen/enrollment-bundles/my-cluster
```

**Example with Sealed Secrets:**
```bash
kubectl create secret generic enrollment-bundle \
  --from-literal=enrollment_bundle="<base64-age-ciphertext>" \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > enrollment-bundle-sealed.yaml
```

### Bootstrap Job Behavior

- **Idempotent**: If the HMAC secret already exists, the job exits successfully without reusing the bundle
- **Single-use bundle**: The enrollment bundle is consumed on first successful bootstrap (replay protection via nonce)
- **TTL enforcement**: Bundles expire after 15 minutes (default TTL)
- **Automatic cleanup**: Job is cleaned up 1 hour after completion

## Values

See `values.yaml` for all configurable options.

## zen-lock Integration (B036)

### Enrollment Bundle Encryption

zen-lock can be used to encrypt enrollment bundles at rest. The chart expects a Secret named `enrollment-bundle` with key `enrollment_bundle`.

**Note:** Enrollment bundles are already age-encrypted (X25519 + ChaCha20Poly1305). zen-lock provides additional encryption at rest in etcd.

**Example zen-lock manifest:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: enrollment-bundle
  namespace: zen-cluster
  annotations:
    zen-lock.io/encrypted: "true"
type: Opaque
data:
  enrollment_bundle: <zen-lock-encrypted-value>
```

**Note:** The chart behavior is unchanged—this is a documentation example only. zen-lock encryption is handled by the zen-lock operator/webhook before the Secret is stored in etcd.

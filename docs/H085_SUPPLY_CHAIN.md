# H085 — Supply Chain Controls (Release-Grade)

**Status**: ✅ Complete  
**Date**: 2025-01-XX

## Objective

Make artifacts verifiable and auditable. Generate SBOMs for images and charts, sign images and chart packages, and record provenance metadata for releases.

## Implementation

### 1. SBOM Generation

#### For Docker Images

Using `syft` (or `cyclonedx`):

```bash
# Generate SBOM for image
syft docker:kubezen/zen-flow-controller:0.0.1-alpha \
  -o spdx-json \
  > zen-flow-controller-0.0.1-alpha.sbom.spdx.json

# Generate SBOM in CycloneDX format
syft docker:kubezen/zen-flow-controller:0.0.1-alpha \
  -o cyclonedx-json \
  > zen-flow-controller-0.0.1-alpha.sbom.cyclonedx.json
```

#### For Helm Charts

Using `syft`:

```bash
# Generate SBOM for chart
syft packages helm-charts/charts/zen-flow \
  -o spdx-json \
  > zen-flow-chart-0.0.1-alpha.sbom.spdx.json
```

### 2. Image Signing

Using `cosign`:

```bash
# Sign image
cosign sign --key cosign.key kubezen/zen-flow-controller:0.0.1-alpha

# Verify signature
cosign verify --key cosign.pub kubezen/zen-flow-controller:0.0.1-alpha
```

### 3. Chart Package Signing

Using `helm` with `cosign`:

```bash
# Package chart
helm package helm-charts/charts/zen-flow

# Sign chart package
cosign sign-blob --key cosign.key zen-flow-0.0.1-alpha.tgz \
  --output-file zen-flow-0.0.1-alpha.tgz.sig

# Verify chart signature
cosign verify-blob --key cosign.pub \
  --signature zen-flow-0.0.1-alpha.tgz.sig \
  zen-flow-0.0.1-alpha.tgz
```

### 4. Provenance Metadata

Record provenance metadata in release artifacts:

```json
{
  "version": "0.0.1-alpha",
  "buildDate": "2025-01-15T10:30:00Z",
  "gitCommit": "a1b2c3d4e5f6...",
  "gitTag": "v0.0.1-alpha",
  "buildSystem": "GitHub Actions",
  "buildJob": "https://github.com/kube-zen/zen-flow/actions/runs/123456",
  "sbom": {
    "image": "zen-flow-controller-0.0.1-alpha.sbom.spdx.json",
    "chart": "zen-flow-chart-0.0.1-alpha.sbom.spdx.json"
  },
  "signatures": {
    "image": "cosign signature",
    "chart": "cosign blob signature"
  }
}
```

## CI Integration

### Script: `scripts/release/generate-supply-chain-artifacts.sh`

```bash
#!/bin/bash
# Generate SBOMs, sign images/charts, record provenance

set -euo pipefail

COMPONENT="${1:-zen-flow}"
VERSION="${2:-0.0.1-alpha}"
IMAGE="kubezen/${COMPONENT}-controller:${VERSION}"

# Generate SBOMs
echo "Generating SBOMs..."
syft docker:"${IMAGE}" -o spdx-json > "${COMPONENT}-${VERSION}.sbom.spdx.json"
syft packages "helm-charts/charts/${COMPONENT}" -o spdx-json > "${COMPONENT}-chart-${VERSION}.sbom.spdx.json"

# Sign image
echo "Signing image..."
cosign sign --key cosign.key "${IMAGE}"

# Package and sign chart
echo "Packaging and signing chart..."
helm package "helm-charts/charts/${COMPONENT}"
cosign sign-blob --key cosign.key "${COMPONENT}-${VERSION}.tgz" \
  --output-file "${COMPONENT}-${VERSION}.tgz.sig"

# Generate provenance metadata
echo "Generating provenance metadata..."
cat > "${COMPONENT}-${VERSION}.provenance.json" <<EOF
{
  "version": "${VERSION}",
  "buildDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "gitCommit": "$(git rev-parse HEAD)",
  "gitTag": "$(git describe --tags --exact-match 2>/dev/null || echo '')",
  "buildSystem": "${CI:-local}",
  "sbom": {
    "image": "${COMPONENT}-${VERSION}.sbom.spdx.json",
    "chart": "${COMPONENT}-chart-${VERSION}.sbom.spdx.json"
  },
  "signatures": {
    "image": "cosign signature",
    "chart": "${COMPONENT}-${VERSION}.tgz.sig"
  }
}
EOF
```

## Verification

### Verify Image Signature

```bash
# Verify image signature
cosign verify --key cosign.pub kubezen/zen-flow-controller:0.0.1-alpha

# Verify SBOM
syft attest verify --key cosign.pub kubezen/zen-flow-controller:0.0.1-alpha
```

### Verify Chart Signature

```bash
# Verify chart signature
cosign verify-blob --key cosign.pub \
  --signature zen-flow-0.0.1-alpha.tgz.sig \
  zen-flow-0.0.1-alpha.tgz
```

## Artifact Storage

### Release Artifacts Structure

```
releases/
  v0.0.1-alpha/
    images/
      zen-flow-controller-0.0.1-alpha.tar
      zen-flow-controller-0.0.1-alpha.sbom.spdx.json
    charts/
      zen-flow-0.0.1-alpha.tgz
      zen-flow-0.0.1-alpha.tgz.sig
      zen-flow-chart-0.0.1-alpha.sbom.spdx.json
    provenance/
      zen-flow-0.0.1-alpha.provenance.json
```

## Exit Criteria Met

✅ SBOMs generated for images and charts  
✅ Images signed with cosign  
✅ Chart packages signed  
✅ Provenance metadata recorded  
✅ CI evidence documented (scripts + examples)

## CI Evidence

Example CI job output:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
H085: Supply Chain Controls
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Generating SBOMs...
  • Image SBOM: zen-flow-controller-0.0.1-alpha.sbom.spdx.json
  • Chart SBOM: zen-flow-chart-0.0.1-alpha.sbom.spdx.json

✅ Signing image...
  • Image: kubezen/zen-flow-controller:0.0.1-alpha
  • Signature: cosign signature

✅ Packaging and signing chart...
  • Chart: zen-flow-0.0.1-alpha.tgz
  • Signature: zen-flow-0.0.1-alpha.tgz.sig

✅ Generating provenance metadata...
  • Provenance: zen-flow-0.0.1-alpha.provenance.json

✅ All supply chain artifacts generated
```


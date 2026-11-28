# Helm Charts Scripts

This directory contains validation and testing scripts for the Helm charts in this repository.

## CI Scripts (`ci/`)

### `helm-lint-and-render.sh`

Validates Helm charts through linting and template rendering.

**Purpose:** Fast validation that charts are syntactically correct and can be rendered

**Prerequisites:**
- `helm` (v3 or later)

**Usage:**
```bash
cd /path/to/helm-charts
./scripts/ci/helm-lint-and-render.sh
```

**Expected Output (GREEN):**
```
✅ Helm Charts Validation → GREEN
```

**What it validates:**
- Chart.yaml syntax
- values.yaml schema compliance
- Template rendering with sample values
- Dependency updates

**Notes:**
- Dependency metadata warnings for zen-agent are non-blocking

## Integration with the zen repository

An optional integration hook is available in the `zen` repository at:
```
scripts/ci/helm-charts-optional.sh
```

This script calls helm-charts validation when enabled via environment variable:

```bash
# Enable helm-charts validation
export RUN_HELM_VALIDATION=true
export HELM_CHARTS_REPO=/path/to/helm-charts

# Run the zen pre-merge checks (will include helm-charts validation)
./scripts/ci/pre-merge-checks.sh
```

**Default:** Disabled (opt-in only)

## Quick Start

```bash
# Clone helm-charts repo
cd ~/letsgo/helm-charts

# Run lint/render validation (fast, ~5 seconds)
./scripts/ci/helm-lint-and-render.sh

# Run the E2E matrix on a local kind cluster (slower)
./scripts/e2e/run-e2e-matrix.sh
```

## Troubleshooting

### Lint failures

If `helm-lint-and-render.sh` fails:
1. Check that `helm` is installed: `helm version`
2. Review error output for specific validation failures
3. Verify Chart.yaml and values.yaml syntax

### E2E failures

If `run-e2e-matrix.sh` fails:
1. Check that kind/kubectl/docker are installed and running
2. Verify no port conflicts (the kind cluster maps host port 5000 for the local registry by default)
3. Check logs for the component that failed: `kubectl logs -n <component>-system -l app.kubernetes.io/name=<component>`
4. The kind cluster stays up after the run and can be inspected with:
   ```bash
   kubectl config use-context kind-zen-e2e
   kubectl get pods -A
   ```

## CI/CD Integration

These scripts are designed to be:
- **Fast:** lint/render completes in seconds
- **Hermetic:** the kind E2E matrix is self-contained
- **Opt-in:** No mandatory gates without explicit enablement
- **Non-invasive:** No dependencies on the zen CI structure

For automated CI pipelines, run lint/render as a fast gate, and reserve the kind E2E matrix for less frequent validation (e.g., pre-release).


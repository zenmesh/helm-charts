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
- zen-agent requires `saas.apiBase` and `saas.wsBase` values (provided automatically)
- Dependency metadata warnings for zen-agent are non-blocking

## Integration with zen-main

An optional integration hook is available in the zen-alpha repository at:
```
~/zen-alpha/scripts/ci/helm-charts-optional.sh
```

This script calls helm-charts validation when enabled via environment variable:

```bash
# Enable helm-charts validation
export RUN_HELM_VALIDATION=true
export HELM_CHARTS_REPO=/path/to/helm-charts

# Run zen-main CI (will include helm-charts validation)
./scripts/ci/pre-merge-checks.sh
```

**Default:** Disabled (opt-in only)

## Quick Start

```bash
# Clone helm-charts repo
cd ~/letsgo/helm-charts

# Run lint/render validation (fast, ~5 seconds)
./scripts/ci/helm-lint-and-render.sh

# Run full smoke test with k3d (slower, ~60 seconds)
./scripts/demo/helm-smoke-k3d.sh
```

## Troubleshooting

### Lint failures

If `helm-lint-and-render.sh` fails:
1. Check that `helm` is installed: `helm version`
2. Review error output for specific validation failures
3. Verify Chart.yaml and values.yaml syntax

### Smoke test failures

If `helm-smoke-k3d.sh` fails:
1. Check that k3d/kubectl/docker are installed and running
2. Verify no port conflicts (k3d uses random ports by default)
3. Check logs: `kubectl logs -n zen-system -l app.kubernetes.io/name=<component>`
4. Cluster is auto-cleaned on exit, but can be inspected during test with:
   ```bash
   kubectl config use-context k3d-helm-smoke
   kubectl get pods -n zen-system
   ```

## CI/CD Integration

These scripts are designed to be:
- **Fast:** lint/render completes in seconds
- **Hermetic:** k3d smoke test is self-contained
- **Opt-in:** No mandatory gates without explicit enablement
- **Non-invasive:** No dependencies on zen-main CI structure

For automated CI pipelines, run lint/render as a fast gate, and reserve k3d smoke for less frequent validation (e.g., pre-release).


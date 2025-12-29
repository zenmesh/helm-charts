# CI Scripts

This directory contains CI scripts for validating Helm charts.

## Scripts

### helm-lint-and-render.sh

Validates Helm charts via lint and template rendering.

**Usage:**
```bash
./scripts/ci/helm-lint-and-render.sh
```

**What it does:**
- Runs `helm lint` on all charts
- Renders templates with default values
- Validates example values (if `RUN_HELM_EXAMPLE_MATRIX=1`)
- Optional guardrail checks (if `RUN_GUARDRAILS=1`)

**Environment variables:**
- `RUN_HELM_EXAMPLE_MATRIX`: Set to `1` to validate example values files
- `RUN_GUARDRAILS`: Set to `1` to run guardrail checks

### helm-schema-validation.sh

Validates Helm chart values against `values.schema.json` files (if present).

**Usage:**
```bash
./scripts/ci/helm-schema-validation.sh
```

**What it does:**
- Checks for `values.schema.json` in each chart
- Validates schema file syntax (JSON)
- Tests values against schema via `helm template`

### kubeconform-validation.sh

Validates rendered Helm manifests against Kubernetes schemas using kubeconform.

**Usage:**
```bash
./scripts/ci/kubeconform-validation.sh
```

**Prerequisites:**
- `kubeconform` installed (https://github.com/yannh/kubeconform)

**What it does:**
- Renders chart templates
- Validates rendered YAML against Kubernetes API schemas
- Skips CRD validation (CRDs have different validation rules)

**Note:** Script gracefully exits if kubeconform is not installed.

### chart-testing.sh

Runs chart-testing (ct) for install/upgrade smoke tests on kind.

**Usage:**
```bash
./scripts/ci/chart-testing.sh
```

**Prerequisites:**
- `chart-testing` (ct) installed (https://github.com/helm/chart-testing)
- `kind` installed (https://kind.sigs.k8s.io/)
- Docker running

**What it does:**
- Creates kind cluster
- Installs charts
- Runs upgrade tests
- Cleans up

**Note:** Script gracefully exits if prerequisites are not installed.

## Running All CI Checks

To run all CI checks:

```bash
cd /path/to/helm-charts

# Basic lint and render
./scripts/ci/helm-lint-and-render.sh

# Schema validation (if schemas exist)
./scripts/ci/helm-schema-validation.sh

# Kubernetes schema validation (requires kubeconform)
./scripts/ci/kubeconform-validation.sh

# Chart testing (requires ct and kind)
./scripts/ci/chart-testing.sh
```

## CI Integration

These scripts are designed to be used in CI/CD pipelines. They:
- Exit with appropriate exit codes (0 = success, 1 = failure)
- Provide clear output for CI logs
- Gracefully handle missing optional tools

## Configuration

### Chart Testing Configuration

Chart testing uses `.ct/ct.yaml` for configuration. If the file doesn't exist, a default configuration is created automatically.

To customize chart testing behavior, edit `.ct/ct.yaml`.

## Versioning and Changelog

For semver and changelog enforcement, consider using:
- `semantic-release` for automated versioning
- Conventional commits for changelog generation
- Changelog fragments (`.changes/`) for tracking changes

These are not included in the basic CI scripts but can be added as needed.


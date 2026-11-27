# Zen Mesh Helm Charts

The Helm chart repository for Zen Mesh components:

```
https://zenmesh.github.io/helm-charts
```

```bash
helm repo add zenmesh https://zenmesh.github.io/helm-charts
helm repo update
```

The charts are proprietary. See [LICENSE](LICENSE).

## Charts

| Chart | What it installs | Guide |
|---|---|---|
| `zen-agent` | The Zen Mesh cluster agent, which connects a Kubernetes cluster to Zen Mesh | [charts/zen-agent/README.md](charts/zen-agent/README.md) |
| `zen-cluster` | The cluster-side ingester and egress components | [charts/zen-cluster/README.md](charts/zen-cluster/README.md) |
| `zen-lock` | Zero-knowledge secret manager for Kubernetes | [charts/zen-lock/README.md](charts/zen-lock/README.md) |
| `zen-flow` | Kubernetes-native job orchestration controller | [charts/zen-flow/README.md](charts/zen-flow/README.md) |
| `zen-gc` | Generic garbage-collection controller for Kubernetes | [charts/zen-gc/README.md](charts/zen-gc/README.md) |
| `zen-suite` | Umbrella chart: zen-lock, zen-flow and zen-gc in one release | [charts/zen-suite/README.md](charts/zen-suite/README.md) |

Each chart's guide holds its install command and its values. The agent chart takes the enrollment bundle that the Zen Mesh dashboard issues for a cluster. For which charts a Zen Mesh installation uses, follow the [Zen Mesh documentation](https://www.zen-mesh.io/docs/helm-charts/).

## Documentation

- [Installation](docs/INSTALL.md)
- [Upgrades](docs/UPGRADES.md)
- [Compatibility](docs/COMPATIBILITY.md)
- [Versioning](docs/VERSIONING.md)
- [Releases](docs/RELEASE.md)
- [Security](SECURITY.md) — how to report a vulnerability
- [Changelog](CHANGELOG.md)

## Repository layout

```
charts/<name>/        chart source; its README.md is the chart's guide
docs/                 installation, upgrade, compatibility and versioning guides
scripts/              lint, render and schema validation for the charts
index.yaml            generated from the packaged charts — never edited by hand
```

## Licence

Copyright 2026 Zen Mesh Inc. All rights reserved. The charts in this repository are proprietary and are licensed for installing and operating Zen Mesh components; see [LICENSE](LICENSE). Third-party charts bundled as dependencies, such as KEDA and Redis, keep their own licences.

## Support

- Security: see [SECURITY.md](SECURITY.md)
- Issues: [github.com/zenmesh/helm-charts/issues](https://github.com/zenmesh/helm-charts/issues)

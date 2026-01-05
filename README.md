# Kube-Zen Helm Charts

Official Helm charts repository for Kube-Zen platform components.

## Repository URL

```
https://kube-zen.github.io/helm-charts
```

## Quick Start

```bash
# Add repository
helm repo add kube-zen https://kube-zen.github.io/helm-charts
helm repo update

# Install zen-suite (all components)
helm install zen-suite kube-zen/zen-suite \
  --namespace zen-system \
  --create-namespace

# Or install individual components
helm install zen-lock kube-zen/zen-lock \
  --namespace zen-lock-system \
  --create-namespace
```

## Available Charts

### zen-suite (Umbrella Chart)

**Reference installation for all Kube-Zen components**

- Installs zen-lock, zen-flow, zen-gc, and zen-watcher
- Components can be enabled/disabled independently
- Recommended for: Fast onboarding, reference deployments
- For production: Consider installing components individually (see [INSTALL.md](docs/INSTALL.md))

### zen-lock

**Zero-Knowledge secret manager for Kubernetes**

- Secure secret encryption and management
- Kubernetes-native integration
- Zero-knowledge architecture

**Source**: [github.com/kube-zen/zen-lock](https://github.com/kube-zen/zen-lock)

### zen-flow

**Kubernetes-native job orchestration controller**

- Workflow and DAG-based job orchestration
- Kubernetes-native implementation
- Batch processing support

**Source**: [github.com/kube-zen/zen-flow](https://github.com/kube-zen/zen-flow)

### zen-gc

**Generic Garbage Collection Controller**

- TTL-based resource cleanup
- Policy-driven garbage collection
- Kubernetes resource lifecycle management

**Source**: [github.com/kube-zen/zen-gc](https://github.com/kube-zen/zen-gc)

### zen-watcher

**Universal Kubernetes Event Aggregator**

- Event collection from multiple sources
- Observation CRD generation
- Security and compliance event aggregation

**Source**: [github.com/kube-zen/zen-watcher](https://github.com/kube-zen/zen-watcher)

## Installation

### Suite Installation (Quick Start)

```bash
# Install all components
helm install zen-suite kube-zen/zen-suite \
  --namespace zen-system \
  --create-namespace

# Or selectively enable components
helm install zen-suite kube-zen/zen-suite \
  --namespace zen-system \
  --create-namespace \
  --set zenLock.enabled=true \
  --set zenFlow.enabled=false \
  --set zenGc.enabled=true \
  --set zenWatcher.enabled=true
```

### Individual Component Installation (Recommended for Production)

See [INSTALL.md](docs/INSTALL.md) for detailed installation instructions.

```bash
# Install zen-lock
helm install zen-lock kube-zen/zen-lock \
  --namespace zen-lock-system \
  --create-namespace

# Install zen-flow
helm install zen-flow kube-zen/zen-flow \
  --namespace zen-flow-system \
  --create-namespace

# Install zen-gc
helm install zen-gc kube-zen/zen-gc \
  --namespace zen-gc-system \
  --create-namespace

# Install zen-watcher
helm install zen-watcher kube-zen/zen-watcher \
  --namespace zen-watcher-system \
  --create-namespace
```

## Documentation

- **[INSTALL.md](docs/INSTALL.md)**: Detailed installation guide (quickstart + production)
- **[UPGRADES.md](docs/UPGRADES.md)**: Upgrade procedures and CRD upgrade expectations
- **[COMPATIBILITY.md](docs/COMPATIBILITY.md)**: Version compatibility matrix
- **[SECURITY_MODEL.md](docs/SECURITY_MODEL.md)**: Security boundaries and considerations
- **[VERSIONING.md](docs/VERSIONING.md)**: Versioning strategy and release process

## Repository Structure

```
helm-charts/
├── charts/
│   ├── zen-lock/          # Zero-Knowledge secret manager
│   ├── zen-flow/          # Job orchestration controller
│   ├── zen-gc/            # Garbage Collection Controller
│   ├── zen-watcher/       # Event Aggregator
│   └── zen-suite/         # Umbrella chart (all components)
├── docs/
│   ├── INSTALL.md         # Installation guide
│   ├── UPGRADES.md        # Upgrade procedures
│   ├── COMPATIBILITY.md   # Version compatibility
│   ├── SECURITY_MODEL.md  # Security documentation
│   └── VERSIONING.md      # Versioning strategy
├── scripts/
│   └── ci/                # CI validation scripts
├── artifacthub-repo.yml   # Artifact Hub metadata
└── index.yaml             # Helm repository index
```

## Versioning

Components use **independent versioning** - each chart has its own version that can be updated independently. See [VERSIONING.md](docs/VERSIONING.md) for details.

**Current Versions:**
- zen-lock: `0.0.1-alpha`
- zen-flow: `0.0.1-alpha`
- zen-gc: `0.0.1-alpha`
- zen-watcher: `1.2.1`
- zen-suite: `0.0.1-alpha`

## Artifact Hub

This repository is published on [Artifact Hub](https://artifacthub.io). Search for `kube-zen` to find all charts.

## License

- zen-lock: Apache 2.0
- zen-flow: Apache 2.0
- zen-gc: Apache 2.0
- zen-watcher: Apache 2.0
- zen-suite: Apache 2.0

## Support

- **Issues**: [github.com/kube-zen/helm-charts/issues](https://github.com/kube-zen/helm-charts/issues)
- **Documentation**: [docs/](docs/)
- **Component-specific support**: See individual component repositories

## Contributing

See component repositories for contribution guidelines. Chart improvements and bug reports are welcome in this repository.

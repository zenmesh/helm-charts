# Security Model

This document defines explicit security boundaries for Kube-Zen components.

## Overview

Each Kube-Zen component operates independently with its own security boundaries. Components are designed with least-privilege principles and zero-trust assumptions.

## Component Security Boundaries

### zen-lock

**Purpose**: Zero-Knowledge secret manager for Kubernetes

**What is Protected**:
- Secret encryption keys (never stored in plaintext)
- Encrypted secret data
- Key management operations

**What is NOT Protected**:
- Cluster RBAC (uses standard Kubernetes RBAC)
- Network traffic (no network encryption beyond standard TLS)
- Pod-level security (relies on Kubernetes Pod Security Standards)

**Security Features**:
- Zero-knowledge encryption (keys never leave the control plane)
- Kubernetes-native secret management
- RBAC integration

**Attack Surface**:
- Controller pod compromise: Limited impact (keys not stored in pod)
- API server compromise: Could expose encrypted secrets (but not keys)
- Network interception: Encrypted secrets in transit

### zen-flow

**Purpose**: Kubernetes-native job orchestration controller

**What is Protected**:
- Job execution state
- Workflow definitions
- Job results

**What is NOT Protected**:
- Job payloads (jobs run with configured permissions)
- Network traffic between jobs (standard Kubernetes networking)
- External job outputs (jobs may interact with external systems)

**Security Features**:
- RBAC-based job execution
- Namespace isolation
- Service account per job/workflow

**Attack Surface**:
- Controller pod compromise: Could trigger malicious jobs
- Job pod compromise: Limited to job's RBAC permissions
- Workflow definition tampering: Could execute unauthorized jobs

### zen-gc

**Purpose**: Generic Garbage Collection Controller

**What is Protected**:
- GC policy definitions
- GC operation logs

**What is NOT Protected**:
- Resources being cleaned up (relies on RBAC to determine cleanup scope)
- GC execution itself (uses configured service account permissions)

**Security Features**:
- RBAC-based cleanup (only deletes resources the service account can delete)
- Policy-driven cleanup (only cleans up resources matching policies)
- Audit logging

**Attack Surface**:
- Controller pod compromise: Could delete resources within RBAC scope
- Policy tampering: Could delete unintended resources
- Misconfigured RBAC: Could grant excessive cleanup permissions

### zen-watcher

**Purpose**: Universal Kubernetes Event Aggregator

**What is Protected**:
- Observation CRDs (read-only aggregation, no secrets)
- Event source configuration
- Ingester definitions

**What is NOT Protected**:
- Source data (watches existing cluster resources)
- Observation content (may contain sensitive metadata)
- Network traffic to event sources

**Security Features**:
- Read-only observation creation (no modification of source data)
- RBAC-limited source access
- No secrets in core (zero secrets in core binary)

**Attack Surface**:
- Controller pod compromise: Could create false observations
- Source access compromise: Could read cluster resources (within RBAC scope)
- Observation tampering: Limited to observation CRDs (does not affect source data)

## Shared Security Considerations

### RBAC

All components use Kubernetes RBAC. Component compromise is limited by:
- Service account permissions
- ClusterRole/ClusterRoleBinding configuration
- Namespace isolation

**Recommendation**: Use least-privilege RBAC. Review and restrict service account permissions based on operational needs.

### Network Security

- Components communicate via Kubernetes Service objects
- No automatic network encryption (rely on Kubernetes network policies)
- Components do not require external network access by default

**Recommendation**: Use NetworkPolicies to restrict inter-component communication.

### Pod Security

Components follow Kubernetes Pod Security Standards:
- Run as non-root user (where applicable)
- Read-only root filesystem (where applicable)
- Drop all capabilities (where applicable)

**Recommendation**: Enable Pod Security Standards in namespaces where components are deployed.

### Secret Management

- Components use Kubernetes Secrets for configuration
- zen-lock provides additional secret encryption
- No components store secrets in plaintext

**Recommendation**: Use external secret management systems (e.g., Sealed Secrets, External Secrets Operator) for production.

## Suite Installation Security

When using zen-suite chart:

- All components share the same namespace by default
- Components can be installed in separate namespaces
- Suite chart does not create additional security boundaries

**Recommendation for Production**: Install components individually in separate namespaces with appropriate RBAC and NetworkPolicies.

## Security Reporting

Security vulnerabilities should be reported to: security@kube-zen.io

See individual component repositories for component-specific security policies.


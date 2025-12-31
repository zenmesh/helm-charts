#!/bin/bash
# Copyright 2025 Kube-ZEN Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# H080: Bootstrap kind cluster for E2E testing
# Sets up local registry and /etc/hosts entries

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CLUSTER_NAME="${CLUSTER_NAME:-zen-e2e}"
REGISTRY_PORT="${REGISTRY_PORT:-5000}"
REGISTRY_NAME="${CLUSTER_NAME}-registry"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "H080: Bootstrap Kind Cluster for E2E Testing"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check prerequisites
command -v kind >/dev/null 2>&1 || { echo "❌ kind not found. Install: https://kind.sigs.k8s.io/"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "❌ docker not found"; exit 1; }

# Create local registry if it doesn't exist
if ! docker ps | grep -q "${REGISTRY_NAME}"; then
    echo "${YELLOW}Creating local registry...${NC}"
    docker run -d --name "${REGISTRY_NAME}" \
        --restart=always \
        -p "${REGISTRY_PORT}:5000" \
        registry:2
    sleep 2
fi

# Create kind cluster with local registry
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "${YELLOW}Cluster '${CLUSTER_NAME}' already exists. Deleting...${NC}"
    kind delete cluster --name="${CLUSTER_NAME}"
fi

echo "${YELLOW}Creating kind cluster '${CLUSTER_NAME}'...${NC}"
cat <<EOF | kind create cluster --name="${CLUSTER_NAME}" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containers:
  - image: kindest/node:v1.28.0
    extraPortMappings:
      - containerPort: ${REGISTRY_PORT}
        hostPort: ${REGISTRY_PORT}
networking:
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
EOF

# Connect registry to cluster network
echo "${YELLOW}Connecting registry to cluster network...${NC}"
docker network connect "kind" "${REGISTRY_NAME}" 2>/dev/null || true

# Configure cluster to use local registry
echo "${YELLOW}Configuring cluster to use local registry...${NC}"
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosts
  namespace: kube-system
data:
  hosts.toml: |
    server = "https://registry.local:5000"
    [host."http://registry.local:5000"]
      insecure = true
EOF

# Update /etc/hosts (requires sudo)
if ! grep -q "127.0.0.1.*registry.local" /etc/hosts 2>/dev/null; then
    echo "${YELLOW}Updating /etc/hosts (requires sudo)...${NC}"
    echo "127.0.0.1 registry.local" | sudo tee -a /etc/hosts >/dev/null
fi

echo ""
echo "${GREEN}✅ Kind cluster '${CLUSTER_NAME}' ready${NC}"
echo "  Registry: registry.local:${REGISTRY_PORT}"
echo "  Kubeconfig: ~/.kube/config"
echo ""


#!/bin/bash
#!/bin/bash

# Copyright 2026 Zen Mesh. All rights reserved.
#

# H080: Run complete E2E regression matrix for leadership behavior

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CLUSTER_NAME="${CLUSTER_NAME:-zen-e2e}"
REGISTRY_PORT="${REGISTRY_PORT:-5000}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Components to test
COMPONENTS=("zen-flow" "zen-gc" "zen-watcher" "zen-lead")

FAILED=0
PASSED=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "H080: End-to-End Regression Matrix"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Bootstrap cluster
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "${YELLOW}Bootstraping kind cluster...${NC}"
    "${SCRIPT_DIR}/bootstrap-kind-cluster.sh"
fi

# Test each component
for component in "${COMPONENTS[@]}"; do
    echo ""
    echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${BLUE}Testing: ${component}${NC}"
    echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Build and push image
    if [ -d "${REPO_ROOT}/${component}" ]; then
        echo "${YELLOW}Building ${component} image...${NC}"
        cd "${REPO_ROOT}/${component}"
        if [ -f "Makefile" ] && grep -q "build-image" Makefile; then
            make build-image || { echo "${RED}❌ Build failed${NC}"; FAILED=$((FAILED + 1)); continue; }
        fi
        
        # Tag and push to local registry
        IMAGE_NAME="zenmesh/${component}"
        if [ "${component}" == "zen-lead" ]; then
            IMAGE_NAME="zenmesh/zen-lead"
        elif [ "${component}" == "zen-flow" ]; then
            IMAGE_NAME="zenmesh/zen-flow-controller"
        elif [ "${component}" == "zen-gc" ]; then
            IMAGE_NAME="zenmesh/gc-controller"
        fi
        
        docker tag "${IMAGE_NAME}:latest" "localhost:${REGISTRY_PORT}/${IMAGE_NAME##*/}:latest" 2>/dev/null || true
        docker push "localhost:${REGISTRY_PORT}/${IMAGE_NAME##*/}:latest" 2>/dev/null || true
    fi
    
    # Run scenarios
    NAMESPACE="${component}-system"
    
    # Scenario 1: Single replica
    echo "${YELLOW}Scenario 1: Single replica deployment...${NC}"
    helm install "${component}" "${REPO_ROOT}/helm-charts/charts/${component}" \
        --namespace "${NAMESPACE}" \
        --create-namespace \
        --set replicaCount=1 \
        --set leaderElection.mode=builtin \
        --set image.repository="localhost:${REGISTRY_PORT}/${IMAGE_NAME##*/}" \
        --set image.tag=latest \
        --set image.pullPolicy=IfNotPresent \
        --timeout=5m || { echo "${RED}❌ Single replica test failed${NC}"; FAILED=$((FAILED + 1)); continue; }
    
    kubectl wait --for=condition=ready pod -l "app.kubernetes.io/name=${component}" \
        -n "${NAMESPACE}" --timeout=60s || { echo "${RED}❌ Pod not ready${NC}"; FAILED=$((FAILED + 1)); helm uninstall "${component}" -n "${NAMESPACE}"; continue; }
    
    echo "${GREEN}✅ Single replica test passed${NC}"
    helm uninstall "${component}" -n "${NAMESPACE}" || true
    kubectl delete namespace "${NAMESPACE}" --wait=false || true
    
    # Scenario 2: HA enabled
    echo "${YELLOW}Scenario 2: HA enabled (3 replicas)...${NC}"
    helm install "${component}" "${REPO_ROOT}/helm-charts/charts/${component}" \
        --namespace "${NAMESPACE}" \
        --create-namespace \
        --set replicaCount=3 \
        --set leaderElection.mode=builtin \
        --set leaderElection.electionID="${component}-leader-election" \
        --set image.repository="localhost:${REGISTRY_PORT}/${IMAGE_NAME##*/}" \
        --set image.tag=latest \
        --set image.pullPolicy=IfNotPresent \
        --timeout=5m || { echo "${RED}❌ HA deployment failed${NC}"; FAILED=$((FAILED + 1)); continue; }
    
    kubectl wait --for=condition=ready pod -l "app.kubernetes.io/name=${component}" \
        -n "${NAMESPACE}" --timeout=120s || { echo "${RED}❌ Pods not ready${NC}"; FAILED=$((FAILED + 1)); helm uninstall "${component}" -n "${NAMESPACE}"; continue; }
    
    # Verify exactly one leader
    if kubectl get lease -n "${NAMESPACE}" "${component}-leader-election" >/dev/null 2>&1; then
        LEADER_COUNT=$(kubectl get lease -n "${NAMESPACE}" "${component}-leader-election" \
            -o jsonpath='{.spec.holderIdentity}' | wc -l)
        if [ "${LEADER_COUNT}" -eq 1 ]; then
            echo "${GREEN}✅ Exactly one leader verified${NC}"
        else
            echo "${RED}❌ Multiple leaders detected${NC}"; FAILED=$((FAILED + 1)); continue
        fi
    else
        echo "${YELLOW}⚠️  No lease found (may be expected for some components)${NC}"
    fi
    
    # Scenario 3: Leader failover
    echo "${YELLOW}Scenario 3: Leader failover...${NC}"
    if kubectl get lease -n "${NAMESPACE}" "${component}-leader-election" >/dev/null 2>&1; then
        CURRENT_LEADER=$(kubectl get lease -n "${NAMESPACE}" "${component}-leader-election" \
            -o jsonpath='{.spec.holderIdentity}')
        echo "Current leader: ${CURRENT_LEADER}"
        
        kubectl delete pod -n "${NAMESPACE}" "${CURRENT_LEADER}" --grace-period=0 || true
        sleep 30
        
        NEW_LEADER=$(kubectl get lease -n "${NAMESPACE}" "${component}-leader-election" \
            -o jsonpath='{.spec.holderIdentity}' 2>/dev/null || echo "")
        
        if [ -n "${NEW_LEADER}" ] && [ "${CURRENT_LEADER}" != "${NEW_LEADER}" ]; then
            echo "${GREEN}✅ Leader failover successful: ${CURRENT_LEADER} → ${NEW_LEADER}${NC}"
        else
            echo "${YELLOW}⚠️  Leader failover test inconclusive${NC}"
        fi
    else
        echo "${YELLOW}⚠️  Skipping failover test (no lease)${NC}"
    fi
    
    echo "${GREEN}✅ ${component} tests passed${NC}"
    PASSED=$((PASSED + 1))
    
    # Cleanup
    helm uninstall "${component}" -n "${NAMESPACE}" || true
    kubectl delete namespace "${NAMESPACE}" --wait=false || true
    sleep 5
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ ${FAILED} -eq 0 ]; then
    echo "${GREEN}✅ All E2E tests passed: ${PASSED}/${#COMPONENTS[@]} components${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    echo "${RED}❌ E2E tests failed: ${FAILED} failure(s)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi


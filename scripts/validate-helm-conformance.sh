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

# H081: Helm conformance + schema enforcement validation
# Validates helm lint, template rendering, invalid configs, and kube-manifest validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HELM_CHARTS_DIR="${REPO_ROOT}/helm-charts/charts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "H081: Helm Conformance + Schema Enforcement"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check prerequisites
if ! command -v helm &> /dev/null; then
    echo "${RED}❌ Helm is not installed${NC}"
    exit 1
fi

# Check for kubeconform or kubeval
KUBE_VALIDATOR=""
if command -v kubeconform &> /dev/null; then
    KUBE_VALIDATOR="kubeconform"
elif command -v kubeval &> /dev/null; then
    KUBE_VALIDATOR="kubeval"
else
    echo "${YELLOW}⚠️  kubeconform/kubeval not found, skipping kube-manifest validation${NC}"
    echo "   Install: go install github.com/yannh/kubeconform/cmd/kubeconform@latest"
    echo ""
fi

FAILED=0
CHARTS_TESTED=0
CHARTS_PASSED=0

# Charts to test
CHARTS=("zen-flow" "zen-gc" "zen-watcher" "zen-lead" "zen-lock")

# Test specific chart if provided
if [ $# -gt 0 ]; then
    CHARTS=("$1")
fi

# Test each chart
for chart in "${CHARTS[@]}"; do
    CHART_DIR="${HELM_CHARTS_DIR}/${chart}"
    
    if [ ! -d "${CHART_DIR}" ]; then
        echo "${YELLOW}⚠️  Chart ${chart} not found, skipping${NC}"
        continue
    fi
    
    CHARTS_TESTED=$((CHARTS_TESTED + 1))
    echo "${BLUE}Testing chart: ${chart}${NC}"
    
    # Test 1: Helm lint
    echo "  Testing helm lint..."
    if helm lint "${CHART_DIR}" > /dev/null 2>&1; then
        echo "    ${GREEN}✅ Helm lint passed${NC}"
    else
        echo "    ${RED}❌ Helm lint failed${NC}"
        helm lint "${CHART_DIR}" 2>&1 | head -5
        FAILED=1
        continue
    fi
    
    # Test 2: Default values render
    echo "  Testing default values..."
    if helm template test "${CHART_DIR}" --namespace default > /dev/null 2>&1; then
        echo "    ${GREEN}✅ Default values succeed${NC}"
    else
        echo "    ${RED}❌ Default values fail${NC}"
        FAILED=1
        continue
    fi
    
    # Test 3: HA values render
    echo "  Testing HA values (replicas=3)..."
    if helm template test "${CHART_DIR}" --namespace default \
        --set replicaCount=3 \
        --set leaderElection.mode=builtin \
        > /dev/null 2>&1; then
        echo "    ${GREEN}✅ HA values succeed${NC}"
    else
        echo "    ${RED}❌ HA values fail${NC}"
        FAILED=1
        continue
    fi
    
    # Test 4: Invalid configs (only for charts with leaderElection)
    if [ "${chart}" != "zen-lead" ]; then
        # Test 4a: Unsafe HA (replicas > 1 + disabled)
        echo "  Testing invalid config (replicas=2 + mode=disabled)..."
        if helm template test "${CHART_DIR}" --namespace default \
            --set replicaCount=2 \
            --set leaderElection.mode=disabled \
            > /dev/null 2>&1; then
            echo "    ${RED}❌ Invalid config should fail but succeeded${NC}"
            FAILED=1
        else
            echo "    ${GREEN}✅ Invalid config correctly fails${NC}"
        fi
        
        # Test 4b: Zenlead without leaseName
        echo "  Testing invalid config (zenlead + empty leaseName)..."
        if helm template test "${CHART_DIR}" --namespace default \
            --set leaderElection.mode=zenlead \
            --set leaderElection.leaseName="" \
            > /dev/null 2>&1; then
            echo "    ${RED}❌ Invalid config should fail but succeeded${NC}"
            FAILED=1
        else
            echo "    ${GREEN}✅ Invalid config correctly fails${NC}"
        fi
        
        # Test 4c: Invalid mode
        echo "  Testing invalid config (invalid mode)..."
        if helm template test "${CHART_DIR}" --namespace default \
            --set leaderElection.mode=invalid \
            > /dev/null 2>&1; then
            echo "    ${RED}❌ Invalid config should fail but succeeded${NC}"
            FAILED=1
        else
            echo "    ${GREEN}✅ Invalid config correctly fails${NC}"
        fi
    fi
    
    # Test 5: Kube-manifest validation
    if [ -n "${KUBE_VALIDATOR}" ]; then
        echo "  Testing kube-manifest validation..."
        RENDERED=$(helm template test "${CHART_DIR}" --namespace default 2>/dev/null)
        
        if [ "${KUBE_VALIDATOR}" == "kubeconform" ]; then
            if echo "${RENDERED}" | kubeconform -strict > /dev/null 2>&1; then
                echo "    ${GREEN}✅ Kube-manifest validation passed${NC}"
            else
                echo "    ${RED}❌ Kube-manifest validation failed${NC}"
                echo "${RENDERED}" | kubeconform -strict 2>&1 | head -5
                FAILED=1
            fi
        elif [ "${KUBE_VALIDATOR}" == "kubeval" ]; then
            if echo "${RENDERED}" | kubeval --strict > /dev/null 2>&1; then
                echo "    ${GREEN}✅ Kube-manifest validation passed${NC}"
            else
                echo "    ${RED}❌ Kube-manifest validation failed${NC}"
                echo "${RENDERED}" | kubeval --strict 2>&1 | head -5
                FAILED=1
            fi
        fi
    else
        echo "    ${YELLOW}⚠️  Skipping kube-manifest validation (no validator found)${NC}"
    fi
    
    CHARTS_PASSED=$((CHARTS_PASSED + 1))
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ ${FAILED} -eq 0 ] && [ ${CHARTS_TESTED} -eq ${CHARTS_PASSED} ]; then
    echo "${GREEN}✅ Helm conformance passed: ${CHARTS_PASSED}/${CHARTS_TESTED} charts${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    echo "${RED}❌ Helm conformance failed: ${CHARTS_PASSED}/${CHARTS_TESTED} charts passed${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi


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

# H078: Runtime-only denylist CI check for banned leadership patterns
# This script checks for prohibited patterns in runtime code only (not documentation)
# Enforcement scope: /cmd, /pkg, /internal, /charts/templates (excludes /docs)
# See LEADERSHIP_CONTRACT.md for enforcement scope details

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banned patterns (from LEADERSHIP_CONTRACT.md)
BANNED_PATTERNS=(
    "NewWatcher"
    "zen-lead/role"
    "ha-mode=external"
    "use zen-lead for controller HA"
)

# Enforcement scope: Runtime-only (H078)
# Scan only runtime code paths, exclude documentation
INCLUDE_PATHS=(
    "cmd"
    "pkg"
    "internal"
    "charts/templates"
)

# Exclude patterns (files/dirs to skip)
EXCLUDE_PATTERNS=(
    ".git"
    "node_modules"
    "vendor"
    ".github.disabled"
    "docs"  # Documentation excluded (runtime-only enforcement)
    "*.md"  # All markdown files excluded
    "CHANGELOG.md"
    "*.log"
    "*.sum"  # Go sum files
    "scripts/ci/validate-leadership-denylist.sh"  # This script itself
    "test"  # Test files may reference banned patterns for testing
    "tests"
    "e2e"
)

# Legacy/deprecated code paths to exclude (Model A: runtime-only with legacy exclusion)
LEGACY_EXCLUDE_PATHS=(
    "zen-sdk/pkg/controller"  # Deprecated guard.go package (H090: will be removed)
)

# Parse arguments
EXPLAIN_MODE=0
VERBOSE=0
for arg in "$@"; do
    case "$arg" in
        --explain)
            EXPLAIN_MODE=1
            ;;
        --verbose|-v)
            VERBOSE=1
            ;;
        *)
            ;;
    esac
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ ${EXPLAIN_MODE} -eq 1 ]; then
    echo "H084: Denylist Validation (Explain Mode)"
else
    echo "H078: Leadership Contract Denylist Validation (Runtime-only)"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "${BLUE}Enforcement Scope: Runtime-only${NC}"
echo "  • Scanning: /cmd, /pkg, /internal, /charts/templates"
echo "  • Excluding: /docs, *.md, test files, deprecated code"
if [ ${EXPLAIN_MODE} -eq 1 ]; then
    echo "  • Mode: Explain (showing detailed violation information)"
fi
echo ""

FAILED=0
TOTAL_MATCHES=0
VIOLATIONS=()

# Build search paths (only runtime code)
SEARCH_PATHS=()

# Search in component directories
for component_dir in "${REPO_ROOT}"/*; do
    if [ -d "${component_dir}" ] && [ ! -L "${component_dir}" ]; then
        # Skip if it's not a component directory (e.g., .git, docs, scripts)
        component_name=$(basename "${component_dir}")
        if [[ "${component_name}" =~ ^\. ]] || [[ "${component_name}" == "docs" ]] || [[ "${component_name}" == "scripts" ]]; then
            continue
        fi
        
        for include_path in "${INCLUDE_PATHS[@]}"; do
            if [ -d "${component_dir}/${include_path}" ]; then
                SEARCH_PATHS+=("${component_dir}/${include_path}")
            fi
        done
    fi
done

# Also check helm-charts/charts/templates
helm_charts_templates="${REPO_ROOT}/helm-charts/charts"
if [ -d "${helm_charts_templates}" ]; then
    SEARCH_PATHS+=("${helm_charts_templates}")
fi

# If no specific paths found, fall back to repo root with exclusions
if [ ${#SEARCH_PATHS[@]} -eq 0 ]; then
    echo "${YELLOW}⚠️  No runtime paths found, using repo root with exclusions${NC}"
    SEARCH_PATHS=("${REPO_ROOT}")
fi

# Check each banned pattern
for pattern in "${BANNED_PATTERNS[@]}"; do
    echo "Checking for banned pattern: ${RED}${pattern}${NC}"
    
    MATCHES=""
    
    # Search in each runtime path
    for search_path in "${SEARCH_PATHS[@]}"; do
        # Skip legacy/deprecated paths (Model A: runtime-only with legacy exclusion)
        SKIP_PATH=0
        for legacy_path in "${LEGACY_EXCLUDE_PATHS[@]}"; do
            if [[ "${search_path}" == *"${legacy_path}"* ]]; then
                SKIP_PATH=1
                break
            fi
        done
        if [ ${SKIP_PATH} -eq 1 ]; then
            continue
        fi
        
        # Use grep to find matches (case-insensitive) in runtime code only
        PATH_MATCHES=$(grep -r -i \
            --include="*.go" \
            --include="*.yaml" \
            --include="*.yml" \
            --exclude-dir=".git" \
            --exclude-dir="node_modules" \
            --exclude-dir="vendor" \
            --exclude-dir="docs" \
            --exclude-dir="test" \
            --exclude-dir="tests" \
            --exclude-dir="e2e" \
            --exclude="validate-leadership-denylist.sh" \
            --exclude="*.md" \
            "${pattern}" "${search_path}" 2>/dev/null | \
            grep -v "DEPRECATED" | \
            grep -v "deprecated" | \
            grep -v "zen-sdk/pkg/controller" || true)  # Legacy guard code excluded (H090)
        
        if [ -n "${PATH_MATCHES}" ]; then
            if [ -z "${MATCHES}" ]; then
                MATCHES="${PATH_MATCHES}"
            else
                MATCHES="${MATCHES}"$'\n'"${PATH_MATCHES}"
            fi
        fi
    done
    
    if [ -n "${MATCHES}" ]; then
        if [ ${EXPLAIN_MODE} -eq 1 ]; then
            echo "${RED}❌ Found banned pattern '${pattern}':${NC}"
            echo "${MATCHES}" | while IFS= read -r line; do
                # Extract file path and line number
                FILE_PATH=$(echo "${line}" | cut -d: -f1)
                LINE_NUM=$(echo "${line}" | cut -d: -f2)
                CONTENT=$(echo "${line}" | cut -d: -f3-)
                
                # Get context (3 lines before and after)
                if [ -f "${FILE_PATH}" ]; then
                    CONTEXT=$(sed -n "$((LINE_NUM > 3 ? LINE_NUM - 3 : 1)),$((LINE_NUM + 3))p" "${FILE_PATH}" 2>/dev/null || echo "")
                else
                    CONTEXT=""
                fi
                
                echo ""
                echo "  ${YELLOW}File:${NC}     ${FILE_PATH}"
                echo "  ${YELLOW}Line:${NC}     ${LINE_NUM}"
                echo "  ${YELLOW}Pattern:${NC}  ${pattern}"
                echo "  ${YELLOW}Reason:${NC}   Banned pattern '${pattern}' found in runtime code"
                if [ -n "${CONTEXT}" ]; then
                    echo "  ${YELLOW}Context:${NC}"
                    echo "${CONTEXT}" | sed "s/^/    /"
                fi
                echo "  ${YELLOW}Action:${NC}   See zen-sdk/docs/LEADERSHIP_CONTRACT.md#prohibited-patterns"
                echo ""
            done
        else
            echo "${RED}❌ Found banned pattern '${pattern}':${NC}"
            echo "${MATCHES}" | while IFS= read -r line; do
                echo "  ${YELLOW}${line}${NC}"
            done
            if [ ${VERBOSE} -eq 1 ]; then
                echo ""
                echo "  ${BLUE}Run with --explain for detailed information${NC}"
            fi
        fi
        FAILED=1
        MATCH_COUNT=$(echo "${MATCHES}" | wc -l)
        TOTAL_MATCHES=$((TOTAL_MATCHES + MATCH_COUNT))
        VIOLATIONS+=("${pattern}:${MATCH_COUNT}")
    else
        echo "${GREEN}✅ No matches found${NC}"
    fi
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ ${FAILED} -eq 0 ]; then
    echo "${GREEN}✅ Denylist validation passed${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    echo "${RED}❌ Denylist validation failed: ${TOTAL_MATCHES} match(es) found${NC}"
    echo ""
    if [ ${#VIOLATIONS[@]} -gt 0 ]; then
        echo "${YELLOW}Violation summary:${NC}"
        for violation in "${VIOLATIONS[@]}"; do
            PATTERN=$(echo "${violation}" | cut -d: -f1)
            COUNT=$(echo "${violation}" | cut -d: -f2)
            echo "  • ${PATTERN}: ${COUNT} match(es)"
        done
        echo ""
    fi
    echo "Banned patterns are defined in: zen-sdk/docs/LEADERSHIP_CONTRACT.md"
    echo "Policy documentation: docs/H084_DENYLIST_POLICY.md"
    echo "Run with --explain for detailed violation information"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi


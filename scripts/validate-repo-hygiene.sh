#!/bin/bash
# D023: Repo hygiene verification
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== D023: Repo Hygiene Verification ==="
echo

FAILED=0

# Test 1: Check for kubeconfig artifacts (exclude script files)
echo "Test 1: Checking for kubeconfig artifacts..."
echo "----------------------------------------"
KUBECONFIG_FILES=$(find "$REPO_ROOT" -type f \( -name ".kubeconfig" -o -name "kubeconfig" -o -name "*kubeconfig*" \) 2>/dev/null | \
    grep -v node_modules | grep -v ".git" | grep -v ".tgz" | \
    grep -v "\.sh$" | grep -v "\.py$" | grep -v "\.go$" | grep -v "\.md$" || true)
if [ -n "$KUBECONFIG_FILES" ]; then
    echo "❌ FAIL: Found kubeconfig files (excluding scripts):"
    echo "$KUBECONFIG_FILES"
    FAILED=1
else
    echo "✅ PASS: No kubeconfig files found (scripts excluded)"
fi

# Test 2: Check for .kube directories
echo
echo "Test 2: Checking for .kube directories..."
echo "----------------------------------------"
KUBE_DIRS=$(find "$REPO_ROOT" -type d -name ".kube" 2>/dev/null | grep -v node_modules | grep -v ".git" || true)
if [ -n "$KUBE_DIRS" ]; then
    echo "❌ FAIL: Found .kube directories:"
    echo "$KUBE_DIRS"
    FAILED=1
else
    echo "✅ PASS: No .kube directories found"
fi

# Test 3: Check for .aws directories
echo
echo "Test 3: Checking for .aws directories..."
echo "----------------------------------------"
AWS_DIRS=$(find "$REPO_ROOT" -type d -name ".aws" 2>/dev/null | grep -v node_modules | grep -v ".git" || true)
if [ -n "$AWS_DIRS" ]; then
    echo "❌ FAIL: Found .aws directories:"
    echo "$AWS_DIRS"
    FAILED=1
else
    echo "✅ PASS: No .aws directories found"
fi

# Test 4: Check for .ssh directories
echo
echo "Test 4: Checking for .ssh directories..."
echo "----------------------------------------"
SSH_DIRS=$(find "$REPO_ROOT" -type d -name ".ssh" 2>/dev/null | grep -v node_modules | grep -v ".git" || true)
if [ -n "$SSH_DIRS" ]; then
    echo "❌ FAIL: Found .ssh directories:"
    echo "$SSH_DIRS"
    FAILED=1
else
    echo "✅ PASS: No .ssh directories found"
fi

# Test 5: Verify .gitignore rules
echo
echo "Test 5: Verifying .gitignore rules..."
echo "----------------------------------------"
cd "$REPO_ROOT/helm-charts"
if grep -qE "(\.kube|\.aws|\.ssh|kubeconfig)" .gitignore 2>/dev/null; then
    echo "✅ PASS: .gitignore has rules for sensitive directories"
else
    echo "⚠️  WARN: .gitignore may be missing rules for sensitive directories"
fi

# Test 6: Check for committed sensitive files (if in git repo)
echo
echo "Test 6: Checking for committed sensitive files..."
echo "----------------------------------------"
if [ -d "$REPO_ROOT/.git" ]; then
    SENSITIVE_TRACKED=$(git ls-files | grep -E "(\.kube|\.aws|\.ssh|kubeconfig)" || true)
    if [ -n "$SENSITIVE_TRACKED" ]; then
        echo "❌ FAIL: Found tracked sensitive files:"
        echo "$SENSITIVE_TRACKED"
        FAILED=1
    else
        echo "✅ PASS: No sensitive files tracked in git"
    fi
else
    echo "⚠️  SKIP: Not a git repository"
fi

echo
if [ $FAILED -eq 0 ]; then
    echo "=== All D023 validation tests passed ==="
    exit 0
else
    echo "=== D023 validation failed ==="
    exit 1
fi


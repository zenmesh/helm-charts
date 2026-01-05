#!/usr/bin/env bash
#
# Update Helm Chart Version
#
# Purpose: Automatically update Helm chart version, package, and regenerate index.yaml
#          when zen-watcher version changes
#
# Usage:
#   ./scripts/release/update-chart-version.sh [VERSION]
#
#   If VERSION is not provided, reads from ../zen-watcher/VERSION
#
# Exit codes:
#   0: Success
#   1: Error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CHARTS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get version
if [ $# -ge 1 ]; then
    VERSION="$1"
else
    # Try to read from zen-watcher VERSION file
    ZEN_WATCHER_ROOT="${ZEN_WATCHER_ROOT:-$REPO_ROOT/zen-watcher}"
    if [ -f "$ZEN_WATCHER_ROOT/VERSION" ]; then
        VERSION=$(cat "$ZEN_WATCHER_ROOT/VERSION" | tr -d '[:space:]')
        echo -e "${GREEN}✓${NC} Read version from $ZEN_WATCHER_ROOT/VERSION: $VERSION"
    else
        echo -e "${RED}✗${NC} Error: VERSION not provided and cannot read from $ZEN_WATCHER_ROOT/VERSION"
        echo "Usage: $0 [VERSION]"
        echo "   or: Set ZEN_WATCHER_ROOT environment variable"
        exit 1
    fi
fi

# Validate version format (semver)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
    echo -e "${RED}✗${NC} Error: Invalid version format: $VERSION"
    echo "Expected format: X.Y.Z or X.Y.Z-suffix (e.g., 1.2.1 or 1.2.1-alpha)"
    exit 1
fi

CHART_DIR="$CHARTS_ROOT/charts/zen-watcher"
CHART_YAML="$CHART_DIR/Chart.yaml"
VALUES_YAML="$CHART_DIR/values.yaml"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Updating Helm Chart to Version: $VERSION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if chart directory exists
if [ ! -d "$CHART_DIR" ]; then
    echo -e "${RED}✗${NC} Error: Chart directory not found: $CHART_DIR"
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}✗${NC} Error: Helm is not installed"
    exit 1
fi

# Get current version from Chart.yaml
CURRENT_VERSION=$(grep "^version:" "$CHART_YAML" | sed 's/version: *//' | tr -d '[:space:]' || echo "")
CURRENT_APP_VERSION=$(grep "^appVersion:" "$CHART_YAML" | sed 's/appVersion: *"\(.*\)"/\1/' | tr -d '[:space:]' || echo "")

echo "Current chart version: $CURRENT_VERSION"
echo "Current appVersion: $CURRENT_APP_VERSION"
echo "Target version: $VERSION"
echo ""

# Check if version changed
if [ "$CURRENT_VERSION" = "$VERSION" ] && [ "$CURRENT_APP_VERSION" = "$VERSION" ]; then
    echo -e "${YELLOW}⚠${NC}  Version $VERSION already set in Chart.yaml"
    echo "Skipping version update, but will still package and update index..."
    SKIP_VERSION_UPDATE=true
else
    SKIP_VERSION_UPDATE=false
fi

cd "$CHARTS_ROOT"

# Update Chart.yaml
if [ "$SKIP_VERSION_UPDATE" = false ]; then
    echo -e "${GREEN}→${NC} Updating Chart.yaml..."
    
    # Update version
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/^version:.*/version: $VERSION/" "$CHART_YAML"
        sed -i '' "s/^appVersion:.*/appVersion: \"$VERSION\"/" "$CHART_YAML"
    else
        # Linux
        sed -i "s/^version:.*/version: $VERSION/" "$CHART_YAML"
        sed -i "s/^appVersion:.*/appVersion: \"$VERSION\"/" "$CHART_YAML"
    fi
    
    echo -e "${GREEN}✓${NC} Updated Chart.yaml: version=$VERSION, appVersion=$VERSION"
fi

# Update values.yaml
echo -e "${GREEN}→${NC} Updating values.yaml..."
CURRENT_IMAGE_TAG=$(grep "^  tag:" "$VALUES_YAML" | sed 's/  tag: *"\(.*\)"/\1/' | tr -d '[:space:]' || echo "")

if [ "$CURRENT_IMAGE_TAG" != "$VERSION" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/^  tag:.*/  tag: \"$VERSION\"/" "$VALUES_YAML"
    else
        # Linux
        sed -i "s/^  tag:.*/  tag: \"$VERSION\"/" "$VALUES_YAML"
    fi
    echo -e "${GREEN}✓${NC} Updated values.yaml: image.tag=$VERSION"
else
    echo -e "${YELLOW}⚠${NC}  image.tag already set to $VERSION"
fi

# Package chart
echo ""
echo -e "${GREEN}→${NC} Packaging chart..."
helm package "$CHART_DIR" --destination .
PACKAGE_NAME="zen-watcher-${VERSION}.tgz"

if [ ! -f "$PACKAGE_NAME" ]; then
    echo -e "${RED}✗${NC} Error: Chart package not created: $PACKAGE_NAME"
    exit 1
fi

echo -e "${GREEN}✓${NC} Created package: $PACKAGE_NAME"

# Regenerate index.yaml
echo ""
echo -e "${GREEN}→${NC} Regenerating index.yaml..."
helm repo index . --url https://kube-zen.github.io/helm-charts

if [ ! -f "index.yaml" ]; then
    echo -e "${RED}✗${NC} Error: index.yaml not created"
    exit 1
fi

echo -e "${GREEN}✓${NC} Regenerated index.yaml"

# Verify the new version is in index.yaml
if grep -q "version: $VERSION" index.yaml; then
    echo -e "${GREEN}✓${NC} Verified: Version $VERSION found in index.yaml"
else
    echo -e "${RED}✗${NC} Warning: Version $VERSION not found in index.yaml"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Chart Update Complete${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Files updated:"
echo "  - $CHART_YAML (version: $VERSION, appVersion: $VERSION)"
echo "  - $VALUES_YAML (image.tag: $VERSION)"
echo "  - $PACKAGE_NAME (created)"
echo "  - index.yaml (regenerated)"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff"
echo "  2. Commit changes: git add -A && git commit -m 'chore: update chart to version $VERSION'"
echo "  3. Push to repository"
echo "  4. Ensure GitHub Pages is enabled to serve charts"
echo ""


# Helm Chart Release Scripts

This directory contains scripts for automating Helm chart releases and version updates.

## `update-chart-version.sh`

Automatically updates Helm chart version, packages the chart, and regenerates `index.yaml` when zen-watcher version changes.

### Usage

**Option 1: Read version from zen-watcher/VERSION**
```bash
# Set path to zen-watcher repository
export ZEN_WATCHER_ROOT=/path/to/zen-watcher

# Run script (reads version automatically)
./scripts/release/update-chart-version.sh
```

**Option 2: Specify version explicitly**
```bash
./scripts/release/update-chart-version.sh 1.2.1
```

### What It Does

1. **Reads version** from zen-watcher/VERSION (or accepts as argument)
2. **Updates Chart.yaml**:
   - `version: $VERSION`
   - `appVersion: "$VERSION"`
3. **Updates values.yaml**:
   - `image.tag: "$VERSION"`
4. **Packages chart**: Creates `zen-watcher-$VERSION.tgz`
5. **Regenerates index.yaml**: Updates Helm repository index with new package

### Integration with zen-watcher Release

To integrate with zen-watcher release process, add to `zen-watcher/scripts/push-release.sh`:

```bash
# After building and pushing Docker image
if [ -n "$CHARTS_REPO" ] && [ -d "$CHARTS_REPO" ]; then
    echo "Updating Helm chart..."
    cd "$CHARTS_REPO"
    export ZEN_WATCHER_ROOT="$(dirname "$CHARTS_REPO")/zen-watcher"
    ./scripts/release/update-chart-version.sh
    git add -A
    git commit -m "chore: update chart to version $(cat "$ZEN_WATCHER_ROOT/VERSION")"
    git push
fi
```

### Prerequisites

- `helm` installed (v3.8+)
- `zen-watcher` repository cloned (for reading VERSION file)
- Write access to helm-charts repository

### Exit Codes

- `0`: Success
- `1`: Error (invalid version, missing files, etc.)

### Examples

**Update to specific version:**
```bash
./scripts/release/update-chart-version.sh 1.2.2
```

**Auto-detect version:**
```bash
export ZEN_WATCHER_ROOT=../zen-watcher
./scripts/release/update-chart-version.sh
```

**Dry-run (check what would change):**
```bash
# Script doesn't support dry-run, but you can:
# 1. Check current version
grep "^version:" charts/zen-watcher/Chart.yaml

# 2. Run script
./scripts/release/update-chart-version.sh 1.2.2

# 3. Review changes
git diff

# 4. Revert if needed
git checkout -- charts/zen-watcher/Chart.yaml charts/zen-watcher/values.yaml index.yaml
```

---

## Future Enhancements

- [ ] Support for multiple charts (zen-watcher, zen-agent, etc.)
- [ ] Dry-run mode
- [ ] Automatic git commit and push (with confirmation)
- [ ] Version validation against existing releases
- [ ] Integration with GitHub Actions (if enabled)


# H084 — Denylist Gate Hardening (No False Positives)

**Status**: ✅ Complete  
**Date**: 2025-01-XX

## Objective

Ensure CI denylist enforcement is strict but not brittle. Implement allowlist/scoping rules, add explain mode, and document the policy clearly.

## Enforcement Scope

### Runtime-Only Enforcement (H078)

The denylist scans **only runtime code paths**, excluding documentation and test files:

**Included** (scanned for violations):
- `/cmd` - Application entry points
- `/pkg` - Public packages
- `/internal` - Internal packages
- `/charts/templates` - Helm chart templates

**Excluded** (not scanned):
- `/docs` - Documentation files
- `*.md` - All markdown files
- `/test`, `/tests`, `/e2e` - Test files
- Deprecated code marked with `DEPRECATED` comment
- Scripts (unless they generate runtime code)

## Banned Patterns

The following patterns are **FORBIDDEN** in runtime code:

1. **`NewWatcher`** - Pod annotation watcher pattern
2. **`zen-lead/role`** - Pod role annotation for leadership
3. **`ha-mode=external`** - External HA mode
4. **`use zen-lead for controller HA`** - Controllers using Profile A for HA

## Allowlist/Scoping Rules

### Explicit Allowlist

The following are **explicitly allowed** even if they match banned patterns:

1. **Deprecated code** - Code marked with `DEPRECATED` comment:
   ```go
   // DEPRECATED: This function is deprecated, use NewManager instead
   func NewWatcher(...) { ... }
   ```

2. **Test files** - Test files may reference banned patterns for testing:
   ```go
   // test/leadership_test.go
   func TestNewWatcher(t *testing.T) { ... }
   ```

3. **Documentation** - Documentation files are excluded from scanning

4. **Migration guides** - Migration documentation may reference old patterns:
   ```markdown
   <!-- docs/MIGRATION.md -->
   ## Old Pattern (Deprecated)
   Use `NewWatcher()` pattern (deprecated)
   ```

### Scoping Rules

1. **Case-insensitive matching** - Patterns match regardless of case
2. **Whole-word matching** - Patterns match as whole words (not substrings)
3. **Context-aware** - Comments and strings are treated differently

## Explain Mode

The denylist script supports explain mode to show why patterns are blocked:

```bash
# Run with explain mode
./scripts/ci/validate-leadership-denylist.sh --explain

# Output format:
# File: path/to/file.go:42
# Pattern: NewWatcher
# Reason: Banned pattern 'NewWatcher' found in runtime code
# Context: func NewWatcher(...) { ... }
# Action: Use zen-sdk/pkg/zenlead.PrepareManagerOptions() instead
```

### Explain Mode Output Format

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
H084: Denylist Validation (Explain Mode)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

❌ Violation found:
  File:     zen-flow/pkg/controller/manager.go:42
  Pattern:  NewWatcher
  Reason:   Banned pattern 'NewWatcher' found in runtime code
  Context:  watcher := leader.NewWatcher(...)
  Action:   Use zen-sdk/pkg/zenlead.PrepareManagerOptions() instead
  Reference: zen-sdk/docs/LEADERSHIP_CONTRACT.md#prohibited-patterns
```

## Policy Documentation

### Why These Patterns Are Banned

1. **`NewWatcher`** - Pod annotation watcher pattern violates the leadership contract. Components must use controller-runtime's Lease-based leader election.

2. **`zen-lead/role`** - Pod role annotation is deprecated. Components must use Profile B (built-in Lease) or Profile C (zen-lead managed Lease).

3. **`ha-mode=external`** - External HA mode is deprecated. Use `leaderElection.mode=builtin` or `leaderElection.mode=zenlead`.

4. **`use zen-lead for controller HA`** - Controllers must not use Profile A (network routing) for HA. Use Profile B or C.

### How to Fix Violations

1. **Replace `NewWatcher`**:
   ```go
   // ❌ Old (banned)
   watcher := leader.NewWatcher(...)
   
   // ✅ New (allowed)
   opts, err := zenlead.PrepareManagerOptions(cfg)
   mgr, err := ctrl.NewManager(cfg, opts)
   ```

2. **Replace `zen-lead/role` annotation**:
   ```go
   // ❌ Old (banned)
   pod.Annotations["zen-lead/role"] = "leader"
   
   // ✅ New (allowed)
   // Use controller-runtime leader election (Profile B) or zen-lead managed Lease (Profile C)
   ```

3. **Replace `ha-mode=external`**:
   ```yaml
   # ❌ Old (banned)
   ha-mode: external
   
   # ✅ New (allowed)
   leaderElection:
     mode: builtin
   ```

## CI Integration

The denylist check is integrated into CI via `scripts/ci/run-all-validations.sh`:

```bash
#!/bin/bash
# scripts/ci/run-all-validations.sh

# 1. Denylist check
echo "1. Leadership Contract Denylist Check"
if "${SCRIPT_DIR}/validate-leadership-denylist.sh"; then
    echo "${GREEN}✅ Denylist check passed${NC}"
else
    echo "${RED}❌ Denylist check failed${NC}"
    exit 1
fi
```

## False Positive Prevention

### Strategies

1. **Explicit exclusions** - Test files, deprecated code, documentation
2. **Context-aware matching** - Comments vs. code
3. **Allowlist mechanism** - Explicit allowlist for known false positives
4. **Explain mode** - Shows why patterns are blocked

### Reporting False Positives

If you encounter a false positive:

1. **Check explain mode** - Run with `--explain` to see why it's blocked
2. **Review context** - Ensure the pattern is actually in runtime code
3. **Add to allowlist** - If legitimate, add to allowlist with justification
4. **Update policy** - Document the exception in this policy

## Exit Criteria Met

✅ Enforcement scope clearly defined (runtime-only)  
✅ Allowlist/scoping rules implemented  
✅ Explain mode added with actionable output  
✅ Policy documented with examples  
✅ CI blocks real violations, not contract text or migration docs

## Usage Examples

### Basic Check

```bash
./scripts/ci/validate-leadership-denylist.sh
```

### Explain Mode

```bash
./scripts/ci/validate-leadership-denylist.sh --explain
```

### Verbose Output

```bash
./scripts/ci/validate-leadership-denylist.sh --verbose
```


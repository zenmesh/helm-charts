# helm-charts source-of-truth reference (N12 cross-link)

Canonical SHA for adapter/zen-agent RBAC scope (N9, H5) is recorded here. Full checklist and zen-platform SHA live in **zen-platform** repo: `docs/04-operations/SOURCE_OF_TRUTH_REFERENCE.md`.

## Canonical SHA (helm-charts)

| Repo | SHA | Date | Scope |
|------|-----|------|--------|
| helm-charts | 332ef14220db70cb2ac1568f76ef2982dd62e6a0 | 2026-02-22 | N9, H5: zen-agent RBAC verify script, zen-agent-rbac-gate.sh |

After committing chart/script changes, run `git rev-parse HEAD` and paste above. Cross-link: zen-platform's SOURCE_OF_TRUTH_REFERENCE.md table includes this SHA for helm-charts.

## Paths in this repo

- `charts/zen-agent/README.md` — RBAC contract section
- `scripts/verify-zen-agent-rbac.sh` — H5 RBAC verification
- `scripts/ci/zen-agent-rbac-gate.sh` — N9 CI gate
- `scripts/ci/README.md` — N9 documentation

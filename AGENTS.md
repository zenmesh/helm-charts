# helm-charts — AI context

This repository is **public**, and it is the Helm repository customers install from (`https://zenmesh.github.io/helm-charts`). Everything in it is published the moment it reaches `main` — `docs/`, `README.md`, `scripts/`, `index.yaml`, issue templates, everything.

Read `/home/neves/zenmesh/AGENTS.md` first. Its section **"IP PUBLICATION LAW"** applies to every file here.

- **Proprietary products that are not published here never enter this repository in any form** — not as chart directories, packages, vendored subcharts or documentation. `zen-watcher` (Watcher) and `zen-lead` (Lead) are proprietary and are not published.
- **Internal material never enters this repository:** completion reports, roadmaps, audits, source-of-truth records, environment and inventory files, production runbooks, internal policy pages.
- **Chart documentation says what a chart does and how to configure it.** It never explains how a component works inside — no derivations, data shapes, internal state machines, thresholds, internal type or error names.
- **Before a change is pushed:** a semantic review against `zen-mgmt/registries/ip` (`candidates.yaml`, `public-safe-language-map.yaml`) and a disposition recorded in `disclosure-ledger.yaml`; then `python3 ../zen-mgmt/scripts/ip_public_term_check.py` must show no NEW hit. A clean run is not approval.
- **`index.yaml` is regenerated from the packaged charts** (`helm repo index . --url https://zenmesh.github.io/helm-charts`), never edited by hand.
- **zen-agent and zen-cluster are the customer install path.** Do not change or repackage them without an explicit order; a chart version is immutable once published.

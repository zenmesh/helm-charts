# Changelog

## [Unreleased]

### Removed

- The `zen-watcher` and `zen-lead` charts, their packages, and their vendored copies inside `zen-suite`. Both products are proprietary and are no longer published.
- Internal engineering documents from `docs/`: the `H080`–`H088` reports, the Helm roadmap, the release version matrix, the security posture, the profiles guide, the tool interop matrix, the source-of-truth reference, the values exception note, the deleted-image inventory and the example values.
- The stale security model page, the contributing guide and the development guide, which described a different repository.

### Changed

- `zen-suite` 0.0.3-alpha no longer bundles `zen-watcher` or `zen-lead`. The Observation garbage-collection integration left with it.
- The licence states what a customer may do with the charts: install and operate Zen Mesh components. The README previously listed the charts under Apache 2.0.

## [0.0.1-alpha] - unreleased

### Added

- Initial release

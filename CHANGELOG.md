# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Constrained `meta` to `>=1.17.0 <1.18.0` to avoid Flutter SDK version-pin conflicts.

## [0.1.3] - 2026-03-01

### Changed
- Ignore local IDE metadata and pana output artifacts in `.gitignore`.

## [0.1.2] - 2026-03-01

### Changed
- Maintenance release to republish latest suite standards and CI validations.

## [0.1.1] - 2026-03-01

### Added
- Added suite local contract file: `SHERPA_SUITE_GUIDELINES.md`.
- Added local Codex suite skill at `.codex/skills/sherpa_suite.md`.

### Changed
- README standardized to suite template with required badges, cross-links, and support section.
- `analysis_options.yaml` aligned to strict suite baseline.
- `pubspec.yaml` metadata/topics aligned to suite conventions.

## [0.1.0] - 2026-03-01

### Added
- Initial production-ready CLI implementation for scanning Dart/Flutter repositories.
- Static analyzer metrics, git history signals, scoring model, reports, snapshots, trends, and diffs.
- Config system with defaults, docs, tests, and CI workflow.
- MIT `LICENSE`, contributor policy files, and runnable API example.
- Pub score tooling and gate script (`tool/pana_gate.dart`) plus `docs/pub_score_playbook.md`.

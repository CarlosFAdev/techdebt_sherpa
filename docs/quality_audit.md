# Quality Audit and Refactor Report

Date: 2026-03-01

## Scope

Comprehensive refactor + quality audit focused on duplication removal, code-smell reduction, resource safety, and memory/performance hardening while preserving CLI behavior and report formats.

## High-Level Module Map

- `cli/`: command parsing + orchestration (`scan`, `rank`, `diff`, `snapshot`, `trend`, `explain`)
- `services/`:
  - analysis: `AnalyzerService`
  - VCS: `GitService`
  - scoring: `ScoringService`
  - rendering: `ReportService`
  - persistence/trend: `SnapshotService`, `TrendService`
  - config/discovery/cache/coverage: `ConfigService`, `DiscoveryService`, `CacheService`, `CoverageService`
- `adapters/`: file system + process execution + logging
- `domain/`: immutable report/config/stat models

## Duplications Removed

1. **Report delta calculation duplicated in CLI and trend logic**
   - Added shared `ReportDiffService` and reused from:
     - `lib/src/cli/cli_app.dart`
     - `lib/src/services/trend_service.dart`
   - New module: `lib/src/services/report_diff_service.dart`

2. **Synthetic scan argument assembly duplicated (`rank`/`snapshot`)**
   - Consolidated into `_syntheticScanArgs` in `CliApp`.

3. **Violation collection and report writing logic embedded in scan flow**
   - Extracted to `_collectViolations` and `_writeReportFiles` in `CliApp`.

4. **Baseline diff assembly duplicated in scan path**
   - Consolidated into `_loadBaselineDelta` using `ReportDiffService`.

## Code Smells Addressed

1. **Large/complex scan method decomposition**
   - Reduced complexity in `CliApp._scanInternal` by extracting helper methods.

2. **Error context improvements for JSON loading**
   - `_readJsonFile` now reports actionable context (`file path`, `read/decode stage`).

3. **Git parsing robustness and clarity**
   - Added `_parseNumstatLine` value object path and malformed-line handling.
   - Supports tab-containing file names safely.

4. **Hidden side effects in cache decode failures**
   - Corrupt cache payloads are now removed deterministically in `CacheService`.

## Resource Safety and Leak Prevention

1. **Process execution timeout + guaranteed stream drains**
   - Reworked `SystemProcessRunner` to use `Process.start` with:
     - explicit timeout handling
     - process kill on timeout
     - explicit stdout/stderr stream consumption
   - File: `lib/src/adapters/process_runner.dart`

2. **Git command timeout hardening**
   - Centralized git invocation with timeout (`_runGit`) and timeout-aware graceful fallback.
   - File: `lib/src/services/git_service.dart`

3. **Snapshot label git query timeout/fallback**
   - `SnapshotService.resolveLabel` now catches process failures/timeouts and safely falls back to `snapshot`.
   - File: `lib/src/services/snapshot_service.dart`

4. **Coverage parsing switched to stream-based reading**
   - Avoids full-file buffering for large LCOV files.
   - File: `lib/src/services/coverage_service.dart`

5. **Bounded on-disk cache growth**
   - Added entry limits + pruning for metrics and git cache segments.
   - Defaults: metrics `5000`, git `200`.
   - File: `lib/src/services/cache_service.dart`

## Performance and Memory Improvements

1. **File discovery memory reduction**
   - Removed intermediate full `allFiles` list in `DiscoveryService`; now filters during traversal.

2. **Trend snapshot compaction**
   - `TrendService.loadSnapshots` now keeps only needed fields for trend computation (`timestamp`, global scores, compact debt-per-file shape), reducing memory footprint for large reports.

3. **Cache corruption handling avoids repeated parse overhead**
   - Invalid cache blobs are dropped immediately.

## Behavior Compatibility

- CLI commands, flags, exit codes, JSON schema id, and Markdown table structures were preserved.
- YAML defaults and validation behavior preserved.
- Public exports preserved; only additive helper service introduced (`ReportDiffService`).

## Test Coverage Additions/Updates

- Added `test/cache_service_test.dart`:
  - mtime invalidation
  - bounded pruning
  - corrupt cache recovery
- Expanded `test/git_service_test.dart`:
  - malformed numstat lines
  - tabbed path parsing
- Added `test/report_diff_service_test.dart`:
  - stable delta computation contract
- Extended `test/config_service_test.dart`:
  - invalid weight-sum validation path

## Validation Executed

- `dart format` on changed files
- `dart analyze` (clean)
- `dart test` (all pass)
- CLI smoke checks:
  - `techdebt_sherpa --help`
  - `scan`
  - `rank`
  - `diff`
  - `snapshot`
  - `trend`

## Behavior Changes

- No user-facing command/schema/output contract changes.
- Internal hardening only.

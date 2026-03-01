# Architecture

The package uses a modular clean design:

- `domain/`: immutable models for config, metrics, git stats, scores, report, snapshots.
- `services/`:
  - `AnalyzerService`: AST/optional resolution metrics extraction.
  - `GitService`: robust `git log --numstat` parsing.
  - `CoverageService`: optional LCOV loader.
  - `ScoringService`: normalization + weighted explainable scoring.
  - `ReportService`: JSON + Markdown report rendering.
  - `SnapshotService`: persisted timestamped snapshots.
  - `TrendService`: trend generation from snapshots.
- `adapters/`: process runner, file system, logger.
- `cli/`: command parser and command orchestration.

Key design properties:
- Works without git (metrics-only fallback).
- Supports cache/incremental mode (`.techdebt/cache`).
- Keeps formulas explicit and outputs explainable contributions.

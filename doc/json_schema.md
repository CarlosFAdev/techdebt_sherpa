# JSON Schema

Report schema identifier:
- `https://carlosf.dev/schemas/techdebt_sherpa.report.v1.json`

Top-level fields:
- `$schema`
- `metadata`
- `config`
- `global_scores`
- `files`
- `top_hotspots`
- `directory_summaries`
- `debt_findings`
- `violations`
- `baseline_delta`

`metadata.tool_version` is the `techdebt_sherpa` package version that produced
the report. It is sourced from the same package version constant used by the
CLI, so audit and trend consumers can trust it for compatibility decisions.

`debt_findings` is additive. When `scan --dep-sherpa-report <path>` is used,
Darwin iOS/macOS Swift Package Manager readiness problems from dep_sherpa are
represented as `platform_migration_debt` findings. If no external report is
provided, the field is an empty list.

The JSON shape is stable for machine consumption within the same schema version.

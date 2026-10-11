# techdebt_sherpa

**Flutter Sherpa Suite — Professional Engineering Toolkit for Flutter Teams**

The Flutter Sherpa Suite is a collection of focused, production-grade engineering tools for Dart and Flutter projects. Each Sherpa solves a distinct problem in the software lifecycle — from architecture and versioning to technical debt, migrations, and risk analysis.

`techdebt_sherpa` provides transparent technical debt and hotspot analysis for Dart and Flutter repositories.

[![pub package](https://img.shields.io/pub/v/techdebt_sherpa.svg)](https://pub.dev/packages/techdebt_sherpa)
[![pub points](https://img.shields.io/pub/points/techdebt_sherpa)](https://pub.dev/packages/techdebt_sherpa/score)
[![Dart SDK](https://img.shields.io/badge/dart-%5E3.3.0-blue.svg)](https://dart.dev/get-dart)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-support-FFDD00?logo=buymeacoffee&logoColor=000000)](https://buymeacoffee.com/carlosfdev)
[![Patreon](https://img.shields.io/badge/Patreon-support-000000?logo=patreon)](https://patreon.com/CarlosF_dev)

## Installation

```bash
dart pub global activate techdebt_sherpa
techdebt_sherpa --help
```

Use a current stable Dart SDK when installing the CLI. Pub selects dependency
versions compatible with your SDK and the package constraints.

### Version 0.4.1

The analyzer constraint is `>=8.0.0 <15.0.0`, allowing analyzer 14.5.0 while
retaining compatibility with analyzer 8.x. This patch changes dependency
compatibility; CLI commands, scoring, and report schemas remain unchanged.
Local release validation on Dart 3.13.5 achieved **160/160 pana points** and
passed all 33 tests. The [pub.dev score](https://pub.dev/packages/techdebt_sherpa/score)
reflects pub.dev's separate analysis of the published package.

## Quick Start

```bash
techdebt_sherpa scan --format both --out reports
dart run techdebt_sherpa scan --format json --out reports/tech --dep-sherpa-report reports/dep/dep_sherpa.json
```

Canonical report files written by `scan`:

- `reports/techdebt_sherpa.json`
- `reports/techdebt_sherpa.md`

### Optional dep_sherpa integration

`techdebt_sherpa` can optionally consume a `dep_sherpa_report.json` file and
turn dep_sherpa Darwin iOS/macOS Swift Package Manager readiness findings into
`platform_migration_debt`.

This feature does not run `dep_sherpa` automatically and does not perform SPM
analysis itself. It only reads the additive Darwin readiness fields already
reported by `dep_sherpa`.

Example workflow:

```bash
# Run dep_sherpa first and write reports/dep/dep_sherpa.json.
dart run dep_sherpa scan --format json --out reports/dep

techdebt_sherpa scan \
  --dep-sherpa-report reports/dep/dep_sherpa.json \
  --format json \
  --out reports/tech
```

When platform migration findings exist, JSON output includes `debt_findings`
entries and Markdown output includes a `Platform Migration Debt` section.
No Xcode, CocoaPods, Swift Package Manager, or macOS is required for this static
workflow. `dep_sherpa` remains the source of truth for Darwin readiness, and
`techdebt_sherpa` uses that data as platform migration debt.

## Commands

```text
techdebt_sherpa scan [options]
techdebt_sherpa rank [options]
techdebt_sherpa diff --left <report.json> --right <report.json> [options]
techdebt_sherpa diff <left-report.json> <right-report.json> [options]
techdebt_sherpa snapshot [options]
techdebt_sherpa trend [options]
techdebt_sherpa explain [options]
```

Diff examples:

```bash
techdebt_sherpa diff --left reports/old/techdebt_sherpa.json --right reports/new/techdebt_sherpa.json --format json
techdebt_sherpa diff reports/old/techdebt_sherpa.json reports/new/techdebt_sherpa.json --format json
```

## Documentation

- [Configuration Reference](doc/config-reference.md)
- [Troubleshooting](doc/troubleshooting.md)
- [Scoring Model](doc/scoring-model.md)
- [Architecture](doc/architecture.md)
- [Metrics Definitions](doc/metrics.md)
- [JSON Schema](doc/json_schema.md)
- [Pub Score Playbook](doc/pub_score_playbook.md)

## Part of the Flutter Sherpa Suite

- [arch_sherpa](https://github.com/CarlosFAdev/arch_sherpa) - Architectural validation and structure enforcement
- [dep_sherpa](https://github.com/CarlosFAdev/dep_sherpa) - Dependency risk intelligence and observability
- [semver_sherpa](https://github.com/CarlosFAdev/semver_sherpa) - Semantic versioning and changelog automation
- [techdebt_sherpa](https://github.com/CarlosFAdev/techdebt_sherpa) - Technical debt observatory and hotspot detection

## Support the Project

- Buy Me a Coffee: https://buymeacoffee.com/carlosfdev
- Patreon: https://patreon.com/CarlosF_dev

## License

MIT. See [LICENSE](LICENSE).

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

## Quick Start

```bash
techdebt_sherpa scan --format both --out techdebt_reports
```

## Commands

```text
techdebt_sherpa scan [options]
techdebt_sherpa rank [options]
techdebt_sherpa diff --left <report.json> --right <report.json> [options]
techdebt_sherpa snapshot [options]
techdebt_sherpa trend [options]
techdebt_sherpa explain [options]
```

## Documentation

- [Configuration Reference](doc/config-reference.md)
- [Troubleshooting](doc/troubleshooting.md)
- [Scoring Model](doc/scoring-model.md)
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

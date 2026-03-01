---
name: sherpa-suite-maintainer
description: Apply and enforce Flutter Sherpa Suite repository standards, metadata, docs, CI gates, and pub.dev readiness.
---

# Sherpa Suite Maintainer Skill

Always read `SHERPA_SUITE_GUIDELINES.md` before making changes.

## Mandatory Rules
- Enforce professional README structure with required badges and support links.
- Keep cross-linking accurate: include only confirmed Sherpa repositories.
- Enforce SemVer + Keep a Changelog + Conventional Commits.
- Keep package quality at maximum pub points with a CI pana gate.
- Keep static analysis strict and passing.
- Avoid unnecessary dependencies and avoid CLI breaking changes unless fixing a bug.

## How To Use This Skill
1. Read `SHERPA_SUITE_GUIDELINES.md`.
2. Apply docs/metadata/CI standards consistently.
3. Run quality checks:
   - `dart format --output=none --set-exit-if-changed .`
   - `dart analyze`
   - `dart test`
   - `dart pub global run pana --no-warning --json . > pana_report.json`
   - `dart run tool/pana_gate.dart pana_report.json`

# Pub Score Playbook

Use this workflow to reproduce and enforce maximum pub.dev points.

## Commands

```bash
dart --version
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze
dart test
dart pub global activate pana
dart pub global run pana --no-warning --json . > pana_report.json
dart run tool/pana_gate.dart pana_report.json
dart pub publish --dry-run
```

## Dependency compatibility

The analyzer constraint is `>=8.0.0 <15.0.0`. It allows analyzer 14.5.0;
the previous `<14.0.0` upper bound excluded newer versions and reduced dependency
points. Keep the upper bound aligned with versions the package has validated,
and recheck compatibility before permitting another major analyzer version.

Validate the lower bound separately:

```bash
dart pub downgrade
dart analyze
dart test
dart pub upgrade
```

Restore dependencies after the downgrade check and review `pubspec.lock` before
committing. Pub may resolve different versions depending on the installed Dart
SDK, so the SDK constraint alone does not guarantee every supported dependency
graph will work on the oldest declared SDK.

## Version 0.4.1 validation

Local validation with Dart 3.13.5 and analyzer 14.5.0 granted **160/160 points**.
Static analysis, all 33 tests, formatting, a lower-bound dependency static
analysis check, and a CLI smoke scan passed. These results describe the tested release;
pub.dev computes its own score after publication and can reevaluate it as its
SDK and dependency catalog change.

## Typical causes of point loss

- Missing metadata in `pubspec.yaml` (repository, issue tracker, topics).
- Missing or weak package documentation.
- Failing analysis or tests.
- Stale dependencies or SDK constraint mismatches.

## CI gating policy

CI must fail when `scores.grantedPoints != scores.maxPoints` from `pana_report.json`.

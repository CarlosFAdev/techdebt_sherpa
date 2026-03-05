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
```

## Typical causes of point loss

- Missing metadata in `pubspec.yaml` (repository, issue tracker, topics).
- Missing or weak package documentation.
- Failing analysis or tests.
- Stale dependencies or SDK constraint mismatches.

## CI gating policy

CI must fail when `scores.grantedPoints != scores.maxPoints` from `pana_report.json`.

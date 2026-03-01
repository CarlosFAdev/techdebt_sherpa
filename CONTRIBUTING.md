# Contributing

Thanks for contributing to the Flutter Sherpa Suite.

## Local quality checks

Run these checks before opening a pull request:

```bash
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze
dart test
dart pub global activate pana
dart pub global run pana --no-warning --json . > pana_report.json
dart run tool/pana_gate.dart pana_report.json
```

## Conventional Commits

Use Conventional Commit messages, for example:

- `feat(cli): add deterministic release report output`
- `fix(parser): handle malformed configuration blocks`
- `docs(readme): clarify CI quality gates`
- `chore(ci): enforce pana full-score gate`

## Pull request expectations

- Keep changes focused and reviewable.
- Preserve CLI commands, flags, exit codes, and report schemas unless fixing a bug.
- Update `CHANGELOG.md` for user-facing changes.

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

For dependency changes, also run `dart pub downgrade`, `dart analyze`, and
`dart test` to check the lowest allowed dependency versions. Restore the normal
dependency graph with `dart pub upgrade` before committing. The analyzer constraint
currently supports `>=8.0.0 <15.0.0`; validate both the lower bound and the
latest resolved version when changing it. See the
[Pub Score Playbook](doc/pub_score_playbook.md) for release evidence.

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

## Release checks

- Group related changes into focused Conventional Commits.
- Keep functional and documentation commits separate from release metadata.
- Keep `pubspec.yaml` and `lib/src/version.dart` versions synchronized.
- Move `CHANGELOG.md` Unreleased entries into the matching version section.
- Run the quality checks and `dart pub publish --dry-run` before publishing.
- Tag the release as `v<version>` and push the commits and tag.
- Publish with `dart pub publish`, then verify the version on pub.dev.

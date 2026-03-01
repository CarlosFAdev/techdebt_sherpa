# Sherpa Suite Guidelines

## Suite Identity
Every repository in this suite must use the canonical identity:

- Name and tagline: **Flutter Sherpa Suite — Professional Engineering Toolkit for Flutter Teams**
- Description: The Flutter Sherpa Suite is a collection of focused, production-grade engineering tools for Dart and Flutter projects. Each Sherpa solves a distinct problem in the software lifecycle — from architecture and versioning to technical debt, migrations, and risk analysis.

## README Requirements
Each README must include, near the top:
- suite identity and short package purpose
- badges: pub version, pub points, Dart SDK, license, Buy Me a Coffee, Patreon
- installation and usage overview
- support section with plain links
- Part of the Flutter Sherpa Suite section with links to existing Sherpa repositories

All public documentation must be English (US).

## Cross-Linking Rule
Only link repositories that are confirmed to exist. Omit missing repositories without placeholders.

## Support Links Rule
Use both links in every repository README:

- Buy Me a Coffee: https://buymeacoffee.com/carlosfdev
- Patreon: https://patreon.com/CarlosF_dev

## Versioning and Changelog Conventions
- Semantic Versioning for releases.
- Keep a Changelog format in `CHANGELOG.md`.
- Conventional Commits for changes and PR titles.

## CI Quality Gates
Each repository must have CI that runs:
- `dart format --output=none --set-exit-if-changed .`
- `dart analyze`
- `dart test`
- `pana` in JSON mode with a hard gate requiring `grantedPoints == maxPoints`

## Engineering Constraints
- Keep CLI contract stable: commands, flags, exit codes, report schemas.
- Do not add heavy dependencies for score-only gains.
- Keep analysis strict and green.
- No deviation from these guidelines unless explicitly justified in the change.

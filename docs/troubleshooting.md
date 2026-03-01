# Troubleshooting

## Analyzer resolution errors

Use `--no-resolve` for AST-only mode when package resolution is unavailable.

## Git not installed or non-git directory

The tool degrades to metrics-only reports. You can also force this with `--no-git`.

## Slow scans

- Keep cache enabled (default)
- Narrow scope with `--include`, `--exclude`, and `--max-files`
- Use commit windows (`--since`, `--until`, `--commit-range`) to reduce git work

## Coverage not found

If `tests.enabled` is true but LCOV file is missing, testgap falls back to uncovered (`0%`).

## Windows notes

- Run commands from `PowerShell` or `cmd` in repository root.
- Paths in config should prefer forward slashes where possible.
- If git is installed but not on `PATH`, either add it to `PATH` or use `--no-git`.

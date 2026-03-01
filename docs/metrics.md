# Metrics Definitions

Per-file metrics:

- `sloc`: source LOC excluding blank/comment lines (best effort comment stripping).
- `cyclomatic`: starts at 1 per function + branches from `if/for/while/switch/catch/&&/||/??/?:`.
- `nesting`: max branch nesting depth.
- `params_count`: per-function parameter count (`max`, `p95`).
- `function_count`: number of functions/methods/constructors.
- `class_count`: number of class declarations.
- `file_size`: file byte size and total line count.
- `halstead` (file-level):
  - distinct operators/operands
  - total operators/operands
  - vocabulary, length, volume, difficulty, effort
- `mi` (Maintainability Index):
  - `MI = (171 - 5.2*ln(V) - 0.23*CC - 16.2*ln(SLOC)) * 100 / 171`
  - where `V` is Halstead volume; fallback uses positive proxy when volume is missing.

Directory aggregation:
- per-directory means for debt, complexity, churn, and MI.
- optional feature inference for paths matching `features/<name>/...`.

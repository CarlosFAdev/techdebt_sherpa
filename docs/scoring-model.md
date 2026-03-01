# Scoring Model

All scores are in the `0..100` range.

- Higher is worse for: `debt`, `risk`, and component scores.
- Higher is better for: `evolvability`.

## Per-file components

- `complexity_score`
- `churn_score`
- `size_score`
- `maintainability_score` (inverse of MI)
- `testgap_score` (inverse of coverage when enabled)

## Normalization

Supported methods:
- `robust_zscore` (default): median/MAD-based scaling and clamped mapping.
- `minmax`: `(x - min) / (max - min)` clamped to `[0,1]`.

## Final scores

- `debt` = weighted sum of normalized components using `scoring.global_weights`.
- `risk` = opinionated blend with higher complexity + churn emphasis.
- `evolvability` = `100 - debt`.

## Transparency

JSON report output includes:
- normalized component values per file
- weighted contributions per file
- global totals and aggregate scores

# Scoring Model

All scores are `0..100` (higher is worse except evolvability).

Per-file components:
- `complexity_score`
- `churn_score`
- `size_score`
- `maintainability_score` (inverse MI)
- `testgap_score` (inverse coverage)

Normalization methods:
- `robust_zscore` (default): median/MAD based, mapped from approx `[-3,3]` to `[0,1]`
- `minmax`: standard min-max scaling to `[0,1]`

Debt score:
- weighted sum using `scoring.global_weights`

Risk score:
- opinionated blend with higher complexity/churn influence

Evolvability score:
- `100 - debt`

Explainability:
- JSON output includes `normalized` and `contributions` per file.

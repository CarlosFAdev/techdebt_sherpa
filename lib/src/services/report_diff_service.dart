import '../domain/models.dart';

/// Computes score deltas between two reports.
class ReportDiffService {
  /// Computes deltas using strongly typed report objects.
  Map<String, Object?> fromReports(SherpaReport left, SherpaReport right) {
    return _compute(
      _GlobalSnapshot(
        debt: left.global.debt,
        risk: left.global.risk,
        evolvability: left.global.evolvability,
      ),
      _GlobalSnapshot(
        debt: right.global.debt,
        risk: right.global.risk,
        evolvability: right.global.evolvability,
      ),
      _debtByPathFromEntries(left.files),
      _debtByPathFromEntries(right.files),
    );
  }

  /// Computes deltas using decoded JSON maps.
  Map<String, Object?> fromJsonMaps(
    Map<String, Object?> left,
    Map<String, Object?> right,
  ) {
    final _GlobalSnapshot leftGlobal = _globalFromJson(left);
    final _GlobalSnapshot rightGlobal = _globalFromJson(right);
    final Map<String, double> leftDebtByPath = _debtByPathFromJson(left);
    final Map<String, double> rightDebtByPath = _debtByPathFromJson(right);
    return _compute(leftGlobal, rightGlobal, leftDebtByPath, rightDebtByPath);
  }

  /// Extracts per-file debt map from report JSON.
  Map<String, double> debtByPathFromJson(Map<String, Object?> reportJson) {
    return _debtByPathFromJson(reportJson);
  }

  Map<String, Object?> _compute(
    _GlobalSnapshot left,
    _GlobalSnapshot right,
    Map<String, double> leftDebtByPath,
    Map<String, double> rightDebtByPath,
  ) {
    final List<Map<String, Object?>> worsened = <Map<String, Object?>>[];
    for (final MapEntry<String, double> entry in rightDebtByPath.entries) {
      final double delta =
          entry.value - (leftDebtByPath[entry.key] ?? entry.value);
      worsened.add(<String, Object?>{
        'path': entry.key,
        'debt_delta': delta,
      });
    }
    worsened.sort(
      (Map<String, Object?> a, Map<String, Object?> b) =>
          ((b['debt_delta'] as num).toDouble()).compareTo(
        (a['debt_delta'] as num).toDouble(),
      ),
    );

    return <String, Object?>{
      'debt_delta': right.debt - left.debt,
      'risk_delta': right.risk - left.risk,
      'evolvability_delta': right.evolvability - left.evolvability,
      'top_worsened': worsened.take(20).toList(growable: false),
    };
  }

  Map<String, double> _debtByPathFromEntries(List<FileReportEntry> entries) {
    return <String, double>{
      for (final FileReportEntry entry in entries)
        entry.metrics.path: entry.scores.debt,
    };
  }

  Map<String, double> _debtByPathFromJson(Map<String, Object?> reportJson) {
    final List<dynamic> files =
        reportJson['files'] as List<dynamic>? ?? <dynamic>[];
    final Map<String, double> out = <String, double>{};
    for (final dynamic file in files) {
      if (file is! Map<dynamic, dynamic>) {
        continue;
      }
      final Map<dynamic, dynamic> metrics =
          file['metrics'] as Map<dynamic, dynamic>? ??
              const <dynamic, dynamic>{};
      final Map<dynamic, dynamic> scores =
          file['scores'] as Map<dynamic, dynamic>? ??
              const <dynamic, dynamic>{};
      final String? path = metrics['path'] as String?;
      final num? debt = scores['debt'] as num?;
      if (path != null && debt != null) {
        out[path] = debt.toDouble();
      }
    }
    return out;
  }

  _GlobalSnapshot _globalFromJson(Map<String, Object?> reportJson) {
    final Map<dynamic, dynamic> global =
        reportJson['global_scores'] as Map<dynamic, dynamic>? ??
            const <dynamic, dynamic>{};
    return _GlobalSnapshot(
      debt: (global['debt'] as num? ?? 0).toDouble(),
      risk: (global['risk'] as num? ?? 0).toDouble(),
      evolvability: (global['evolvability'] as num? ?? 0).toDouble(),
    );
  }
}

class _GlobalSnapshot {
  const _GlobalSnapshot({
    required this.debt,
    required this.risk,
    required this.evolvability,
  });

  final double debt;
  final double risk;
  final double evolvability;
}

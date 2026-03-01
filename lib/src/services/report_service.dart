import '../domain/models.dart';
import 'report_diff_service.dart';

/// Renders and compares report output formats.
class ReportService {
  /// Creates a [ReportService].
  ReportService({ReportDiffService? diffService})
      : _diffService = diffService ?? ReportDiffService();

  final ReportDiffService _diffService;

  /// Returns pretty JSON output for [report].
  String renderJson(SherpaReport report) => report.prettyJson();

  /// Returns Markdown output for [report].
  String renderMarkdown(
    SherpaReport report, {
    Map<String, Object?>? baselineDelta,
  }) {
    final StringBuffer b = StringBuffer();
    b.writeln('# TechDebt Sherpa Report');
    b.writeln();
    b.writeln('Generated: `${report.metadata.timestamp.toIso8601String()}`');
    b.writeln();
    b.writeln('## Global Summary');
    b.writeln();
    b.writeln('| Score | Value |');
    b.writeln('|---|---:|');
    b.writeln('| Debt Score | ${report.global.debt.toStringAsFixed(2)} |');
    b.writeln('| Risk Score | ${report.global.risk.toStringAsFixed(2)} |');
    b.writeln(
      '| Evolvability Score | ${report.global.evolvability.toStringAsFixed(2)} |',
    );
    b.writeln('| Files | ${report.global.totals['files']} |');
    b.writeln('| SLOC | ${report.global.totals['sloc']} |');
    b.writeln();

    b.writeln('## Top Hotspots');
    b.writeln();
    b.writeln(
      '| Path | Debt | Risk | Cyclomatic Max | Churn | MI | Coverage |',
    );
    b.writeln('|---|---:|---:|---:|---:|---:|---:|');
    for (final FileReportEntry entry in report.topHotspots) {
      b.writeln(
        '| `${entry.metrics.path}` | ${entry.scores.debt.toStringAsFixed(1)} '
        '| ${entry.scores.risk.toStringAsFixed(1)} '
        '| ${entry.metrics.cyclomaticMax} '
        '| ${entry.git?.churn ?? 0} '
        '| ${entry.metrics.maintainabilityIndex.toStringAsFixed(1)} '
        '| ${entry.coverage?.toStringAsFixed(1) ?? 'n/a'} |',
      );
    }
    b.writeln();

    b.writeln('## Directory Summary');
    b.writeln();
    b.writeln(
      '| Directory | Files | Avg Debt | Avg Complexity | Avg Churn | Avg MI |',
    );
    b.writeln('|---|---:|---:|---:|---:|---:|');
    for (final DirectorySummary d in report.directories) {
      b.writeln(
        '| `${d.path}` | ${d.fileCount} | ${d.avgDebt.toStringAsFixed(1)} | '
        '${d.avgComplexity.toStringAsFixed(1)} | ${d.avgChurn.toStringAsFixed(1)} | ${d.avgMi.toStringAsFixed(1)} |',
      );
    }
    b.writeln();

    if (baselineDelta != null) {
      b.writeln('## What Changed vs Baseline');
      b.writeln();
      b.writeln(
        '- Debt delta: `${(baselineDelta['debt_delta'] as num).toStringAsFixed(2)}`',
      );
      b.writeln(
        '- Risk delta: `${(baselineDelta['risk_delta'] as num).toStringAsFixed(2)}`',
      );
      b.writeln(
        '- Evolvability delta: `${(baselineDelta['evolvability_delta'] as num).toStringAsFixed(2)}`',
      );
      b.writeln();
    }

    b.writeln('## Threshold Violations');
    b.writeln();
    if (report.violations.isEmpty) {
      b.writeln('No threshold failures detected. Exit code: `0`.');
    } else {
      b.writeln(
        'Threshold failures detected. Exit code: `3` when `--fail-on` matches:',
      );
      for (final String violation in report.violations) {
        b.writeln('- $violation');
      }
    }

    return b.toString();
  }

  /// Computes baseline deltas between two reports.
  Map<String, Object?> computeBaselineDelta(
    SherpaReport left,
    SherpaReport right,
  ) =>
      _diffService.fromReports(left, right);
}

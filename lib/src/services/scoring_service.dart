import 'dart:math';

import '../domain/models.dart';
import '../utils/math_utils.dart';

/// Container with all score outputs from a scan.
class ScoringResult {
  /// Creates a [ScoringResult].
  const ScoringResult({
    required this.files,
    required this.global,
    required this.hotspots,
    required this.directories,
  });

  final List<FileReportEntry> files;
  final GlobalScores global;
  final List<FileReportEntry> hotspots;
  final List<DirectorySummary> directories;
}

/// Calculates per-file and global technical debt scores.
class ScoringService {
  /// Computes scores from metrics, git signals, and coverage.
  ScoringResult score({
    required List<FileMetrics> metrics,
    required Map<String, GitFileStats> git,
    required Map<String, double> coverage,
    required SherpaConfig config,
  }) {
    if (metrics.isEmpty) {
      return const ScoringResult(
        files: <FileReportEntry>[],
        global: GlobalScores(
          debt: 0,
          risk: 0,
          evolvability: 100,
          totals: <String, num>{},
        ),
        hotspots: <FileReportEntry>[],
        directories: <DirectorySummary>[],
      );
    }

    final List<double> rawComplexity =
        metrics.map((FileMetrics m) => m.cyclomaticMax.toDouble()).toList();
    final List<double> rawChurn = metrics.map((FileMetrics m) {
      final GitFileStats? g = git[m.path];
      if (g == null) {
        return 0.0;
      }
      return g.commitCount * config.git.churnWeightCommits +
          g.churn * config.git.churnWeightLines;
    }).toList();
    final List<double> rawSize =
        metrics.map((FileMetrics m) => m.sloc.toDouble()).toList();
    final List<double> rawMaintainability =
        metrics.map((FileMetrics m) => 100 - m.maintainabilityIndex).toList();
    final List<double> rawTestGap = metrics.map((FileMetrics m) {
      final double cov = _findCoverage(m.path, coverage);
      return 100 - cov;
    }).toList();

    final _Normalizer normalizer = _Normalizer(
      config.scoring.normalizationMethod,
    );
    final List<double> nComplexity = normalizer.normalize(rawComplexity);
    final List<double> nChurn = normalizer.normalize(rawChurn);
    final List<double> nSize = normalizer.normalize(rawSize);
    final List<double> nMaintainability = normalizer.normalize(
      rawMaintainability,
    );
    final List<double> nTestGap = normalizer.normalize(rawTestGap);

    final Map<String, double> weights = config.scoring.globalWeights;

    final List<FileReportEntry> entries = <FileReportEntry>[];
    for (int i = 0; i < metrics.length; i += 1) {
      final FileMetrics m = metrics[i];
      final GitFileStats? g = git[m.path];
      final double coveragePct = _findCoverage(m.path, coverage);

      final double complexity = nComplexity[i] * 100;
      final double churn = nChurn[i] * 100;
      final double size = nSize[i] * 100;
      final double maintainability = nMaintainability[i] * 100;
      final double testgap = nTestGap[i] * 100;

      final Map<String, double> contributions = <String, double>{
        'complexity': complexity * (weights['complexity'] ?? 0),
        'churn': churn * (weights['churn'] ?? 0),
        'size': size * (weights['size'] ?? 0),
        'maintainability': maintainability * (weights['maintainability'] ?? 0),
        'testgap': testgap * (weights['testgap'] ?? 0),
      };
      final double debt = clamp100(
        contributions.values.fold<double>(0, (double a, double b) => a + b),
      );
      final double risk = clamp100(
        (complexity * 0.45) + (churn * 0.45) + (size * 0.1),
      );
      final double evolvability = clamp100(100 - debt);

      entries.add(
        FileReportEntry(
          metrics: m,
          git: g,
          coverage: coveragePct,
          thresholdViolations: _thresholdViolations(
            m,
            config.metrics.thresholds,
          ),
          scores: FileScores(
            debt: debt,
            complexity: complexity,
            churn: churn,
            size: size,
            maintainability: maintainability,
            testGap: testgap,
            risk: risk,
            evolvability: evolvability,
            normalized: <String, double>{
              'complexity': nComplexity[i],
              'churn': nChurn[i],
              'size': nSize[i],
              'maintainability': nMaintainability[i],
              'testgap': nTestGap[i],
            },
            contributions: contributions,
          ),
        ),
      );
    }

    entries.sort(
      (FileReportEntry a, FileReportEntry b) =>
          b.scores.debt.compareTo(a.scores.debt),
    );
    final List<FileReportEntry> hotspots = entries
        .take(config.scoring.output.includeTopHotspots)
        .toList(growable: false);
    final List<DirectorySummary> directories = _directorySummaries(entries);

    final double avgDebt = _avg(
      entries.map((FileReportEntry e) => e.scores.debt),
    );
    final double avgRisk = _avg(
      entries.map((FileReportEntry e) => e.scores.risk),
    );
    final double avgEvo = _avg(
      entries.map((FileReportEntry e) => e.scores.evolvability),
    );

    final int totalSloc = entries.fold<int>(
      0,
      (int a, FileReportEntry e) => a + e.metrics.sloc,
    );
    final int totalFiles = entries.length;

    final GlobalScores global = GlobalScores(
      debt: avgDebt,
      risk: avgRisk,
      evolvability: avgEvo,
      totals: <String, num>{
        'files': totalFiles,
        'sloc': totalSloc,
        'functions': entries.fold<int>(
          0,
          (int a, FileReportEntry e) => a + e.metrics.functionCount,
        ),
        'classes': entries.fold<int>(
          0,
          (int a, FileReportEntry e) => a + e.metrics.classCount,
        ),
      },
    );

    return ScoringResult(
      files: entries,
      global: global,
      hotspots: hotspots,
      directories: directories,
    );
  }

  double _findCoverage(String relPath, Map<String, double> coverage) {
    for (final MapEntry<String, double> entry in coverage.entries) {
      if (entry.key.endsWith(relPath.replaceAll('\\', '/'))) {
        return entry.value;
      }
    }
    return 0;
  }

  List<String> _thresholdViolations(
    FileMetrics m,
    Map<String, Threshold> thresholds,
  ) {
    final List<String> out = <String>[];
    final Threshold? c = thresholds['cyclomatic'];
    if (c?.warn != null && m.cyclomaticMax >= c!.warn!) {
      out.add('cyclomatic_warn');
    }
    if (c?.fail != null && m.cyclomaticMax >= c!.fail!) {
      out.add('cyclomatic_fail');
    }
    final Threshold? n = thresholds['nesting'];
    if (n?.warn != null && m.nestingMax >= n!.warn!) {
      out.add('nesting_warn');
    }
    if (n?.fail != null && m.nestingMax >= n!.fail!) {
      out.add('nesting_fail');
    }
    final Threshold? mi = thresholds['mi'];
    if (mi?.warnBelow != null && m.maintainabilityIndex <= mi!.warnBelow!) {
      out.add('mi_warn_below');
    }
    if (mi?.failBelow != null && m.maintainabilityIndex <= mi!.failBelow!) {
      out.add('mi_fail_below');
    }
    return out;
  }

  List<DirectorySummary> _directorySummaries(List<FileReportEntry> entries) {
    final Map<String, List<FileReportEntry>> groups =
        <String, List<FileReportEntry>>{};
    for (final FileReportEntry entry in entries) {
      groups
          .putIfAbsent(entry.metrics.directory, () => <FileReportEntry>[])
          .add(entry);
    }

    final List<DirectorySummary> out = <DirectorySummary>[];
    for (final MapEntry<String, List<FileReportEntry>> e in groups.entries) {
      out.add(
        DirectorySummary(
          path: e.key,
          fileCount: e.value.length,
          avgDebt: _avg(e.value.map((FileReportEntry f) => f.scores.debt)),
          avgComplexity: _avg(
            e.value.map((FileReportEntry f) => f.scores.complexity),
          ),
          avgChurn: _avg(e.value.map((FileReportEntry f) => f.scores.churn)),
          avgMi: _avg(
            e.value.map((FileReportEntry f) => f.metrics.maintainabilityIndex),
          ),
        ),
      );
    }
    out.sort(
      (DirectorySummary a, DirectorySummary b) =>
          b.avgDebt.compareTo(a.avgDebt),
    );
    return out;
  }

  double _avg(Iterable<double> values) {
    final List<double> list = values.toList(growable: false);
    if (list.isEmpty) {
      return 0;
    }
    return list.reduce((double a, double b) => a + b) / list.length;
  }
}

class _Normalizer {
  _Normalizer(this.method);

  final String method;

  List<double> normalize(List<double> values) {
    if (values.isEmpty) {
      return values;
    }
    if (method == 'minmax') {
      final double minV = values.reduce(min);
      final double maxV = values.reduce(max);
      if ((maxV - minV).abs() < 1e-9) {
        return List<double>.filled(values.length, 0);
      }
      return values
          .map((double v) => clamp01((v - minV) / (maxV - minV)))
          .toList(growable: false);
    }

    final double med = median(values);
    final double m = mad(values, med);
    if (m.abs() < 1e-9) {
      return List<double>.filled(values.length, 0);
    }
    return values.map((double v) {
      final double z = 0.6745 * ((v - med) / m);
      // Map roughly [-3, +3] to [0, 1].
      return clamp01((z + 3) / 6);
    }).toList(growable: false);
  }
}

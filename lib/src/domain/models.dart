import 'dart:convert';

import 'package:meta/meta.dart';

/// Project-level configuration values.
@immutable
class ProjectConfig {
  /// Creates a [ProjectConfig].
  const ProjectConfig({this.root = '.', this.language = 'dart'});

  final String root;
  final String language;

  /// Converts this configuration to JSON-compatible data.
  Map<String, Object?> toJson() => <String, Object?>{
        'root': root,
        'language': language,
      };
}

/// Threshold settings for warnings and failures.
@immutable
class Threshold {
  /// Creates a [Threshold].
  const Threshold({this.warn, this.fail, this.warnBelow, this.failBelow});

  final double? warn;
  final double? fail;
  final double? warnBelow;
  final double? failBelow;

  /// Converts this threshold to JSON-compatible data.
  Map<String, Object?> toJson() => <String, Object?>{
        'warn': warn,
        'fail': fail,
        'warn_below': warnBelow,
        'fail_below': failBelow,
      };
}

/// Metric feature toggles and threshold map.
@immutable
class MetricsConfig {
  /// Creates a [MetricsConfig].
  const MetricsConfig({required this.enabled, required this.thresholds});

  final List<String> enabled;
  final Map<String, Threshold> thresholds;

  /// Returns package defaults for metrics.
  static MetricsConfig defaults() => const MetricsConfig(
        enabled: <String>[
          'sloc',
          'cyclomatic',
          'nesting',
          'mi',
          'halstead',
          'file_size',
          'class_count',
          'function_count',
          'params_count',
        ],
        thresholds: <String, Threshold>{
          'cyclomatic': Threshold(warn: 10, fail: 20),
          'nesting': Threshold(warn: 4, fail: 6),
          'mi': Threshold(warnBelow: 65, failBelow: 50),
        },
      );

  /// Converts this metrics config to JSON-compatible data.
  Map<String, Object?> toJson() => <String, Object?>{
        'enabled': enabled,
        'thresholds': thresholds.map(
          (String key, Threshold value) =>
              MapEntry<String, Object?>(key, value.toJson()),
        ),
      };
}

/// Git signal configuration.
@immutable
class GitConfig {
  /// Creates a [GitConfig].
  const GitConfig({
    this.enabled = true,
    this.sinceDays = 180,
    this.churnWeightCommits = 0.5,
    this.churnWeightLines = 0.5,
    this.hotspotFormula = '(norm_complexity + norm_churn) / 2',
    this.includeOwnershipProxy = false,
  });

  final bool enabled;
  final int sinceDays;
  final double churnWeightCommits;
  final double churnWeightLines;
  final String hotspotFormula;
  final bool includeOwnershipProxy;

  /// Converts this git config to JSON-compatible data.
  Map<String, Object?> toJson() => <String, Object?>{
        'enabled': enabled,
        'since_days': sinceDays,
        'churn_weights': <String, Object?>{
          'commits': churnWeightCommits,
          'lines_changed': churnWeightLines,
        },
        'hotspot_formula': hotspotFormula,
        'include_ownership_proxy': includeOwnershipProxy,
      };
}

/// Optional test coverage configuration.
@immutable
class TestsConfig {
  /// Creates a [TestsConfig].
  const TestsConfig({
    this.enabled = false,
    this.lcovPath = 'coverage/lcov.info',
  });

  final bool enabled;
  final String lcovPath;

  /// Converts this test config to JSON-compatible data.
  Map<String, Object?> toJson() => <String, Object?>{
        'enabled': enabled,
        'lcov_path': lcovPath,
      };
}

/// Markdown output rendering options.
@immutable
class MarkdownOutputConfig {
  /// Creates a [MarkdownOutputConfig].
  const MarkdownOutputConfig({
    this.includeTables = true,
    this.includeTopHotspots = 20,
    this.includePerDirectorySummary = true,
  });

  final bool includeTables;
  final int includeTopHotspots;
  final bool includePerDirectorySummary;

  /// Converts this markdown config to JSON-compatible data.
  Map<String, Object?> toJson() => <String, Object?>{
        'include_tables': includeTables,
        'include_top_hotspots': includeTopHotspots,
        'include_per_directory_summary': includePerDirectorySummary,
      };
}

/// Scoring weights and normalization settings.
@immutable
class ScoringConfig {
  /// Creates a [ScoringConfig].
  const ScoringConfig({
    required this.globalWeights,
    this.normalizationMethod = 'robust_zscore',
    this.output = const MarkdownOutputConfig(),
  });

  final Map<String, double> globalWeights;
  final String normalizationMethod;
  final MarkdownOutputConfig output;

  /// Returns package defaults for scoring.
  static ScoringConfig defaults() => const ScoringConfig(
        globalWeights: <String, double>{
          'complexity': 0.30,
          'churn': 0.30,
          'size': 0.15,
          'maintainability': 0.15,
          'testgap': 0.10,
        },
      );

  /// Converts this scoring config to JSON-compatible data.
  Map<String, Object?> toJson() => <String, Object?>{
        'global_weights': globalWeights,
        'normalization': <String, Object?>{'method': normalizationMethod},
        'output': <String, Object?>{'markdown': output.toJson()},
      };
}

/// Root configuration object for scans.
@immutable
class SherpaConfig {
  /// Creates a [SherpaConfig].
  const SherpaConfig({
    this.project = const ProjectConfig(),
    this.include = const <String>['lib/**.dart', 'bin/**.dart'],
    this.exclude = const <String>['**/.dart_tool/**', '**/build/**'],
    this.metrics = const MetricsConfig(
      enabled: <String>[],
      thresholds: <String, Threshold>{},
    ),
    this.git = const GitConfig(),
    this.tests = const TestsConfig(),
    this.scoring = const ScoringConfig(globalWeights: <String, double>{}),
  });

  final ProjectConfig project;
  final List<String> include;
  final List<String> exclude;
  final MetricsConfig metrics;
  final GitConfig git;
  final TestsConfig tests;
  final ScoringConfig scoring;

  /// Returns the package default configuration.
  static SherpaConfig defaults() => SherpaConfig(
        metrics: MetricsConfig.defaults(),
        scoring: ScoringConfig.defaults(),
      );

  /// Converts this root config to JSON-compatible data.
  Map<String, Object?> toJson() => <String, Object?>{
        'project': project.toJson(),
        'include': include,
        'exclude': exclude,
        'metrics': metrics.toJson(),
        'git': git.toJson(),
        'tests': tests.toJson(),
        'scoring': scoring.toJson(),
      };

  /// Returns a stable pretty JSON string used in config hashing.
  String stableJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Halstead metrics for a source file.
@immutable
class HalsteadMetrics {
  /// Creates a [HalsteadMetrics] object.
  const HalsteadMetrics({
    required this.distinctOperators,
    required this.distinctOperands,
    required this.totalOperators,
    required this.totalOperands,
    required this.vocabulary,
    required this.length,
    required this.volume,
    required this.difficulty,
    required this.effort,
  });

  final int distinctOperators;
  final int distinctOperands;
  final int totalOperators;
  final int totalOperands;
  final int vocabulary;
  final int length;
  final double volume;
  final double difficulty;
  final double effort;

  /// Returns a zero-value Halstead object.
  static HalsteadMetrics empty() => const HalsteadMetrics(
        distinctOperators: 0,
        distinctOperands: 0,
        totalOperators: 0,
        totalOperands: 0,
        vocabulary: 0,
        length: 0,
        volume: 0,
        difficulty: 0,
        effort: 0,
      );

  /// Converts these Halstead metrics to JSON-compatible data.
  Map<String, Object?> toJson() => <String, Object?>{
        'distinct_operators': distinctOperators,
        'distinct_operands': distinctOperands,
        'total_operators': totalOperators,
        'total_operands': totalOperands,
        'vocabulary': vocabulary,
        'length': length,
        'volume': volume,
        'difficulty': difficulty,
        'effort': effort,
      };
}

/// Static metrics for a single file.
@immutable
class FileMetrics {
  /// Creates a [FileMetrics].
  const FileMetrics({
    required this.path,
    required this.sloc,
    required this.fileSizeBytes,
    required this.lineCount,
    required this.functionCount,
    required this.classCount,
    required this.cyclomaticSum,
    required this.cyclomaticMax,
    required this.cyclomaticP95,
    required this.nestingMax,
    required this.paramsMax,
    required this.paramsP95,
    required this.maintainabilityIndex,
    required this.halstead,
    required this.feature,
    required this.directory,
  });

  final String path;
  final int sloc;
  final int fileSizeBytes;
  final int lineCount;
  final int functionCount;
  final int classCount;
  final int cyclomaticSum;
  final int cyclomaticMax;
  final double cyclomaticP95;
  final int nestingMax;
  final int paramsMax;
  final double paramsP95;
  final double maintainabilityIndex;
  final HalsteadMetrics halstead;
  final String? feature;
  final String directory;

  /// Converts these file metrics to JSON-compatible data.
  Map<String, Object?> toJson() => <String, Object?>{
        'path': path,
        'sloc': sloc,
        'file_size_bytes': fileSizeBytes,
        'line_count': lineCount,
        'function_count': functionCount,
        'class_count': classCount,
        'cyclomatic_sum': cyclomaticSum,
        'cyclomatic_max': cyclomaticMax,
        'cyclomatic_p95': cyclomaticP95,
        'nesting_max': nestingMax,
        'params_max': paramsMax,
        'params_p95': paramsP95,
        'maintainability_index': maintainabilityIndex,
        'halstead': halstead.toJson(),
        'feature': feature,
        'directory': directory,
      };
}

/// Git-derived statistics for one file.
@immutable
class GitFileStats {
  /// Creates a [GitFileStats].
  const GitFileStats({
    required this.path,
    required this.commitCount,
    required this.linesAdded,
    required this.linesDeleted,
    this.lastModified,
    this.distinctAuthors,
  });

  final String path;
  final int commitCount;
  final int linesAdded;
  final int linesDeleted;
  final DateTime? lastModified;
  final int? distinctAuthors;

  /// Returns aggregate churn (`linesAdded + linesDeleted`).
  int get churn => linesAdded + linesDeleted;

  /// Converts these git stats to JSON-compatible data.
  Map<String, Object?> toJson() => <String, Object?>{
        'path': path,
        'commit_count': commitCount,
        'lines_added': linesAdded,
        'lines_deleted': linesDeleted,
        'churn': churn,
        'last_modified': lastModified?.toIso8601String(),
        'distinct_authors': distinctAuthors,
      };
}

/// Score breakdown for one file.
@immutable
class FileScores {
  /// Creates a [FileScores].
  const FileScores({
    required this.debt,
    required this.complexity,
    required this.churn,
    required this.size,
    required this.maintainability,
    required this.testGap,
    required this.risk,
    required this.evolvability,
    required this.normalized,
    required this.contributions,
  });

  final double debt;
  final double complexity;
  final double churn;
  final double size;
  final double maintainability;
  final double testGap;
  final double risk;
  final double evolvability;
  final Map<String, double> normalized;
  final Map<String, double> contributions;

  /// Converts these scores to JSON-compatible data.
  Map<String, Object?> toJson() => <String, Object?>{
        'debt': debt,
        'complexity': complexity,
        'churn': churn,
        'size': size,
        'maintainability': maintainability,
        'testgap': testGap,
        'risk': risk,
        'evolvability': evolvability,
        'normalized': normalized,
        'contributions': contributions,
      };
}

/// Full report row for one file.
@immutable
class FileReportEntry {
  /// Creates a [FileReportEntry].
  const FileReportEntry({
    required this.metrics,
    required this.git,
    required this.scores,
    this.coverage,
    required this.thresholdViolations,
  });

  final FileMetrics metrics;
  final GitFileStats? git;
  final FileScores scores;
  final double? coverage;
  final List<String> thresholdViolations;

  /// Converts this report entry to JSON-compatible data.
  Map<String, Object?> toJson() => <String, Object?>{
        'metrics': metrics.toJson(),
        'git': git?.toJson(),
        'scores': scores.toJson(),
        'coverage': coverage,
        'threshold_violations': thresholdViolations,
      };
}

/// Aggregated score summary for a directory.
@immutable
class DirectorySummary {
  /// Creates a [DirectorySummary].
  const DirectorySummary({
    required this.path,
    required this.fileCount,
    required this.avgDebt,
    required this.avgComplexity,
    required this.avgChurn,
    required this.avgMi,
  });

  final String path;
  final int fileCount;
  final double avgDebt;
  final double avgComplexity;
  final double avgChurn;
  final double avgMi;

  /// Converts this directory summary to JSON-compatible data.
  Map<String, Object?> toJson() => <String, Object?>{
        'path': path,
        'file_count': fileCount,
        'avg_debt': avgDebt,
        'avg_complexity': avgComplexity,
        'avg_churn': avgChurn,
        'avg_mi': avgMi,
      };
}

/// Global aggregate score object.
@immutable
class GlobalScores {
  /// Creates a [GlobalScores].
  const GlobalScores({
    required this.debt,
    required this.risk,
    required this.evolvability,
    required this.totals,
  });

  final double debt;
  final double risk;
  final double evolvability;
  final Map<String, num> totals;

  /// Converts this global score object to JSON-compatible data.
  Map<String, Object?> toJson() => <String, Object?>{
        'debt': debt,
        'risk': risk,
        'evolvability': evolvability,
        'totals': totals,
      };
}

/// Metadata emitted with each report.
@immutable
class ReportMetadata {
  /// Creates a [ReportMetadata].
  const ReportMetadata({
    required this.version,
    required this.timestamp,
    required this.configHash,
    this.gitHead,
    required this.schemaVersion,
  });

  final String version;
  final DateTime timestamp;
  final String configHash;
  final String? gitHead;
  final String schemaVersion;

  /// Converts this metadata object to JSON-compatible data.
  Map<String, Object?> toJson() => <String, Object?>{
        'tool_version': version,
        'schema_version': schemaVersion,
        'timestamp': timestamp.toIso8601String(),
        'config_hash': configHash,
        'git_head': gitHead,
      };
}

/// Full report payload.
@immutable
class SherpaReport {
  /// Creates a [SherpaReport].
  const SherpaReport({
    required this.metadata,
    required this.config,
    required this.global,
    required this.files,
    required this.topHotspots,
    required this.directories,
    required this.violations,
    this.baselineDelta,
  });

  final ReportMetadata metadata;
  final SherpaConfig config;
  final GlobalScores global;
  final List<FileReportEntry> files;
  final List<FileReportEntry> topHotspots;
  final List<DirectorySummary> directories;
  final List<String> violations;
  final Map<String, Object?>? baselineDelta;

  /// Converts this report to JSON-compatible data.
  Map<String, Object?> toJson() => <String, Object?>{
        r'$schema':
            'https://carlosf.dev/schemas/techdebt_sherpa.report.v1.json',
        'metadata': metadata.toJson(),
        'config': config.toJson(),
        'global_scores': global.toJson(),
        'files': files.map((FileReportEntry e) => e.toJson()).toList(),
        'top_hotspots':
            topHotspots.map((FileReportEntry e) => e.toJson()).toList(),
        'directory_summaries':
            directories.map((DirectorySummary d) => d.toJson()).toList(),
        'violations': violations,
        'baseline_delta': baselineDelta,
      };

  /// Returns a pretty JSON string for human inspection.
  String prettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Snapshot metadata for trend analysis.
@immutable
class Snapshot {
  /// Creates a [Snapshot].
  const Snapshot({
    required this.label,
    required this.path,
    required this.timestamp,
    required this.globalDebt,
    required this.globalRisk,
    required this.globalEvolvability,
  });

  final String label;
  final String path;
  final DateTime timestamp;
  final double globalDebt;
  final double globalRisk;
  final double globalEvolvability;

  /// Converts this snapshot to JSON-compatible data.
  Map<String, Object?> toJson() => <String, Object?>{
        'label': label,
        'path': path,
        'timestamp': timestamp.toIso8601String(),
        'global_debt': globalDebt,
        'global_risk': globalRisk,
        'global_evolvability': globalEvolvability,
      };
}

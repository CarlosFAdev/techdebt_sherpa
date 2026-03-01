import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../adapters/file_system.dart';
import '../domain/models.dart';

/// Loads and validates YAML configuration.
class ConfigService {
  /// Creates a [ConfigService].
  ConfigService(this._fs);

  final FileSystemAdapter _fs;

  /// Loads configuration from [configPath] or defaults when missing.
  SherpaConfig load({String? configPath, String root = '.'}) {
    final SherpaConfig defaults = SherpaConfig.defaults();
    final String resolved = configPath ?? p.join(root, 'techdebt_sherpa.yaml');
    if (!_fs.fileExists(resolved)) {
      return defaults;
    }
    final dynamic parsed = loadYaml(_fs.readAsString(resolved));
    if (parsed is! YamlMap) {
      throw const FormatException('Config must be a YAML mapping.');
    }

    final Map<dynamic, dynamic> map = parsed;
    final Map<dynamic, dynamic> projectMap = _asMap(map['project']);
    final Map<dynamic, dynamic> metricsMap = _asMap(map['metrics']);
    final Map<dynamic, dynamic> gitMap = _asMap(map['git']);
    final Map<dynamic, dynamic> testsMap = _asMap(map['tests']);
    final Map<dynamic, dynamic> scoringMap = _asMap(map['scoring']);

    final ProjectConfig project = ProjectConfig(
      root: _string(projectMap['root']) ?? defaults.project.root,
      language: _string(projectMap['language']) ?? defaults.project.language,
    );

    final Map<dynamic, dynamic> thresholdsRaw = _asMap(
      metricsMap['thresholds'],
    );
    final Map<String, Threshold> thresholds = <String, Threshold>{
      ...defaults.metrics.thresholds,
      for (final MapEntry<dynamic, dynamic> entry in thresholdsRaw.entries)
        '${entry.key}': _threshold(_asMap(entry.value)),
    };

    final MetricsConfig metrics = MetricsConfig(
      enabled: _asStringList(metricsMap['enabled']) ?? defaults.metrics.enabled,
      thresholds: thresholds,
    );

    final Map<dynamic, dynamic> churnWeights = _asMap(gitMap['churn_weights']);
    final GitConfig git = GitConfig(
      enabled: _bool(gitMap['enabled']) ?? defaults.git.enabled,
      sinceDays: _int(gitMap['since_days']) ?? defaults.git.sinceDays,
      churnWeightCommits:
          _double(churnWeights['commits']) ?? defaults.git.churnWeightCommits,
      churnWeightLines: _double(churnWeights['lines_changed']) ??
          defaults.git.churnWeightLines,
      hotspotFormula:
          _string(gitMap['hotspot_formula']) ?? defaults.git.hotspotFormula,
      includeOwnershipProxy: _bool(gitMap['include_ownership_proxy']) ??
          defaults.git.includeOwnershipProxy,
    );

    final TestsConfig tests = TestsConfig(
      enabled: _bool(testsMap['enabled']) ?? defaults.tests.enabled,
      lcovPath: _string(testsMap['lcov_path']) ?? defaults.tests.lcovPath,
    );

    final Map<dynamic, dynamic> globalWeightsRaw = _asMap(
      scoringMap['global_weights'],
    );
    final Map<String, double> globalWeights = <String, double>{
      ...defaults.scoring.globalWeights,
      for (final MapEntry<dynamic, dynamic> entry in globalWeightsRaw.entries)
        '${entry.key}': _double(entry.value) ?? 0,
    };

    final Map<dynamic, dynamic> normalization = _asMap(
      scoringMap['normalization'],
    );
    final Map<dynamic, dynamic> output = _asMap(scoringMap['output']);
    final Map<dynamic, dynamic> markdown = _asMap(output['markdown']);
    final ScoringConfig scoring = ScoringConfig(
      globalWeights: globalWeights,
      normalizationMethod: _string(normalization['method']) ??
          defaults.scoring.normalizationMethod,
      output: MarkdownOutputConfig(
        includeTables: _bool(markdown['include_tables']) ??
            defaults.scoring.output.includeTables,
        includeTopHotspots: _int(markdown['include_top_hotspots']) ??
            defaults.scoring.output.includeTopHotspots,
        includePerDirectorySummary:
            _bool(markdown['include_per_directory_summary']) ??
                defaults.scoring.output.includePerDirectorySummary,
      ),
    );

    final List<String> include =
        _asStringList(map['include']) ?? defaults.include;
    final List<String> exclude =
        _asStringList(map['exclude']) ?? defaults.exclude;

    _validate(scoring: scoring, git: git, metrics: metrics);

    return SherpaConfig(
      project: project,
      include: include,
      exclude: exclude,
      metrics: metrics,
      git: git,
      tests: tests,
      scoring: scoring,
    );
  }

  /// Writes an example configuration file to [path].
  void writeExample(String path) {
    final String content = '''project:
  root: .
  language: dart
include:
  - lib/**.dart
  - bin/**.dart
exclude:
  - '**/.dart_tool/**'
  - '**/build/**'
metrics:
  enabled: [sloc, cyclomatic, nesting, mi, halstead, file_size, class_count, function_count, params_count]
  thresholds:
    cyclomatic:
      warn: 10
      fail: 20
    nesting:
      warn: 4
      fail: 6
    mi:
      warn_below: 65
      fail_below: 50
git:
  enabled: true
  since_days: 180
  churn_weights:
    commits: 0.5
    lines_changed: 0.5
  hotspot_formula: '(norm_complexity + norm_churn) / 2'
tests:
  enabled: false
  lcov_path: coverage/lcov.info
scoring:
  global_weights:
    complexity: 0.30
    churn: 0.30
    size: 0.15
    maintainability: 0.15
    testgap: 0.10
  normalization:
    method: robust_zscore
  output:
    markdown:
      include_tables: true
      include_top_hotspots: 20
      include_per_directory_summary: true
''';
    _fs.writeAsString(path, content);
  }

  void _validate({
    required ScoringConfig scoring,
    required GitConfig git,
    required MetricsConfig metrics,
  }) {
    final double weightSum = scoring.globalWeights.values.fold<double>(
      0,
      (double a, double b) => a + b,
    );
    if ((weightSum - 1).abs() > 0.001) {
      throw const FormatException('scoring.global_weights must sum to 1.0');
    }
    if (git.churnWeightCommits < 0 || git.churnWeightLines < 0) {
      throw const FormatException('git.churn_weights values must be >= 0');
    }
    final Set<String> methods = <String>{'robust_zscore', 'minmax'};
    if (!methods.contains(scoring.normalizationMethod)) {
      throw const FormatException(
        'scoring.normalization.method must be robust_zscore|minmax',
      );
    }
    if (metrics.enabled.isEmpty) {
      throw const FormatException('metrics.enabled cannot be empty');
    }
  }

  Map<dynamic, dynamic> _asMap(dynamic value) {
    if (value is YamlMap) {
      return value;
    }
    if (value is Map<dynamic, dynamic>) {
      return value;
    }
    return <dynamic, dynamic>{};
  }

  List<String>? _asStringList(dynamic value) {
    if (value is YamlList || value is List<dynamic>) {
      final Iterable<dynamic> items = value as Iterable<dynamic>;
      return items.map((dynamic e) => '$e').toList(growable: false);
    }
    return null;
  }

  String? _string(dynamic value) => value == null ? null : '$value';

  int? _int(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse('$value');
  }

  double? _double(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value');
  }

  bool? _bool(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    if (value is String) {
      if (value.toLowerCase() == 'true') {
        return true;
      }
      if (value.toLowerCase() == 'false') {
        return false;
      }
    }
    return null;
  }

  Threshold _threshold(Map<dynamic, dynamic> map) => Threshold(
        warn: _double(map['warn']),
        fail: _double(map['fail']),
        warnBelow: _double(map['warn_below']),
        failBelow: _double(map['fail_below']),
      );
}

/// Parses an ISO date string into UTC.
DateTime? parseDate(String? input) {
  if (input == null || input.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(input)?.toUtc();
}

/// Resolves the config path with package defaults.
String resolveConfigPath(String? input) {
  if (input == null || input.isEmpty) {
    return 'techdebt_sherpa.yaml';
  }
  return p.normalize(input);
}

/// Throws if the given [path] does not exist in [fs].
void assertPathExists(
  FileSystemAdapter fs,
  String path, {
  required String label,
}) {
  if (!fs.fileExists(path) && !fs.directoryExists(path)) {
    throw FileSystemException('$label not found', path);
  }
}

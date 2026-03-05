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
    final String resolvedPath =
        _resolvePath(configPath: configPath, root: root);
    if (!_fs.fileExists(resolvedPath)) {
      return defaults;
    }
    final dynamic parsed = loadYaml(_fs.readAsString(resolvedPath));
    if (parsed is! YamlMap) {
      throw const FormatException('Config must be a YAML mapping.');
    }

    final _ConfigSections sections = _ConfigSections.fromRoot(parsed);
    final ProjectConfig project = _buildProject(
      sections.project,
      defaults: defaults.project,
    );
    final MetricsConfig metrics = _buildMetrics(
      sections.metrics,
      defaults: defaults.metrics,
    );
    final GitConfig git = _buildGit(sections.git, defaults: defaults.git);
    final TestsConfig tests =
        _buildTests(sections.tests, defaults: defaults.tests);
    final ScoringConfig scoring = _buildScoring(
      sections.scoring,
      defaults: defaults.scoring,
    );
    final List<String> include =
        _asStringList(sections.root['include']) ?? defaults.include;
    final List<String> exclude =
        _asStringList(sections.root['exclude']) ?? defaults.exclude;

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

  String _resolvePath({required String? configPath, required String root}) {
    return configPath ?? p.join(root, 'techdebt_sherpa.yaml');
  }

  ProjectConfig _buildProject(
    Map<dynamic, dynamic> projectMap, {
    required ProjectConfig defaults,
  }) {
    return ProjectConfig(
      root: _string(projectMap['root']) ?? defaults.root,
      language: _string(projectMap['language']) ?? defaults.language,
    );
  }

  MetricsConfig _buildMetrics(
    Map<dynamic, dynamic> metricsMap, {
    required MetricsConfig defaults,
  }) {
    final Map<dynamic, dynamic> thresholdsRaw =
        _asMap(metricsMap['thresholds']);
    final Map<String, Threshold> thresholds = <String, Threshold>{
      ...defaults.thresholds,
      for (final MapEntry<dynamic, dynamic> entry in thresholdsRaw.entries)
        '${entry.key}': _threshold(_asMap(entry.value)),
    };
    return MetricsConfig(
      enabled: _asStringList(metricsMap['enabled']) ?? defaults.enabled,
      thresholds: thresholds,
    );
  }

  GitConfig _buildGit(
    Map<dynamic, dynamic> gitMap, {
    required GitConfig defaults,
  }) {
    final Map<dynamic, dynamic> churnWeights = _asMap(gitMap['churn_weights']);
    return GitConfig(
      enabled: _bool(gitMap['enabled']) ?? defaults.enabled,
      sinceDays: _int(gitMap['since_days']) ?? defaults.sinceDays,
      churnWeightCommits:
          _double(churnWeights['commits']) ?? defaults.churnWeightCommits,
      churnWeightLines:
          _double(churnWeights['lines_changed']) ?? defaults.churnWeightLines,
      hotspotFormula:
          _string(gitMap['hotspot_formula']) ?? defaults.hotspotFormula,
      includeOwnershipProxy: _bool(gitMap['include_ownership_proxy']) ??
          defaults.includeOwnershipProxy,
    );
  }

  TestsConfig _buildTests(
    Map<dynamic, dynamic> testsMap, {
    required TestsConfig defaults,
  }) {
    return TestsConfig(
      enabled: _bool(testsMap['enabled']) ?? defaults.enabled,
      lcovPath: _string(testsMap['lcov_path']) ?? defaults.lcovPath,
    );
  }

  ScoringConfig _buildScoring(
    Map<dynamic, dynamic> scoringMap, {
    required ScoringConfig defaults,
  }) {
    final Map<dynamic, dynamic> globalWeightsRaw = _asMap(
      scoringMap['global_weights'],
    );
    final Map<String, double> globalWeights = <String, double>{
      ...defaults.globalWeights,
      for (final MapEntry<dynamic, dynamic> entry in globalWeightsRaw.entries)
        '${entry.key}': _double(entry.value) ?? 0,
    };

    final Map<dynamic, dynamic> normalization =
        _asMap(scoringMap['normalization']);
    final Map<dynamic, dynamic> output = _asMap(scoringMap['output']);
    final Map<dynamic, dynamic> markdown = _asMap(output['markdown']);
    return ScoringConfig(
      globalWeights: globalWeights,
      normalizationMethod:
          _string(normalization['method']) ?? defaults.normalizationMethod,
      output: MarkdownOutputConfig(
        includeTables:
            _bool(markdown['include_tables']) ?? defaults.output.includeTables,
        includeTopHotspots: _int(markdown['include_top_hotspots']) ??
            defaults.output.includeTopHotspots,
        includePerDirectorySummary:
            _bool(markdown['include_per_directory_summary']) ??
                defaults.output.includePerDirectorySummary,
      ),
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

class _ConfigSections {
  const _ConfigSections({
    required this.root,
    required this.project,
    required this.metrics,
    required this.git,
    required this.tests,
    required this.scoring,
  });

  final Map<dynamic, dynamic> root;
  final Map<dynamic, dynamic> project;
  final Map<dynamic, dynamic> metrics;
  final Map<dynamic, dynamic> git;
  final Map<dynamic, dynamic> tests;
  final Map<dynamic, dynamic> scoring;

  static _ConfigSections fromRoot(Map<dynamic, dynamic> root) {
    final Map<dynamic, dynamic> normalized = _asMapStatic(root);
    return _ConfigSections(
      root: normalized,
      project: _asMapStatic(normalized['project']),
      metrics: _asMapStatic(normalized['metrics']),
      git: _asMapStatic(normalized['git']),
      tests: _asMapStatic(normalized['tests']),
      scoring: _asMapStatic(normalized['scoring']),
    );
  }

  static Map<dynamic, dynamic> _asMapStatic(dynamic value) {
    if (value is YamlMap) {
      return value;
    }
    if (value is Map<dynamic, dynamic>) {
      return value;
    }
    return <dynamic, dynamic>{};
  }
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

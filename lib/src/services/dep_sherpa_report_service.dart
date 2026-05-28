import 'dart:convert';
import 'dart:io';

import '../adapters/file_system.dart';
import '../domain/models.dart';

/// Reads dep_sherpa JSON reports and converts supported signals to findings.
class DepSherpaReportService {
  /// Creates a [DepSherpaReportService].
  const DepSherpaReportService(this._fs);

  final FileSystemAdapter _fs;

  /// Reads and parses a dep_sherpa JSON report from [path].
  DepSherpaReportInput read(String path) {
    final String raw;
    try {
      raw = _fs.readAsString(path);
    } on FileSystemException catch (e) {
      throw FormatException(
        'Failed to read dep_sherpa report at $path: ${e.message}',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw FormatException(
        'Invalid dep_sherpa report JSON at $path: ${e.message}',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('dep_sherpa report JSON object expected at $path');
    }
    return DepSherpaReportInput.fromJson(decoded.cast<String, Object?>());
  }

  /// Converts supported Darwin readiness data into tech debt findings.
  List<DebtFinding> findingsFromReport(DepSherpaReportInput report) {
    final List<DebtFinding> findings = <DebtFinding>[];
    final DepSherpaDarwinReadiness? readiness = report.darwinReadiness;

    if ((readiness?.summary.blocked ?? 0) > 0) {
      findings.add(
        DebtFinding(
          category: _category,
          severity: 'high',
          source: 'dep_sherpa',
          message:
              'Project has blocked iOS/macOS Swift Package Manager readiness dependencies.',
          recommendation:
              'Review blocked dependencies in the dep_sherpa report and plan SPM migration work.',
          details: <String, Object?>{
            'blocked_count': readiness!.summary.blocked,
            'mode': readiness.mode,
            'dependency_manager': readiness.dependencyManager,
            'spm_readiness': readiness.spmReadiness,
          },
        ),
      );
    }

    if ((readiness?.summary.partial ?? 0) > 0) {
      findings.add(
        DebtFinding(
          category: _category,
          severity: 'medium',
          source: 'dep_sherpa',
          message:
              'Project has partially migrated or incomplete iOS/macOS Swift Package Manager readiness dependencies.',
          recommendation:
              'Review partial dependencies in the dep_sherpa report and complete SPM migration gaps.',
          details: <String, Object?>{
            'partial_count': readiness!.summary.partial,
            'mode': readiness.mode,
            'dependency_manager': readiness.dependencyManager,
            'spm_readiness': readiness.spmReadiness,
          },
        ),
      );
    }

    if (readiness?.enforcement.violated ?? false) {
      final DepSherpaDarwinEnforcement enforcement = readiness!.enforcement;
      findings.add(
        DebtFinding(
          category: _category,
          severity: 'high',
          source: 'dep_sherpa',
          message:
              'dep_sherpa Darwin Swift Package Manager readiness enforcement was violated.',
          recommendation:
              'Resolve dep_sherpa enforcement violations before relying on SPM migration readiness.',
          signals: enforcement.hardRiskTriggers,
          details: <String, Object?>{
            'mode': readiness.mode,
            'hard_risk_triggers': enforcement.hardRiskTriggers,
            'violation_messages': enforcement.violationMessages,
            'blocked_count': enforcement.blockedCount,
            'partial_count': enforcement.partialCount,
            'warning_finding_count': enforcement.warningFindingCount,
            'error_finding_count': enforcement.errorFindingCount,
          },
        ),
      );
    }

    for (final DepSherpaDependencyPlatformCompatibility dependency
        in report.dependencies) {
      if (!dependency.applicable) {
        continue;
      }
      for (final String signal in dependency.signals) {
        findings.add(_findingForSignal(signal, dependency));
      }
    }

    return findings;
  }

  DebtFinding _findingForSignal(
    String signal,
    DepSherpaDependencyPlatformCompatibility dependency,
  ) {
    final _SignalDebtMapping mapping =
        _signalMappings[signal] ?? _unknownSignalMapping;
    return DebtFinding(
      category: _category,
      severity: mapping.severity,
      source: 'dep_sherpa',
      dependency: dependency.name,
      signals: <String>[signal],
      message: mapping.message,
      recommendation: mapping.recommendation,
      details: <String, Object?>{
        'platforms': dependency.platforms,
        'dependency_manager': dependency.dependencyManager,
        'spm_readiness': dependency.spmReadiness,
        if (dependency.recommendations.isNotEmpty)
          'dep_sherpa_recommendations': dependency.recommendations,
      },
    );
  }
}

const String _category = 'platform_migration_debt';

const Map<String, _SignalDebtMapping> _signalMappings =
    <String, _SignalDebtMapping>{
  'darwin.plugin.spm_missing': _SignalDebtMapping(
    severity: 'high',
    message:
        'Dependency is blocked for Swift Package Manager readiness because it appears to rely on CocoaPods-only metadata.',
    recommendation:
        'Add Package.swift and an SPM-compatible source layout, or track upstream plugin support.',
  ),
  'darwin.plugin.spm_partial_layout': _SignalDebtMapping(
    severity: 'medium',
    message:
        'Dependency has partial Swift Package Manager metadata or an incomplete source layout.',
    recommendation:
        'Complete the SPM source layout and validate the plugin through both SPM and CocoaPods where needed.',
  ),
  'darwin.plugin.cocoapods_regression_risk': _SignalDebtMapping(
    severity: 'high',
    message:
        'Dependency may have a mixed SPM/CocoaPods migration that risks breaking CocoaPods compatibility.',
    recommendation:
        'Update podspec source paths and validate CocoaPods fallback.',
  ),
  'darwin.plugin.privacy_manifest_spm_resource_missing': _SignalDebtMapping(
    severity: 'medium',
    message:
        'PrivacyInfo.xcprivacy may not be bundled correctly through Swift Package Manager.',
    recommendation:
        'Declare the privacy manifest as a resource in Package.swift when needed.',
  ),
  'darwin.plugin.pigeon_legacy_swift_output': _SignalDebtMapping(
    severity: 'medium',
    message:
        'Pigeon Swift output still targets the legacy CocoaPods Classes layout.',
    recommendation:
        'Move generated Swift output to the SPM target source directory.',
  ),
  'darwin.plugin.spm_gitignore_missing': _SignalDebtMapping(
    severity: 'low',
    message:
        'Swift Package Manager cache/build directories may not be ignored.',
    recommendation: 'Add .build/ and .swiftpm/ to .gitignore.',
  ),
};

const _SignalDebtMapping _unknownSignalMapping = _SignalDebtMapping(
  severity: 'low',
  message: 'Unknown Darwin readiness signal reported by dep_sherpa.',
  recommendation:
      'Inspect the dep_sherpa report and update techdebt_sherpa signal mapping if needed.',
);

class _SignalDebtMapping {
  const _SignalDebtMapping({
    required this.severity,
    required this.message,
    required this.recommendation,
  });

  final String severity;
  final String message;
  final String recommendation;
}

/// Minimal dep_sherpa report input used by techdebt_sherpa.
class DepSherpaReportInput {
  /// Creates a [DepSherpaReportInput].
  const DepSherpaReportInput({
    required this.darwinReadiness,
    required this.dependencies,
  });

  final DepSherpaDarwinReadiness? darwinReadiness;
  final List<DepSherpaDependencyPlatformCompatibility> dependencies;

  /// Parses supported dep_sherpa report fields.
  factory DepSherpaReportInput.fromJson(Map<String, Object?> json) {
    final Map<String, Object?>? platformReadiness =
        _mapOrNull(json['platformReadiness']);
    final DepSherpaDarwinReadiness? darwinReadiness =
        DepSherpaDarwinReadiness.fromJsonOrNull(
      _mapOrNull(platformReadiness?['darwin']),
    );
    final List<DepSherpaDependencyPlatformCompatibility> dependencies =
        <DepSherpaDependencyPlatformCompatibility>[];
    final Object? rawDependencies = json['dependencies'];
    if (rawDependencies is List) {
      for (final Object? rawDependency in rawDependencies) {
        final Map<String, Object?>? dependencyMap = _mapOrNull(rawDependency);
        if (dependencyMap == null) {
          continue;
        }
        final DepSherpaDependencyPlatformCompatibility? compatibility =
            DepSherpaDependencyPlatformCompatibility.fromJsonOrNull(
          dependencyMap,
        );
        if (compatibility != null) {
          dependencies.add(compatibility);
        }
      }
    }
    return DepSherpaReportInput(
      darwinReadiness: darwinReadiness,
      dependencies: dependencies,
    );
  }
}

/// Top-level dep_sherpa Darwin readiness payload.
class DepSherpaDarwinReadiness {
  /// Creates a [DepSherpaDarwinReadiness].
  const DepSherpaDarwinReadiness({
    required this.mode,
    required this.applicable,
    required this.dependencyManager,
    required this.spmReadiness,
    required this.summary,
    required this.enforcement,
  });

  final String mode;
  final bool applicable;
  final String dependencyManager;
  final String spmReadiness;
  final DepSherpaDarwinSummary summary;
  final DepSherpaDarwinEnforcement enforcement;

  static DepSherpaDarwinReadiness? fromJsonOrNull(
    Map<String, Object?>? json,
  ) {
    if (json == null) {
      return null;
    }
    return DepSherpaDarwinReadiness(
      mode: _stringValue(json['mode']),
      applicable: json['applicable'] == true,
      dependencyManager: _stringValue(json['dependencyManager']),
      spmReadiness: _stringValue(json['spmReadiness']),
      summary: DepSherpaDarwinSummary.fromJson(_mapOrNull(json['summary'])),
      enforcement: DepSherpaDarwinEnforcement.fromJson(
        _mapOrNull(json['enforcement']),
      ),
    );
  }
}

/// dep_sherpa Darwin readiness counts.
class DepSherpaDarwinSummary {
  /// Creates a [DepSherpaDarwinSummary].
  const DepSherpaDarwinSummary({
    required this.ready,
    required this.partial,
    required this.blocked,
    required this.notApplicable,
    required this.unknown,
  });

  final int ready;
  final int partial;
  final int blocked;
  final int notApplicable;
  final int unknown;

  static DepSherpaDarwinSummary fromJson(Map<String, Object?>? json) {
    return DepSherpaDarwinSummary(
      ready: _intValue(json?['ready']),
      partial: _intValue(json?['partial']),
      blocked: _intValue(json?['blocked']),
      notApplicable: _intValue(json?['notApplicable']),
      unknown: _intValue(json?['unknown']),
    );
  }
}

/// dep_sherpa Darwin enforcement payload.
class DepSherpaDarwinEnforcement {
  /// Creates a [DepSherpaDarwinEnforcement].
  const DepSherpaDarwinEnforcement({
    required this.enabled,
    required this.violated,
    required this.hardRiskTriggers,
    required this.violationMessages,
    required this.blockedCount,
    required this.partialCount,
    required this.warningFindingCount,
    required this.errorFindingCount,
  });

  final bool enabled;
  final bool violated;
  final List<String> hardRiskTriggers;
  final List<String> violationMessages;
  final int blockedCount;
  final int partialCount;
  final int warningFindingCount;
  final int errorFindingCount;

  static DepSherpaDarwinEnforcement fromJson(Map<String, Object?>? json) {
    return DepSherpaDarwinEnforcement(
      enabled: json?['enabled'] == true,
      violated: json?['violated'] == true,
      hardRiskTriggers: _stringList(json?['hardRiskTriggers']),
      violationMessages: _stringList(json?['violationMessages']),
      blockedCount: _intValue(json?['blockedCount']),
      partialCount: _intValue(json?['partialCount']),
      warningFindingCount: _intValue(json?['warningFindingCount']),
      errorFindingCount: _intValue(json?['errorFindingCount']),
    );
  }
}

/// Per-dependency Darwin compatibility payload from dep_sherpa.
class DepSherpaDependencyPlatformCompatibility {
  /// Creates a [DepSherpaDependencyPlatformCompatibility].
  const DepSherpaDependencyPlatformCompatibility({
    required this.name,
    required this.applicable,
    required this.platforms,
    required this.dependencyManager,
    required this.spmReadiness,
    required this.signals,
    required this.recommendations,
  });

  final String name;
  final bool applicable;
  final List<String> platforms;
  final String dependencyManager;
  final String spmReadiness;
  final List<String> signals;
  final List<String> recommendations;

  static DepSherpaDependencyPlatformCompatibility? fromJsonOrNull(
    Map<String, Object?> json,
  ) {
    final Map<String, Object?>? platformCompatibility =
        _mapOrNull(json['platformCompatibility']);
    final Map<String, Object?>? darwin =
        _mapOrNull(platformCompatibility?['darwin']);
    if (darwin == null) {
      return null;
    }
    final Map<String, Object?>? dependency = _mapOrNull(json['dependency']);
    final Map<String, Object?>? node = _mapOrNull(dependency?['node']);
    return DepSherpaDependencyPlatformCompatibility(
      name: _stringValue(node?['name']),
      applicable: darwin['applicable'] == true,
      platforms: _stringList(darwin['platforms']),
      dependencyManager: _stringValue(darwin['dependencyManager']),
      spmReadiness: _stringValue(darwin['spmReadiness']),
      signals: _stringList(darwin['signals']),
      recommendations: _stringList(darwin['recommendations']),
    );
  }
}

Map<String, Object?>? _mapOrNull(Object? input) {
  if (input is Map<String, Object?>) {
    return input;
  }
  if (input is Map<String, dynamic>) {
    return input.cast<String, Object?>();
  }
  if (input is Map) {
    return input.cast<String, Object?>();
  }
  return null;
}

String _stringValue(Object? input) => input is String ? input : '';

int _intValue(Object? input) => input is num ? input.toInt() : 0;

List<String> _stringList(Object? input) {
  if (input is! List) {
    return const <String>[];
  }
  return input.whereType<String>().toList(growable: false);
}

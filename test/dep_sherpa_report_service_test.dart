import 'package:file/memory.dart';
import 'package:path/path.dart' as p;
import 'package:techdebt_sherpa/src/adapters/file_system.dart';
import 'package:techdebt_sherpa/src/services/dep_sherpa_report_service.dart';
import 'package:test/test.dart';

void main() {
  final DepSherpaReportService service =
      DepSherpaReportService(LocalFileSystemAdapter());

  group('DepSherpaReportService parser', () {
    test('reads top-level platformReadiness.darwin', () {
      final report = service.read(_fixture('dep_sherpa_report_darwin_blocked'));

      expect(report.darwinReadiness?.mode, 'advisory');
      expect(report.darwinReadiness?.dependencyManager, 'cocoapods');
      expect(report.darwinReadiness?.spmReadiness, 'blocked');
      expect(report.darwinReadiness?.summary.blocked, 1);
    });

    test('reads per-dependency platformCompatibility.darwin', () {
      final report = service.read(_fixture('dep_sherpa_report_darwin_blocked'));
      final dependency = report.dependencies.single;

      expect(dependency.name, 'blocked_plugin');
      expect(dependency.applicable, isTrue);
      expect(dependency.platforms, <String>['ios', 'macos']);
      expect(dependency.signals, <String>['darwin.plugin.spm_missing']);
    });

    test('handles missing Darwin and platformCompatibility fields', () {
      final noDarwin = service.read(_fixture('dep_sherpa_report_no_darwin'));
      final missingFields =
          service.read(_fixture('dep_sherpa_report_missing_platform_fields'));

      expect(noDarwin.darwinReadiness, isNull);
      expect(noDarwin.dependencies, isEmpty);
      expect(missingFields.darwinReadiness, isNull);
      expect(missingFields.dependencies, isEmpty);
    });

    test('ignores unknown fields', () {
      final report =
          service.read(_fixture('dep_sherpa_report_missing_platform_fields'));

      expect(report.darwinReadiness, isNull);
    });

    test('fails clearly on malformed JSON', () {
      final MemoryFileSystem mem = MemoryFileSystem.test();
      mem.file('bad.json').writeAsStringSync('{bad');
      final parser = DepSherpaReportService(LocalFileSystemAdapter(fs: mem));

      expect(
        () => parser.read('bad.json'),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('Invalid dep_sherpa report JSON'),
          ),
        ),
      );
    });
  });

  group('DepSherpaReportService mapping', () {
    test('spm_missing maps to high platform_migration_debt', () {
      final findings = service.findingsFromReport(
        service.read(_fixture('dep_sherpa_report_darwin_blocked')),
      );
      final dependencyFinding = findings.last;

      expect(dependencyFinding.category, 'platform_migration_debt');
      expect(dependencyFinding.severity, 'high');
      expect(dependencyFinding.dependency, 'blocked_plugin');
      expect(dependencyFinding.signals, <String>['darwin.plugin.spm_missing']);
    });

    test('partial and warning signals map to expected severities', () {
      final findings = service.findingsFromReport(
        service.read(_fixture('dep_sherpa_report_darwin_partial')),
      );

      expect(
          _severityFor(findings, 'darwin.plugin.spm_partial_layout'), 'medium');
      expect(
        _severityFor(
          findings,
          'darwin.plugin.privacy_manifest_spm_resource_missing',
        ),
        'medium',
      );
      expect(_severityFor(findings, 'darwin.plugin.pigeon_legacy_swift_output'),
          'medium');
      expect(
          _severityFor(findings, 'darwin.plugin.spm_gitignore_missing'), 'low');
    });

    test('cocoapods_regression_risk maps to high severity', () {
      final findings = service.findingsFromReport(
        service.read(_fixture('dep_sherpa_report_darwin_mixed_regression')),
      );

      expect(
        _severityFor(findings, 'darwin.plugin.cocoapods_regression_risk'),
        'high',
      );
    });

    test('unknown signal is represented safely', () {
      final findings = service.findingsFromReport(
        service.read(_fixture('dep_sherpa_report_unknown_signal')),
      );
      final unknown = findings.singleWhere(
        (finding) => finding.signals.contains('darwin.plugin.future_signal'),
      );

      expect(unknown.category, 'platform_migration_debt');
      expect(unknown.severity, 'low');
      expect(unknown.message, contains('Unknown Darwin readiness signal'));
    });

    test('ready report produces no migration debt findings', () {
      final findings = service.findingsFromReport(
        service.read(_fixture('dep_sherpa_report_darwin_ready')),
      );

      expect(findings, isEmpty);
    });

    test('enforcement violation produces a high project-level finding', () {
      final findings = service.findingsFromReport(
        service.read(_fixture('dep_sherpa_report_darwin_enforcement_violated')),
      );

      expect(
        findings,
        contains(
          isA<dynamic>()
              .having((dynamic f) => f.severity, 'severity', 'high')
              .having((dynamic f) => f.dependency, 'dependency', null),
        ),
      );
      expect(findings.last.details['violation_messages'], isNotEmpty);
    });
  });
}

String _fixture(String name) =>
    p.join('test', 'fixtures', 'dep_sherpa', '$name.json');

String? _severityFor(List<dynamic> findings, String signal) {
  return findings
      .singleWhere(
        (dynamic finding) => (finding.signals as List<String>).contains(signal),
      )
      .severity as String?;
}

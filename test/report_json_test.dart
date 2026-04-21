import 'package:techdebt_sherpa/src/domain/models.dart';
import 'package:test/test.dart';

void main() {
  test('json report includes audit_sherpa summary fields', () {
    final report = SherpaReport(
      metadata: ReportMetadata(
        version: '0.1.0',
        timestamp: DateTime.parse('2026-03-01T00:00:00Z'),
        configHash: 'abc',
        gitHead: 'head',
        schemaVersion: 'v1',
      ),
      config: SherpaConfig.defaults(),
      global: const GlobalScores(
        debt: 42.5,
        risk: 55.1,
        evolvability: 57.5,
        totals: <String, num>{'files': 2, 'sloc': 30},
      ),
      files: <FileReportEntry>[
        FileReportEntry(
          metrics: FileMetrics(
            path: 'lib/a.dart',
            sloc: 10,
            fileSizeBytes: 100,
            lineCount: 20,
            functionCount: 1,
            classCount: 1,
            cyclomaticSum: 2,
            cyclomaticMax: 2,
            cyclomaticP95: 2,
            nestingMax: 1,
            paramsMax: 1,
            paramsP95: 1,
            maintainabilityIndex: 80,
            halstead: HalsteadMetrics.empty(),
            feature: null,
            directory: 'lib',
          ),
          git: null,
          scores: const FileScores(
            debt: 42,
            complexity: 40,
            churn: 20,
            size: 10,
            maintainability: 20,
            testGap: 80,
            risk: 38,
            evolvability: 58,
            normalized: <String, double>{},
            contributions: <String, double>{},
          ),
          coverage: 75,
          thresholdViolations: const <String>['cyclomatic_fail'],
        ),
        FileReportEntry(
          metrics: FileMetrics(
            path: 'lib/b.dart',
            sloc: 20,
            fileSizeBytes: 150,
            lineCount: 30,
            functionCount: 2,
            classCount: 1,
            cyclomaticSum: 3,
            cyclomaticMax: 3,
            cyclomaticP95: 3,
            nestingMax: 1,
            paramsMax: 1,
            paramsP95: 1,
            maintainabilityIndex: 75,
            halstead: HalsteadMetrics.empty(),
            feature: null,
            directory: 'lib',
          ),
          git: null,
          scores: const FileScores(
            debt: 35,
            complexity: 30,
            churn: 15,
            size: 12,
            maintainability: 25,
            testGap: 70,
            risk: 30,
            evolvability: 60,
            normalized: <String, double>{},
            contributions: <String, double>{},
          ),
          coverage: 80,
          thresholdViolations: const <String>[],
        ),
      ],
      topHotspots: const <FileReportEntry>[],
      directories: const <DirectorySummary>[],
      violations: const <String>['lib/a.dart:cyclomatic_fail'],
    );

    final json = report.toJson();
    expect(json['schema_version'], '0.1.0');
    expect(json['summary'], {
      'high_severity_issues': 1,
      'hotspot_count': 0,
      'total_debt_indicators': 2,
    });
  });
}

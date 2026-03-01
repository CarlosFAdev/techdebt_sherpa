import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:techdebt_sherpa/src/domain/models.dart';
import 'package:techdebt_sherpa/src/services/report_service.dart';
import 'package:test/test.dart';

void main() {
  test('markdown rendering matches golden', () {
    final SherpaReport report = SherpaReport(
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
        totals: <String, num>{'files': 1, 'sloc': 10},
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
          git: const GitFileStats(
              path: 'lib/a.dart',
              commitCount: 1,
              linesAdded: 1,
              linesDeleted: 1),
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
          thresholdViolations: <String>[],
        ),
      ],
      topHotspots: const <FileReportEntry>[],
      directories: const <DirectorySummary>[
        DirectorySummary(
            path: 'lib',
            fileCount: 1,
            avgDebt: 42,
            avgComplexity: 40,
            avgChurn: 20,
            avgMi: 80),
      ],
      violations: const <String>[],
    );

    final String md = ReportService().renderMarkdown(report);
    final File golden =
        const LocalFileSystem().file(p.join('test', 'goldens', 'report.md'));
    expect(md, golden.readAsStringSync());
  });
}

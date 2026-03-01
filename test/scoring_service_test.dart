import 'package:techdebt_sherpa/src/domain/models.dart';
import 'package:techdebt_sherpa/src/services/scoring_service.dart';
import 'package:test/test.dart';

void main() {
  test('scores files and keeps debt within 0..100', () {
    final List<FileMetrics> metrics = <FileMetrics>[
      FileMetrics(
        path: 'lib/a.dart',
        sloc: 20,
        fileSizeBytes: 200,
        lineCount: 30,
        functionCount: 2,
        classCount: 1,
        cyclomaticSum: 4,
        cyclomaticMax: 3,
        cyclomaticP95: 3,
        nestingMax: 2,
        paramsMax: 2,
        paramsP95: 2,
        maintainabilityIndex: 80,
        halstead: HalsteadMetrics.empty(),
        feature: null,
        directory: 'lib',
      ),
      FileMetrics(
        path: 'lib/b.dart',
        sloc: 200,
        fileSizeBytes: 1000,
        lineCount: 300,
        functionCount: 8,
        classCount: 3,
        cyclomaticSum: 50,
        cyclomaticMax: 20,
        cyclomaticP95: 19,
        nestingMax: 7,
        paramsMax: 6,
        paramsP95: 5,
        maintainabilityIndex: 35,
        halstead: HalsteadMetrics.empty(),
        feature: null,
        directory: 'lib',
      ),
    ];

    final ScoringResult result = ScoringService().score(
      metrics: metrics,
      git: <String, GitFileStats>{
        'lib/a.dart': const GitFileStats(
            path: 'lib/a.dart',
            commitCount: 2,
            linesAdded: 10,
            linesDeleted: 2),
        'lib/b.dart': const GitFileStats(
            path: 'lib/b.dart',
            commitCount: 20,
            linesAdded: 400,
            linesDeleted: 200),
      },
      coverage: <String, double>{'lib/a.dart': 90, 'lib/b.dart': 20},
      config: SherpaConfig.defaults(),
    );

    expect(result.files, hasLength(2));
    expect(result.files.first.scores.debt, inInclusiveRange(0, 100));
    expect(result.global.debt, inInclusiveRange(0, 100));
    expect(result.global.evolvability, inInclusiveRange(0, 100));
  });
}

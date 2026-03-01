import 'package:file/memory.dart';
import 'package:techdebt_sherpa/src/adapters/file_system.dart';
import 'package:techdebt_sherpa/src/services/config_service.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigService', () {
    test('loads defaults when config does not exist', () {
      final LocalFileSystemAdapter fs =
          LocalFileSystemAdapter(fs: MemoryFileSystem.test());
      final ConfigService service = ConfigService(fs);

      final config = service.load(root: '.');

      expect(config.project.root, '.');
      expect(config.metrics.enabled, contains('cyclomatic'));
      expect(config.scoring.globalWeights['complexity'], 0.30);
    });

    test('parses YAML and overrides defaults', () {
      final MemoryFileSystem mem = MemoryFileSystem.test();
      mem.file('techdebt_sherpa.yaml').writeAsStringSync('''
metrics:
  enabled: [sloc, cyclomatic]
scoring:
  global_weights:
    complexity: 0.4
    churn: 0.2
    size: 0.2
    maintainability: 0.1
    testgap: 0.1
''');
      final LocalFileSystemAdapter fs = LocalFileSystemAdapter(fs: mem);
      final ConfigService service = ConfigService(fs);

      final config = service.load(root: '.');

      expect(config.metrics.enabled, <String>['sloc', 'cyclomatic']);
      expect(config.scoring.globalWeights['complexity'], 0.4);
      expect(
          config.scoring.globalWeights.values.fold<double>(0, (a, b) => a + b),
          closeTo(1.0, 0.001));
    });

    test('throws on invalid global weights sum', () {
      final MemoryFileSystem mem = MemoryFileSystem.test();
      mem.file('techdebt_sherpa.yaml').writeAsStringSync(
          '''\nmetrics:\n  enabled: [sloc]\nscoring:\n  global_weights:\n    complexity: 0.5\n    churn: 0.5\n    size: 0.5\n    maintainability: 0.0\n    testgap: 0.0\n''');
      final LocalFileSystemAdapter fs = LocalFileSystemAdapter(fs: mem);
      final ConfigService service = ConfigService(fs);

      expect(() => service.load(root: '.'), throwsFormatException);
    });
  });
}

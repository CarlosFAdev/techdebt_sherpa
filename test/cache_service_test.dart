import 'dart:convert';

import 'package:file/memory.dart';
import 'package:path/path.dart' as p;
import 'package:techdebt_sherpa/src/adapters/file_system.dart';
import 'package:techdebt_sherpa/src/services/cache_service.dart';
import 'package:test/test.dart';

void main() {
  group('CacheService', () {
    test('invalidates metrics cache when mtime changes', () {
      final LocalFileSystemAdapter fs =
          LocalFileSystemAdapter(fs: MemoryFileSystem.test());
      final CacheService cache = CacheService(
        fs,
        cacheDir: '.cache',
        toolVersion: '0.1.0',
      );

      final DateTime first = DateTime.utc(2026, 1, 1);
      final DateTime second = DateTime.utc(2026, 1, 2);
      cache.writeMetrics(
        relativePath: 'lib/a.dart',
        mtime: first,
        payload: <String, Object?>{'path': 'lib/a.dart'},
      );

      expect(
        cache.readMetrics(relativePath: 'lib/a.dart', mtime: first),
        isNotNull,
      );
      expect(
        cache.readMetrics(relativePath: 'lib/a.dart', mtime: second),
        isNull,
      );
    });

    test('prunes old cache entries by max count', () {
      final LocalFileSystemAdapter fs =
          LocalFileSystemAdapter(fs: MemoryFileSystem.test());
      final CacheService cache = CacheService(
        fs,
        cacheDir: '.cache',
        toolVersion: '0.1.0',
        maxMetricEntries: 2,
      );

      for (int i = 0; i < 5; i += 1) {
        cache.writeMetrics(
          relativePath: 'lib/file_$i.dart',
          mtime: DateTime.utc(2026, 1, 1, 0, 0, i),
          payload: <String, Object?>{'path': 'lib/file_$i.dart'},
        );
      }

      final int count = fs
          .listDir(p.join('.cache', 'metrics'))
          .where((entity) => entity.path.endsWith('.json'))
          .length;
      expect(count, lessThanOrEqualTo(2));
    });

    test('drops corrupt git cache payload', () {
      final LocalFileSystemAdapter fs =
          LocalFileSystemAdapter(fs: MemoryFileSystem.test());
      final CacheService cache = CacheService(
        fs,
        cacheDir: '.cache',
        toolVersion: '0.1.0',
      );
      cache.writeGit('ok', <String, Object?>{'a': 1});
      final String target = fs
          .listDir(p.join('.cache', 'git'))
          .where((entity) => entity.path.endsWith('.json'))
          .single
          .path;
      fs.writeAsString(target, '{bad json');

      expect(cache.readGit('ok'), isNull);

      cache.writeGit('ok2', <String, Object?>{'a': 2});
      final String latest = fs
          .listDir(p.join('.cache', 'git'))
          .where((entity) => entity.path.endsWith('.json'))
          .map((entity) => entity.path)
          .last;
      final dynamic decoded = jsonDecode(fs.readAsString(latest));
      expect(decoded, isA<Map<String, dynamic>>());
    });
  });
}

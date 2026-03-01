import 'dart:convert';

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import '../adapters/file_system.dart';
import '../utils/hash_utils.dart';

/// Filesystem-backed cache for metric and git computations.
class CacheService {
  /// Creates a [CacheService].
  CacheService(
    this._fs, {
    required this.cacheDir,
    required this.toolVersion,
    this.maxMetricEntries = 5000,
    this.maxGitEntries = 200,
  });

  final FileSystemAdapter _fs;
  final String cacheDir;
  final String toolVersion;
  final int maxMetricEntries;
  final int maxGitEntries;

  String _metricsPath(String relativePath) => p.join(
        cacheDir,
        'metrics',
        '${sha256OfString('$toolVersion::$relativePath')}.json',
      );

  String _gitPath(String key) =>
      p.join(cacheDir, 'git', '${sha256OfString('$toolVersion::$key')}.json');

  /// Reads cached metric payload if present and still valid for [mtime].
  Map<String, Object?>? readMetrics({
    required String relativePath,
    required DateTime mtime,
  }) {
    final String path = _metricsPath(relativePath);
    if (!_fs.fileExists(path)) {
      return null;
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(_fs.readAsString(path));
    } on FormatException {
      _fs.deleteFile(path);
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final String? saved = decoded['mtime'] as String?;
    if (saved == null || saved != mtime.toUtc().toIso8601String()) {
      return null;
    }
    final dynamic payload = decoded['payload'];
    if (payload is Map<String, dynamic>) {
      return payload.cast<String, Object?>();
    }
    return null;
  }

  /// Stores metric payload in cache and prunes overflow entries.
  void writeMetrics({
    required String relativePath,
    required DateTime mtime,
    required Map<String, Object?> payload,
  }) {
    final String dir = p.join(cacheDir, 'metrics');
    _fs.createDir(dir);
    _fs.writeAsString(
      _metricsPath(relativePath),
      encodeJson(<String, Object?>{
        'mtime': mtime.toUtc().toIso8601String(),
        'payload': payload,
      }),
    );
    _pruneDirectory(dir, maxMetricEntries);
  }

  /// Reads cached git payload by key.
  Map<String, Object?>? readGit(String key) {
    final String path = _gitPath(key);
    if (!_fs.fileExists(path)) {
      return null;
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(_fs.readAsString(path));
    } on FormatException {
      _fs.deleteFile(path);
      return null;
    }
    if (decoded is Map<String, dynamic>) {
      return decoded.cast<String, Object?>();
    }
    return null;
  }

  /// Stores git payload in cache and prunes overflow entries.
  void writeGit(String key, Map<String, Object?> payload) {
    final String dir = p.join(cacheDir, 'git');
    _fs.createDir(dir);
    _fs.writeAsString(_gitPath(key), encodeJson(payload));
    _pruneDirectory(dir, maxGitEntries);
  }

  void _pruneDirectory(String dir, int maxEntries) {
    if (maxEntries <= 0 || !_fs.directoryExists(dir)) {
      return;
    }
    final List<File> files =
        _fs.listDir(dir).whereType<File>().toList(growable: false);
    if (files.length <= maxEntries) {
      return;
    }
    final List<File> sorted = List<File>.from(files)
      ..sort(
        (File a, File b) =>
            a.lastModifiedSync().compareTo(b.lastModifiedSync()),
      );
    final int deleteCount = sorted.length - maxEntries;
    for (int i = 0; i < deleteCount; i += 1) {
      _fs.deleteFile(sorted[i].path);
    }
  }
}

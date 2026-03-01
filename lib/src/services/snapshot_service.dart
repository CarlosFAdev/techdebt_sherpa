import 'dart:convert';

import 'package:path/path.dart' as p;

import '../adapters/file_system.dart';
import '../adapters/process_runner.dart';

/// Persists timestamped report snapshots.
class SnapshotService {
  /// Creates a [SnapshotService].
  SnapshotService(this._fs, this._runner);

  final FileSystemAdapter _fs;
  final ProcessRunner _runner;

  /// Resolves default snapshot label from git head when available.
  Future<String> resolveLabel(String root, {String? provided}) async {
    if (provided != null && provided.trim().isNotEmpty) {
      return provided;
    }
    final ProcessResultData result;
    try {
      result = await _runner.run(
        'git',
        const <String>['rev-parse', '--short', 'HEAD'],
        workingDirectory: root,
        timeout: const Duration(seconds: 10),
      );
    } on Exception {
      return 'snapshot';
    }
    if (result.exitCode == 0 && result.stdout.trim().isNotEmpty) {
      return result.stdout.trim();
    }
    return 'snapshot';
  }

  /// Writes a snapshot file and returns its path.
  String writeSnapshot({
    required String root,
    required Map<String, Object?> reportJson,
    required String label,
  }) {
    final DateTime now = DateTime.now().toUtc();
    final String dir = p.join(root, '.techdebt', 'snapshots');
    _fs.createDir(dir);
    final String safeLabel = label.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final String name =
        '${now.toIso8601String().replaceAll(':', '-')}_$safeLabel.json';
    final String path = p.join(dir, name);
    _fs.writeAsString(
      path,
      const JsonEncoder.withIndent('  ').convert(reportJson),
    );
    return path;
  }
}

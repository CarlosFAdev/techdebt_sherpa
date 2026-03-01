import 'dart:convert';

import '../adapters/file_system.dart';

/// Reads LCOV coverage files and returns per-file coverage percentages.
class CoverageService {
  /// Creates a [CoverageService].
  CoverageService(this._fs);

  final FileSystemAdapter _fs;

  /// Loads coverage from [lcovPath] under [root].
  Future<Map<String, double>> loadCoverage({
    required String root,
    required String lcovPath,
  }) async {
    final String path = '$root/$lcovPath';
    if (!_fs.fileExists(path)) {
      return <String, double>{};
    }

    final Map<String, int> found = <String, int>{};
    final Map<String, int> hit = <String, int>{};
    String? current;

    await for (final String line in _fs
        .openRead(path)
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.startsWith('SF:')) {
        current = line.substring(3).replaceAll('\\', '/');
      } else if (line.startsWith('LF:') && current != null) {
        found[current] = int.tryParse(line.substring(3)) ?? 0;
      } else if (line.startsWith('LH:') && current != null) {
        hit[current] = int.tryParse(line.substring(3)) ?? 0;
      }
    }

    final Map<String, double> out = <String, double>{};
    for (final String file in found.keys) {
      final int lf = found[file] ?? 0;
      final int lh = hit[file] ?? 0;
      out[file] = lf == 0 ? 0 : (lh / lf) * 100;
    }
    return out;
  }
}

import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import '../adapters/file_system.dart';

/// Discovers Dart files using include and exclude globs.
class DiscoveryService {
  /// Creates a [DiscoveryService].
  DiscoveryService(this._fs);

  final FileSystemAdapter _fs;

  /// Returns matched Dart files relative to [root].
  List<String> discoverDartFiles({
    required String root,
    required List<String> include,
    required List<String> exclude,
    int? maxFiles,
  }) {
    final List<Glob> includeGlobs =
        include.map(Glob.new).toList(growable: false);
    final List<Glob> excludeGlobs =
        exclude.map(Glob.new).toList(growable: false);

    final List<String> matched = <String>[];
    for (final File file
        in _fs.listDir(root, recursive: true).whereType<File>()) {
      final String absolutePath = p.normalize(file.path);
      if (!absolutePath.endsWith('.dart')) {
        continue;
      }
      final String rel = p.normalize(p.relative(absolutePath, from: root));
      final bool includeHit =
          includeGlobs.isEmpty || includeGlobs.any((Glob g) => g.matches(rel));
      final bool excludeHit = excludeGlobs.any((Glob g) => g.matches(rel));
      if (includeHit && !excludeHit) {
        matched.add(rel);
      }
    }
    matched.sort();
    if (maxFiles != null && maxFiles > 0 && matched.length > maxFiles) {
      return matched.sublist(0, maxFiles);
    }
    return matched;
  }
}

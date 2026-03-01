import 'dart:convert';
import 'dart:async';

import '../adapters/process_runner.dart';
import '../domain/models.dart';
import 'cache_service.dart';

/// Time window options for git history queries.
class GitWindow {
  /// Creates a [GitWindow].
  const GitWindow({this.since, this.until, this.commitRange});

  final DateTime? since;
  final DateTime? until;
  final String? commitRange;

  /// Returns a deterministic cache key for this window.
  String cacheKey() =>
      'since=${since?.toIso8601String()}|until=${until?.toIso8601String()}|range=$commitRange';
}

/// Result payload from git analysis.
class GitAnalysisResult {
  /// Creates a [GitAnalysisResult].
  const GitAnalysisResult({
    required this.statsByFile,
    required this.head,
    required this.available,
  });

  final Map<String, GitFileStats> statsByFile;
  final String? head;
  final bool available;
}

/// Collects git-based per-file signals.
class GitService {
  /// Creates a [GitService].
  GitService(this._runner, this._cache);

  final ProcessRunner _runner;
  final CacheService _cache;
  static const Duration _gitTimeout = Duration(seconds: 30);

  /// Collects churn/commit metadata for files in [window].
  Future<GitAnalysisResult> collect({
    required String repoRoot,
    required GitWindow window,
    required bool useCache,
    required bool includeOwnershipProxy,
  }) async {
    final bool available = await _isGitAvailable(repoRoot);
    if (!available) {
      return const GitAnalysisResult(
        statsByFile: <String, GitFileStats>{},
        head: null,
        available: false,
      );
    }

    final String? head = await _gitHead(repoRoot);
    final String cacheKey =
        'head=$head|${window.cacheKey()}|owners=$includeOwnershipProxy';

    if (useCache) {
      final Map<String, Object?>? cached = _cache.readGit(cacheKey);
      if (cached != null) {
        return _fromCache(cached);
      }
    }

    final Map<String, _Accumulator> acc = <String, _Accumulator>{};
    final List<String> args = <String>[
      'log',
      '--numstat',
      '--format=@@@%H|%at|%an',
    ];
    if (window.commitRange != null && window.commitRange!.isNotEmpty) {
      args.add(window.commitRange!);
    } else {
      if (window.since != null) {
        args.add('--since=${window.since!.toIso8601String()}');
      }
      if (window.until != null) {
        args.add('--until=${window.until!.toIso8601String()}');
      }
    }
    args.add('--');

    final ProcessResultData logResult;
    try {
      logResult = await _runGit(args, repoRoot: repoRoot);
    } on TimeoutException {
      return GitAnalysisResult(
        statsByFile: <String, GitFileStats>{},
        head: head,
        available: false,
      );
    }
    if (logResult.exitCode != 0) {
      return GitAnalysisResult(
        statsByFile: <String, GitFileStats>{},
        head: head,
        available: false,
      );
    }

    String? currentAuthor;
    int? currentTs;
    for (final String line in const LineSplitter().convert(logResult.stdout)) {
      if (line.startsWith('@@@')) {
        final List<String> parts = line.substring(3).split('|');
        if (parts.length >= 3) {
          currentTs = int.tryParse(parts[1]);
          currentAuthor = parts[2];
        }
        continue;
      }
      if (line.trim().isEmpty || line.startsWith(' ')) {
        continue;
      }
      final _NumstatLine? parsed = _parseNumstatLine(line);
      if (parsed == null) {
        continue;
      }
      final int added = parsed.added;
      final int deleted = parsed.deleted;
      final String path = parsed.path;
      final _Accumulator fileAcc = acc.putIfAbsent(path, _Accumulator.new);
      fileAcc.commits += 1;
      fileAcc.added += added;
      fileAcc.deleted += deleted;
      if (currentTs != null) {
        final DateTime dt = DateTime.fromMillisecondsSinceEpoch(
          currentTs * 1000,
          isUtc: true,
        );
        if (fileAcc.lastModified == null || dt.isAfter(fileAcc.lastModified!)) {
          fileAcc.lastModified = dt;
        }
      }
      if (includeOwnershipProxy && currentAuthor != null) {
        fileAcc.authors.add(currentAuthor);
      }
    }

    final Map<String, GitFileStats> stats = <String, GitFileStats>{
      for (final MapEntry<String, _Accumulator> e in acc.entries)
        e.key: GitFileStats(
          path: e.key,
          commitCount: e.value.commits,
          linesAdded: e.value.added,
          linesDeleted: e.value.deleted,
          lastModified: e.value.lastModified,
          distinctAuthors:
              includeOwnershipProxy ? e.value.authors.length : null,
        ),
    };

    final GitAnalysisResult result = GitAnalysisResult(
      statsByFile: stats,
      head: head,
      available: true,
    );

    if (useCache) {
      _cache.writeGit(cacheKey, <String, Object?>{
        'available': true,
        'head': head,
        'stats': stats.map(
          (String k, GitFileStats v) =>
              MapEntry<String, Object?>(k, v.toJson()),
        ),
      });
    }
    return result;
  }

  Future<bool> _isGitAvailable(String repoRoot) async {
    final ProcessResultData version;
    try {
      version = await _runGit(const <String>['--version']);
    } on TimeoutException {
      return false;
    }
    if (version.exitCode != 0) {
      return false;
    }
    final ProcessResultData inRepo;
    try {
      inRepo = await _runGit(
        const <String>['rev-parse', '--is-inside-work-tree'],
        repoRoot: repoRoot,
      );
    } on TimeoutException {
      return false;
    }
    return inRepo.exitCode == 0 && inRepo.stdout.trim() == 'true';
  }

  Future<String?> _gitHead(String repoRoot) async {
    final ProcessResultData head;
    try {
      head = await _runGit(
        const <String>['rev-parse', '--short', 'HEAD'],
        repoRoot: repoRoot,
      );
    } on TimeoutException {
      return null;
    }
    if (head.exitCode != 0) {
      return null;
    }
    return head.stdout.trim();
  }

  Future<ProcessResultData> _runGit(
    List<String> args, {
    String? repoRoot,
  }) {
    return _runner.run(
      'git',
      args,
      workingDirectory: repoRoot,
      timeout: _gitTimeout,
    );
  }

  _NumstatLine? _parseNumstatLine(String line) {
    final List<String> cols = line.split('\t');
    if (cols.length < 3) {
      return null;
    }
    final String path = cols.sublist(2).join('\t').trim();
    if (path.isEmpty) {
      return null;
    }
    return _NumstatLine(
      added: int.tryParse(cols[0]) ?? 0,
      deleted: int.tryParse(cols[1]) ?? 0,
      path: path,
    );
  }

  GitAnalysisResult _fromCache(Map<String, Object?> cached) {
    final Map<String, dynamic> statsRaw =
        (cached['stats'] as Map<dynamic, dynamic>).cast<String, dynamic>();
    final Map<String, GitFileStats> stats = <String, GitFileStats>{};
    for (final MapEntry<String, dynamic> entry in statsRaw.entries) {
      final Map<String, dynamic> v =
          (entry.value as Map<dynamic, dynamic>).cast<String, dynamic>();
      stats[entry.key] = GitFileStats(
        path: entry.key,
        commitCount: (v['commit_count'] as num).toInt(),
        linesAdded: (v['lines_added'] as num).toInt(),
        linesDeleted: (v['lines_deleted'] as num).toInt(),
        lastModified: v['last_modified'] == null
            ? null
            : DateTime.parse(v['last_modified'] as String),
        distinctAuthors: (v['distinct_authors'] as num?)?.toInt(),
      );
    }
    return GitAnalysisResult(
      statsByFile: stats,
      head: cached['head'] as String?,
      available: cached['available'] as bool? ?? true,
    );
  }
}

class _Accumulator {
  int commits = 0;
  int added = 0;
  int deleted = 0;
  DateTime? lastModified;
  final Set<String> authors = <String>{};
}

class _NumstatLine {
  const _NumstatLine({
    required this.added,
    required this.deleted,
    required this.path,
  });

  final int added;
  final int deleted;
  final String path;
}

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
    if (!await _isGitAvailable(repoRoot)) {
      return _emptyResult();
    }
    final String? head = await _gitHead(repoRoot);
    final String cacheKey =
        'head=$head|${window.cacheKey()}|owners=$includeOwnershipProxy';

    final GitAnalysisResult? cached = _readCachedResult(
      cacheKey: cacheKey,
      useCache: useCache,
    );
    if (cached != null) {
      return cached;
    }

    final ProcessResultData? logResult = await _runGitLog(
      repoRoot: repoRoot,
      window: window,
    );
    if (logResult == null || logResult.exitCode != 0) {
      return _resultWithHead(head, available: false);
    }

    final Map<String, GitFileStats> stats = _parseLogToStats(
      logResult.stdout,
      includeOwnershipProxy: includeOwnershipProxy,
    );

    final GitAnalysisResult result = GitAnalysisResult(
      statsByFile: stats,
      head: head,
      available: true,
    );

    if (useCache) {
      _cache.writeGit(cacheKey, _toCachePayload(result));
    }
    return result;
  }

  GitAnalysisResult _emptyResult() => const GitAnalysisResult(
        statsByFile: <String, GitFileStats>{},
        head: null,
        available: false,
      );

  GitAnalysisResult _resultWithHead(String? head, {required bool available}) =>
      GitAnalysisResult(
        statsByFile: const <String, GitFileStats>{},
        head: head,
        available: available,
      );

  GitAnalysisResult? _readCachedResult({
    required String cacheKey,
    required bool useCache,
  }) {
    if (!useCache) {
      return null;
    }
    final Map<String, Object?>? cached = _cache.readGit(cacheKey);
    if (cached == null) {
      return null;
    }
    return _fromCache(cached);
  }

  Future<ProcessResultData?> _runGitLog({
    required String repoRoot,
    required GitWindow window,
  }) async {
    try {
      return await _runGit(_buildLogArgs(window), repoRoot: repoRoot);
    } on TimeoutException {
      return null;
    }
  }

  List<String> _buildLogArgs(GitWindow window) {
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
    return args;
  }

  Map<String, GitFileStats> _parseLogToStats(
    String stdout, {
    required bool includeOwnershipProxy,
  }) {
    final Map<String, _Accumulator> accumulators = <String, _Accumulator>{};
    String? currentAuthor;
    int? currentTs;

    for (final String line in const LineSplitter().convert(stdout)) {
      if (line.startsWith('@@@')) {
        final _CommitMeta meta = _parseCommitMeta(line);
        currentTs = meta.timestamp;
        currentAuthor = meta.author;
        continue;
      }
      if (_shouldSkipLine(line)) {
        continue;
      }
      final _NumstatLine? parsed = _parseNumstatLine(line);
      if (parsed == null) {
        continue;
      }
      _recordNumstat(
        accumulators: accumulators,
        parsed: parsed,
        currentTs: currentTs,
        currentAuthor: currentAuthor,
        includeOwnershipProxy: includeOwnershipProxy,
      );
    }

    return _toGitStats(
      accumulators,
      includeOwnershipProxy: includeOwnershipProxy,
    );
  }

  _CommitMeta _parseCommitMeta(String line) {
    final List<String> parts = line.substring(3).split('|');
    if (parts.length < 3) {
      return const _CommitMeta();
    }
    return _CommitMeta(
      timestamp: int.tryParse(parts[1]),
      author: parts[2],
    );
  }

  bool _shouldSkipLine(String line) =>
      line.trim().isEmpty || line.startsWith(' ');

  void _recordNumstat({
    required Map<String, _Accumulator> accumulators,
    required _NumstatLine parsed,
    required int? currentTs,
    required String? currentAuthor,
    required bool includeOwnershipProxy,
  }) {
    final _Accumulator fileAcc =
        accumulators.putIfAbsent(parsed.path, _Accumulator.new);
    fileAcc.commits += 1;
    fileAcc.added += parsed.added;
    fileAcc.deleted += parsed.deleted;
    _recordLastModified(fileAcc, currentTs);
    if (includeOwnershipProxy && currentAuthor != null) {
      fileAcc.authors.add(currentAuthor);
    }
  }

  void _recordLastModified(_Accumulator acc, int? currentTs) {
    if (currentTs == null) {
      return;
    }
    final DateTime candidate = DateTime.fromMillisecondsSinceEpoch(
      currentTs * 1000,
      isUtc: true,
    );
    if (acc.lastModified == null || candidate.isAfter(acc.lastModified!)) {
      acc.lastModified = candidate;
    }
  }

  Map<String, GitFileStats> _toGitStats(
    Map<String, _Accumulator> accumulators, {
    required bool includeOwnershipProxy,
  }) {
    return <String, GitFileStats>{
      for (final MapEntry<String, _Accumulator> entry in accumulators.entries)
        entry.key: GitFileStats(
          path: entry.key,
          commitCount: entry.value.commits,
          linesAdded: entry.value.added,
          linesDeleted: entry.value.deleted,
          lastModified: entry.value.lastModified,
          distinctAuthors:
              includeOwnershipProxy ? entry.value.authors.length : null,
        ),
    };
  }

  Map<String, Object?> _toCachePayload(GitAnalysisResult result) {
    return <String, Object?>{
      'available': result.available,
      'head': result.head,
      'stats': result.statsByFile.map(
        (String path, GitFileStats stats) =>
            MapEntry<String, Object?>(path, stats.toJson()),
      ),
    };
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

class _CommitMeta {
  const _CommitMeta({this.timestamp, this.author});

  final int? timestamp;
  final String? author;
}

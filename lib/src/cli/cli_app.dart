import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../adapters/file_system.dart';
import '../adapters/logger.dart';
import '../adapters/process_runner.dart';
import '../domain/models.dart';
import '../services/services.dart';
import '../utils/hash_utils.dart';
import 'exit_codes.dart';

class CliApp {
  CliApp({FileSystemAdapter? fs, ProcessRunner? runner})
      : _fs = fs ?? LocalFileSystemAdapter(),
        _runner = runner ?? SystemProcessRunner();

  final FileSystemAdapter _fs;
  final ProcessRunner _runner;
  final ReportDiffService _reportDiffService = ReportDiffService();
  static const String toolVersion = '0.1.0';
  static const String schemaVersion = 'v1';

  Future<int> run(List<String> args) async {
    final ArgParser parser = _buildParser();
    ArgResults root;
    try {
      root = parser.parse(args);
    } on FormatException catch (e) {
      stderr.writeln('Invalid usage: ${e.message}');
      stderr.writeln(parser.usage);
      return ExitCodes.usage;
    }

    if ((root['help'] as bool) || root.command == null) {
      _printRootHelp(parser);
      return ExitCodes.success;
    }

    final ArgResults command = root.command!;
    if ((command['help'] as bool? ?? false) == true) {
      stdout.writeln('techdebt_sherpa ${command.name} [options]');
      stdout.writeln();
      stdout.writeln(parser.commands[command.name]?.usage ?? '');
      return ExitCodes.success;
    }
    final Logger logger = Logger(
      verbose: command['verbose'] as bool? ?? false,
      quiet: command['quiet'] as bool? ?? false,
    );

    try {
      switch (command.name) {
        case 'scan':
          return await _runScan(command, logger);
        case 'rank':
          return await _runRank(command, logger);
        case 'diff':
          return _runDiff(command, logger);
        case 'snapshot':
          return await _runSnapshot(command, logger);
        case 'trend':
          return _runTrend(command, logger);
        case 'explain':
          return _runExplain(command);
        default:
          stderr.writeln('Unknown command: ${command.name}');
          return ExitCodes.usage;
      }
    } catch (e, st) {
      logger.error('$e\n$st');
      return ExitCodes.analysisFailed;
    }
  }

  ArgParser _buildParser() {
    final ArgParser parser = ArgParser();
    parser.addFlag('help', abbr: 'h', negatable: false, help: 'Show help.');

    parser.addCommand('scan', _scanParser());
    parser.addCommand('rank', _rankParser());
    parser.addCommand('diff', _diffParser());
    parser.addCommand('snapshot', _snapshotParser());
    parser.addCommand('trend', _trendParser());
    parser.addCommand('explain', _explainParser());

    return parser;
  }

  void _printRootHelp(ArgParser parser) {
    stdout.writeln('techdebt_sherpa <command> [options]');
    stdout.writeln();
    stdout.writeln('Commands:');
    stdout.writeln('  scan      Analyze repository and write report files');
    stdout.writeln('  rank      Show top hotspots');
    stdout.writeln('  diff      Compare two JSON reports');
    stdout.writeln('  snapshot  Store timestamped snapshot JSON');
    stdout.writeln('  trend     Build trend from snapshots');
    stdout.writeln('  explain   Show metric formulas and defaults');
    stdout.writeln();
    stdout.writeln('Global options:');
    stdout.writeln(parser.usage);
    stdout.writeln();
    stdout
        .writeln('Use `techdebt_sherpa <command> --help` for command options.');
  }

  ArgParser _scanParser() => ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('config', help: 'Path to config YAML.')
    ..addOption(
      'format',
      defaultsTo: 'both',
      allowed: <String>['json', 'md', 'both'],
    )
    ..addOption('out', defaultsTo: 'techdebt_reports')
    ..addOption('baseline')
    ..addOption('since')
    ..addOption('until')
    ..addOption('commit-range')
    ..addOption('max-files')
    ..addMultiOption('include')
    ..addMultiOption('exclude')
    ..addMultiOption('fail-on')
    ..addFlag(
      'git',
      defaultsTo: true,
      negatable: true,
      help: 'Enable git analysis.',
    )
    ..addFlag(
      'resolve',
      defaultsTo: true,
      negatable: true,
      help: 'Use analyzer resolution.',
    )
    ..addFlag(
      'cache',
      defaultsTo: true,
      negatable: true,
      help: 'Use cache/incremental mode.',
    )
    ..addOption('cache-dir', defaultsTo: '.techdebt/cache')
    ..addFlag('quiet', defaultsTo: false, negatable: false)
    ..addFlag('verbose', defaultsTo: false, negatable: false);

  ArgParser _rankParser() => ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('top', defaultsTo: '20')
    ..addOption(
      'format',
      defaultsTo: 'table',
      allowed: <String>['table', 'json'],
    )
    ..addOption('config')
    ..addFlag('quiet', defaultsTo: false, negatable: false)
    ..addFlag('verbose', defaultsTo: false, negatable: false);

  ArgParser _diffParser() => ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('left')
    ..addOption('right')
    ..addOption(
      'format',
      defaultsTo: 'both',
      allowed: <String>['json', 'md', 'both'],
    )
    ..addFlag('quiet', defaultsTo: false, negatable: false)
    ..addFlag('verbose', defaultsTo: false, negatable: false);

  ArgParser _snapshotParser() => ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('label')
    ..addOption('config')
    ..addFlag('quiet', defaultsTo: false, negatable: false)
    ..addFlag('verbose', defaultsTo: false, negatable: false);

  ArgParser _trendParser() => ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption(
      'format',
      defaultsTo: 'both',
      allowed: <String>['md', 'json', 'both'],
    )
    ..addOption('window')
    ..addFlag('quiet', defaultsTo: false, negatable: false)
    ..addFlag('verbose', defaultsTo: false, negatable: false);

  ArgParser _explainParser() => ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('metric')
    ..addFlag('quiet', defaultsTo: false, negatable: false)
    ..addFlag('verbose', defaultsTo: false, negatable: false);

  Future<int> _runScan(ArgResults args, Logger logger) async {
    final _ScanOutcome outcome = await _scanInternal(
      args,
      logger,
      writeFiles: true,
    );
    final List<String> failOn =
        (args['fail-on'] as List<String>?) ?? <String>[];
    if (failOn.isNotEmpty) {
      final bool failed = outcome.report.violations.any(
        (String v) => failOn.any((String rule) => v.contains(rule)),
      );
      if (failed) {
        return ExitCodes.thresholdViolated;
      }
    }
    return ExitCodes.success;
  }

  Future<int> _runRank(ArgResults args, Logger logger) async {
    final List<String> rankScanArgs = _syntheticScanArgs(
      configPath: args['config'] as String?,
      forcedOptions: <String>[
        '--format=json',
        '--out=.techdebt/tmp',
        '--max-files=2000'
      ],
    );
    final ArgResults synthetic = _buildParser().commands['scan']!.parse(
          rankScanArgs,
        );
    final _ScanOutcome outcome = await _scanInternal(
      synthetic,
      logger,
      writeFiles: false,
    );
    final int top = int.tryParse(args['top'] as String? ?? '20') ?? 20;
    final List<FileReportEntry> list =
        outcome.report.topHotspots.take(top).toList(growable: false);
    if ((args['format'] as String) == 'json') {
      stdout.writeln(
        const JsonEncoder.withIndent('  ').convert(
          list.map((FileReportEntry e) => e.toJson()).toList(growable: false),
        ),
      );
      return ExitCodes.success;
    }

    stdout.writeln('Top $top hotspots');
    stdout.writeln('-----  -----  -----   -----   ----');
    stdout.writeln('Debt   Risk   Churn   Cyclo   Path');
    stdout.writeln('-----  -----  -----   -----   ----');
    for (final FileReportEntry e in list) {
      stdout.writeln(
        '${e.scores.debt.toStringAsFixed(1).padLeft(5)} '
        '${e.scores.risk.toStringAsFixed(1).padLeft(6)} '
        '${(e.git?.churn ?? 0).toString().padLeft(7)} '
        '${e.metrics.cyclomaticMax.toString().padLeft(7)} '
        '${e.metrics.path}',
      );
    }
    return ExitCodes.success;
  }

  int _runDiff(ArgResults args, Logger logger) {
    final String? leftPath = args['left'] as String?;
    final String? rightPath = args['right'] as String?;
    if (leftPath == null || rightPath == null) {
      logger.error('diff requires --left and --right');
      return ExitCodes.usage;
    }
    final Map<String, Object?> left = _readJsonFile(leftPath);
    final Map<String, Object?> right = _readJsonFile(rightPath);

    final Map<String, Object?> delta =
        _reportDiffService.fromJsonMaps(left, right);
    final String format = args['format'] as String;
    if (format == 'json' || format == 'both') {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(delta));
    }
    if (format == 'md' || format == 'both') {
      stdout.writeln('# Diff Summary\n');
      stdout.writeln(
        '- Debt delta: ${(delta['debt_delta'] as num).toStringAsFixed(2)}',
      );
      stdout.writeln(
        '- Risk delta: ${(delta['risk_delta'] as num).toStringAsFixed(2)}',
      );
      stdout.writeln(
        '- Evolvability delta: ${(delta['evolvability_delta'] as num).toStringAsFixed(2)}',
      );
      stdout.writeln('\n## Top worsened files\n');
      stdout.writeln('| Path | Debt Delta |');
      stdout.writeln('|---|---:|');
      for (final dynamic item in delta['top_worsened'] as List<dynamic>) {
        final Map<dynamic, dynamic> row = item as Map<dynamic, dynamic>;
        stdout.writeln(
          '| `${row['path']}` | ${(row['debt_delta'] as num).toStringAsFixed(2)} |',
        );
      }
    }
    return ExitCodes.success;
  }

  Future<int> _runSnapshot(ArgResults args, Logger logger) async {
    final List<String> snapshotScanArgs = _syntheticScanArgs(
      configPath: args['config'] as String?,
      forcedOptions: <String>['--format=json'],
    );
    final ArgResults synthetic = _buildParser().commands['scan']!.parse(
          snapshotScanArgs,
        );
    final _ScanOutcome outcome = await _scanInternal(
      synthetic,
      logger,
      writeFiles: false,
    );
    final SnapshotService snapshots = SnapshotService(_fs, _runner);
    final String label = await snapshots.resolveLabel(
      '.',
      provided: args['label'] as String?,
    );
    final String path = snapshots.writeSnapshot(
      root: '.',
      reportJson: outcome.report.toJson(),
      label: label,
    );
    stdout.writeln(path);
    return ExitCodes.success;
  }

  int _runTrend(ArgResults args, Logger logger) {
    final int? window = int.tryParse(args['window'] as String? ?? '');
    final TrendService trends = TrendService(_fs);
    final List<Map<String, Object?>> snapshots = trends.loadSnapshots(
      '.',
      window: window,
    );
    final Map<String, Object?> trend = trends.buildTrend(snapshots);
    final String format = args['format'] as String;
    if (format == 'json' || format == 'both') {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(trend));
    }
    if (format == 'md' || format == 'both') {
      stdout.writeln(trends.toMarkdown(trend));
    }
    return ExitCodes.success;
  }

  int _runExplain(ArgResults args) {
    const Map<String, String> defs = <String, String>{
      'sloc': 'Source lines of code excluding blanks/comments (best effort).',
      'cyclomatic':
          '1 + decision points (`if`, loops, boolean branches) aggregated per file.',
      'nesting': 'Maximum nested branch depth per file.',
      'mi':
          'Maintainability Index = (171 - 5.2 ln(V) - 0.23 CC - 16.2 ln(SLOC)) * 100 / 171.',
      'halstead':
          'Halstead operators/operands vocabulary, length, volume, difficulty, effort.',
      'file_size': 'File size in bytes and lines.',
      'class_count': 'Number of class declarations per file.',
      'function_count': 'Number of functions/methods/constructors per file.',
      'params_count': 'Parameter count max/p95 distribution per file.',
    };

    final String? metric = args['metric'] as String?;
    if (metric != null && metric.isNotEmpty) {
      stdout.writeln(defs[metric] ?? 'Unknown metric: $metric');
      return ExitCodes.success;
    }

    stdout.writeln(
      'Scoring components: complexity, churn, size, maintainability, testgap.',
    );
    stdout.writeln('Normalization: robust_zscore (default) or minmax.');
    stdout.writeln(
      'Default weights: complexity=0.30 churn=0.30 size=0.15 maintainability=0.15 testgap=0.10.',
    );
    stdout.writeln('\nMetrics definitions:');
    defs.forEach(
        (String key, String value) => stdout.writeln('- $key: $value'));
    return ExitCodes.success;
  }

  Future<_ScanOutcome> _scanInternal(
    ArgResults args,
    Logger logger, {
    required bool writeFiles,
  }) async {
    final String root = '.';
    final ConfigService configService = ConfigService(_fs);
    final SherpaConfig fileConfig = configService.load(
      configPath: args['config'] as String?,
      root: root,
    );

    final _IncludeExclude includeExclude = _resolveIncludeExclude(
      args: args,
      config: fileConfig,
    );
    final List<String> files = _discoverFiles(
      root: root,
      includeExclude: includeExclude,
      maxFilesArg: args['max-files'] as String?,
    );
    logger.debug('Discovered ${files.length} Dart files.');

    final bool useCache = _useCache(args);
    final CacheService cache = _buildCacheService(args);

    final AnalyzerService analyzer = AnalyzerService(
      _fs,
      cache,
      toolVersion: toolVersion,
    );
    final List<FileMetrics> analyzed = await analyzer.analyzeFiles(
      root: root,
      relativePaths: files,
      resolve: args['resolve'] as bool? ?? true,
      useCache: useCache,
    );

    final _GitOutcome gitOutcome = await _collectGitSignals(
      args: args,
      config: fileConfig,
      cache: cache,
      root: root,
      useCache: useCache,
    );
    final Map<String, double> coverage = await _loadCoverage(
      root: root,
      config: fileConfig,
    );

    final ScoringResult scored = ScoringService().score(
      metrics: analyzed,
      git: gitOutcome.statsByFile,
      coverage: coverage,
      config: fileConfig,
    );

    final Map<String, Object?>? baselineDelta = _loadBaselineDelta(
      baselinePath: args['baseline'] as String?,
      global: scored.global,
      files: scored.files,
    );

    final List<String> violations = _collectViolations(scored.files);

    final SherpaReport report = SherpaReport(
      metadata: ReportMetadata(
        version: toolVersion,
        schemaVersion: schemaVersion,
        timestamp: DateTime.now().toUtc(),
        configHash: sha256OfString(fileConfig.stableJson()),
        gitHead: gitOutcome.head,
      ),
      config: fileConfig,
      global: scored.global,
      files: scored.files,
      topHotspots: scored.hotspots,
      directories: scored.directories,
      violations: violations,
      baselineDelta: baselineDelta,
    );

    if (writeFiles) {
      _writeReportFiles(
        report: report,
        outDir: args['out'] as String? ?? 'techdebt_reports',
        format: args['format'] as String? ?? 'both',
        baselineDelta: baselineDelta,
      );
    }

    return _ScanOutcome(report);
  }

  _IncludeExclude _resolveIncludeExclude({
    required ArgResults args,
    required SherpaConfig config,
  }) {
    return _IncludeExclude(
      include: <String>[
        ...config.include,
        ...(args['include'] as List<String>?) ?? <String>[],
      ],
      exclude: <String>[
        ...config.exclude,
        ...(args['exclude'] as List<String>?) ?? <String>[],
      ],
    );
  }

  List<String> _discoverFiles({
    required String root,
    required _IncludeExclude includeExclude,
    required String? maxFilesArg,
  }) {
    final int? maxFiles = int.tryParse(maxFilesArg ?? '');
    return DiscoveryService(_fs).discoverDartFiles(
      root: root,
      include: includeExclude.include,
      exclude: includeExclude.exclude,
      maxFiles: maxFiles,
    );
  }

  bool _useCache(ArgResults args) => args['cache'] as bool? ?? true;

  CacheService _buildCacheService(ArgResults args) {
    return CacheService(
      _fs,
      cacheDir: args['cache-dir'] as String? ?? '.techdebt/cache',
      toolVersion: toolVersion,
    );
  }

  Future<_GitOutcome> _collectGitSignals({
    required ArgResults args,
    required SherpaConfig config,
    required CacheService cache,
    required String root,
    required bool useCache,
  }) async {
    if (!(args['git'] as bool? ?? config.git.enabled)) {
      return const _GitOutcome(
        statsByFile: <String, GitFileStats>{},
        head: null,
      );
    }

    final String? commitRange = args['commit-range'] as String?;
    final DateTime? since = _resolveSince(
      sinceArg: args['since'] as String?,
      commitRange: commitRange,
      sinceDays: config.git.sinceDays,
    );
    final GitAnalysisResult gitResult =
        await GitService(_runner, cache).collect(
      repoRoot: root,
      window: GitWindow(
        since: since,
        until: parseDate(args['until'] as String?),
        commitRange: commitRange,
      ),
      useCache: useCache,
      includeOwnershipProxy: config.git.includeOwnershipProxy,
    );
    return _GitOutcome(
        statsByFile: gitResult.statsByFile, head: gitResult.head);
  }

  DateTime? _resolveSince({
    required String? sinceArg,
    required String? commitRange,
    required int sinceDays,
  }) {
    if ((commitRange ?? '').isNotEmpty) {
      return null;
    }
    return parseDate(sinceArg) ??
        DateTime.now().toUtc().subtract(Duration(days: sinceDays));
  }

  Future<Map<String, double>> _loadCoverage({
    required String root,
    required SherpaConfig config,
  }) async {
    if (!config.tests.enabled) {
      return <String, double>{};
    }
    return CoverageService(_fs).loadCoverage(
      root: root,
      lcovPath: config.tests.lcovPath,
    );
  }

  Map<String, Object?> _readJsonFile(String path) {
    final String raw;
    try {
      raw = _fs.readAsString(path);
    } on FileSystemException catch (e) {
      throw FormatException('Failed to read JSON file at $path: ${e.message}');
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw FormatException('Invalid JSON at $path: ${e.message}');
    }
    if (decoded is Map<String, dynamic>) {
      return decoded.cast<String, Object?>();
    }
    throw FormatException('JSON object expected in $path');
  }

  List<String> _syntheticScanArgs({
    required String? configPath,
    required List<String> forcedOptions,
  }) {
    final List<String> args = <String>[...forcedOptions];
    if (configPath != null && configPath.isNotEmpty) {
      args.add('--config=$configPath');
    }
    return args;
  }

  Map<String, Object?>? _loadBaselineDelta({
    required String? baselinePath,
    required GlobalScores global,
    required List<FileReportEntry> files,
  }) {
    if (baselinePath == null ||
        baselinePath.isEmpty ||
        !_fs.fileExists(baselinePath)) {
      return null;
    }
    final Map<String, Object?> baseline = _readJsonFile(baselinePath);
    return _reportDiffService.fromJsonMaps(baseline, <String, Object?>{
      'global_scores': global.toJson(),
      'files': files.map((FileReportEntry e) => e.toJson()).toList(),
    });
  }

  List<String> _collectViolations(List<FileReportEntry> files) {
    final List<String> violations = <String>[];
    for (final FileReportEntry entry in files) {
      for (final String violation in entry.thresholdViolations) {
        if (violation.contains('fail')) {
          violations.add('${entry.metrics.path}:$violation');
        }
      }
    }
    return violations;
  }

  void _writeReportFiles({
    required SherpaReport report,
    required String outDir,
    required String format,
    required Map<String, Object?>? baselineDelta,
  }) {
    _fs.createDir(outDir);
    final ReportService reports = ReportService();
    if (format == 'json' || format == 'both') {
      _fs.writeAsString(
        p.join(outDir, 'techdebt_report.json'),
        reports.renderJson(report),
      );
    }
    if (format == 'md' || format == 'both') {
      _fs.writeAsString(
        p.join(outDir, 'techdebt_report.md'),
        reports.renderMarkdown(report, baselineDelta: baselineDelta),
      );
    }
  }
}

class _ScanOutcome {
  const _ScanOutcome(this.report);

  final SherpaReport report;
}

class _IncludeExclude {
  const _IncludeExclude({required this.include, required this.exclude});

  final List<String> include;
  final List<String> exclude;
}

class _GitOutcome {
  const _GitOutcome({required this.statsByFile, required this.head});

  final Map<String, GitFileStats> statsByFile;
  final String? head;
}

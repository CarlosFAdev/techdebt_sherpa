import 'dart:math';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import '../adapters/file_system.dart';
import '../domain/models.dart';
import '../utils/math_utils.dart';
import 'cache_service.dart';

/// Collects static code metrics from Dart source files.
class AnalyzerService {
  /// Creates an analyzer service.
  AnalyzerService(this._fs, this._cache, {required this.toolVersion});

  final FileSystemAdapter _fs;
  final CacheService _cache;

  /// Tool version used for cache keying.
  final String toolVersion;

  /// Analyzes the provided Dart files and returns per-file metrics.
  Future<List<FileMetrics>> analyzeFiles({
    required String root,
    required List<String> relativePaths,
    required bool resolve,
    required bool useCache,
  }) async {
    final List<FileMetrics> output = <FileMetrics>[];

    AnalysisContextCollection? collection;
    if (resolve) {
      collection = AnalysisContextCollection(
        includedPaths: <String>[p.normalize(p.absolute(root))],
      );
    }

    for (final String relativePath in relativePaths) {
      final String abs = p.normalize(p.absolute(p.join(root, relativePath)));
      final DateTime mtime = _fs.modified(abs);
      if (useCache) {
        final Map<String, Object?>? cached = _cache.readMetrics(
          relativePath: relativePath,
          mtime: mtime,
        );
        if (cached != null) {
          output.add(_fromCache(cached));
          continue;
        }
      }

      final String content = _fs.readAsString(abs);
      final CompilationUnit unit;
      if (resolve && collection != null) {
        final dynamic resolved = await collection
            .contextFor(abs)
            .currentSession
            .getResolvedUnit(abs);
        if (resolved is ResolvedUnitResult) {
          unit = resolved.unit;
        } else {
          unit = parseString(
            content: content,
            path: abs,
            throwIfDiagnostics: false,
          ).unit;
        }
      } else {
        unit = parseString(
          content: content,
          path: abs,
          throwIfDiagnostics: false,
        ).unit;
      }

      final _ComplexityVisitor visitor = _ComplexityVisitor();
      unit.accept(visitor);

      final HalsteadMetrics halstead = _computeHalstead(unit.beginToken);
      final int sloc = _computeSloc(content);
      final int lineCount = '\n'.allMatches(content).length + 1;
      final int bytes = _fs.size(abs);

      final List<int> complexities = visitor.functionComplexities;
      final List<int> params = visitor.paramsPerFunction;
      final int cyclomaticSum = complexities.fold<int>(
        0,
        (int a, int b) => a + b,
      );
      final int cyclomaticMax =
          complexities.isEmpty ? 0 : complexities.reduce(max);
      final double cyclomaticP95 = percentile(complexities, 0.95);
      final int paramsMax = params.isEmpty ? 0 : params.reduce(max);
      final double paramsP95 = percentile(params, 0.95);

      final double mi = _computeMaintainabilityIndex(
        sloc: sloc,
        cyclomaticSum: cyclomaticSum,
        halsteadVolume: halstead.volume,
      );

      final FileMetrics metrics = FileMetrics(
        path: relativePath,
        sloc: sloc,
        fileSizeBytes: bytes,
        lineCount: lineCount,
        functionCount: visitor.functionCount,
        classCount: visitor.classCount,
        cyclomaticSum: cyclomaticSum,
        cyclomaticMax: cyclomaticMax,
        cyclomaticP95: cyclomaticP95,
        nestingMax: visitor.maxNesting,
        paramsMax: paramsMax,
        paramsP95: paramsP95,
        maintainabilityIndex: mi,
        halstead: halstead,
        feature: _inferFeature(relativePath),
        directory: p.dirname(relativePath),
      );

      if (useCache) {
        _cache.writeMetrics(
          relativePath: relativePath,
          mtime: mtime,
          payload: metrics.toJson(),
        );
      }
      output.add(metrics);
    }

    return output;
  }

  FileMetrics _fromCache(Map<String, Object?> json) {
    final Map<String, Object?> halsteadRaw =
        (json['halstead'] as Map<dynamic, dynamic>).cast<String, Object?>();
    return FileMetrics(
      path: json['path'] as String,
      sloc: (json['sloc'] as num).toInt(),
      fileSizeBytes: (json['file_size_bytes'] as num).toInt(),
      lineCount: (json['line_count'] as num).toInt(),
      functionCount: (json['function_count'] as num).toInt(),
      classCount: (json['class_count'] as num).toInt(),
      cyclomaticSum: (json['cyclomatic_sum'] as num).toInt(),
      cyclomaticMax: (json['cyclomatic_max'] as num).toInt(),
      cyclomaticP95: (json['cyclomatic_p95'] as num).toDouble(),
      nestingMax: (json['nesting_max'] as num).toInt(),
      paramsMax: (json['params_max'] as num).toInt(),
      paramsP95: (json['params_p95'] as num).toDouble(),
      maintainabilityIndex: (json['maintainability_index'] as num).toDouble(),
      halstead: HalsteadMetrics(
        distinctOperators: (halsteadRaw['distinct_operators'] as num).toInt(),
        distinctOperands: (halsteadRaw['distinct_operands'] as num).toInt(),
        totalOperators: (halsteadRaw['total_operators'] as num).toInt(),
        totalOperands: (halsteadRaw['total_operands'] as num).toInt(),
        vocabulary: (halsteadRaw['vocabulary'] as num).toInt(),
        length: (halsteadRaw['length'] as num).toInt(),
        volume: (halsteadRaw['volume'] as num).toDouble(),
        difficulty: (halsteadRaw['difficulty'] as num).toDouble(),
        effort: (halsteadRaw['effort'] as num).toDouble(),
      ),
      feature: json['feature'] as String?,
      directory: json['directory'] as String,
    );
  }

  int _computeSloc(String content) {
    bool inBlock = false;
    int count = 0;
    for (final String rawLine in content.split('\n')) {
      final _SlocLineResult result = _prepareSlocLine(
        rawLine: rawLine,
        inBlock: inBlock,
      );
      inBlock = result.inBlock;
      if (result.line == null) {
        continue;
      }
      final String? line = _removeInlineComment(result.line!);
      if (line == null) {
        continue;
      }
      count += 1;
    }
    return count;
  }

  _SlocLineResult _prepareSlocLine({
    required String rawLine,
    required bool inBlock,
  }) {
    final String line = rawLine.trim();
    if (line.isEmpty) {
      return _SlocLineResult(line: null, inBlock: inBlock);
    }
    final _SlocLineResult afterLeading = _stripLeadingBlock(
      line: line,
      inBlock: inBlock,
    );
    if (afterLeading.line == null) {
      return afterLeading;
    }
    if (afterLeading.line!.startsWith('//')) {
      return _SlocLineResult(line: null, inBlock: afterLeading.inBlock);
    }
    return _stripInlineBlock(
      line: afterLeading.line!,
      inBlock: afterLeading.inBlock,
    );
  }

  _SlocLineResult _stripLeadingBlock({
    required String line,
    required bool inBlock,
  }) {
    if (!inBlock) {
      return _SlocLineResult(line: line, inBlock: false);
    }
    final int close = line.indexOf('*/');
    if (close < 0) {
      return const _SlocLineResult(line: null, inBlock: true);
    }
    final String stripped = line.substring(close + 2).trim();
    if (stripped.isEmpty) {
      return const _SlocLineResult(line: null, inBlock: false);
    }
    return _SlocLineResult(line: stripped, inBlock: false);
  }

  _SlocLineResult _stripInlineBlock({
    required String line,
    required bool inBlock,
  }) {
    final int blockStart = line.indexOf('/*');
    if (blockStart < 0) {
      return _SlocLineResult(line: line, inBlock: inBlock);
    }
    final int blockEnd = line.indexOf('*/', blockStart + 2);
    if (blockEnd >= 0) {
      final String collapsed =
          '${line.substring(0, blockStart)} ${line.substring(blockEnd + 2)}'
              .trim();
      if (collapsed.isEmpty) {
        return _SlocLineResult(line: null, inBlock: inBlock);
      }
      return _SlocLineResult(line: collapsed, inBlock: inBlock);
    }
    final String prefix = line.substring(0, blockStart).trim();
    if (prefix.isEmpty) {
      return const _SlocLineResult(line: null, inBlock: true);
    }
    return _SlocLineResult(line: prefix, inBlock: true);
  }

  String? _removeInlineComment(String line) {
    final int inlineComment = line.indexOf('//');
    if (inlineComment == 0) {
      return null;
    }
    if (inlineComment < 0) {
      return line;
    }
    final String stripped = line.substring(0, inlineComment).trim();
    if (stripped.isEmpty) {
      return null;
    }
    return stripped;
  }

  HalsteadMetrics _computeHalstead(Token beginToken) {
    final Set<String> distinctOperators = <String>{};
    final Set<String> distinctOperands = <String>{};
    int totalOperators = 0;
    int totalOperands = 0;

    Token? token = beginToken;
    int guard = 0;
    while (token != null && guard < 1000000) {
      guard += 1;
      if (token.next == token || token.lexeme == 'EOF') {
        break;
      }
      final String lexeme = token.lexeme;
      if (token.isKeywordOrIdentifier) {
        distinctOperands.add(lexeme);
        totalOperands += 1;
      } else if (token.type.name.contains('LITERAL')) {
        distinctOperands.add(lexeme);
        totalOperands += 1;
      } else if (lexeme.isNotEmpty && lexeme.trim().isNotEmpty) {
        distinctOperators.add(lexeme);
        totalOperators += 1;
      }
      token = token.next;
    }

    final int vocabulary = distinctOperators.length + distinctOperands.length;
    final int length = totalOperators + totalOperands;
    final double volume = vocabulary == 0 ? 0 : length * safeLog2(vocabulary);
    final double difficulty = distinctOperands.isEmpty
        ? 0
        : (distinctOperators.length / 2) *
            (totalOperands / distinctOperands.length);
    final double effort = difficulty * volume;

    return HalsteadMetrics(
      distinctOperators: distinctOperators.length,
      distinctOperands: distinctOperands.length,
      totalOperators: totalOperators,
      totalOperands: totalOperands,
      vocabulary: vocabulary,
      length: length,
      volume: volume,
      difficulty: difficulty,
      effort: effort,
    );
  }

  double _computeMaintainabilityIndex({
    required int sloc,
    required int cyclomaticSum,
    required double halsteadVolume,
  }) {
    final double effectiveVolume =
        halsteadVolume > 0 ? halsteadVolume : max(sloc.toDouble(), 1);
    final double effectiveSloc = max(sloc.toDouble(), 1);
    final double raw = 171 -
        5.2 * log(effectiveVolume) -
        0.23 * cyclomaticSum -
        16.2 * log(effectiveSloc);
    return clamp100((raw * 100) / 171);
  }

  String? _inferFeature(String relativePath) {
    final List<String> parts = p.split(relativePath);
    final int idx = parts.indexOf('features');
    if (idx >= 0 && idx + 1 < parts.length) {
      return parts[idx + 1];
    }
    return null;
  }
}

class _ComplexityVisitor extends RecursiveAstVisitor<void> {
  int classCount = 0;
  int functionCount = 0;
  int maxNesting = 0;
  int _currentNesting = 0;
  final List<int> functionComplexities = <int>[];
  final List<int> paramsPerFunction = <int>[];
  final List<int> _complexityStack = <int>[];

  void _enterBranch() {
    if (_complexityStack.isNotEmpty) {
      _complexityStack[_complexityStack.length - 1] += 1;
    }
  }

  void _enterNesting() {
    _currentNesting += 1;
    if (_currentNesting > maxNesting) {
      maxNesting = _currentNesting;
    }
  }

  void _leaveNesting() {
    _currentNesting = max(0, _currentNesting - 1);
  }

  void _handleFunction(FormalParameterList? params, void Function() visitBody) {
    functionCount += 1;
    _complexityStack.add(1);
    paramsPerFunction.add(params?.parameters.length ?? 0);
    visitBody();
    functionComplexities.add(_complexityStack.removeLast());
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    classCount += 1;
    super.visitClassDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _handleFunction(
      node.functionExpression.parameters,
      () => super.visitFunctionDeclaration(node),
    );
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _handleFunction(node.parameters, () => super.visitMethodDeclaration(node));
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _handleFunction(
      node.parameters,
      () => super.visitConstructorDeclaration(node),
    );
  }

  @override
  void visitIfStatement(IfStatement node) {
    _enterBranch();
    _enterNesting();
    super.visitIfStatement(node);
    _leaveNesting();
  }

  @override
  void visitForStatement(ForStatement node) {
    _enterBranch();
    _enterNesting();
    super.visitForStatement(node);
    _leaveNesting();
  }

  @override
  void visitForEachPartsWithDeclaration(ForEachPartsWithDeclaration node) {
    _enterBranch();
    super.visitForEachPartsWithDeclaration(node);
  }

  @override
  void visitForEachPartsWithIdentifier(ForEachPartsWithIdentifier node) {
    _enterBranch();
    super.visitForEachPartsWithIdentifier(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    _enterBranch();
    _enterNesting();
    super.visitWhileStatement(node);
    _leaveNesting();
  }

  @override
  void visitDoStatement(DoStatement node) {
    _enterBranch();
    _enterNesting();
    super.visitDoStatement(node);
    _leaveNesting();
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    _enterBranch();
    super.visitConditionalExpression(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final String op = node.operator.lexeme;
    if (op == '&&' || op == '||' || op == '??') {
      _enterBranch();
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitSwitchCase(SwitchCase node) {
    _enterBranch();
    _enterNesting();
    super.visitSwitchCase(node);
    _leaveNesting();
  }

  @override
  void visitCatchClause(CatchClause node) {
    _enterBranch();
    _enterNesting();
    super.visitCatchClause(node);
    _leaveNesting();
  }
}

class _SlocLineResult {
  const _SlocLineResult({required this.line, required this.inBlock});

  final String? line;
  final bool inBlock;
}

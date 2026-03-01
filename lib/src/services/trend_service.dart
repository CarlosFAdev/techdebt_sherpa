import 'dart:convert';

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import '../adapters/file_system.dart';
import 'report_diff_service.dart';

/// Builds trend output from stored snapshots.
class TrendService {
  /// Creates a [TrendService].
  TrendService(this._fs, {ReportDiffService? diffService})
      : _diffService = diffService ?? ReportDiffService();

  final FileSystemAdapter _fs;
  final ReportDiffService _diffService;

  /// Loads snapshot files and returns compact report data.
  List<Map<String, Object?>> loadSnapshots(String root, {int? window}) {
    final String dir = p.join(root, '.techdebt', 'snapshots');
    if (!_fs.directoryExists(dir)) {
      return <Map<String, Object?>>[];
    }
    final List<FileSystemEntity> files = _fs
        .listDir(dir)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.json'))
        .toList()
      ..sort((File a, File b) => a.path.compareTo(b.path));

    List<FileSystemEntity> selected = files;
    if (window != null && window > 0 && files.length > window) {
      selected = files.sublist(files.length - window);
    }

    final List<Map<String, Object?>> parsed = <Map<String, Object?>>[];
    for (final FileSystemEntity file in selected) {
      final dynamic json = jsonDecode(_fs.readAsString(file.path));
      if (json is Map<String, dynamic>) {
        final Map<String, Object?> report = json.cast<String, Object?>();
        final Map<dynamic, dynamic> metadata =
            report['metadata'] as Map<dynamic, dynamic>? ??
                const <dynamic, dynamic>{};
        final Map<dynamic, dynamic> global =
            report['global_scores'] as Map<dynamic, dynamic>? ??
                const <dynamic, dynamic>{};
        parsed.add(<String, Object?>{
          'metadata': <String, Object?>{
            'timestamp': metadata['timestamp'],
          },
          'global_scores': <String, Object?>{
            'debt': global['debt'],
            'risk': global['risk'],
            'evolvability': global['evolvability'],
          },
          'files': _compactFiles(report['files'] as List<dynamic>?),
        });
      }
    }
    return parsed;
  }

  List<Map<String, Object?>> _compactFiles(List<dynamic>? files) {
    if (files == null || files.isEmpty) {
      return <Map<String, Object?>>[];
    }
    final List<Map<String, Object?>> compact = <Map<String, Object?>>[];
    for (final dynamic file in files) {
      if (file is! Map<dynamic, dynamic>) {
        continue;
      }
      final Map<dynamic, dynamic> metrics =
          file['metrics'] as Map<dynamic, dynamic>? ??
              const <dynamic, dynamic>{};
      final Map<dynamic, dynamic> scores =
          file['scores'] as Map<dynamic, dynamic>? ??
              const <dynamic, dynamic>{};
      final String? path = metrics['path'] as String?;
      final num? debt = scores['debt'] as num?;
      if (path == null || debt == null) {
        continue;
      }
      compact.add(<String, Object?>{
        'metrics': <String, Object?>{'path': path},
        'scores': <String, Object?>{'debt': debt.toDouble()},
      });
    }
    return compact;
  }

  /// Builds trend series and worsening hotspots from snapshots.
  Map<String, Object?> buildTrend(List<Map<String, Object?>> snapshots) {
    final List<Map<String, Object?>> series = <Map<String, Object?>>[];
    final Map<String, double> worsening = <String, double>{};

    for (final Map<String, Object?> snapshot in snapshots) {
      final Map<String, dynamic> meta =
          (snapshot['metadata'] as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      final Map<String, dynamic> global =
          (snapshot['global_scores'] as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      series.add(<String, Object?>{
        'timestamp': meta['timestamp'],
        'debt': global['debt'],
        'risk': global['risk'],
        'evolvability': global['evolvability'],
      });
    }

    if (snapshots.length >= 2) {
      final Map<String, dynamic> left = snapshots[snapshots.length - 2];
      final Map<String, dynamic> right = snapshots[snapshots.length - 1];
      final Map<String, Object?> diff = _diffService.fromJsonMaps(
        left.cast<String, Object?>(),
        right.cast<String, Object?>(),
      );
      for (final dynamic item in diff['top_worsened'] as List<dynamic>) {
        final Map<dynamic, dynamic> entry = item as Map<dynamic, dynamic>;
        final String? path = entry['path'] as String?;
        final num? delta = entry['debt_delta'] as num?;
        if (path != null && delta != null) {
          worsening[path] = delta.toDouble();
        }
      }
    }

    final List<MapEntry<String, double>> topWorsening =
        worsening.entries.toList()
          ..sort(
            (MapEntry<String, double> a, MapEntry<String, double> b) =>
                b.value.compareTo(a.value),
          );

    return <String, Object?>{
      'series': series,
      'top_worsening_hotspots': topWorsening
          .take(20)
          .map(
            (MapEntry<String, double> e) => <String, Object?>{
              'path': e.key,
              'debt_delta': e.value,
            },
          )
          .toList(growable: false),
    };
  }

  /// Renders trend output as Markdown.
  String toMarkdown(Map<String, Object?> trend) {
    final StringBuffer b = StringBuffer();
    b.writeln('# Trend');
    b.writeln();
    b.writeln('## Global Time Series');
    b.writeln();
    b.writeln('| Timestamp | Debt | Risk | Evolvability |');
    b.writeln('|---|---:|---:|---:|');
    for (final dynamic point in trend['series'] as List<dynamic>) {
      final Map<dynamic, dynamic> p = point as Map<dynamic, dynamic>;
      b.writeln(
        '| ${p['timestamp']} | ${(p['debt'] as num).toStringAsFixed(2)} | ${(p['risk'] as num).toStringAsFixed(2)} | ${(p['evolvability'] as num).toStringAsFixed(2)} |',
      );
    }
    b.writeln();
    b.writeln('## Top Worsening Hotspots');
    b.writeln();
    b.writeln('| Path | Debt Delta |');
    b.writeln('|---|---:|');
    for (final dynamic item
        in trend['top_worsening_hotspots'] as List<dynamic>) {
      final Map<dynamic, dynamic> m = item as Map<dynamic, dynamic>;
      b.writeln(
        '| `${m['path']}` | ${(m['debt_delta'] as num).toStringAsFixed(2)} |',
      );
    }
    return b.toString();
  }
}

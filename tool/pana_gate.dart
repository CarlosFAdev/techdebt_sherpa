import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/pana_gate.dart <pana_report.json>');
    exit(2);
  }

  final File file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('Pana report not found: ${args.first}');
    exit(2);
  }

  final dynamic decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('Invalid pana report format.');
    exit(2);
  }

  final Map<String, dynamic> report = decoded;
  final Map<String, dynamic> scores =
      report['scores'] as Map<String, dynamic>? ?? <String, dynamic>{};
  final int granted = (scores['grantedPoints'] as num?)?.toInt() ?? -1;
  final int max = (scores['maxPoints'] as num?)?.toInt() ?? -1;

  stdout.writeln('pana points: $granted/$max');
  if (granted != max) {
    stderr.writeln('Pana gate failed: expected full score.');
    exit(1);
  }
}

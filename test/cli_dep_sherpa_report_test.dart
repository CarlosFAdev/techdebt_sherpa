import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:techdebt_sherpa/src/cli/cli_app.dart';
import 'package:techdebt_sherpa/src/cli/exit_codes.dart';
import 'package:techdebt_sherpa/src/version.dart';
import 'package:test/test.dart';

void main() {
  group('scan --dep-sherpa-report', () {
    test('existing command behavior is unchanged when absent', () async {
      final Directory outDir = await Directory.systemTemp.createTemp(
        'techdebt_sherpa_no_dep_',
      );

      final int exitCode = await CliApp().run(<String>[
        'scan',
        '--format=json',
        '--out=${outDir.path}',
        '--max-files=1',
        '--no-git',
        '--no-resolve',
        '--no-cache',
        '--quiet',
      ]);

      expect(exitCode, ExitCodes.success);
      final json = _readReport(outDir);
      final metadata = json['metadata'] as Map<String, dynamic>;
      expect(metadata['tool_version'], techdebtSherpaVersion);
      expect(metadata['tool_version'], isNot('0.1.0'));
      expect(json['debt_findings'], isEmpty);
    });

    test('valid dep_sherpa report adds platform_migration_debt findings',
        () async {
      final Directory outDir = await Directory.systemTemp.createTemp(
        'techdebt_sherpa_dep_',
      );

      final int exitCode = await CliApp().run(<String>[
        'scan',
        '--format=json',
        '--out=${outDir.path}',
        '--max-files=1',
        '--no-git',
        '--no-resolve',
        '--no-cache',
        '--quiet',
        '--dep-sherpa-report=${_fixture('dep_sherpa_report_darwin_blocked')}',
      ]);

      expect(exitCode, ExitCodes.success);
      final json = _readReport(outDir);
      final findings = json['debt_findings'] as List<dynamic>;
      expect(
        findings,
        contains(
          isA<Map<dynamic, dynamic>>()
              .having(
                (Map<dynamic, dynamic> f) => f['category'],
                'category',
                'platform_migration_debt',
              )
              .having(
                (Map<dynamic, dynamic> f) => f['severity'],
                'severity',
                'high',
              ),
        ),
      );
    });

    test('missing dep_sherpa report produces input error', () async {
      final Directory outDir = await Directory.systemTemp.createTemp(
        'techdebt_sherpa_missing_dep_',
      );

      final int exitCode = await CliApp().run(<String>[
        'scan',
        '--format=json',
        '--out=${outDir.path}',
        '--max-files=1',
        '--no-git',
        '--no-resolve',
        '--no-cache',
        '--quiet',
        '--dep-sherpa-report=${p.join(outDir.path, 'missing.json')}',
      ]);

      expect(exitCode, ExitCodes.usage);
    });

    test('malformed dep_sherpa report produces input error', () async {
      final Directory outDir = await Directory.systemTemp.createTemp(
        'techdebt_sherpa_bad_dep_',
      );
      final File bad = File(p.join(outDir.path, 'bad.json'));
      bad.writeAsStringSync('{bad');

      final int exitCode = await CliApp().run(<String>[
        'scan',
        '--format=json',
        '--out=${outDir.path}',
        '--max-files=1',
        '--no-git',
        '--no-resolve',
        '--no-cache',
        '--quiet',
        '--dep-sherpa-report=${bad.path}',
      ]);

      expect(exitCode, ExitCodes.usage);
    });
  });
}

String _fixture(String name) =>
    p.join('test', 'fixtures', 'dep_sherpa', '$name.json');

Map<String, Object?> _readReport(Directory outDir) {
  final File report = File(p.join(outDir.path, 'techdebt_sherpa.json'));
  return (jsonDecode(report.readAsStringSync()) as Map<String, dynamic>)
      .cast<String, Object?>();
}

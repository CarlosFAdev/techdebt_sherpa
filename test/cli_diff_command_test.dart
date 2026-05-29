import 'dart:convert';
import 'dart:io';

import 'package:techdebt_sherpa/src/cli/cli_app.dart';
import 'package:techdebt_sherpa/src/cli/exit_codes.dart';
import 'package:test/test.dart';

void main() {
  group('diff command', () {
    test('supports explicit left and right paths with json format', () async {
      final Directory temp =
          await Directory.systemTemp.createTemp('techdebt_sherpa_diff_');
      addTearDown(() => temp.delete(recursive: true));
      final File left = await _writeDiffReport(temp, 'old.json', debt: 10);
      final File right = await _writeDiffReport(temp, 'new.json', debt: 15);

      final int code = await CliApp().run(<String>[
        'diff',
        '--left',
        left.path,
        '--right',
        right.path,
        '--format',
        'json',
      ]);

      expect(code, ExitCodes.success);
    });

    test('supports positional left and right paths with json format', () async {
      final Directory temp =
          await Directory.systemTemp.createTemp('techdebt_sherpa_diff_');
      addTearDown(() => temp.delete(recursive: true));
      final File left = await _writeDiffReport(temp, 'old.json', debt: 10);
      final File right = await _writeDiffReport(temp, 'new.json', debt: 15);

      final int code = await CliApp().run(<String>[
        'diff',
        left.path,
        right.path,
        '--format',
        'json',
      ]);

      expect(code, ExitCodes.success);
    });

    test('rejects positional paths mixed with explicit flags', () async {
      final int code = await CliApp().run(<String>[
        'diff',
        'old.json',
        'new.json',
        '--left',
        'explicit-old.json',
      ]);

      expect(code, ExitCodes.usage);
    });

    test('reports usage when a path is missing', () async {
      final int code = await CliApp().run(<String>['diff', 'old.json']);

      expect(code, ExitCodes.usage);
    });

    test('reports usage for too many positional paths', () async {
      final int code = await CliApp().run(<String>[
        'diff',
        'old.json',
        'new.json',
        'extra.json',
      ]);

      expect(code, ExitCodes.usage);
    });
  });
}

Future<File> _writeDiffReport(
  Directory directory,
  String name, {
  required double debt,
}) async {
  final File file = File('${directory.path}/$name');
  await file.writeAsString(
    jsonEncode(<String, Object?>{
      'global_scores': <String, Object?>{
        'debt': debt,
        'risk': 20,
        'evolvability': 80,
      },
      'files': <Object?>[
        <String, Object?>{
          'metrics': <String, Object?>{'path': 'lib/a.dart'},
          'scores': <String, Object?>{'debt': debt},
        },
      ],
    }),
  );
  return file;
}

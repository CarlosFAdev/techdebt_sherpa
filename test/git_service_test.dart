import 'dart:io';

import 'package:file/memory.dart';
import 'package:techdebt_sherpa/src/adapters/file_system.dart';
import 'package:techdebt_sherpa/src/adapters/process_runner.dart';
import 'package:techdebt_sherpa/src/services/cache_service.dart';
import 'package:techdebt_sherpa/src/services/git_service.dart';
import 'package:test/test.dart';

class FakeProcessRunner implements ProcessRunner {
  FakeProcessRunner({this.logOutput});

  final String? logOutput;

  @override
  Future<ProcessResultData> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration? timeout,
  }) async {
    final String cmd = '$executable ${arguments.join(' ')}';
    if (cmd.startsWith('git --version')) {
      return ProcessResultData(
          exitCode: 0, stdout: 'git version 2.0', stderr: '');
    }
    if (cmd.contains('rev-parse --is-inside-work-tree')) {
      return ProcessResultData(exitCode: 0, stdout: 'true\n', stderr: '');
    }
    if (cmd.contains('rev-parse --short HEAD')) {
      return ProcessResultData(exitCode: 0, stdout: 'abc123\n', stderr: '');
    }
    if (cmd.contains('log --numstat')) {
      return ProcessResultData(
        exitCode: 0,
        stdout: logOutput ??
            '''@@@abc123|1700000000|Alice
10	2	lib/a.dart
1	0	lib/b.dart
@@@def456|1701000000|Bob
5	4	lib/a.dart
''',
        stderr: '',
      );
    }
    return ProcessResultData(
        exitCode: 1, stdout: '', stderr: 'unsupported: $cmd');
  }
}

void main() {
  test('parses numstat output into per-file stats', () async {
    final LocalFileSystemAdapter fs =
        LocalFileSystemAdapter(fs: MemoryFileSystem.test());
    final CacheService cache =
        CacheService(fs, cacheDir: '.cache', toolVersion: '0.1.0');
    final GitService service = GitService(FakeProcessRunner(), cache);

    final result = await service.collect(
      repoRoot: Directory.current.path,
      window: const GitWindow(),
      useCache: false,
      includeOwnershipProxy: true,
    );

    expect(result.available, isTrue);
    expect(result.statsByFile['lib/a.dart']!.commitCount, 2);
    expect(result.statsByFile['lib/a.dart']!.linesAdded, 15);
    expect(result.statsByFile['lib/a.dart']!.linesDeleted, 6);
    expect(result.statsByFile['lib/a.dart']!.distinctAuthors, 2);
  });

  test('handles malformed lines and tabbed paths', () async {
    final LocalFileSystemAdapter fs =
        LocalFileSystemAdapter(fs: MemoryFileSystem.test());
    final CacheService cache =
        CacheService(fs, cacheDir: '.cache', toolVersion: '0.1.0');
    final GitService service = GitService(
      FakeProcessRunner(
        logOutput: '''@@@abc123|1700000000|Alice
-	-	binary.dat
3	1	lib/weird	name.dart
malformed-line
''',
      ),
      cache,
    );

    final result = await service.collect(
      repoRoot: Directory.current.path,
      window: const GitWindow(),
      useCache: false,
      includeOwnershipProxy: false,
    );

    expect(result.available, isTrue);
    expect(result.statsByFile['binary.dat']!.churn, 0);
    expect(result.statsByFile['lib/weird\tname.dart']!.linesAdded, 3);
    expect(result.statsByFile['lib/weird\tname.dart']!.linesDeleted, 1);
  });
}

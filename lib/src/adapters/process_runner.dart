import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Result envelope for process execution.
class ProcessResultData {
  /// Creates a [ProcessResultData].
  ProcessResultData({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

/// Abstraction for running child processes.
abstract class ProcessRunner {
  /// Runs a process and returns structured output.
  Future<ProcessResultData> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration? timeout,
  });
}

/// Default system implementation of [ProcessRunner].
class SystemProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResultData> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration? timeout,
  }) async {
    final String command = '$executable ${arguments.join(' ')}';
    final Process process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: false,
    );
    final Future<String> stdoutFuture =
        process.stdout.transform(utf8.decoder).join();
    final Future<String> stderrFuture =
        process.stderr.transform(utf8.decoder).join();

    final int exitCode;
    if (timeout == null) {
      exitCode = await process.exitCode;
    } else {
      try {
        exitCode = await process.exitCode.timeout(timeout);
      } on TimeoutException {
        process.kill();
        await process.exitCode;
        throw TimeoutException('Command timed out: $command', timeout);
      }
    }

    final List<String> outputs = await Future.wait(<Future<String>>[
      stdoutFuture,
      stderrFuture,
    ]);
    return ProcessResultData(
      exitCode: exitCode,
      stdout: outputs[0],
      stderr: outputs[1],
    );
  }
}

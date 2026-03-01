/// Process exit codes used by the CLI commands.
class ExitCodes {
  /// Success with no threshold failures.
  static const int success = 0;

  /// Invalid usage or arguments.
  static const int usage = 1;

  /// Analysis execution failed.
  static const int analysisFailed = 2;

  /// Analysis succeeded but configured failure thresholds were violated.
  static const int thresholdViolated = 3;
}

class Logger {
  Logger({this.verbose = false, this.quiet = false});

  final bool verbose;
  final bool quiet;

  void info(String message) {
    if (!quiet) {
      // ignore: avoid_print
      print(message);
    }
  }

  void debug(String message) {
    if (verbose && !quiet) {
      // ignore: avoid_print
      print('[debug] $message');
    }
  }

  void warn(String message) {
    if (!quiet) {
      // ignore: avoid_print
      print('[warn] $message');
    }
  }

  void error(String message) {
    // ignore: avoid_print
    print('[error] $message');
  }
}

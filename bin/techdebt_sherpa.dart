import 'dart:io';

import 'package:techdebt_sherpa/src/cli/cli_app.dart';

Future<void> main(List<String> args) async {
  final int code = await CliApp().run(args);
  exit(code);
}

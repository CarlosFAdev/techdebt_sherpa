import 'dart:convert';

import 'package:techdebt_sherpa/techdebt_sherpa.dart';

/// Minimal runnable example for using the package API.
void main() {
  final SherpaConfig defaults = SherpaConfig.defaults();
  final String json =
      const JsonEncoder.withIndent('  ').convert(defaults.toJson());
  // ignore: avoid_print
  print(json);
}

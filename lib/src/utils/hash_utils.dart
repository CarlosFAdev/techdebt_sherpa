import 'dart:convert';

import 'package:crypto/crypto.dart';

String sha256OfString(String input) =>
    sha256.convert(utf8.encode(input)).toString();

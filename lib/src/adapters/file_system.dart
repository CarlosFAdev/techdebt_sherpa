import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/local.dart';

/// Abstraction over filesystem access for testability.
abstract class FileSystemAdapter {
  Directory directory(String path);
  File file(String path);
  bool fileExists(String path);
  bool directoryExists(String path);
  String readAsString(String path);
  Stream<List<int>> openRead(String path);
  void writeAsString(String path, String contents);
  void deleteFile(String path);
  void createDir(String path, {bool recursive = true});
  List<FileSystemEntity> listDir(String path, {bool recursive = false});
  DateTime modified(String path);
  int size(String path);
}

/// Local disk implementation of [FileSystemAdapter].
class LocalFileSystemAdapter implements FileSystemAdapter {
  /// Creates a local filesystem adapter.
  LocalFileSystemAdapter({FileSystem? fs})
      : _fs = fs ?? const LocalFileSystem();

  final FileSystem _fs;

  @override
  Directory directory(String path) => _fs.directory(path);

  @override
  File file(String path) => _fs.file(path);

  @override
  bool fileExists(String path) => _fs.file(path).existsSync();

  @override
  bool directoryExists(String path) => _fs.directory(path).existsSync();

  @override
  String readAsString(String path) => _fs.file(path).readAsStringSync();

  @override
  Stream<List<int>> openRead(String path) => _fs.file(path).openRead();

  @override
  void writeAsString(String path, String contents) {
    final File file = _fs.file(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  @override
  void deleteFile(String path) {
    final File file = _fs.file(path);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  @override
  void createDir(String path, {bool recursive = true}) {
    _fs.directory(path).createSync(recursive: recursive);
  }

  @override
  List<FileSystemEntity> listDir(String path, {bool recursive = false}) =>
      _fs.directory(path).listSync(recursive: recursive, followLinks: false);

  @override
  DateTime modified(String path) => _fs.file(path).lastModifiedSync();

  @override
  int size(String path) => _fs.file(path).lengthSync();
}

/// Encodes an object as pretty JSON.
String encodeJson(Object? input) =>
    const JsonEncoder.withIndent('  ').convert(input);

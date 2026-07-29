import 'dart:io';

abstract interface class ProjectFileIo {
  Future<bool> exists(String path);
  Future<String> read(String path);
  Future<void> writeAndFlush(String path, String content);
  Future<void> copy(String from, String to);
  Future<void> rename(String from, String to);
  Future<void> delete(String path);
}

final class DartProjectFileIo implements ProjectFileIo {
  const DartProjectFileIo();

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<String> read(String path) => File(path).readAsString();

  @override
  Future<void> writeAndFlush(String path, String content) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);
  }

  @override
  Future<void> copy(String from, String to) async {
    await File(from).copy(to);
  }

  @override
  Future<void> rename(String from, String to) async {
    await File(from).rename(to);
  }

  @override
  Future<void> delete(String path) => File(path).delete();
}

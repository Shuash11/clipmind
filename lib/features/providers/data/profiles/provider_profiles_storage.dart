import 'dart:io';

/// Narrow text storage seam for profile metadata. Values passed through this
/// seam are JSON metadata only, never secure-storage values.
abstract interface class ProviderProfilesStorage {
  Future<String?> read();
  Future<void> write(String contents);
}

final class FileProviderProfilesStorage implements ProviderProfilesStorage {
  FileProviderProfilesStorage(this._file);

  final File _file;

  @override
  Future<String?> read() async {
    if (!await _file.exists()) return null;
    return _file.readAsString();
  }

  @override
  Future<void> write(String contents) =>
      _file.writeAsString(contents, flush: true);
}

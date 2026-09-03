import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Stores only non-secret registration data on the device.
class CadastroDraftStore {
  CadastroDraftStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'diavicon.registration_draft.v1';
  final FlutterSecureStorage _storage;

  Future<Map<String, dynamic>> load() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      await _storage.delete(key: _storageKey);
    }
    return <String, dynamic>{};
  }

  Future<void> save(Map<String, dynamic> draft) async {
    final previous = await load();
    final previousImagePaths = <String>{};
    _collectImagePaths(previous, previousImagePaths);
    final sanitized = await _sanitizeMap(draft);
    await _storage.write(key: _storageKey, value: jsonEncode(sanitized));

    final nextImagePaths = <String>{};
    _collectImagePaths(sanitized, nextImagePaths);
    for (final path in previousImagePaths.difference(nextImagePaths)) {
      await _deletePrivateImage(path);
    }
  }

  Future<void> clear() async {
    final draft = await load();
    final imagePaths = <String>{};
    _collectImagePaths(draft, imagePaths);
    for (final path in imagePaths) {
      await _deletePrivateImage(path);
    }
    await _storage.delete(key: _storageKey);
  }

  Future<Map<String, dynamic>> _sanitizeMap(Map<String, dynamic> input) async {
    final result = <String, dynamic>{};
    for (final entry in input.entries) {
      final key = entry.key;
      if (key == 'senha' || key == 'password') continue;
      final value = await _sanitizeValue(key, entry.value);
      if (value != null) result[key] = value;
    }
    return result;
  }

  Future<dynamic> _sanitizeValue(String key, dynamic value) async {
    if (key == 'fotoPath' || key == 'fotoPerfilPath') {
      if (value is! String || value.trim().isEmpty) return null;
      return _copyImageToPrivateDirectory(value);
    }
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Map) {
      return _sanitizeMap(Map<String, dynamic>.from(value));
    }
    if (value is List) {
      final result = <dynamic>[];
      for (final item in value) {
        final sanitized = await _sanitizeValue('', item);
        if (sanitized != null) result.add(sanitized);
      }
      return result;
    }
    return value.toString();
  }

  Future<String?> _copyImageToPrivateDirectory(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    final directory = await _privateImageDirectory();
    if (_isInsideDirectory(source.path, directory.path)) return source.path;
    await directory.create(recursive: true);
    final extension = source.path.contains('.')
        ? source.path.substring(source.path.lastIndexOf('.'))
        : '.image';
    final destination = File(
      '${directory.path}${Platform.pathSeparator}${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await source.copy(destination.path);
    return destination.path;
  }

  Future<Directory> _privateImageDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(
      '${support.path}${Platform.pathSeparator}registration_drafts',
    );
  }

  bool _isInsideDirectory(String filePath, String directoryPath) {
    final file = File(filePath).absolute.path.replaceAll('\\', '/').toLowerCase();
    final directory =
        Directory(directoryPath).absolute.path.replaceAll('\\', '/').toLowerCase();
    return file.startsWith('$directory/');
  }

  Future<void> _deletePrivateImage(String path) async {
    try {
      final directory = await _privateImageDirectory();
      if (!_isInsideDirectory(path, directory.path)) return;
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // A missing temporary image does not invalidate the rest of the draft.
    }
  }

  void _collectImagePaths(dynamic value, Set<String> result) {
    if (value is Map) {
      for (final entry in value.entries) {
        if ((entry.key == 'fotoPath' || entry.key == 'fotoPerfilPath') &&
            entry.value is String) {
          result.add(entry.value as String);
        }
        _collectImagePaths(entry.value, result);
      }
    } else if (value is List) {
      for (final item in value) {
        _collectImagePaths(item, result);
      }
    }
  }
}

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

typedef RandomBytes = List<int> Function(int length);

abstract interface class MasterKeyProvider {
  Future<SecretKey?> loadExisting();

  Future<SecretKey> create();

  Future<void> reset();
}

class MasterKeyUnavailableException implements Exception {
  const MasterKeyUnavailableException();
}

class MasterKeyMissingException implements Exception {
  const MasterKeyMissingException();
}

class LocalMasterKeyStore implements MasterKeyProvider {
  LocalMasterKeyStore(this._keyFile, {RandomBytes? randomBytes})
    : _randomBytes = randomBytes ?? _generateSecureRandomBytes;

  static const keyLength = 32;

  final File _keyFile;
  final RandomBytes _randomBytes;
  SecretKey? _cachedKey;

  File get _pendingFile => File('${_keyFile.path}.pending');
  File get _lockFile => File('${_keyFile.path}.lock');

  @override
  Future<SecretKey?> loadExisting() async {
    final cached = _cachedKey;
    if (cached != null) return cached;
    return _withLock(() async {
      if (await _keyFile.exists()) return _cache(await _read(_keyFile));
      if (!await _pendingFile.exists()) return null;

      final recovered = await _read(_pendingFile);
      await _restrictFilePermissions(_pendingFile);
      await _pendingFile.rename(_keyFile.path);
      return _cache(recovered);
    });
  }

  @override
  Future<SecretKey> create() async {
    final cached = _cachedKey;
    if (cached != null) return cached;
    return _withLock(() async {
      if (await _keyFile.exists()) return _cache(await _read(_keyFile));
      if (await _pendingFile.exists()) {
        final recovered = await _read(_pendingFile);
        await _restrictFilePermissions(_pendingFile);
        await _pendingFile.rename(_keyFile.path);
        return _cache(recovered);
      }

      final bytes = Uint8List.fromList(_randomBytes(keyLength));
      if (bytes.length != keyLength) {
        throw const MasterKeyUnavailableException();
      }

      await _pendingFile.create(exclusive: true);
      await _restrictFilePermissions(_pendingFile);
      await _pendingFile.writeAsBytes(bytes, flush: true);
      await _pendingFile.rename(_keyFile.path);
      return _cache(bytes);
    });
  }

  @override
  Future<void> reset() async {
    await _withLock(() async {
      if (await _keyFile.exists()) await _keyFile.delete();
      if (await _pendingFile.exists()) await _pendingFile.delete();
      _cachedKey = null;
    });
  }

  Future<T> _withLock<T>(Future<T> Function() action) async {
    try {
      await _keyFile.parent.create(recursive: true);
      await _restrictDirectoryPermissions(_keyFile.parent);
      final lock = await _lockFile.open(mode: FileMode.append);
      try {
        await lock.lock(FileLock.exclusive);
        return await action();
      } finally {
        await lock.unlock();
        await lock.close();
      }
    } on MasterKeyUnavailableException {
      rethrow;
    } on FileSystemException {
      throw const MasterKeyUnavailableException();
    }
  }

  Future<void> _restrictDirectoryPermissions(Directory directory) async {
    if (!(Platform.isMacOS || Platform.isLinux)) return;
    await _chmod('700', directory.path);
  }

  Future<void> _restrictFilePermissions(File file) async {
    if (!(Platform.isMacOS || Platform.isLinux)) return;
    await _chmod('600', file.path);
  }

  Future<void> _chmod(String mode, String path) async {
    try {
      final result = await Process.run('/bin/chmod', [mode, path]);
      if (result.exitCode != 0) {
        throw const MasterKeyUnavailableException();
      }
    } catch (_) {
      throw const MasterKeyUnavailableException();
    }
  }

  Future<Uint8List> _read(File file) async {
    await _restrictFilePermissions(file);
    final bytes = await file.readAsBytes();
    if (bytes.length != keyLength) {
      throw const MasterKeyUnavailableException();
    }
    return bytes;
  }

  SecretKey _cache(List<int> bytes) {
    final key = SecretKeyData(Uint8List.fromList(bytes));
    _cachedKey = key;
    return key;
  }

  static List<int> _generateSecureRandomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
